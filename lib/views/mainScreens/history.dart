import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../global/global_vars.dart'; // Contains sharedPreferences and driverId

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});


  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? driverId = sharedPreferences!.getString('uid');

  // ---------------------------
  // FETCHING LOGIC
  // ---------------------------

  Stream<List<Map<String, dynamic>>> _getDriverHistory() {
    if (driverId == null) {
      return Stream.value([]);
    }

    // 1. Fetch completed parcel requests
    final requestsStream = _firestore
        .collection('requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered') // Assuming 'completed' is final status for parcels
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'type': 'parcel', 'id': doc.id}).toList());

    // 2. Fetch delivered orders (food/e-commerce)
    final ordersStream = _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered') // Assuming 'delivered' is final status for orders
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'type': 'order', 'id': doc.id}).toList());

    // 3. Merge the two streams and sort by completion time
    return requestsStream.transform(
      StreamTransformer<List<Map<String, dynamic>>, List<Map<String, dynamic>>>.fromHandlers(
        handleData: (requests, sink) async {
          final orders = await ordersStream.first;
          final allHistory = [...requests, ...orders];

          // Sort by the completion time (completedAt or a similar field)
          allHistory.sort((a, b) {
            final aTime = (a['completedAt'] ?? a['deliveredAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bTime = (b['completedAt'] ?? b['deliveredAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bTime.compareTo(aTime); // Descending order (newest first)
          });

          sink.add(allHistory);
        },
      ),
    );
  }

  // ---------------------------
  // WIDGET HELPERS
  // ---------------------------

  Widget _buildHistoryTile(Map<String, dynamic> data) {
    final type = data['type'];
    final timestamp = (data['completedAt'] ?? data['deliveredAt']) as Timestamp?;
    final date = timestamp != null ? DateFormat('MMM dd, yyyy h:mm a').format(timestamp.toDate()) : 'N/A';

    String title;
    String subtitle;
    double fare;
    IconData icon;
    Color color;

    if (type == 'parcel') {
      title = "Parcel Delivery";
      subtitle = "From ${data['pickupAddress']} to ${data['destinationAddress']}";
      fare = (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble();
      icon = Icons.luggage;
      color = Colors.red;
    } else { // 'order'
      title = "Food/Item Delivery";
      final sellerName = data['seller']?['name'] ?? 'Shop';
      subtitle = "From ${sellerName} to customer dropoff";
      fare = (data['deliveryFee'] ?? 0).toDouble();
      icon = Icons.restaurant;
      color = Colors.green.shade700;
    }

    final formattedFare = NumberFormat.currency(symbol: 'ZMW ', decimalDigits: 2).format(fare);


    return Card(
      color: primaryColor,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              date,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formattedFare,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.green.shade800,
                fontSize: 16,
              ),
            ),
            const Text("Earnings", style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // BUILD METHOD
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xFF09113C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2B7B),
        title: const Text(
          "Ride History",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getDriverHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}'));
          }

          final historyList = snapshot.data ?? [];

          if (historyList.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No completed deliveries yet.",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      "Your completed parcel and order history will appear here.",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              return _buildHistoryTile(historyList[index]);
            },
          );
        },
      ),
    );
  }
}