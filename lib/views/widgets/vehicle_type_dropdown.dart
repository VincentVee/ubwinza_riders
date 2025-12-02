import 'package:flutter/material.dart';

class VehicleTypeDropdown extends StatelessWidget {
  final String? selectedVehicleType;
  final ValueChanged<String?> onVehicleTypeChanged;

  const VehicleTypeDropdown({
    Key? key,
    required this.selectedVehicleType,
    required this.onVehicleTypeChanged,
  }) : super(key: key);

  // Vehicle types for Zambian context
  static const List<Map<String, String>> vehicleTypes = [
    {
      'value': 'motorbike',
      'label': 'Motorbike', // Motorcycle (e.g., Honda, Yamaha)
    },
    {
      'value': 'bicycle',
      'label': 'Bicycle', // Bicycle/Pedal bike
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      // SAME as CustomeTextField
      margin: const EdgeInsets.all(11),
      padding: const EdgeInsets.all(8.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(12),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedVehicleType,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: const TextStyle(color: Colors.black),

        // Match TextField's decoration
        decoration: const InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.two_wheeler,
            color: Colors.blueAccent,
          ),
          hintText: "Vehicle Type",
          hintStyle: TextStyle(color: Colors.grey),
        ),

        icon: const Icon(
          Icons.arrow_drop_down,
          color: Colors.blueAccent,
        ),

        // SIMPLE, single-line items (no Column, no multi-line)
        items: vehicleTypes.map((vehicle) {
          return DropdownMenuItem<String>(
            value: vehicle['value'],
            child: Text(
              vehicle['label']!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),

        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Please select vehicle type";
          }
          return null;
        },

        onChanged: onVehicleTypeChanged,
      ),
    );
  }
}
