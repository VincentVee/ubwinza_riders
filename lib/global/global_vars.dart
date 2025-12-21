
import 'dart:ui';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position? position;

List<Placemark>? placeMark;
String googleApiKey = "AIzaSyC24a0-yk2HG6ONDtpbPRlL_lWkxeqqQ2Y";
final Color primaryColor = Color(0xFF1A2B7B);

String fullAddress = "";
SharedPreferences? sharedPreferences;

String get driverName => sharedPreferences?.getString("name") ?? "";
String get driverEmail => sharedPreferences?.getString("email") ?? "";
String get driverImageUrl => sharedPreferences?.getString("imageUrl") ?? "";
String get driverPhone => sharedPreferences?.getString("phone") ?? "";
String get driverVehicleType => sharedPreferences?.getString("vehicleType") ?? "motorbike";
String get driverVehicleModel => sharedPreferences?.getString("vehicleModel") ?? "";
String get driverVehicleColor => sharedPreferences?.getString("vehicleColor") ?? "";
String get driverLicensePlate => sharedPreferences?.getString("licensePlate") ?? "";
String get driverAddress => sharedPreferences?.getString("address") ?? "";
double get driverRating => sharedPreferences?.getDouble("rating") ?? 5.0;
int get driverTotalRides => sharedPreferences?.getInt("totalRides") ?? 0;
