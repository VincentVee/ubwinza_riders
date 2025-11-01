import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ubwinza_riders/views/mainScreens/parcel_in_progress.dart';

class NewAvailableOrderScreen extends StatefulWidget {
  const NewAvailableOrderScreen({super.key});

  @override
  State<NewAvailableOrderScreen> createState() =>
      _NewAvailableOrderScreenState();
}

class _NewAvailableOrderScreenState extends State<NewAvailableOrderScreen> {
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
          'Available Ride Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A2B7B),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No available ride requests.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final requestId = docs[index].id;

              return SafeArea(
                child: Card(
                  color: const Color(0xFF1A2B7B),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['userName'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pickup: ${data['pickupAddress'] ?? 'N/A'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Destination: ${data['destinationAddress'] ?? 'N/A'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Estimated Fare: ZMW ${data['estimatedFare']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Accept'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              onPressed: () =>
                                  _confirmAccept(context, requestId, driverId, data),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              onPressed: () => _confirmReject(context, requestId),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmAccept(BuildContext context, String requestId, String driverId, Map<String, dynamic> requestData) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2B7B),
        title: const Text('Accept Request'),
        content: const Text(
          'Do you want to accept this ride request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _acceptRequest(requestId, driverId, requestData);
            },
            child: const Text('Accept', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(String requestId, String driverId, Map<String, dynamic> requestData) async {
    try {
      final driver = _auth.currentUser;
      
      // Get rider data from Firestore
      final riderDoc = await _firestore.collection('riders').doc(driverId).get();
      final riderData = riderDoc.data();
      
      await _firestore.collection('requests').doc(requestId).update({
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

      // Navigate to the parcel screen with "accepted" status
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ParcelInProgressScreen(
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
            content: Text('Failed to accept: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmReject(BuildContext context, String requestId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2B7B),
        title: const Text('Reject Request'),
        content: const Text(
          'Are you sure you want to reject this ride request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _rejectRequest(requestId);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
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