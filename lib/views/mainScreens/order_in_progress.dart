import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../../global/global_vars.dart';

// ⭐ RENAMED CLASS: ParcelInProgressScreen -> OrdersInProgress
class OrdersInProgress extends StatefulWidget {
  final String requestId;
  final String initialStatus;

  const OrdersInProgress({
    super.key,
    required this.requestId,
    this.initialStatus = 'accepted',
  });

  @override
  State<OrdersInProgress> createState() =>
      _OrdersInProgressState();
}

class _OrdersInProgressState extends State<OrdersInProgress> {
  // Google Map
  final Completer<GoogleMapController> _controller = Completer();

  // Firebase Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // TTS
  final FlutterTts _tts = FlutterTts();

  // Request Data
  Map<String, dynamic>? requestData;

  // Map Elements
  Set<Marker> _markers = {};
  List<LatLng> _currentRoute = [];
  Set<Polyline> _polylines = {};

  // Navigation Steps
  List<Map<String, dynamic>> _navSteps = [];
  int _currentStepIndex = 0;

  // Navigation Status
  String _tripStage = "idle";
  bool _isLoading = true;
  bool _canProceedToDestination = false;
  bool _disposed = false;
  // ⭐ NEW: For Start Ride button loader
  bool _isRouting = false;

  // ETA & Distance
  String _etaText = "";
  String _distanceText = "";

  // Location Tracking
  Timer? _locationTimer;
  LatLng? _currentLocation;
  LatLng? _lastLocation;

  // Camera Control
  LatLng? _routeTarget;
  double _lastBearing = 0;

  // ⭐ KEY FIX: Controls whether map snaps to driver or stays put
  bool _autoCameraEnabled = true;

  // Rerouting
  DateTime? _lastRerouteTime;

  // UI Instruction
  String _currentInstruction = "Waiting for route...";

  // Night Mode
  bool _forceNightMode = false;

