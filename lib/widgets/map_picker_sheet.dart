import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Show the map picker as a tall bottom sheet like a native experience.
/// [title] should be something clean like "MY HOME BASE ADDRESS".
Future<Map<String, dynamic>?> showMapPickerSheet(
    BuildContext context, {
      required LatLng initial,
      required String title,
    }) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent, // Keeps the underlying sheet card look clean
    builder: (_) => _MapPickerSheet(initial: initial, title: title),
  );
}

class _MapPickerSheet extends StatefulWidget {
  const _MapPickerSheet({required this.initial, required this.title});
  final LatLng initial;
  final String title;

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  GoogleMapController? _map;
  late LatLng _center;
  String _addressText = '';

  @override
  void initState() {
    super.initState();
    _center = widget.initial;
    _addressText = _fmtAddress(_center);
  }

  String _fmtAddress(LatLng p) {
    // Simple async-free placeholder string.
    // You can replace this later with a reverse geocoding lookup if needed!
    return '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
  }

  void _recenter() {
    _map?.animateCamera(CameraUpdate.newLatLng(widget.initial));
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final sheetHeight = h * 0.9; // Spans nice and tall across the viewport

    return SizedBox(
      height: sheetHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Material(
          color: Colors.white,
          child: Stack(
            children: [
              /// Map Layer
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.initial,
                    zoom: 16,
                  ),
                  onMapCreated: (c) => _map = c,
                  onCameraMove: (pos) {
                    // Continuously track the coordinates center point as the user pans
                    _center = pos.target;
                  },
                  onCameraIdle: () {
                    // Update the visible layout string only when the camera stops moving
                    setState(() => _addressText = _fmtAddress(_center));
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),

              /// Drop Pin Overlay (Stays locked perfectly in the center)
              const IgnorePointer(
                child: Center(
                  child: Icon(Icons.location_on, size: 42, color: Color(0xFFE53935)),
                ),
              ),

              /// Top Hint Tag
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.08),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: const Text(
                      'Swipe to move map',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),

              /// Back Floating Action Button
              Positioned(
                left: 16,
                bottom: 220, // Raised slightly so it stays above the bottom details card
                child: FloatingActionButton(
                  heroTag: 'back_btn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.black87),
                ),
              ),

              /// Recenter Floating Action Button
              Positioned(
                right: 16,
                bottom: 220,
                child: FloatingActionButton(
                  heroTag: 'center_btn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _recenter,
                  child: const Icon(Icons.near_me, color: Colors.black87),
                ),
              ),

              /// Bottom Sheet Details Info Panel
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.12),
                        blurRadius: 16,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFF09113C),
                        ),
                      ),
                      const SizedBox(height: 12),

                      /// Location Details Display Card Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12, width: 1.2),
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2B7B).withOpacity(.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.place_outlined, color: Color(0xFF1A2B7B)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _addressText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Selected location target',
                                    style: TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// Confirmation Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            // Pop out details mapping bundle back down to our core fields state layer
                            Navigator.pop<Map<String, dynamic>>(context, {
                              'lat': _center.latitude,
                              'lng': _center.longitude,
                              'address': _addressText,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2B7B), // Re-styled to match your App's dark blue accent theme
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Confirm Location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}