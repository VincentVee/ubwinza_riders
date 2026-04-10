import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ubwinza_riders/views/mainScreens/parcel_in_progress.dart';

import '../../global/global_vars.dart';

class NewAvailableRequestsScreen extends StatefulWidget {
  const NewAvailableRequestsScreen({super.key});

  @override
  State<NewAvailableRequestsScreen> createState() =>
      _NewAvailableRequestsScreenState();
}

class _NewAvailableRequestsScreenState extends State<NewAvailableRequestsScreen> {

  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? amountError;

  static const double minimumBalance = 50;

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

      /// CHECK RIDER BALANCE FIRST
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection("riders").doc(driverId).snapshots(),
        builder: (context, riderSnapshot) {

          if (riderSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!riderSnapshot.hasData || !riderSnapshot.data!.exists) {
            return const Center(child: Text("Rider profile not found"));
          }

          final riderData =
          riderSnapshot.data!.data() as Map<String, dynamic>;

          final double balance =
          (riderData["balance"] ?? 0).toDouble();

          /// 🚫 BLOCK RIDER IF BALANCE TOO LOW
          if (balance < minimumBalance) {
            return _buildInsufficientBalance(balance);
          }

          /// ✅ SHOW REQUESTS IF BALANCE OK
          return _buildRequestsList(driverId);
        },
      ),
    );
  }

  /// AVAILABLE REQUESTS LIST
  Widget _buildRequestsList(String driverId) {
    return StreamBuilder<QuerySnapshot>(
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

            return Card(
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
                          color: Colors.white
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
                      'Estimated Fare: ZMW ${(data['estimatedFare'] ?? 0).toDouble().toStringAsFixed(2)}',
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
                          ),
                          onPressed: () => _confirmAccept(
                              context, requestId, driverId, data),
                        ),

                        ElevatedButton.icon(
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          onPressed: () => _confirmReject(context, requestId),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// LOW BALANCE SCREEN
  Widget _buildInsufficientBalance(double balance) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Colors.orange,
            ),

            const SizedBox(height: 20),

            const Text(
              "Insufficient Balance",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "Current Balance: ZMW ${balance.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 16,color: Colors.black),
            ),

            const SizedBox(height: 10),

            const Text(
              "You need to top up your wallet to accept rides.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add Amount"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2B7B),
                padding: const EdgeInsets.symmetric(
                    horizontal: 30, vertical: 12),
              ),
              onPressed: () {
                _showTopUpDialog(context);
              },
            ),
          ],
        ),
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

  void _showTopUpDialog(BuildContext context) {

    final amountController = TextEditingController();
    String selectedNetwork = "MTN";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),

      ),
      builder: (context) {

        return StatefulBuilder(
          builder: (context, setState) {

            void setQuickAmount(int amount) {
              amountController.text = amount.toString();
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const Center(
                    child: Text(
                      "Top Up Wallet",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// NETWORK SELECT
                  const Text(
                    "Select Network",
                    style: TextStyle(fontWeight: FontWeight.bold,color: Colors.black),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      _networkButton("MTN", selectedNetwork, (v){
                        setState(()=> selectedNetwork = v);
                      }),

                      _networkButton("Airtel", selectedNetwork, (v){
                        setState(()=> selectedNetwork = v);
                      }),

                      _networkButton("Zamtel", selectedNetwork, (v){
                        setState(()=> selectedNetwork = v);
                      }),

                    ],
                  ),

                  const SizedBox(height: 25),

                  /// QUICK AMOUNTS
                  const Text(
                    "Quick Amount",
                    style: TextStyle(fontWeight: FontWeight.bold,color: Colors.black),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      _quickAmountButton(50, setQuickAmount),
                      _quickAmountButton(100, setQuickAmount),
                      _quickAmountButton(150, setQuickAmount),
                      _quickAmountButton(200, setQuickAmount),

                    ],
                  ),

                  const SizedBox(height: 25),

                  /// MANUAL AMOUNT
                  if (amountError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        amountError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Enter Amount (ZMW)",
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),

                  /// PAY BUTTON
                  SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),

                        child: const Text(
                          "Proceed to Payment",
                          style: TextStyle(fontSize: 16),
                        ),

                          onPressed: () {

                            final amount = double.tryParse(amountController.text) ?? 0;

                            if (amount < 50) {
                              setState(() {
                                amountError = "Please enter an amount of K50 and above.";
                              });
                              return;
                            }

                            setState(() {
                              amountError = null;
                            });

                            Navigator.pop(context);

                            _initiateTopUp(selectedNetwork, amount);
                          },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _networkButton(
      String network,
      String selected,
      Function(String) onTap,
      ) {
    final bool active = network == selected;

    Color networkColor;

    switch (network) {
      case "MTN":
        networkColor = const Color(0xFFFFCC00); // MTN Yellow
        break;

      case "Airtel":
        networkColor = const Color(0xFFE60000); // Airtel Red
        break;

      case "Zamtel":
        networkColor = const Color(0xFF008000); // Zamtel Green
        break;

      default:
        networkColor = Colors.grey;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(network),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 14),

          decoration: BoxDecoration(
            color: networkColor,
            borderRadius: BorderRadius.circular(12),

            /// Highlight if selected
            border: Border.all(
              color: active ? Colors.black : Colors.transparent,
              width: active ? 3 : 0,
            ),

            boxShadow: active
                ? [
              BoxShadow(
                color: networkColor.withOpacity(0.6),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ]
                : [],
          ),

          child: Center(
            child: Text(
              network,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,

                /// MTN text must be black
                color: network == "MTN" ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _quickAmountButton(
      int amount,
      Function(int) onTap,
      ) {
    return GestureDetector(

      onTap: ()=> onTap(amount),

      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 10),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade200,
        ),

        child: Center(
          child: Text(
            "ZMW $amount",
            style: const TextStyle(fontWeight: FontWeight.bold,color: Colors.black),
          ),
        ),
      ),
    );
  }

  void _initiateTopUp(String network, double amount) {

    print("Network: $network");
    print("Amount: $amount");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Processing $network payment of ZMW ${amount.toStringAsFixed(2)}",
        ),
      ),
    );

    /// Here you call
    /// MTN MoMo API
    /// Airtel Money API
    /// Zamtel API
  }
}