import 'package:flutter/material.dart';

class VehicleTypeDropdown extends StatelessWidget {
  final String selectedVehicleType;
  final Function(String?) onVehicleTypeChanged;

  const VehicleTypeDropdown({
    Key? key,
    required this.selectedVehicleType,
    required this.onVehicleTypeChanged,
  }) : super(key: key);

  // Vehicle types for Zambian context
  static const List<Map<String, String>> vehicleTypes = [
    {
      'value': 'motorbike',
      'label': 'Motorbike',
      'description': 'Motorcycle (e.g., Honda, Yamaha)'
    },
    {
      'value': 'bicycle',
      'label': 'Bicycle',
      'description': 'Bicycle/Pedal bike'
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedVehicleType,
          isExpanded: true,
          icon: const Icon(Icons.motorcycle),
          elevation: 16,
          style: const TextStyle(color: Colors.black),
          onChanged: onVehicleTypeChanged,
          items: vehicleTypes.map<DropdownMenuItem<String>>((Map<String, String> vehicle) {
            return DropdownMenuItem<String>(
              value: vehicle['value'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vehicle['label']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    vehicle['description']!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}