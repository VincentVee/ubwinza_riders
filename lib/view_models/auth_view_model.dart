import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart' as fs_store;
import 'package:ubwinza_riders/main.dart';
import 'package:ubwinza_riders/views/splashScreen/splash_screen.dart';

import '../global/global_instances.dart';
import '../global/global_vars.dart';
import '../views/mainScreens/home_screen.dart';

// ------------------------------------------------------------------------
// ⭐ 1. MISSING RIDER USER MODEL (REQUIRED BY PROFILE SCREEN)
// ------------------------------------------------------------------------
class RiderUser {
  final String? uid;
  final String? name;
  final String? email;
  final String? imageUrl;
  final String? status;
  final String? phone;
  final String? vehicleType;
  final double? rating;
  final int? totalRides;

  RiderUser({
    this.uid,
    this.name,
    this.email,
    this.imageUrl,
    this.status,
    this.phone,
    this.vehicleType,
    this.rating,
    this.totalRides,
  });

  // Helper method to create RiderUser from Firestore data/SharedPreferences
  factory RiderUser.fromMap(Map<String, dynamic> data) {
    return RiderUser(
      uid: data["uid"],
      name: data["name"],
      email: data["email"],
      imageUrl: data["imageUrl"],
      status: data["status"],
      phone: data["phone"],
      vehicleType: data["vehicleType"],
      rating: (data["rating"] ?? 0.0).toDouble(),
      totalRides: (data["totalRides"] ?? 0).toInt(),
    );
  }
}

// ------------------------------------------------------------------------
// ⭐ 2. AUTH VIEW MODEL (EXTENDS ChangeNotifier for Profile Screen updates)
// ------------------------------------------------------------------------
class AuthViewModel with ChangeNotifier {
  RiderUser? _currentUser;
  final ImagePicker _picker = ImagePicker();

  // Load initial user data from shared preferences when AuthViewModel is created
  AuthViewModel() {
    _initializeUser();
  }

  void _initializeUser() {
    if (sharedPreferences!.containsKey("uid")) {
      _currentUser = RiderUser(
        uid: sharedPreferences!.getString("uid"),
        name: sharedPreferences!.getString("name"),
        email: sharedPreferences!.getString("email"),
        imageUrl: sharedPreferences!.getString("imageUrl"),
        status: sharedPreferences!.getString("status"),
        phone: sharedPreferences!.getString("phone"),
        vehicleType: sharedPreferences!.getString("vehicleType"),
        rating: sharedPreferences!.getDouble("rating"),
        totalRides: sharedPreferences!.getInt("totalRides"),
      );
    }
  }

  // ⭐ MISSING FUNCTION 1: getCurrentUser
  RiderUser getCurrentUser() {
    // Returns the current user model, initializing from SharedPreferences if null
    return _currentUser ?? RiderUser();
  }

