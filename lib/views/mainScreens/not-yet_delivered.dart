import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ubwinza_riders/views/mainScreens/parcel_in_progress.dart';

class NotYetDelivered extends StatefulWidget {
  const NotYetDelivered({super.key});

  @override
  State<NotYetDelivered> createState() => _NotYetDeliveredState();
}

class _NotYetDeliveredState extends State<NotYetDelivered> {
  final String driverId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parcels In Progress"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('driverId', isEqualTo: driverId)
            .where('status', isEqualTo: 'in-progress')
            .orderBy('acceptedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 🔄 Loading state
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          // ❌ No parcels in progress
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No parcels in progress",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          // 📌 List of parcels not yet delivered
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
              docs[index].data() as Map<String, dynamic>;
              final requestId = docs[index].id;

              final userName = data['userName'] ?? 'Customer';
              final pickup = data['pickupAddress'] ?? 'Pickup';
              final destination =
                  data['destinationAddress'] ?? 'Destination';
              final userImage = data['userImage'];

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: userImage != null
                        ? NetworkImage(userImage)
                        : null,
                    child: userImage == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    "For: $userName",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("Pickup: $pickup",
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text("Destination: $destination",
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 28, color: Colors.black54),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParcelInProgressScreen(
                          requestId: requestId,
                          initialStatus: data['status'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
