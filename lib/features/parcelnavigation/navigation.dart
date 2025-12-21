// lib/navigation/navigation_service.dart

import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class NavigationService {
  final String googleApiKey;

  NavigationService({required this.googleApiKey});

  /// Main method – fetch route, steps, distance, ETA
  Future<NavigationResult?> getRoute(
      LatLng origin, LatLng destination) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$googleApiKey';

    final res = await http.get(Uri.parse(url));

    if (res.statusCode != 200) return null;

    final data = json.decode(res.body);
    if (data['routes'] == null || data['routes'].isEmpty) return null;

    final route = data['routes'][0];

    // Decode polyline
    final String encoded = route['overview_polyline']['points'];
    final List<LatLng> points = decodePolyline(encoded);

    // Extract LEG
    final leg = route['legs'][0];
    final String etaText = leg['duration']['text'];
    final String distanceText = leg['distance']['text'];

    final List<Map<String, dynamic>> steps = [];

    for (final step in leg['steps']) {
      final end = step['end_location'];

      steps.add({
        'instruction': stripHtml(step['html_instructions'] ?? ''),
        'endLat': end['lat'],
        'endLng': end['lng'],
        'maneuver': (step['maneuver'] ?? ''),
        'highwayShield': extractHighwayShield(step['html_instructions'] ?? ''),
        'rawHtml': step['html_instructions'] ?? '',
      });
    }

    return NavigationResult(
      polylinePoints: points,
      steps: steps,
      eta: etaText,
      distance: distanceText,
    );
  }

  // ----------------------------------------
  // Decode Google polyline into LatLng list
  // ----------------------------------------

  List<LatLng> decodePolyline(String encoded) {
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

  // ----------------------------------------
  // Extract Highway Codes (T2, M9, T4)
  // ----------------------------------------

  String extractHighwayShield(String html) {
    final cleaned = stripHtml(html);
    final words = cleaned.split(" ");

    for (final word in words) {
      if (RegExp(r'^[A-Z]+\d+$').hasMatch(word)) {
        return word; // Ex: T2, M9, T4
      }
    }

    return "";
  }

  // ----------------------------------------
  // Strip HTML tags from Google instructions
  // ----------------------------------------

  static String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }
}

// -------------------------------------------------------
// RESULT MODEL FOR CLEAN DATA FLOW BETWEEN COMPONENTS
// -------------------------------------------------------

class NavigationResult {
  final List<LatLng> polylinePoints;
  final List<Map<String, dynamic>> steps;
  final String eta;
  final String distance;

  NavigationResult({
    required this.polylinePoints,
    required this.steps,
    required this.eta,
    required this.distance,
  });
}
