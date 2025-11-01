import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubwinza_riders/features/services/app_service_life_cycle.dart';
import 'package:ubwinza_riders/views/splashScreen/splash_screen.dart';

import 'global/global_vars.dart';

// Add this global variable
AppLifecycleService? appLifecycleService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  sharedPreferences = await SharedPreferences.getInstance();

  // Initialize app lifecycle service
  appLifecycleService = AppLifecycleService(sharedPreferences!);

  await Permission.locationWhenInUse.isDenied.then((valueOfPermission) {
    if(valueOfPermission) {
      Permission.locationWhenInUse.request();
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Set user online when app starts
    _setInitialOnlineStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLifecycleService?.didChangeAppLifecycleState(state);
  }

  Future<void> _setInitialOnlineStatus() async {
    // Wait a bit for Firebase auth to initialize
    await Future.delayed(const Duration(seconds: 1));
    
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await appLifecycleService?.setUserOnline();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ubwinza Rider App',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MySplashScreen(),
    );
  }
}