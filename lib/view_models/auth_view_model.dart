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
import '../views/mainScreens/pending_approval.dart';

// Rider User Model
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
  final double? balance;
  final double? commission;

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
    this.balance,
    this.commission
  });

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
      balance: (data["balance"] ?? 0.0).toDouble(),
      commission: (data["commission"] ?? 0.0).toDouble(),
      totalRides: (data["totalRides"] ?? 0).toInt(),
    );
  }
}

class AuthViewModel with ChangeNotifier {
  RiderUser? _currentUser;
  final ImagePicker _picker = ImagePicker();

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
        balance: sharedPreferences!.getDouble("balance"),
        commission: sharedPreferences!.getDouble("commission"),
        totalRides: sharedPreferences!.getInt("totalRides"),
      );
    }
  }

  RiderUser getCurrentUser() {
    return _currentUser ?? RiderUser();
  }

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
      final String downloadUrl = await uploadImageToFirebase(pickedFile);
      final uid = fb_auth.FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection("riders").doc(uid).update({
        "imageUrl": downloadUrl,
      });

      await sharedPreferences!.setString("imageUrl", downloadUrl);

      _currentUser = RiderUser(
        uid: uid,
        name: _currentUser?.name,
        email: _currentUser?.email,
        imageUrl: downloadUrl,
        status: _currentUser?.status,
        phone: _currentUser?.phone,
        vehicleType: _currentUser?.vehicleType,
        rating: _currentUser?.rating,
        balance: _currentUser?.balance,
        commission: _currentUser?.commission,
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

  Future<void> updateUserName(String newName, BuildContext context) async {
    if (newName.trim().isEmpty) {
      commonViewModel.showSnackBar("Name cannot be empty.", context);
      return;
    }

    commonViewModel.showSnackBar("Updating name...", context);

    try {
      final uid = fb_auth.FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection("riders").doc(uid).update({
        "name": newName,
      });

      await sharedPreferences!.setString("name", newName);

      _currentUser = RiderUser(
        uid: uid,
        name: newName,
        email: _currentUser?.email,
        imageUrl: _currentUser?.imageUrl,
        status: _currentUser?.status,
        phone: _currentUser?.phone,
        vehicleType: _currentUser?.vehicleType,
        rating: _currentUser?.rating,
        balance: _currentUser?.balance,
        commission: _currentUser?.commission,
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

  Future<void> validateSignUpForm(
      XFile? profileImage,
      XFile? nrcFrontImage,
      XFile? nrcBackImage,
      String nrcNumber,
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
    // Validate profile image
    if (profileImage == null) {
      commonViewModel.showSnackBar("Please select a profile image", context);
      return;
    }

    // Validate NRC images
    if (nrcFrontImage == null || nrcBackImage == null) {
      commonViewModel.showSnackBar("Please upload both sides of your NRC", context);
      return;
    }

    // Validate NRC number
    if (nrcNumber.isEmpty) {
      commonViewModel.showSnackBar("Please enter your NRC number", context);
      return;
    }

    // Password confirmation
    if (password != confirm) {
      commonViewModel.showSnackBar("Password and confirmation do not match!", context);
      return;
    }

    // Required fields
    if (password.isEmpty ||
        email.isEmpty ||
        name.isEmpty ||
        phone.isEmpty ||
        selectedVehicleType.isEmpty ||
        locationAddress.isEmpty) {
      commonViewModel.showSnackBar("Please enter all the required fields!", context);
      return;
    }

    // Vehicle validation
    if (selectedVehicleType == "motorbike") {
      if (vehicleModel.isEmpty || vehicleColor.isEmpty || licensePlate.isEmpty) {
        commonViewModel.showSnackBar(
          "Please enter vehicle model, color, and plate for a motorbike!",
          context,
        );
        return;
      }
    }

    // Email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      commonViewModel.showSnackBar("Please enter a valid email address", context);
      return;
    }

    // Zambian phone validation
    final zambiaPhoneRegex = RegExp(r'^(?:\+260|0)\d{9}$');
    if (!zambiaPhoneRegex.hasMatch(phone)) {
      commonViewModel.showSnackBar(
        "Please enter a valid Zambian phone number (e.g., 097XXXXXXX or +260XXXXXXXXX)",
        context,
      );
      return;
    }

    // GPS safety check
    final lat = position?.latitude;
    final lng = position?.longitude;
    if (lat == null || lng == null) {
      debugPrint('⚠️ position is null; saving without lat/lng');
    }

    commonViewModel.showSnackBar("Creating your account...", context);

    // Create user in Firebase Auth
    final fb_auth.User? currentUser = await createUserInFirebase(email, password, context);

    if (currentUser == null) {
      fb_auth.FirebaseAuth.instance.signOut();
      return;
    }

    // Upload images
    final String profileImageUrl = await uploadImageToFirebase(profileImage);
    final String nrcFrontUrl = await uploadNRCImageToFirebase(nrcFrontImage, currentUser.uid, 'front');
    final String nrcBackUrl = await uploadNRCImageToFirebase(nrcBackImage, currentUser.uid, 'back');

    // Save user info with PENDING status
    final ok = await saveUserToFireStore(
      currentUser: currentUser,
      profileImageUrl: profileImageUrl,
      nrcFrontUrl: nrcFrontUrl,
      nrcBackUrl: nrcBackUrl,
      nrcNumber: nrcNumber,
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

    // Navigate to pending approval screen
    if (context.mounted) {
      commonViewModel.showSnackBar(
        "Account created successfully! Please wait for admin approval.",
        context,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
      );
    }
  }

  Future<fb_auth.User?> createUserInFirebase(
      String email,
      String password,
      BuildContext context
      ) async {
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
    final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final fs_store.Reference ref = fs_store.FirebaseStorage.instance
        .ref()
        .child('ridersimages/$fileName');

    final fs_store.UploadTask task = ref.putFile(File(image.path));
    final fs_store.TaskSnapshot snap = await task;
    final String url = await snap.ref.getDownloadURL();
    return url;
  }

  Future<String> uploadNRCImageToFirebase(XFile image, String uid, String side) async {
    final String fileName = 'nrc_${uid}_${side}_${DateTime.now().millisecondsSinceEpoch}';
    final fs_store.Reference ref = fs_store.FirebaseStorage.instance
        .ref()
        .child('riders_nrc/$uid/$fileName');

    final fs_store.UploadTask task = ref.putFile(File(image.path));
    final fs_store.TaskSnapshot snap = await task;
    final String url = await snap.ref.getDownloadURL();
    return url;
  }

  Future<bool> saveUserToFireStore({
    required fb_auth.User currentUser,
    required String profileImageUrl,
    required String nrcFrontUrl,
    required String nrcBackUrl,
    required String nrcNumber,
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
    try {
      await FirebaseFirestore.instance.collection("riders").doc(currentUser.uid).set({
        "uid": currentUser.uid,
        "imageUrl": profileImageUrl,
        "email": email,
        "name": name,
        "phone": phone,
        "vehicleType": selectedVehicleType,
        "vehicleModel": vehicleModel,
        "vehicleColor": vehicleColor,
        "licensePlate": licensePlate,
        "address": locationAddress,
        "nrcNumber": nrcNumber,
        "nrcFrontUrl": nrcFrontUrl,
        "nrcBackUrl": nrcBackUrl,
        "earnings": 0.0,
        "rating": 0.0,
        "totalRides": 0,
        "balance": 0.0,
        "commission": 0.0,
        if (latitude != null) "latitude": latitude,
        if (longitude != null) "longitude": longitude,
        "createdAt": FieldValue.serverTimestamp(),
        "status": "pending",
        "isOnline": false
      });

      // Save locally
      await sharedPreferences!.setString("uid", currentUser.uid);
      await sharedPreferences!.setString("email", email);
      await sharedPreferences!.setString("name", name);
      await sharedPreferences!.setString("imageUrl", profileImageUrl);
      await sharedPreferences!.setString("phone", phone);
      await sharedPreferences!.setString("vehicleType", selectedVehicleType);
      await sharedPreferences!.setString("vehicleModel", vehicleModel);
      await sharedPreferences!.setString("vehicleColor", vehicleColor);
      await sharedPreferences!.setString("licensePlate", licensePlate);
      await sharedPreferences!.setString("address", locationAddress);
      await sharedPreferences!.setString("status", "pending");
      await sharedPreferences!.setBool("isOnline", false);
      await sharedPreferences!.setDouble("rating", 0.0);
      await sharedPreferences!.setDouble("balance", 0.0);
      await sharedPreferences!.setDouble("commission", 0.0);
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
      String email,
      String password,
      BuildContext context
      ) async {
    if (email.isEmpty || password.isEmpty) {
      commonViewModel.showSnackBar("Email and Password are required!", context);
      return;
    }

    commonViewModel.showSnackBar("Checking your credentials...!", context);

    fb_auth.User? currentFirebaseUser = await signInUser(email, password, context);

    if (currentFirebaseUser == null) return;

    await readDataFromFirestoreAndSetDataLocally(currentFirebaseUser, context);

    _initializeUser();
    notifyListeners();

    // Check if user is approved
    final status = sharedPreferences!.getString("status") ?? "pending";
    if (status == "approved") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      commonViewModel.showSnackBar("Signed in successfully...!", context);
    } else if (status == "pending") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PendingApprovalScreen()));
    } else {
      commonViewModel.showSnackBar("Your account has been rejected. Contact support.", context);
      await fb_auth.FirebaseAuth.instance.signOut();
    }
  }

  Future<fb_auth.User?> signInUser(
      String email,
      String password,
      BuildContext context
      ) async {
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
      fb_auth.User currentFirebaseUser,
      BuildContext context
      ) async {
    await FirebaseFirestore.instance
        .collection("riders")
        .doc(currentFirebaseUser.uid)
        .get()
        .then((dataSnapshot) async {
      if (dataSnapshot.exists) {
        final data = dataSnapshot.data()!;

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
            "rating", (data["rating"] ?? 0.0).toDouble());
        await sharedPreferences!
            .setInt("totalRides", (data["totalRides"] ?? 0).toInt());
        await sharedPreferences!.setString("status", data["status"] ?? "pending");
        await sharedPreferences!.setBool("isOnline", data["isOnline"] ?? false);
        await sharedPreferences!.setDouble("balance", (data["balance"] ?? 0.0).toDouble());
        await sharedPreferences!.setDouble("commission", (data["commission"] ?? 0.0).toDouble());
      } else {
        commonViewModel.showSnackBar("This rider record does not exist", context);
        fb_auth.FirebaseAuth.instance.signOut();
      }
    }).catchError((error) {
      commonViewModel.showSnackBar("Error reading data: ${error.toString()}", context);
      fb_auth.FirebaseAuth.instance.signOut();
    });
  }

  Future<void> logout(BuildContext context) async {
    try {
      await appLifecycleService?.setUserOffline();
      await sharedPreferences!.clear();
      _currentUser = null;
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