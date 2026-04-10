import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ubwinza_riders/global/global_instances.dart';
import 'package:ubwinza_riders/global/global_vars.dart';
import 'package:ubwinza_riders/views/mainScreens/history.dart';
import 'package:ubwinza_riders/views/mainScreens/new_available_orders.dart';
import 'package:ubwinza_riders/views/mainScreens/new_available_requests.dart';
import 'package:ubwinza_riders/views/mainScreens/not-yet_delivered.dart';
import 'package:ubwinza_riders/views/mainScreens/profile_screen.dart';
import 'package:ubwinza_riders/views/mainScreens/total_earnings.dart';
import 'Withdraw_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late bool _isLoggedIn;
  late bool _isBlocked;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  void _checkUserStatus() {
    _isLoggedIn = FirebaseAuth.instance.currentUser != null &&
        sharedPreferences!.getString("uid") != null;

    final String riderStatus = sharedPreferences!.getString("status") ?? "pending";
    _isBlocked = _isLoggedIn && riderStatus != "approved";
  }

  // Logic to fetch earnings from Firestore
  Future<double> _getEarnings() async {
    try {
      double total = 0.0;
      final uid = sharedPreferences!.getString("uid");
      if (uid == null) return 0.0;

      // Fetch Parcel Requests
      final reqSnap = await _firestore
          .collection('requests')
          .where('driverId', isEqualTo: uid)
          .where('status', isEqualTo: 'delivered')
          .get();
      for (var doc in reqSnap.docs) {
        total += (doc.data()['actualFare'] ?? doc.data()['estimatedFare'] ?? 0).toDouble();
      }

      // Fetch Orders
      final ordSnap = await _firestore
          .collection('orders')
          .where('driverId', isEqualTo: uid)
          .where('status', isEqualTo: 'delivered')
          .get();
      for (var doc in ordSnap.docs) {
        total += (doc.data()['deliveryFee'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  void _navigateToScreen(int index, BuildContext context) {
    if (_isBlocked || !_isLoggedIn) return;

    Widget screen;
    switch (index) {
      case 0: screen = const NewAvailableRequestsScreen(); break;
      case 1: screen = const NewAvailableOrdersScreen(); break;
      case 2: screen = const NotYetDelivered(); break;
      case 3: screen = const HistoryScreen(); break;
      case 4: screen = const TotalEarningsScreen(); break;
      default: return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // --- UI COMPONENTS ---

  Widget _buildCustomDrawerHeader() {
    final name = sharedPreferences!.getString("name") ?? "Rider";
    final imageUrl = sharedPreferences!.getString("imageUrl");
    final String driverId = sharedPreferences!.getString("uid") ?? "";

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection("riders").doc(driverId).snapshots(),
      builder: (context, snapshot) {
        double balance = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          balance = (data["balance"] ?? 0).toDouble();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 25),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A2B7B), Color(0xFF09113C)],
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
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: (imageUrl != null && imageUrl.isNotEmpty)
                          ? Image.network(imageUrl, fit: BoxFit.cover, width: 70, height: 70)
                          : const Icon(Icons.person, size: 40, color: Color(0xFF1A2B7B)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawScreen())),
                    icon: const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 28),
                  )
                ],
              ),
              const SizedBox(height: 15),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(FirebaseAuth.instance.currentUser?.email ?? "", style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text("Balance: ZMW ${balance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _drawerItem(String title, IconData icon, int index) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
      onTap: () {
        Navigator.pop(context);
        _navigateToScreen(index, context);
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            FittedBox(child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black))),
            Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _jobButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _checkUserStatus();
    final userName = sharedPreferences!.getString("name") ?? "Rider";

    return Scaffold(
      backgroundColor: const Color(0xFF1A2B7B),
      drawer: (_isLoggedIn && !_isBlocked)
          ? Drawer(
        backgroundColor: const Color(0xFF09113C),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCustomDrawerHeader(),
                    _drawerItem("Available Requests", Icons.explore_outlined, 0),
                    _drawerItem("Available Orders", Icons.shopping_bag_outlined, 1),
                    _drawerItem("Pending Deliveries", Icons.local_shipping_outlined, 2),
                    const Divider(color: Colors.white10),
                    _drawerItem("History", Icons.history, 3),
                    _drawerItem("Total Earnings", Icons.payments_outlined, 4),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: ListTile(
                onTap: () => authViewModel.logout(context),
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      )
          : null,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A2B7B),
        title: Text(_isBlocked ? "Account Status" : "Hi, $userName"),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(sharedPreferences!.getString("imageUrl") ?? ""),
                child: sharedPreferences!.getString("imageUrl") == null ? const Icon(Icons.person) : null,
              ),
            ),
          )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome back,", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF09113C))),
              const SizedBox(height: 20),

              // Stats Row
              Row(
                children: [
                  _buildStatCard("Status", _isBlocked ? "Blocked" : "Online", Icons.radar, Colors.blue),
                  const SizedBox(width: 15),
                  FutureBuilder<double>(
                    future: _getEarnings(),
                    builder: (context, snapshot) {
                      String price = snapshot.hasData ? "ZMW ${snapshot.data!.toStringAsFixed(2)}" : "Calculating...";
                      return _buildStatCard("Earned", price, Icons.payments, Colors.green);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 25),

              const Text("Find Work", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 15),
              Row(
                children: [
                  _jobButton("New Rides", Icons.local_taxi, Colors.indigo, () => _navigateToScreen(0, context)),
                  const SizedBox(width: 12),
                  _jobButton("New Orders", Icons.fastfood, Colors.indigoAccent, () => _navigateToScreen(1, context)),
                ],
              ),
              const SizedBox(height: 30),

              const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Colors.black)),
              const SizedBox(height: 15),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 1.6,
                children: [
                  _quickActionButton("History", Icons.history, Colors.blue, () => _navigateToScreen(3, context)),
                  _quickActionButton("Earnings", Icons.bar_chart, Colors.teal, () => _navigateToScreen(4, context)),
                  _quickActionButton("Withdraw", Icons.wallet, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawScreen()))),
                  _quickActionButton("Pending", Icons.pending_actions, Colors.redAccent, () => _navigateToScreen(2, context)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}