import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ubwinza_riders/global/global_instances.dart';
import 'package:ubwinza_riders/global/global_vars.dart';
import 'package:ubwinza_riders/views/mainScreens/history.dart';
import 'package:ubwinza_riders/views/mainScreens/new_available_order.dart';
import 'package:ubwinza_riders/views/mainScreens/not-yet_delivered.dart';
import 'package:ubwinza_riders/views/mainScreens/profile_screen.dart';
import 'package:ubwinza_riders/views/mainScreens/total_earnings.dart';
// Note: You removed the explicit provider import from HomeScreen, which is fine
// since you're using global_instances and sharedPreferences.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // Global variables derived from checks
  late bool _isLoggedIn;
  late bool _isBlocked;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  // Method to check login status and rider status from shared preferences
  void _checkUserStatus() {
    // 1. Check Login Status
    _isLoggedIn = FirebaseAuth.instance.currentUser != null &&
        sharedPreferences!.getString("uid") != null;

    // 2. Check Rider Status (only relevant if logged in)
    final String riderStatus = sharedPreferences!.getString("status") ?? "pending";
    _isBlocked = _isLoggedIn && riderStatus != "approved";
  }

  // Helper method for navigation logic
  void _navigateToScreen(int index, BuildContext context) {
    if (_isBlocked || !_isLoggedIn) return;

    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NewAvailableOrderScreen()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotYetDelivered()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
    } else if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TotalEarningsScreen()));
    } else if (index == 5) {
      authViewModel.logout(context);
    }
  }

  // Helper method to build the list item for the Drawer
  Widget _drawerItem(String title, IconData iconData, int index) {
    return ListTile(
      leading: Icon(iconData, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: Colors.white70),
      ),
      onTap: () => _navigateToScreen(index, context),
    );
  }

  // Helper method to build the header for the Drawer
  Widget _buildDrawerHeader() {
    final name = sharedPreferences!.getString("name") ?? "Rider";
    final imageUrl = sharedPreferences!.getString("imageUrl");

    return UserAccountsDrawerHeader(
      accountName: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      accountEmail: Text(
        FirebaseAuth.instance.currentUser?.email ?? "rider@email.com",
        style: const TextStyle(color: Colors.white70),
      ),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? ClipOval(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: 90,
            height: 90,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Color(0xFF1A2B7B)),
          ),
        )
            : const Icon(Icons.person, color: Color(0xFF1A2B7B), size: 40),
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2B7B),
      ),
    );
  }

  // Widget to display the profile picture used in the AppBar
  Widget _buildProfileAvatar() {
    final imageUrl = sharedPreferences!.getString("imageUrl");
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? ClipOval(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: 36,
            height: 36,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Color(0xFF1A2B7B), size: 24),
          ),
        )
            : const Icon(Icons.person, color: Color(0xFF1A2B7B), size: 24),
      ),
    );
  }

  // Handler for the PopupMenuButton
  void _onMenuItemSelected(BuildContext context, int result) {
    if (result == 0) {
      // Profile - Only available if logged in and not blocked
      if (_isLoggedIn && !_isBlocked) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      }
    } else if (result == 1) {
      // Logout - Always available
      authViewModel.logout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    _checkUserStatus(); // Re-run status check on build to ensure up-to-date state

    final userName = sharedPreferences!.getString("name") ?? "Rider";
    const int activeOrders = 0; // Assuming this is derived elsewhere, or is 0 for the example

    // Determine the content based on block status
    final String bodyText;
    final Color statusColor;

    if (!_isLoggedIn) {
      bodyText = "Your account has been blocked or is pending approval. Please contact support.";
      statusColor = Colors.grey;
    } else if (_isBlocked) {
      bodyText = "Your account has been blocked or is pending approval. Please contact support.";
      statusColor = Colors.red.shade700;
    } else {
      bodyText = activeOrders > 0 ? "$activeOrders ACTIVE DELIVERY" : "NO ACTIVE DELIVERIES";
      statusColor = activeOrders > 0 ? Colors.amber.shade700 : Colors.green.shade700;
    }

    // --- Build the AppBar Actions List ---
    List<PopupMenuItem<int>> menuItems = [];

    // 1. Profile option is only added if logged in and not blocked
    if (_isLoggedIn && !_isBlocked) {
      menuItems.add(const PopupMenuItem(
        value: 0,
        child: Row(
          children: [
            Icon(Icons.person_outline, color: Colors.yellow),
            SizedBox(width: 8),
            Text("Profile", style: TextStyle(color: Colors.white)),
          ],
        ),
      ));
    }

    // 2. Logout option is always added if the user is currently in a session
    if (FirebaseAuth.instance.currentUser != null) {
      menuItems.add(const PopupMenuItem(
        value: 1,
        child: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text("Logout", style: TextStyle(color: Colors.red)),
          ],
        ),
      ));
    }


    return Scaffold(
      // 1. Hide the menu drawer if the user is not logged in or is blocked
      drawer: (_isLoggedIn && !_isBlocked)
          ? Drawer(
        child: Container(
          color: const Color(0xFF09113C),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _buildDrawerHeader(),
              _drawerItem("New Available Orders", Icons.assessment, 0),
              _drawerItem("Not yet Delivered", Icons.location_history, 2),
              const Divider(color: Colors.white30),
              _drawerItem("History", Icons.done_all, 3),
              _drawerItem("Total Earnings", Icons.monetization_on, 4),
              const Divider(color: Colors.white30),
            ],
          ),
        ),
      )
          : null, // Null hides the drawer and the menu icon

      backgroundColor: const Color(0xFF1A2B7B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2B7B),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white), // Ensure drawer icon is white

        title: Text(
          _isBlocked ? "Account Status" : "Welcome $userName",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 1,
          ),
        ),

        // 2. Profile Pop-up Menu
        actions: [
          PopupMenuButton<int>(
            color: const Color(0xFF09113C),
            onSelected: (result) => _onMenuItemSelected(context, result),
            itemBuilder: (context) => menuItems,
            // Child is the avatar widget
            child: _buildProfileAvatar(),
          ),
        ],
      ),

      // 3. Conditional Body Content
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Status Card: Displays block/login status or delivery status
              Container(
                padding: const EdgeInsets.all(25),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      _isBlocked ? Icons.block : (_isLoggedIn ? (activeOrders > 0 ? Icons.fire_truck : Icons.check_circle_outline) : Icons.login),
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bodyText.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 4. Primary Action Button: Only visible if approved and logged in
              if (_isLoggedIn && !_isBlocked)
                ElevatedButton.icon(
                  onPressed: () => _navigateToScreen(0, context),
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text("VIEW AVAILABLE JOBS"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2B7B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
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