  // ⭐ MISSING FUNCTION 2: pickImageAndUpdate
  Future<void> pickImageAndUpdate(BuildContext context) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) {
      commonViewModel.showSnackBar("No image selected.", context);
      return;
    }

    commonViewModel.showSnackBar("Uploading profile picture...", context);

    try {
      // 1. Upload new image
      final String downloadUrl = await uploadImageToFirebase(pickedFile);
      final uid = fb_auth.FirebaseAuth.instance.currentUser!.uid;

      // 2. Update Firestore
      await FirebaseFirestore.instance.collection("riders").doc(uid).update({
        "imageUrl": downloadUrl,
      });

      // 3. Update SharedPreferences
      await sharedPreferences!.setString("imageUrl", downloadUrl);

      // 4. Update local model and notify listeners
      _currentUser = RiderUser(
        uid: uid,
        name: _currentUser?.name,
        email: _currentUser?.email,
        imageUrl: downloadUrl, // New image URL
        status: _currentUser?.status,
        phone: _currentUser?.phone,
        vehicleType: _currentUser?.vehicleType,
        rating: _currentUser?.rating,
        totalRides: _currentUser?.totalRides,
      );
      notifyListeners();

      if (context.mounted) {
        commonViewModel.showSnackBar("Profile picture updated successfully!", context);
      }
    } catch (e) {
      debugPrint('Error updating profile picture: $e');
      if (context.mounted) {
        commonViewModel.showSnackBar("Failed to update picture: $e", context);
      }
    }
  }

  // ⭐ MISSING FUNCTION 3: updateUserName
  Future<void> updateUserName(String newName, BuildContext context) async {
    if (newName.trim().isEmpty) {
      commonViewModel.showSnackBar("Name cannot be empty.", context);
      return;
    }

    commonViewModel.showSnackBar("Updating name...", context);

    try {
      final uid = fb_auth.FirebaseAuth.instance.currentUser!.uid;

      // 1. Update Firestore
      await FirebaseFirestore.instance.collection("riders").doc(uid).update({
        "name": newName,
      });

      // 2. Update SharedPreferences
      await sharedPreferences!.setString("name", newName);

      // 3. Update local model and notify listeners
      _currentUser = RiderUser(
        uid: uid,
        name: newName, // New name
        email: _currentUser?.email,
        imageUrl: _currentUser?.imageUrl,
        status: _currentUser?.status,
        phone: _currentUser?.phone,
        vehicleType: _currentUser?.vehicleType,
        rating: _currentUser?.rating,
        totalRides: _currentUser?.totalRides,
      );
      notifyListeners();

      if (context.mounted) {
        commonViewModel.showSnackBar("Name updated successfully!", context);
      }
    } catch (e) {
      debugPrint('Error updating name: $e');
      if (context.mounted) {
        commonViewModel.showSnackBar("Failed to update name: $e", context);
      }
    }
  }