  // Night Map Style
  static const String nightMapJson = '''
[
  {"elementType": "geometry","stylers": [{"color": "#1d1d1d"}]},
  {"elementType": "labels.icon","stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill","stylers": [{"color": "#8e8e8e"}]},
  {"elementType": "labels.text.stroke","stylers": [{"color": "#1d1d1d"}]},
  {"featureType": "road","elementType": "geometry","stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#ffffff"}]},
  {"featureType": "water","elementType": "geometry","stylers": [{"color": "#181818"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _tripStage = "idle";
    _initTTS();
    _loadRequestData();
  }

  void _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    _disposed = true;
    _locationTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadRequestData() async {
    try {
      final doc = await _firestore
          .collection('orders')
          .doc(widget.requestId)
          .get();

      if (!doc.exists) throw Exception("Order not found");

      requestData = doc.data();

      // ⭐ MODIFIED: Use nested 'seller' for pickup coordinates
      final pickup = LatLng(
        requestData!['seller']['lat'],
        requestData!['seller']['lng'],
      );

      // ⭐ MODIFIED: Use nested 'dropoff' for destination coordinates
      final destination = LatLng(
        requestData!['dropoff']['lat'],
        requestData!['dropoff']['lng'],
      );

      // Preview Polyline
      await _getPolyline(
        pickup,
        destination,
        Colors.blueAccent,
        'previewRoute',
        buildNavSteps: false,
      );

      _setMarkers(pickup, destination);

      if (!_disposed) {
        setState(() {
          _isLoading = false;
          _currentInstruction =
              "Tap 'Start Ride' to begin navigation to pickup.";
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading request: $e')),
      );
    }
  }

  // ---------------------------
  // GOOGLE DIRECTIONS
  // ---------------------------

  Future<void> _getPolyline(
      LatLng origin,
      LatLng destination,
      Color color,
      String id, {
        bool buildNavSteps = true,
      }) async {
    // NOTE: `global_vars.dart` must contain `googleApiKey`
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$googleApiKey';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return;

    final data = json.decode(res.body);
    final routes = data['routes'] as List;
    if (routes.isEmpty) return;

    final route = routes.first;
    final encoded = route['overview_polyline']['points'];
    final points = _decodePolyline(encoded);

    final legs = route['legs'] as List;
    final leg = legs.first;

    _etaText = leg['duration']['text'];
    _distanceText = leg['distance']['text'];

    if (buildNavSteps) {
      _currentRoute = points;
      _navSteps.clear();

      for (final step in leg['steps']) {
        final end = step['end_location'];
        final lanes = step['lanes'] ?? [];

        _navSteps.add({
          'instruction': step['html_instructions'] ?? '',
          'endLat': end['lat'],
          'endLng': end['lng'],
          'maneuver': step['maneuver'] ?? "",
          'lanes': lanes,
        });
      }

      _currentStepIndex = 0;
      if (_navSteps.isNotEmpty) {
        _currentInstruction = _stripHtml(_navSteps.first['instruction']);
      }
    }

    final polyline = Polyline(
      polylineId: PolylineId(id),
      points: points,
      width: 6,
      color: color,
    );

    if (!_disposed) {
      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value == id);
        _polylines.add(polyline);
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return poly;
  }

  // ---------------------------
  // START RIDE
  // ---------------------------

  Future<void> _startRide() async {
    // ⭐ START OF CHANGE: Set loading state
    setState(() {
      _isRouting = true;
    });

    await _tts.speak("Starting your ride.");

    await _firestore.collection('orders').doc(widget.requestId).update({
      'status': 'in-progress',
      'startedAt': DateTime.now(),
    });

    final pos = await Geolocator.getCurrentPosition();
    _currentLocation = LatLng(pos.latitude, pos.longitude);

    // Initial driver location push
    await _firestore.collection('orders').doc(widget.requestId).update({
      'driverLat': _currentLocation!.latitude,
      'driverLog': _currentLocation!.longitude,
    });


    // ⭐ MODIFIED: Use nested 'seller' for pickup coordinates
    final pickup = LatLng(
      requestData!['seller']['lat'],
      requestData!['seller']['lng'],
    );

    _routeTarget = pickup;

    // This is the long-running operation that needs the loader
    await _getPolyline(
      _currentLocation!,
      _routeTarget!,
      Colors.green,
      "activeRoute",
      buildNavSteps: true,
    );

    // ⭐ END OF CHANGE: Clear loading state and set new trip stage
    setState(() {
      _tripStage = "to_pickup";
      _autoCameraEnabled = true; // Enable auto-follow on start
      _isRouting = false;
    });

    _startLocationTracking();
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    // Update location every 1 second
    _locationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateDriverLocation();
    });
  }

  // ---------------------------
  // REAL-TIME LOCATION UPDATES
  // ---------------------------

  Future<void> _updateDriverLocation() async {
    if (_tripStage == 'idle' || _tripStage == 'arrived') return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(pos.latitude, pos.longitude);

      // PUSHING NEW LAT/LNG TO FIRESTORE
      await _firestore.collection('orders').doc(widget.requestId).update({
        'driverLat': _currentLocation!.latitude,
        'driverLng': _currentLocation!.longitude,
        // Optional: Add timestamp for last update
        // 'lastLocationUpdate': FieldValue.serverTimestamp(),
      });


      // ⭐ MODIFIED: Use nested 'seller' for pickup coordinates
      final pickup = LatLng(
        requestData!['seller']['lat'],
        requestData!['seller']['lng'],
      );

      // ⭐ MODIFIED: Use nested 'dropoff' for destination coordinates
      final destination = LatLng(
        requestData!['dropoff']['lat'],
        requestData!['dropoff']['lng'],
      );

      _setMarkers(pickup, destination);

      // Only move camera if user hasn't disabled it
      if (_autoCameraEnabled) {
        await _smoothFollowCamera();
      }

      final distToPickup = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        pickup.latitude,
        pickup.longitude,
      );

      final distToDest = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        destination.latitude,
        destination.longitude,
      );

      // ARRIVING AT PICKUP
      if (_tripStage == "to_pickup") {
        // ⭐ REQUESTED CHANGE: Use 150 meters instead of 35 meters
        final canProceed = distToPickup < 150;

        if (canProceed && !_canProceedToDestination) {
          await _tts.speak("You have arrived at the pickup.");
          HapticFeedback.mediumImpact();
          setState(() {
            _currentInstruction =
                "Arrived at pickup. Confirm parcel and press 'Heading to Destination'.";
            _canProceedToDestination = true;
          });
        }
        // OPTIONAL: Added state reversal if driver moves away
        else if (!canProceed && _canProceedToDestination) {
          setState(() {
            _currentInstruction = "Move closer to the pickup (within 150m).";
            _canProceedToDestination = false;
          });
        }
      }

      // REROUTE IF OFF ROUTE
      if (_currentRoute.isNotEmpty &&
          _isOffRoute(_currentLocation!, _currentRoute)) {
        final now = DateTime.now();
        if (_lastRerouteTime == null ||
            now.difference(_lastRerouteTime!).inSeconds > 10) {
          _lastRerouteTime = now;
          setState(() => _currentInstruction = "Recalculating route...");

          await _getPolyline(
            _currentLocation!,
            _routeTarget!,
            Colors.green,
            "activeRoute",
            buildNavSteps: true,
          );

          await _tts.speak("Route recalculated.");
        }
      } else {
        await _announceNextTurn();
      }

      // ARRIVE AT DESTINATION
      if (_tripStage == "to_destination" && distToDest < 35) {
        await _tts.speak("You have arrived at the destination.");
        HapticFeedback.mediumImpact();

        setState(() {
          _tripStage = "arrived";
          _currentInstruction = "Arrived at destination.";
        });
      }
    } catch (e) {
      debugPrint("Location update error: $e");
    }
  }

  // ---------------------------
  // HEADING-ALIGNED CAMERA (STRAIGHT VIEW)
  // ---------------------------

  Future<void> _smoothFollowCamera() async {
    if (_currentLocation == null) return;

    final controller = await _controller.future;
    double bearing = _lastBearing;

    // Only update bearing if we moved significantly (> 5 meters)
    if (_lastLocation != null) {
      final dist = Geolocator.distanceBetween(
        _lastLocation!.latitude,
        _lastLocation!.longitude,
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      if (dist > 5) {
        bearing = Geolocator.bearingBetween(
          _lastLocation!.latitude,
          _lastLocation!.longitude,
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
        _lastBearing = bearing;
      }
    }

    _lastLocation = _currentLocation;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation!,
          zoom: 18,
          tilt: 0, // 0 = Flat/Straight View
          bearing: bearing, // Rotates map so "Up" is where you are going
        ),
      ),
    );
  }

  // ---------------------------
  // RE-CENTER ACTION
  // ---------------------------
  void _recenterCamera() {
    setState(() {
      _autoCameraEnabled = true;
    });
    _smoothFollowCamera();
  }

  // ---------------------------
  // TURN ANNOUNCER (UNCHANGED)
  // ---------------------------

  bool _isRoundaboutStep(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] ?? "";
    return maneuver.contains("roundabout");
  }

  int _extractRoundaboutExit(String instruction) {
    final match = RegExp(r'(\d+)(st|nd|rd|th)').firstMatch(instruction);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  String _lastSpoken = "";
  DateTime _lastSpeechTime = DateTime.now().subtract(const Duration(seconds: 10));
  final List<int> _ttsDistances = [300, 150, 80, 40, 20];
  int _lastDistanceBucket = -1;

  Future<void> _announceNextTurn() async {
    if (_currentLocation == null) return;
    if (_navSteps.isEmpty || _currentStepIndex >= _navSteps.length) return;

    final step = _navSteps[_currentStepIndex];
    final end = LatLng(step['endLat'], step['endLng']);
    final instruction = _stripHtml(step['instruction']);
    final dist = Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      end.latitude,
      end.longitude,
    );

    if (_isRoundaboutStep(step)) {
      final exit = _extractRoundaboutExit(instruction);
      String spoken;
      if (dist > 40) {
        spoken = exit > 0
            ? "At the roundabout, take the ${exit}th exit."
            : "Approaching a roundabout.";
      } else {
        spoken = exit > 0
            ? "Take the ${exit}th exit."
            : "Exit the roundabout.";
        HapticFeedback.mediumImpact();
        _currentStepIndex++;
      }
      if (spoken != _currentInstruction) setState(() => _currentInstruction = spoken);
      if (spoken != _lastSpoken && DateTime.now().difference(_lastSpeechTime).inSeconds >= 6) {
        _lastSpeechTime = DateTime.now();
        _lastSpoken = spoken;
        await _tts.speak(spoken);
      }
      return;
    }

    int bucket = _ttsDistances.firstWhere((d) => dist >= d, orElse: () => 0);
    if (bucket == _lastDistanceBucket && bucket != 0) return;

    String spokenText;
    if (bucket > 20) {
      spokenText = "In $bucket meters, $instruction";
    } else if (dist < 20) {
      spokenText = instruction;
      HapticFeedback.mediumImpact();
      _currentStepIndex++;
    } else {
      return;
    }

    setState(() => _currentInstruction = spokenText);
    _lastDistanceBucket = bucket;

    if (spokenText != _lastSpoken && DateTime.now().difference(_lastSpeechTime).inSeconds >= 6) {
      _lastSpeechTime = DateTime.now();
      _lastSpoken = spokenText;
      await _tts.speak(spokenText);
    }
  }

  // ---------------------------
  // UTILS
  // ---------------------------

  bool _isOffRoute(LatLng pos, List<LatLng> route) {
    double minDist = 999999;
    for (final point in route) {
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        point.latitude,
        point.longitude,
      );
      if (d < minDist) minDist = d;
    }
    return minDist > 40;
  }

  Future<void> _proceedToDestination() async {
    if (!_canProceedToDestination) {
      await _tts.speak("Move closer to the pickup first.");
      return;
    }

    // ⭐ OPTIONAL: Add loading state here too, as it involves route calc
    if (!_disposed) setState(() => _isRouting = true);

    // ⭐ MODIFIED: Use nested 'dropoff' for destination coordinates
    final destination = LatLng(requestData!['dropoff']['lat'], requestData!['dropoff']['lng']);
    
    _routeTarget = destination;
    await _tts.speak("Heading to destination.");
    await _firestore.collection('orders').doc(widget.requestId).update({'status': 'heading_to_destination'});
    await _getPolyline(_currentLocation!, destination, Colors.green, "activeRoute", buildNavSteps: true);

    // ⭐ OPTIONAL: Clear loading state here
    if (!_disposed) setState(() => _isRouting = false);

    setState(() {
      _tripStage = "to_destination";
      _canProceedToDestination = false;
      _autoCameraEnabled = true; // Re-enable auto follow
    });
  }

  Future<void> _completeRide() async {
    await _tts.speak("Ride completed.");
    await _firestore.collection('orders').doc(widget.requestId).update({
      'status': 'completed',
      'completedAt': DateTime.now(),
      'driverLat': null, // Clear driver location on completion
      'driverLng': null,
    });
    Navigator.pop(context);
  }

  Widget _laneGuidanceWidget(Map<String, dynamic> step) {
    final lanes = step['lanes'] as List<dynamic>?;
    if (lanes == null || lanes.isEmpty) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: lanes.map((lane) {
        final valid = lane['valid'] ?? false;
        final indication = (lane['indications'] as List).join(", ");
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: valid ? Colors.green : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            indication.toUpperCase(),
            style: TextStyle(color: valid ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }

  IconData _turnIcon(String maneuver) {
    switch (maneuver) {
      case "turn-left": return Icons.turn_left;
      case "turn-right": return Icons.turn_right;
      case "uturn-left": case "uturn-right": return Icons.u_turn_left;
      case "fork-left": return Icons.turn_slight_left;
      case "fork-right": return Icons.turn_slight_right;
      default: return Icons.straight;
    }
  }

  Widget _bigTurnArrow(String maneuver) {
    return Icon(_turnIcon(maneuver), size: 70, color: Colors.blueAccent);
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&');
  }

  void _setMarkers(LatLng pickup, LatLng destination) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        // ⭐ MODIFIED: Use nested 'seller' for pickup position
        position: LatLng(requestData!['seller']['lat'], requestData!['seller']['lng']),
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        // ⭐ MODIFIED: Use nested 'dropoff' for destination position
        position: LatLng(requestData!['dropoff']['lat'], requestData!['dropoff']['lng']),
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          rotation: _lastBearing, // Rotate icon to match car direction
        ),
      );
    }
    if (!_disposed) setState(() => _markers = markers);
  }

  Widget _buildActionButton() {
    // ⭐ NEW: Show loader if routing is in progress
    if (_isRouting) {
      return _loadingButton("Preparing Route...");
    }

    switch (_tripStage) {
      case "idle": return _button("Start Ride", primaryColor, _startRide);
      case "to_pickup": return _button("Heading to Destination", _canProceedToDestination ? Colors.green : Colors.grey, _canProceedToDestination ? _proceedToDestination : null);
      case "to_destination": return _button("Navigating to Destination", Colors.green, null);
      case "arrived": return _button("Complete Ride", Colors.teal, _completeRide);
      default: return const SizedBox();
    }
  }

  // ⭐ NEW: Loading Button Widget
  Widget _loadingButton(String text) {
    return ElevatedButton(
      onPressed: null, // Disable button while loading
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey, // Use a neutral color for loading
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.green,
              strokeWidth: 5,
            ),
          ),
          const SizedBox(width: 15),
          Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _button(String text, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }

  Future<void> _applyMapStyle() async {
    final controller = await _controller.future;
    if (_forceNightMode) controller.setMapStyle(nightMapJson);
    else controller.setMapStyle(null);
  }

  // ---------------------------
  // BUILD UI
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Ride Navigation", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_forceNightMode ? Icons.dark_mode : Icons.light_mode,
                color: Colors.white),
            onPressed: () {
              setState(() => _forceNightMode = !_forceNightMode);
              _applyMapStyle();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // FIX: Use Listener to detect user touch
          Listener(
            onPointerDown: (_) {
              setState(() {
                _autoCameraEnabled = false;
              });
            },
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                // ⭐ MODIFIED: Use nested 'seller' for initial camera target
                target: LatLng(requestData!['seller']['lat'], requestData!['seller']['lng']),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _controller.complete(controller);
                _applyMapStyle();
              },
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              markers: _markers,
              polylines: _polylines,
            ),
          ),

          // RE-CENTER BUTTON (Only shows if you moved the map)
          if (!_autoCameraEnabled &&
              _tripStage != "idle" &&
              _tripStage != "arrived")
            Positioned(
              bottom: 130, // Above the bottom button
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: _recenterCamera,
                backgroundColor: Colors.white,
                icon: const Icon(Icons.navigation, color: Colors.blue),
                label: const Text("Re-center",
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ),

          // Bottom Action Button
          Positioned(
              bottom: 65, left: 12, right: 12, child: _buildActionButton()),
        ],
      ),
    );
  }
}