import 'package:flutter/material.dart';

class WithdrawScreen extends StatelessWidget {
  const WithdrawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Withdraw"),
        backgroundColor: const Color(0xFF1A2B7B),
      ),
      body: const Center(
        child: Text(
          "Withdraw functionality coming here 💸",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}