// ------------------------------------------------------------------------
// --- EXISTING FUNCTIONS (WITH MINOR ADJUSTMENTS) ---
// ------------------------------------------------------------------------

  Future<void> validateSignUpForm(
      XFile? image,
      String password,
      String confirm,
      String email,
      String name,
      String phone,
      String selectedVehicleType,
      String vehicleModel,
      String vehicleColor,
      String licensePlate,
      String locationAddress,
      BuildContext context,
      ) async {
    // ... (Existing validation logic) ...
    // Ensure image is selected
    if (image == null) {
      commonViewModel.showSnackBar(
          "Please select an image from gallery", context);
      return;
    }

    // Password confirmation
    if (password != confirm) {
      commonViewModel.showSnackBar(
          "Password and confirmation do not match!", context);
      return;
    }

    // Required for all users
    if (password.isEmpty ||
        confirm.isEmpty ||
        email.isEmpty ||
        name.isEmpty ||
        phone.isEmpty ||
        selectedVehicleType.isEmpty ||
        locationAddress.isEmpty) {
      commonViewModel.showSnackBar("Please enter all the required fields!", context);
      return;
    }

    // Vehicle field validation based on type
    if (selectedVehicleType == "motorbike") {
      if (vehicleModel.isEmpty ||
          vehicleColor.isEmpty ||
          licensePlate.isEmpty) {
        commonViewModel.showSnackBar(
            "Please enter vehicle model, color, and plate for a motorbike!",
            context);
        return;
      }
    } else if (selectedVehicleType == "bicycle") {
      // Allow optional values — no validation needed
      vehicleModel = vehicleModel.isEmpty ? "" : vehicleModel;
      vehicleColor = vehicleColor.isEmpty ? "" : vehicleColor;
      licensePlate = licensePlate.isEmpty ? "" : licensePlate;
    }

    // Email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      commonViewModel.showSnackBar("Please enter a valid email address", context);
      return;
    }

    // Zambian phone number validation
    final zambiaPhoneRegex = RegExp(r'^(?:\+260|0)\d{9}$');
    if (!zambiaPhoneRegex.hasMatch(phone)) {
      commonViewModel.showSnackBar(
          "Please enter a valid Zambian phone number (e.g., 097XXXXXXX or +260XXXXXXXXX)",
          context);
      return;
    }

    // GPS safety check
    final lat = position?.latitude;
    final lng = position?.longitude;
    if (lat == null || lng == null) {
      debugPrint('⚠️ position is null; saving without lat/lng');
    }

    commonViewModel.showSnackBar("Please wait...", context);

    // Create user in Firebase Auth
    final fb_auth.User? currentUser =
    await createUserInFirebase(email, password, context);

    if (currentUser == null) {
      fb_auth.FirebaseAuth.instance.signOut();
      return;
    }

    // Upload profile image
    final String downloadUrl = await uploadImageToFirebase(image);

    // Save user info to Firestore
    final ok = await saveUserToFireStore(
      currentUser: currentUser,
      downloadUrl: downloadUrl,
      email: email,
      name: name,
      phone: phone,
      selectedVehicleType: selectedVehicleType,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      licensePlate: licensePlate,
      locationAddress: locationAddress,
      latitude: lat,
      longitude: lng,
      context: context,
    );

    if (!ok) return;

    // ⭐ Update local model after successful sign up
    _currentUser = RiderUser.fromMap(await FirebaseFirestore.instance.collection("riders").doc(currentUser.uid).get().then((doc) => doc.data()!));
    notifyListeners();

    // Navigate after successful account creation
    if (context.mounted) {
      commonViewModel.showSnackBar("Account created successfully", context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    }
  }

  Future<fb_auth.User?> createUserInFirebase(
      String email, String password, BuildContext context) async {
    // ... (Existing createUserInFirebase logic) ...
    try {
      final cred = await fb_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      return cred.user;
    } on fb_auth.FirebaseAuthException catch (e) {
      commonViewModel.showSnackBar(e.message ?? e.code, context);
      return null;
    } catch (e) {
      commonViewModel.showSnackBar(e.toString(), context);
      return null;
    }
  }

  Future<String> uploadImageToFirebase(XFile image) async {
    // ... (Existing uploadImageToFirebase logic) ...
    final String fileName = DateTime.now().microsecondsSinceEpoch.toString();
    final fs_store.Reference ref =
    fs_store.FirebaseStorage.instance.ref().child('ridersimages/$fileName');

    final fs_store.UploadTask task = ref.putFile(File(image.path));
    final fs_store.TaskSnapshot snap = await task;
    final String url = await snap.ref.getDownloadURL();
    return url;
  }

  Future<bool> saveUserToFireStore({
    required fb_auth.User currentUser,
    required String downloadUrl,
    required String email,
    required String name,
    required String phone,
    required String selectedVehicleType,
    required String vehicleModel,
    required String vehicleColor,
    required String licensePlate,
    required String locationAddress,
    double? latitude,
    double? longitude,
    required BuildContext context,
  }) async {
    // ... (Existing saveUserToFireStore logic) ...
    try {
      await FirebaseFirestore.instance
          .collection("riders")
          .doc(currentUser.uid)
          .set({
        "uid": currentUser.uid,
        "imageUrl": downloadUrl,
        "email": email,
        "name": name,
        "phone": phone,
        "vehicleType": selectedVehicleType,
        "vehicleModel": vehicleModel,
        "vehicleColor": vehicleColor,
        "licensePlate": licensePlate,
        "address": locationAddress,
        "earnings": 0.0,
        "rating": 5.0,
        "totalRides": 0,
        if (latitude != null) "latitude": latitude,
        if (longitude != null) "longitude": longitude,
        "createdAt": FieldValue.serverTimestamp(),
        "status": "approved",
        "isOnline": true
      }, SetOptions(merge: true));

      // Save locally (SharedPreferences)
      await sharedPreferences!.setString("uid", currentUser.uid);
      await sharedPreferences!.setString("email", email);
      await sharedPreferences!.setString("name", name);
      await sharedPreferences!.setString("imageUrl", downloadUrl);
      await sharedPreferences!.setString("phone", phone);
      await sharedPreferences!.setString("vehicleType", selectedVehicleType);
      await sharedPreferences!.setString("vehicleModel", vehicleModel);
      await sharedPreferences!.setString("vehicleColor", vehicleColor);
      await sharedPreferences!.setString("licensePlate", licensePlate);
      await sharedPreferences!.setString("address", locationAddress);
      await sharedPreferences!.setString("status", _currentUser!.status!);
      await sharedPreferences!.setBool("isOnline", true);
      await sharedPreferences!.setDouble("rating", 5.0); // Default rating
      await sharedPreferences!.setInt("totalRides", 0);

      return true;
    } on FirebaseException catch (e) {
      commonViewModel.showSnackBar(
        "Firestore error: ${e.message ?? e.code}",
        context,
      );
      debugPrint('Firestore error: $e');
      return false;
    } catch (e) {
      commonViewModel.showSnackBar(e.toString(), context);
      debugPrint('Unexpected error saving rider: $e');
      return false;
    }
  }

  Future<void> validateSignInForm(
      String email, String password, BuildContext context) async {
    // ... (Existing validateSignInForm logic) ...
    if (email.isEmpty || password.isEmpty) {
      commonViewModel.showSnackBar("Email and Password are required!", context);
      return;
    }

    commonViewModel.showSnackBar("Checking your credentials...!", context);

    fb_auth.User? currentFirebaseUser =
    await signInUser(email, password, context);

    if (currentFirebaseUser == null) return;

    await readDataFromFirestoreAndSetDataLocally(currentFirebaseUser, context);

    // ⭐ After reading data, update the local model
    _initializeUser();
    notifyListeners();

    Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));

    commonViewModel.showSnackBar("Signed in successfully...!", context);
  }

  Future<fb_auth.User?> signInUser(
      String email, String password, BuildContext context) async {
    // ... (Existing signInUser logic) ...
    fb_auth.User? currentUser;

    await fb_auth.FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password)
        .then((valueAuth) {
      currentUser = valueAuth.user;
    }).catchError((errorMsg) {
      commonViewModel.showSnackBar(errorMsg.toString(), context);
    });

    if (currentUser == null) {
      fb_auth.FirebaseAuth.instance.signOut();
      return null;
    }

    return currentUser;
  }

  Future<void> readDataFromFirestoreAndSetDataLocally(
      fb_auth.User currentFirebaseUser, BuildContext context) async {
    // ... (Existing readDataFromFirestoreAndSetDataLocally logic) ...
    await FirebaseFirestore.instance
        .collection("riders")
        .doc(currentFirebaseUser.uid)
        .get()
        .then((dataSnapshot) async {
      if (dataSnapshot.exists) {
        final data = dataSnapshot.data()!;

        if (data["status"] == "approved") {
          await appLifecycleService?.setUserOnline();

          await sharedPreferences!.setString("uid", currentFirebaseUser.uid);
          await sharedPreferences!.setString("email", data["email"]);
          await sharedPreferences!.setString("name", data["name"]);
          await sharedPreferences!.setString("imageUrl", data["imageUrl"]);
          await sharedPreferences!.setString("phone", data["phone"] ?? "");
          await sharedPreferences!.setString(
              "vehicleType", data["vehicleType"] ?? "motorbike");
          await sharedPreferences!.setString(
              "vehicleModel", data["vehicleModel"] ?? "");
          await sharedPreferences!.setString(
              "vehicleColor", data["vehicleColor"] ?? "");
          await sharedPreferences!.setString(
              "licensePlate", data["licensePlate"] ?? "");
          await sharedPreferences!.setString(
              "address", data["address"] ?? "");
          await sharedPreferences!.setDouble(
              "rating", (data["rating"] ?? 5.0).toDouble());
          await sharedPreferences!
              .setInt("totalRides", (data["totalRides"] ?? 0).toInt());
          await sharedPreferences!.setString("status", data["status"]);
          await sharedPreferences!.setBool("isOnline", data["isOnline"]);

        } else {
          commonViewModel.showSnackBar("You are blocked by admin!", context);
          fb_auth.FirebaseAuth.instance.signOut();
        }
      } else {
        commonViewModel.showSnackBar(
            "This rider record does not exist", context);
        fb_auth.FirebaseAuth.instance.signOut();
      }
    }).catchError((error) {
      commonViewModel.showSnackBar("Error reading data: ${error.toString()}", context);
      fb_auth.FirebaseAuth.instance.signOut();
    });
  }

  Future<void> logout(BuildContext context) async {
    // ... (Existing logout logic) ...
    try {
      await appLifecycleService?.setUserOffline();

      await sharedPreferences!.clear();
      _currentUser = null; // Clear local model

      await fb_auth.FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MySplashScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (context.mounted) {
        commonViewModel.showSnackBar("Error during logout", context);
      }
    }
  }
}