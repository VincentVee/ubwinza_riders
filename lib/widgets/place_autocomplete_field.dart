import 'package:flutter/material.dart';
import '../../features/services/place_service.dart'; // Verify your exact path here

class PlaceAutocompleteField extends StatefulWidget {
  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.service,
    required this.label,
    required this.onPlacePicked,
    required this.onClear,
  });

  final TextEditingController controller;
  final PlaceService service;
  final String label;
  final ValueChanged<PlaceDetail> onPlacePicked;
  final VoidCallback onClear;

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;

  void _showOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 6.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white, // Crisp white background container
            child: _isLoading
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A2B7B)),
                  ),
                ),
              ),
            )
                : _suggestions.isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Text(
                "No addresses found",
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            )
                : Container(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Enhanced, tall vertical sizing
                    leading: const Icon(Icons.location_on_outlined, color: Color(0xFF1A2B7B), size: 22),
                    title: Text(
                      item.description,
                      maxLines: 3, // Expands cleanly over multiple lines
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black, // Dark black text color
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    onTap: () async {
                      _hideOverlay();
                      FocusScope.of(context).unfocus();
                      widget.controller.text = "Loading coordinates...";
                      try {
                        final detail = await widget.service.detail(item.placeId);
                        widget.onPlacePicked(detail);
                      } catch (e) {
                        widget.controller.clear();
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        style: const TextStyle(color: Colors.black87, fontSize: 15),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF1A2B7B)),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.black45, size: 20),
            onPressed: () {
              widget.onClear();
              _hideOverlay();
              setState(() {});
            },
          )
              : null, // Removed map icon completely
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1A2B7B), width: 1.5),
          ),
        ),
        onChanged: (val) async {
          if (val.trim().isEmpty) {
            _hideOverlay();
            return;
          }
          setState(() {
            _isLoading = true;
          });
          _showOverlay();

          try {
            final res = await widget.service.autocomplete(val);
            if (mounted) {
              setState(() {
                _suggestions = res;
                _isLoading = false;
              });
              _showOverlay();
            }
          } catch (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }
        },
      ),
    );
  }
}