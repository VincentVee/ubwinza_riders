import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// IMPORTANT: Ensure this import path is correct for your project structure
import '../../view_models/auth_view_model.dart';

// ------------------------------------------------------------------------
// --- COMPLETE PROFILE SCREEN CLASS ---
// ------------------------------------------------------------------------

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Define the common colors for clarity and reuse
  static const Color appPrimaryColor = Color(0xFF1A2B7B);
  static const Color accentColor = Color(0xFFFF5A3D);
  static const Color scaffoldBackgroundColor = Color(0xFF09113C);

  @override
  Widget build(BuildContext context) {
    // ASSUMPTION: AuthViewModel is provided higher up in the widget tree.
    // Ensure you have a ChangeNotifierProvider wrapping your app/home screen
    final authViewModel = context.watch<AuthViewModel>();
    final user = authViewModel.getCurrentUser();

    final String name = user.name ?? 'Guest Rider';
    final String email = user.email ?? 'N/A';
    final String imageUrl = user.imageUrl ?? '';
    final String phone = user.phone ?? 'N/A';
    final String vehicleType = user.vehicleType ?? 'N/A';
    final String status = user.status ?? 'Unknown';

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: appPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // -------------------
              // 1. Profile Picture (Editable via Icon Tap)
              // -------------------
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : null,
                      child: imageUrl.isEmpty
                          ? const Icon(
                        Icons.person,
                        size: 60,
                        color: appPrimaryColor,
                      )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell( // Make camera icon tappable
                        onTap: () async {
                          await authViewModel.pickImageAndUpdate(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
        
              // -------------------
              // 2. User Details (Name is editable)
              // -------------------
              _buildProfileDetailCard(
                context: context,
                authViewModel: authViewModel,
                icon: Icons.person_outline,
                label: 'Name',
                value: name,
                isEditable: true,
                onTap: () {
                  _showEditNameDialog(context, authViewModel, name);
                },
              ),
              _buildProfileDetailCard(
                context: context,
                authViewModel: authViewModel,
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: phone,
                isEditable: false,
              ),
              _buildProfileDetailCard(
                context: context,
                authViewModel: authViewModel,
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
                isEditable: false,
              ),
              _buildProfileDetailCard(
                context: context,
                authViewModel: authViewModel,
                icon: Icons.verified_user_outlined,
                label: 'Rider Status',
                value: status.toUpperCase(),
                isEditable: false,
              ),
              _buildProfileDetailCard(
                context: context,
                authViewModel: authViewModel,
                icon: Icons.two_wheeler_outlined,
                label: 'Vehicle Type',
                value: vehicleType.toUpperCase(),
                isEditable: false,
              ),
        
              const SizedBox(height: 32),
        
              // -------------------
              // 3. Action Buttons (Logout)
              // -------------------
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => authViewModel.logout(context),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper function to show a dialog for editing the user's name.
  void _showEditNameDialog(BuildContext context, AuthViewModel authViewModel, String currentName) {
    final TextEditingController nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2B7B),
          title: const Text('Edit Name', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter new name',
              hintStyle: const TextStyle(color: Colors.white70),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Save', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != currentName) {
                  Navigator.of(dialogContext).pop();
                  await authViewModel.updateUserName(newName, context);
                } else {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }


  /// Reusable widget for displaying profile details.
  Widget _buildProfileDetailCard({
    required BuildContext context,
    required AuthViewModel authViewModel,
    required IconData icon,
    required String label,
    required String value,
    bool isEditable = true,
    VoidCallback? onTap,
  }) {
    const Color cardColor = Color(0xFF1A2B7B);

    return Card(
      elevation: 1,
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      child: InkWell(
        onTap: isEditable ? onTap : null,

        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (isEditable)
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}