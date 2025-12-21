// lib/navigation/navigation_map.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'navigation_controller.dart';

class NavigationMap extends StatelessWidget {
  final NavigationController controller;

  final LatLng pickup;
  final LatLng destination;

  final bool nightMode;
  final VoidCallback onRecenter;

  const NavigationMap({
    super.key,
    required this.controller,
    required this.pickup,
    required this.destination,
    required this.nightMode,
    required this.onRecenter,
  });

  // Night theme JSON
  static const String nightStyle = '''
[
  {"elementType": "geometry","stylers":[{"color":"#1d1d1d"}]},
  {"elementType": "labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType": "labels.text.fill","stylers":[{"color":"#8e8e8e"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1d1d1d"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#181818"}]}
]
''';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: pickup,
            zoom: 15,
          ),
          onMapCreated: (GoogleMapController map) {
            if (!controller.mapController.isCompleted) {
              controller.mapController.complete(map);
            }
            if (nightMode) {
              map.setMapStyle(nightStyle);
            }
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,

          // Prevent auto-follow when user drags
          onCameraMoveStarted: () {
            controller.isUserInteracting = true;
          },

          markers: _buildMarkers(),
          polylines: _buildPolylines(),
        ),

        // RECENTER BUTTON
        Positioned(
          right: 15,
          bottom: 140,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            elevation: 3,
            onPressed: onRecenter,
            child: const Icon(Icons.my_location, color: Colors.black),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // MARKERS
  // ------------------------------------------------------------

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Pickup
    markers.add(
      Marker(
        markerId: const MarkerId("pickup"),
        position: pickup,
        infoWindow: const InfoWindow(title: "Pickup"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );

    // Destination
    markers.add(
      Marker(
        markerId: const MarkerId("destination"),
        position: destination,
        infoWindow: const InfoWindow(title: "Destination"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Driver
    if (controller.currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("driver"),
          position: controller.currentLocation!,
          anchor: const Offset(0.5, 0.5),
          rotation: controller.lastBearing,
          flat: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    return markers;
  }

  // ------------------------------------------------------------
  // POLYLINES (Route + Passed Segments)
  // ------------------------------------------------------------

  Set<Polyline> _buildPolylines() {
    final lines = <Polyline>{};

    // Active route (Green)
    lines.add(
      Polyline(
        polylineId: const PolylineId("activeRoute"),
        points: controller.routePoints,
        width: 7,
        color: Colors.green,
      ),
    );

    // Passed route (Grey)
    lines.add(
      Polyline(
        polylineId: const PolylineId("passedTrail"),
        points: controller.passedTrail,
        width: 5,
        color: Colors.grey,
      ),
    );

    return lines;
  }
}
