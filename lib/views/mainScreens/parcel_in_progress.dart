import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../global/global_vars.dart';

class ParcelInProgressScreen extends StatefulWidget {
  final String requestId;
  final String initialStatus;

  const ParcelInProgressScreen({
    super.key,
    required this.requestId,
    this.initialStatus = 'accepted',
  });

  @override
  State<ParcelInProgressScreen> createState() =>
      _ParcelInProgressScreenState();
}

class _ParcelInProgressScreenState extends State<ParcelInProgressScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterTts _tts = FlutterTts();

  Map<String, dynamic>? requestData;
  Set<Marker> _markers = {};
  List<LatLng> _currentRoute = [];
  Set<Polyline> _polylines = {};
  String _tripStage = 'idle'; // idle → to_pickup → to_destination → arrived
  bool _isLoading = true;
  Timer? _locationTimer;
  LatLng? _currentLocation;
  LatLng? _lastLocation;
  DateTime? _lastCameraUpdate;
  DateTime? _lastRerouteTime;
  bool _canProceedToDestination = false;

  @override
  void initState() {
    super.initState();
    _initTTS();
    _loadRequestData();
  }

  void _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.4);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadRequestData() async {
    try {
      final doc =
      await _firestore.collection('requests').doc(widget.requestId).get();
      if (!doc.exists) throw Exception("Request not found");

      requestData = doc.data();

      final pickup = LatLng(requestData!['pickupLat'], requestData!['pickupLng']);
      final destination =
      LatLng(requestData!['destinationLat'], requestData!['destinationLng']);

      await _getPolyline(pickup, destination, Colors.blueAccent, 'pickupToDest');
      _setMarkers(pickup, destination);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading request: $e')));
    }
  }

  void _setMarkers(LatLng pickup, LatLng destination) {
    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
    if (_currentLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
  }

  Future<void> _getPolyline(
      LatLng origin, LatLng destination, Color color, String id) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$googleApiKey';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return;

    final data = json.decode(res.body);
    final routes = data['routes'] as List;
    if (routes.isEmpty) return;

    final encoded = routes.first['overview_polyline']['points'];
    final points = _decodePolyline(encoded);

    _currentRoute = points; // save route points for deviation detection

    final polyline = Polyline(
      polylineId: PolylineId(id),
      color: color,
      width: 7,
      points: points,
    );

    setState(() {
      _polylines.removeWhere((p) => p.polylineId.value == id);
      _polylines.add(polyline);
    });
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

  Future<void> _startRide() async {
    await _tts.speak("Starting your ride. Head to pickup location.");
    final pos = await Geolocator.getCurrentPosition();
    _currentLocation = LatLng(pos.latitude, pos.longitude);

    final pickup = LatLng(requestData!['pickupLat'], requestData!['pickupLng']);
    await _getPolyline(_currentLocation!, pickup, Colors.green, 'toPickup');

    setState(() {
      _tripStage = 'to_pickup';
      _canProceedToDestination = false;
    });

    _startLocationTracking();
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      await _updateDriverLocation();
    });
  }

  Future<void> _updateDriverLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _currentLocation = LatLng(pos.latitude, pos.longitude);

      final pickup = LatLng(requestData!['pickupLat'], requestData!['pickupLng']);
      final destination =
      LatLng(requestData!['destinationLat'], requestData!['destinationLng']);

      _setMarkers(pickup, destination);
      await _smoothFollowCamera();

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

      // Enable button near pickup
      if (_tripStage == 'to_pickup') {
        setState(() => _canProceedToDestination = distToPickup < 40);
      }

      // Stop spam rerouting — only if off route > 50m
      if (_currentRoute.isNotEmpty && _isOffRoute(_currentLocation!, _currentRoute)) {
        final now = DateTime.now();
        if (_lastRerouteTime == null ||
            now.difference(_lastRerouteTime!).inSeconds > 20) {
          _lastRerouteTime = now;
          final target = _tripStage == 'to_pickup' ? pickup : destination;
          await _getPolyline(_currentLocation!, target, Colors.green,
              _tripStage == 'to_pickup' ? 'toPickup' : 'toDestination');
          await _tts.speak("Route recalculated. Continue on the new path.");
        }
      }

      if (_tripStage == 'to_destination' && distToDest < 40) {
        await _tts.speak("You have arrived at your destination.");
        setState(() => _tripStage = 'arrived');
      }
    } catch (e) {
      debugPrint('Location update error: $e');
    }
  }

  bool _isOffRoute(LatLng pos, List<LatLng> route) {
    double minDistance = double.infinity;
    for (final point in route) {
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        point.latitude,
        point.longitude,
      );
      if (d < minDistance) minDistance = d;
    }
    return minDistance > 50; // reroute only if > 50m off the route
  }

  Future<void> _smoothFollowCamera() async {
    final now = DateTime.now();
    if (_lastCameraUpdate != null &&
        now.difference(_lastCameraUpdate!).inSeconds < 3) return;
    _lastCameraUpdate = now;

    final controller = await _controller.future;
    double bearing = 0;
    if (_lastLocation != null) {
      final dx = _currentLocation!.longitude - _lastLocation!.longitude;
      final dy = _currentLocation!.latitude - _lastLocation!.latitude;
      bearing = (Math.atan2(dx, dy) * 180 / Math.pi);
    }
    _lastLocation = _currentLocation;

    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: _currentLocation!,
        zoom: 19.5,
        tilt: 80,
        bearing: bearing,
      ),
    ));
  }

  Future<void> _proceedToDestination() async {
    if (!_canProceedToDestination) {
      await _tts.speak("You need to get closer to the pickup before proceeding.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Move closer to the pickup first.")),
      );
      return;
    }

    final pickup = LatLng(requestData!['pickupLat'], requestData!['pickupLng']);
    final destination =
    LatLng(requestData!['destinationLat'], requestData!['destinationLng']);

    await _tts.speak("Heading to destination.");
    await _getPolyline(pickup, destination, Colors.green, 'toDestination');

    await _firestore
        .collection('requests')
        .doc(widget.requestId)
        .update({'status': 'heading_to_destination'});

    setState(() {
      _tripStage = 'to_destination';
      _canProceedToDestination = false;
    });
  }

  Future<void> _completeRide() async {
    await _tts.speak("Ride completed successfully.");
    _locationTimer?.cancel();
    await _firestore
        .collection('requests')
        .doc(widget.requestId)
        .update({'status': 'completed'});
    if (mounted) Navigator.pop(context);
  }

  Widget _buildActionButton() {
    switch (_tripStage) {
      case 'idle':
        return _button("Start Ride", Colors.blue, _startRide);
      case 'to_pickup':
        return _button(
          "Heading to Destination",
          _canProceedToDestination ? Colors.green : Colors.lightBlueAccent,
          _proceedToDestination,
        );
      case 'to_destination':
        return _button("Heading to Destination", Colors.green, null);
      case 'arrived':
        return _button("Complete Ride", Colors.teal, _completeRide);
      default:
        return const SizedBox();
    }
  }

  Widget _button(String text, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final pickup = requestData?['pickupAddress'] ?? 'N/A';
    final dest = requestData?['destinationAddress'] ?? 'N/A';
    final user = requestData?['userName'] ?? 'Customer';

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Navigation'), backgroundColor: Colors.green),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(requestData!['pickupLat'], requestData!['pickupLng']),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (c) => _controller.complete(c),
          ),
          Positioned(
            bottom: 140,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Passenger: $user',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Pickup: $pickup', style: const TextStyle(fontSize: 14)),
                  Text('Destination: $dest',
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 12,
            right: 12,
            child: _buildActionButton(),
          ),
        ],
      ),
    );
  }
}
