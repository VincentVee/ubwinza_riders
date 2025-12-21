import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../global/global_vars.dart'; // Contains sharedPreferences and driverId

class TotalEarningsScreen extends StatefulWidget {
  const TotalEarningsScreen({super.key});

  @override
  State<TotalEarningsScreen> createState() => _TotalEarningsScreenState();
}

class _TotalEarningsScreenState extends State<TotalEarningsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? driverId = sharedPreferences!.getString('uid');

  // ---------------------------
  // EARNINGS CALCULATION LOGIC
  // ---------------------------

  /// Fetches and calculates the total earnings from both requests (parcels) and orders.
  Future<double> _calculateTotalEarnings() async {
    if (driverId == null) {
      return 0.0;
    }

    double totalEarnings = 0.0;

    // 1. Fetch completed Parcel Requests
    // Status: 'completed'
    final requestsSnapshot = await _firestore
        .collection('requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .get();

    for (var doc in requestsSnapshot.docs) {
      // Assuming 'actualFare' or 'estimatedFare' represents the driver's cut/earning for the request
      final data = doc.data();
      double fare = (data['actualFare'] ?? data['estimatedFare'] ?? 0).toDouble();
      totalEarnings += fare;
    }

    // 2. Fetch Delivered Orders (Food/E-commerce)
    // Status: 'delivered'
    final ordersSnapshot = await _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .get();

    for (var doc in ordersSnapshot.docs) {
      // Assuming 'deliveryFee' is the primary component of driver earnings for an order
      final data = doc.data();
      double deliveryFee = (data['deliveryFee'] ?? 0).toDouble();

      // NOTE: You might need to add a commission deduction here if the 'deliveryFee'
      // is the gross fee charged to the user and a percentage goes to the platform.
      // For now, we assume deliveryFee is the driver's net earning for that order.
      totalEarnings += deliveryFee;
    }

    return totalEarnings;
  }

  // ---------------------------
  // WIDGET HELPERS
  // ---------------------------

  Widget _buildEarningCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                Icon(icon, color: Colors.white54, size: 30),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
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
          "Total Earnings",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Color(0xFF09113C),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              FutureBuilder<double>(
                future: _calculateTotalEarnings(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 100.0),
                        child: CircularProgressIndicator(color: Colors.indigo.shade800),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(child: Text("Error calculating earnings."));
                  }

                  final total = snapshot.data ?? 0.0;
                  final formattedTotal = NumberFormat.currency(
                    symbol: 'ZMW ', // Customize symbol for Zambian Kwacha
                    decimalDigits: 2,
                  ).format(total);

                  return _buildEarningCard(
                    "Total Lifetime Earnings",
                    formattedTotal,
                    const Color(0xFF1A2B7B),
                    Icons.account_balance_wallet,
                  );
                },
              ),

              const SizedBox(height: 40),

              // Optional: Placeholder for breakdown or recent activity
              Center(
                child: Text(
                  "Earnings are aggregated from all completed requests (status: 'delivered') and orders (status: 'delivered').",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}