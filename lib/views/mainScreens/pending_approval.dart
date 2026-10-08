import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../global/global_instances.dart';
import '../../global/global_vars.dart';
import '../authScreens/auth_screen.dart';
import '../mainScreens/home_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  String status = 'pending';
  bool _isCheckingManual = false;

  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
  }

  void _checkApprovalStatus() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    FirebaseFirestore.instance
        .collection('riders')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final newStatus = snapshot.data()?['status'] ?? 'pending';
        if (newStatus != status) {
          if (mounted) {
            setState(() {
              status = newStatus;
            });
          }

          if (newStatus == 'approved') {
            _updateCacheAndNavigateHome(newStatus);
          } else if (newStatus == 'rejected') {
            _showRejectionMessage();
          }
        }
      }
    });
  }

  Future<void> _manualStatusCheck() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isCheckingManual = true;
    });

    try {
      DocumentSnapshot snap = await FirebaseFirestore.instance.collection('riders').doc(userId).get();
      if (snap.exists) {
        String currentStatus = snap.get('status') ?? 'pending';
        if (currentStatus == 'approved') {
          _updateCacheAndNavigateHome(currentStatus);
          return;
        } else if (currentStatus == 'rejected') {
          _showRejectionMessage();
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification pending. Our admins are still evaluating your profile."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Handle exceptions or errors here safely
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingManual = false;
        });
      }
    }
  }
  // Updates Shared Preferences first, then routes to clear loops safely
  Future<void> _updateCacheAndNavigateHome(String finalStatus) async {
    await sharedPreferences!.setString("status", finalStatus);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _showRejectionMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Application Rejected', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your account registration application has been rejected by management. Please contact rider operations support details.',
          style: TextStyle(color: Color(0xFF495057), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => _handleSignOut(),
            child: const Text('OK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    await sharedPreferences!.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09113C),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
              child: Column(
                children: [
                  const Text(
                    'Ubwinza Riders',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verification Hub',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
                            strokeWidth: 3,
                          ),
                        ),
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.history_toggle_off_rounded,
                            size: 48,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Profile Under Review',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF09113C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your partner documents are currently being checked against standard compliance profiles.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ' vetting evaluations complete within 24-48 hours. Secure notifications will deploy post-activation.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: Colors.blue.shade800, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Live sync state operational. This module updates immediately upon admin authorization metrics.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isCheckingManual ? null : _manualStatusCheck,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A2B7B),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isCheckingManual
                            ? const SizedBox.shrink()
                            : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                        label: _isCheckingManual
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Text(
                          "Refresh Application Status",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SafeArea(
                      child: TextButton.icon(
                        onPressed: () => _handleSignOut(),
                        icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF1A2B7B)),
                        label: const Text(
                          'Disconnect / Sign Out',
                          style: TextStyle(
                            color: Color(0xFF1A2B7B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}