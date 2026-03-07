import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// ⭐ ADDED IMPORT
import 'package:geocoding/geocoding.dart';
import 'package:ubwinza_riders/views/mainScreens/order_in_progress.dart'; 

// FIX: Change to the correct class name from previous code review
import 'package:ubwinza_riders/views/mainScreens/parcel_in_progress.dart'; // <-- KEEPING OLD PATH FOR COMPATIBILITY
// Using the correct class name for navigation

// --- Global Theme Colors (for consistency) ---
const Color primaryColor = Color(0xFF1A2B7B);
const Color successColor = Colors.green;
const Color warningColor = Colors.orangeAccent;

// =================================================================
// NewAvailableOrdersScreen (No Change Required)
// =================================================================

class NewAvailableOrdersScreen extends StatefulWidget {
  const NewAvailableOrdersScreen({super.key});

  @override
  State<NewAvailableOrdersScreen> createState() =>
      _NewAvailableOrdersScreenState();
}

class _NewAvailableOrdersScreenState extends State<NewAvailableOrdersScreen> {
  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final String? driverId = _auth.currentUser?.uid;

    if (driverId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No rider logged in.',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Orders Ready for Pickup',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('orders')
            .where('status', isEqualTo: 'prepared')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading orders: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_ind_outlined, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text(
                    'No orders ready for pickup.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final requestId = docs[index].id;

              return PickupRequestCard(
                data: data,
                requestId: requestId,
                driverId: driverId,
                onAccept: _confirmAccept,
                onReject: _confirmReject,
              );
            },
          );
        },
      ),
    );
  }

  // --- Core Action Logic (FIX APPLIED HERE) ---

  void _confirmAccept(BuildContext context, String requestId, String driverId, Map<String, dynamic> requestData) {
      // ... (logic remains the same)
      showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: primaryColor,
        title: const Text('Accept Pickup'),
        content: const Text(
          'Confirm acceptance for pickup and delivery?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _acceptRequest(requestId, driverId, requestData);
            },
            child: const Text('Accept', style: TextStyle(color: successColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(String requestId, String driverId, Map<String, dynamic> requestData) async {
    // ... (logic remains the same)
    try {
      final riderDoc = await _firestore.collection('riders').doc(driverId).get();
      final riderData = riderDoc.data();
      
      await _firestore.collection('orders').doc(requestId).update({
        // FIX: Change status to 'accepted' so it is removed from the 'prepared' list
        'status': 'accepted', 
        'driverId': driverId,
        'driverName': riderData?['name'] ?? 'Unknown Rider',
        'driverPhone': riderData?['phone'] ?? '',
        'driverImage': riderData?['imageUrl'] ?? '',
        'acceptedAt': FieldValue.serverTimestamp(),
        'vehicleType': riderData?['vehicleType'] ?? '',
        'vehicleModel': riderData?['vehicleModel'] ?? '',
        'licensePlate': riderData?['licensePlate'] ?? '',
      });

      if (context.mounted) {
        // FIX: Change to the correct class name for the navigation screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrdersInProgress( // Renamed class here
              requestId: requestId,
              initialStatus: 'accepted',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept pickup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmReject(BuildContext context, String requestId) {
    // ... (logic remains the same)
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: primaryColor,
        title: const Text('Reject Pickup'),
        content: const Text(
          'Are you sure you want to reject this assigned pickup order?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _rejectRequest(requestId);
            },
            child: const Text('Reject', style: TextStyle(color: warningColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectRequest(String requestId) async {
    // ... (logic remains the same)
    try {
      await _firestore.collection('orders').doc(requestId).update({
        'status': 'prepared', 
        'driverId': FieldValue.delete(),
        'driverName': FieldValue.delete(),
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order rejected. Reverted to pending status.'),
            backgroundColor: warningColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// =================================================================
// PickupRequestCard (CONVERTED TO STATEFUL)
// =================================================================

class PickupRequestCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String requestId;
  final String driverId;
  final Function(BuildContext, String, String, Map<String, dynamic>) onAccept;
  final Function(BuildContext, String) onReject;

  const PickupRequestCard({
    super.key,
    required this.data,
    required this.requestId,
    required this.driverId,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<PickupRequestCard> createState() => _PickupRequestCardState();
}

class _PickupRequestCardState extends State<PickupRequestCard> {
  // ⭐ STATE VARIABLES TO HOLD THE ADDRESSES
  // We MUST keep the final variable names from the original request
  // as the display variables in the build method.
  String pickupAddress = 'Loading pickup address...';
  String destinationAddress = 'Loading dropoff address...';
  
  // --- Utility Functions ---

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return DateFormat('h:mm a (MMM d)').format(date);
  }
  
  String _formatZMW(double? amount) {
    return 'ZMW ${amount?.toStringAsFixed(2) ?? '0.00'}';
  }

  // ⭐ CORE REVERSE GEOCODING FUNCTION
  Future<String> _reverseGeocode(double? lat, double? lng) async {
    if (lat == null || lng == null) {
      return 'Address N/A (Missing Coords)';
    }
    
    // Fallback to coordinates
    String coords = '(${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Construct a readable address string
        String address = [
          place.street,
          place.subLocality,
          place.locality,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        
        // Return the readable address or fallback to coordinates
        return address.isNotEmpty ? address : coords;
      }
      return coords;
    } catch (e) {
      // Return coordinates on geocoding failure
      return 'Lookup Failed: $coords';
    }
  }

  // --- Initialization and Geocoding Call ---

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  void _loadAddresses() async {
    final data = widget.data;

    // 1. Pickup Coordinates (Extracting from data['seller'] and data['pickupAddress'] fallbacks)
    final pickupLat = data['seller']?['lat'] as double? ?? data['pickupLat'] as double?;
    final pickupLng = data['seller']?['lng'] as double? ?? data['pickupLng'] as double?;
    
    // 2. Dropoff Coordinates
    final dropoffLat = data['dropoff']?['lat'] as double? ?? data['destinationLat'] as double?;
    final dropoffLng = data['dropoff']?['lng'] as double? ?? data['destinationLng'] as double?;

    // Perform lookups
    final newPickupAddress = await _reverseGeocode(pickupLat, pickupLng);
    final newDestinationAddress = await _reverseGeocode(dropoffLat, dropoffLng);

    // Update the state (and the variables named as requested)
    if (mounted) {
      setState(() {
        pickupAddress = newPickupAddress;
        destinationAddress = newDestinationAddress;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // ⭐ VARIABLE ASSIGNMENT (Using the state variables)
    // The names here MUST match the requested final variable names.
    // They are no longer local `final` variables, but are state properties.
    final estimatedFare = widget.data['total'] as double? ?? widget.data['estimatedFare'] as double?;
    final deliveryFee = widget.data['deliveryFee'] as double? ?? 0.0;
    final rideType = widget.data['rideType'] as String? ?? 'N/A';
    final createdAt = widget.data['createdAt'] as Timestamp?;

    return Card(
      color: primaryColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rideType.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatTimestamp(createdAt),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white30, height: 15),

            // Pickup/Destination (Uses the state properties: pickupAddress, destinationAddress)
            _buildAddressRow(
              icon: Icons.store,
              label: 'Pickup',
              address: pickupAddress, // ⭐ Uses Geocoded address
              color: successColor,
            ),
            _buildAddressRow(
              icon: Icons.location_on,
              label: 'Dropoff',
              address: destinationAddress, // ⭐ Uses Geocoded address
              color: warningColor,
            ),
            
            const SizedBox(height: 10),

            // Fare Details
            _buildFareDetail(
              label: 'Total Payout (Delivery Fee)',
              value: _formatZMW(deliveryFee),
              color: successColor,
              isBold: true,
            ),
            _buildFareDetail(
              label: 'Total Customer Charge',
              value: _formatZMW(estimatedFare),
              color: Colors.white70,
              isBold: false,
            ),
            
            const SizedBox(height: 15),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Accept Pickup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => widget.onAccept(context, widget.requestId, widget.driverId, widget.data),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: warningColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => widget.onReject(context, widget.requestId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressRow({required IconData icon, required String label, required String address, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  address,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareDetail({required String label, required String value, required Color color, required bool isBold}) {
    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: isBold ? 15 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}