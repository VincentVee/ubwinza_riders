// lib/navigation/navigation_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'navigation.dart';

class NavigationController {
  final NavigationService navigationService;
  final FlutterTts tts = FlutterTts();

  // Map Control
  Completer<GoogleMapController> mapController = Completer();
  LatLng? currentLocation;
  LatLng? lastLocation;

  // Route & Steps
  List<LatLng> routePoints = [];
  List<Map<String, dynamic>> steps = [];
  int currentStepIndex = 0;

  // ETA
  String eta = "";
  String distance = "";

  // Trail Behind (Grey)
  List<LatLng> passedTrail = [];

  // Camera / user interaction
  bool isUserInteracting = false;
  double lastBearing = 0;

  // Rerouting
  DateTime? lastRerouteTime;

  // Stream
  StreamSubscription<Position>? gpsStream;

  // Speech Throttle
  String lastSpoken = "";
  DateTime lastSpeechTime = DateTime.now().subtract(const Duration(seconds: 10));
  final List<int> ttsTriggerDistances = [300, 150, 80, 40, 20];
  int lastDistanceBucket = -1;

  NavigationController({required this.navigationService});

  // ------------------------------------------------------------
  // INITIALIZATION
  // ------------------------------------------------------------

  Future<void> initTTS() async {
    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.45);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(true);
  }

  Future<void> startLocationTracking(Function() onLocationUpdate) async {
    gpsStream?.cancel();

    gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((pos) async {
      currentLocation = LatLng(pos.latitude, pos.longitude);

      passedTrail.add(currentLocation!);

      await onLocationUpdate();
    });
  }

  // ------------------------------------------------------------
  // LOAD ROUTE FROM GOOGLE DIRECTIONS
  // ------------------------------------------------------------

  Future<bool> loadRoute(LatLng origin, LatLng destination) async {
    final result = await navigationService.getRoute(origin, destination);
    if (result == null) return false;

    routePoints = result.polylinePoints;
    steps = result.steps;
    eta = result.eta;
    distance = result.distance;
    currentStepIndex = 0;

    return true;
  }

  // ------------------------------------------------------------
  // CAMERA FOLLOWING — GOOGLE MAPS NAVIGATION MODE
  // ------------------------------------------------------------

  Future<void> followCamera() async {
    if (currentLocation == null) return;
    if (isUserInteracting) return;

    final controller = await mapController.future;

    double bearing = lastBearing;

    if (lastLocation != null) {
      final moved = Geolocator.distanceBetween(
        lastLocation!.latitude,
        lastLocation!.longitude,
        currentLocation!.latitude,
        currentLocation!.longitude,
      );

      if (moved > 1) {
        bearing = Geolocator.bearingBetween(
          lastLocation!.latitude,
          lastLocation!.longitude,
          currentLocation!.latitude,
          currentLocation!.longitude,
        );
        lastBearing = bearing;
      }
    }

    lastLocation = currentLocation;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentLocation!,
          zoom: 17.5,
          tilt: 60, // NAVIGATION MODE TILT
          bearing: bearing,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // OFF ROUTE DETECTION
  // ------------------------------------------------------------

  bool isOffRoute(LatLng pos) {
    double minDist = 999999;

    for (final p in routePoints) {
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < minDist) minDist = d;
    }

    return minDist > 40; // Only recalc if truly off route
  }

  // ------------------------------------------------------------
  // STEP / TURN ANNOUNCER
  // ------------------------------------------------------------

  Future<void> announceStep(Function updateInstruction) async {
    if (steps.isEmpty || currentStepIndex >= steps.length) return;
    if (currentLocation == null) return;

    final step = steps[currentStepIndex];
    final end = LatLng(step['endLat'], step['endLng']);
    final instruction = step['instruction'];
    final maneuver = step['maneuver'] ?? "";

    double dist = Geolocator.distanceBetween(
      currentLocation!.latitude,
      currentLocation!.longitude,
      end.latitude,
      end.longitude,
    );

    // ROUNDABOUT
    if (maneuver.contains("roundabout")) {
      int exitNum = extractRoundaboutExit(step['rawHtml'] ?? "");

      String spoken;
      if (dist > 40) {
        spoken = exitNum > 0
            ? "At the roundabout, take the ${exitNum}th exit."
            : "Approaching a roundabout.";
      } else {
        spoken = exitNum > 0
            ? "Take the ${exitNum}th exit."
            : "Exit the roundabout.";
        HapticFeedback.mediumImpact();
        currentStepIndex++;
      }

      updateInstruction(spoken);
      await speakOnce(spoken);
      return;
    }

    // NORMAL TURNS
    int bucket = ttsTriggerDistances.firstWhere(
          (d) => dist >= d,
      orElse: () => 0,
    );

    if (bucket == lastDistanceBucket && bucket != 0) return;

    String spoken;

    if (bucket > 20) {
      spoken = "In $bucket meters, $instruction";
    } else if (dist < 20) {
      spoken = instruction;
      HapticFeedback.mediumImpact();
      currentStepIndex++;
    } else {
      return;
    }

    lastDistanceBucket = bucket;
    updateInstruction(spoken);
    await speakOnce(spoken);
  }

  // ------------------------------------------------------------
  // TTS THROTTLE
  // ------------------------------------------------------------

  Future<void> speakOnce(String text) async {
    if (text == lastSpoken) return;
    if (DateTime.now().difference(lastSpeechTime).inSeconds < 5) return;

    lastSpoken = text;
    lastSpeechTime = DateTime.now();
    await tts.speak(text);
  }

  // ------------------------------------------------------------
  // ROUNDABOUT EXIT EXTRACTION
  // ------------------------------------------------------------

  int extractRoundaboutExit(String html) {
    final m = RegExp(r'(\d+)(st|nd|rd|th)').firstMatch(html);
    if (m != null) return int.tryParse(m.group(1)!) ?? 0;
    return 0;
  }

  // ------------------------------------------------------------
  // CLEANUP
  // ------------------------------------------------------------

  void dispose() {
    gpsStream?.cancel();
    tts.stop();
  }
}
