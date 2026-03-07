import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationUpdater {
  Timer? _locationUpdateTimer;
  final CollectionReference _driverCollection = 
      FirebaseFirestore.instance.collection('riders'); 
      // Ensure 'riders' matches your collection name
  
  static const Duration _updateInterval = Duration(seconds: 10);

  /// 🚀 Starts the 10-second periodic location update.
  /// 
  /// This must be called when the driver goes online or starts a ride.
  void startLocationUpdates() {
    final driverUid = FirebaseAuth.instance.currentUser?.uid;
    if (driverUid == null) {
      debugPrint('🛑 Driver not logged in. Cannot start tracking.');
      return;
    }

    // Stop any existing timer to prevent duplicates
    stopLocationUpdates(); 

    // 1. Run immediately on start
    _fetchAndSendLocation(driverUid);

    // 2. Set up the recurring timer
    _locationUpdateTimer = Timer.periodic(
      _updateInterval,
      (Timer t) => _fetchAndSendLocation(driverUid),
    );
    debugPrint('✅ Location tracking started every 10 seconds.');
  }

  /// 🛑 Stops the periodic location updating process.
  /// 
  /// This must be called in the widget's dispose() or when the driver goes offline.
  void stopLocationUpdates() {
    if (_locationUpdateTimer != null) {
      _locationUpdateTimer!.cancel();
      _locationUpdateTimer = null;
      debugPrint('❌ Location tracking stopped.');
    }
  }

  /// 🌍 Fetches the current location and updates Firestore.
  Future<void> _fetchAndSendLocation(String driverUid) async {
    try {
      // 1. Permissions and Services Check
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (!serviceEnabled || permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location services or permissions insufficient. Skipping update.');
        // Consider stopping tracking if permissions are permanently lost
        return;
      }

      // 2. Get Position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Update Firestore
      await _driverCollection.doc(driverUid).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastUpdateTime': FieldValue.serverTimestamp(),
      });

      debugPrint('📍 Updated: Lat ${position.latitude}, Lng ${position.longitude}');
      
    } catch (e) {
      debugPrint('🚨 Error fetching or updating location: $e');
    }
  }
}