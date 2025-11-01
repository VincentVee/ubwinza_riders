import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class AppLifecycleService with WidgetsBindingObserver {
  final SharedPreferences sharedPreferences;
  
  AppLifecycleService(this.sharedPreferences);
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground - set online
        _updateOnlineStatus(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is in background - set offline
        _updateOnlineStatus(false);
        break;
      case AppLifecycleState.detached:
        // App is closed - set offline
        _updateOnlineStatus(false);
        break;
      case AppLifecycleState.hidden:
        // App is hidden - set offline
        _updateOnlineStatus(false);
        break;
    }
  }
  
  Future<void> _updateOnlineStatus(bool isOnline) async {
    try {
      final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection("riders")
            .doc(currentUser.uid)
            .update({
          "isOnline": isOnline
        });
        
        await sharedPreferences.setBool("isOnline", isOnline);
      }
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }
  
  // Call this when user explicitly logs out
  Future<void> setUserOffline() async {
    await _updateOnlineStatus(false);
  }
  
  // Call this when user logs in or app starts
  Future<void> setUserOnline() async {
    await _updateOnlineStatus(true);
  }
}