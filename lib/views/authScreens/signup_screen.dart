import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/services/place_service.dart';
import '../../global/global_instances.dart';
import '../../global/global_vars.dart';

import '../../widgets/place_autocomplete_field.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/vehicle_type_dropdown.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  XFile? profileImageFile;
  XFile? nrcFrontImageFile;
  XFile? nrcBackImageFile;
  ImagePicker pickerImage = ImagePicker();

  TextEditingController nameTextEditingController = TextEditingController();
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();
  TextEditingController confirmTextEditingController = TextEditingController();
  TextEditingController phoneTextEditingController = TextEditingController();
  TextEditingController vehicleModelTextEditingController = TextEditingController();
  TextEditingController vehicleColorTextEditingController = TextEditingController();
  TextEditingController licensePlateTextEditingController = TextEditingController();
  TextEditingController locationTextEditingController = TextEditingController();
  TextEditingController nrcNumberTextEditingController = TextEditingController();

  String? selectedVehicleType;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool _isSigningUp = false;

  late final PlaceService _placeService = PlaceService(googleApiKey);
  double? _baseLatitude;
  double? _baseLongitude;

  Future<void> pickImage(ImageSource source, String type) async {
    XFile? pickedFile = await pickerImage.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        if (type == 'profile') {
          profileImageFile = pickedFile;
        } else if (type == 'nrcFront') {
          nrcFrontImageFile = pickedFile;
        } else if (type == 'nrcBack') {
          nrcBackImageFile = pickedFile;
        }
      });
    }
  }

  Widget _buildImagePicker(String title, XFile? imageFile, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showImageSourceDialog(type),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: imageFile == null
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 34,
                  color: const Color(0xFF1A2B7B),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload Image',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.file(
                File(imageFile.path),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showImageSourceDialog(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1A2B7B)),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.camera, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF1A2B7B)),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.gallery, type);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09113C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Partner Registration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _showImageSourceDialog('profile'),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        backgroundImage: profileImageFile == null ? null : FileImage(File(profileImageFile!.path)),
                        child: profileImageFile == null
                            ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 28, color: Colors.white70),
                            SizedBox(height: 4),
                            Text('Add Photo', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
                          ],
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Profile Picture', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(36), topRight: Radius.circular(36)),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF09113C))),
                      const SizedBox(height: 16),
                      CustomeTextField(textEditingController: nameTextEditingController, iconData: Icons.person_outline, hintString: "Full Name", isObsecure: false, enable: true),
                      const SizedBox(height: 12),
                      CustomeTextField(textEditingController: emailTextEditingController, iconData: Icons.email_outlined, hintString: "Email Address", isObsecure: false, enable: true),
                      const SizedBox(height: 12),
                      CustomeTextField(textEditingController: phoneTextEditingController, iconData: Icons.phone_android_outlined, hintString: "Phone Number", isObsecure: false, enable: true),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      const Text('NRC Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF09113C))),
                      const SizedBox(height: 16),
                      CustomeTextField(textEditingController: nrcNumberTextEditingController, iconData: Icons.badge_outlined, hintString: "NRC Number (e.g., 123456/78/1)", isObsecure: false, enable: true),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildImagePicker('NRC Front Side', nrcFrontImageFile, 'nrcFront')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildImagePicker('NRC Back Side', nrcBackImageFile, 'nrcBack')),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      const Text('Vehicle Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF09113C))),
                      const SizedBox(height: 16),
                      VehicleTypeDropdown(
                        selectedVehicleType: selectedVehicleType,
                        onVehicleTypeChanged: (String? newValue) {
                          setState(() {
                            selectedVehicleType = newValue;
                            if (selectedVehicleType != 'motorbike') {
                              vehicleModelTextEditingController.clear();
                              vehicleColorTextEditingController.clear();
                              licensePlateTextEditingController.clear();
                            }
                          });
                        },
                      ),
                      if (selectedVehicleType == 'motorbike') ...[
                        const SizedBox(height: 12),
                        CustomeTextField(textEditingController: vehicleModelTextEditingController, iconData: Icons.delivery_dining_outlined, hintString: "Vehicle Model (e.g., Honda)", isObsecure: false, enable: true),
                        const SizedBox(height: 12),
                        CustomeTextField(textEditingController: vehicleColorTextEditingController, iconData: Icons.color_lens_outlined, hintString: "Vehicle Color", isObsecure: false, enable: true),
                        const SizedBox(height: 12),
                        CustomeTextField(textEditingController: licensePlateTextEditingController, iconData: Icons.pin_outlined, hintString: "License Plate", isObsecure: false, enable: true),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      const Text('Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF09113C))),
                      const SizedBox(height: 16),
                      CustomeTextField(textEditingController: passwordTextEditingController, iconData: Icons.lock_outline, hintString: "Password", isObsecure: true, enable: true),
                      const SizedBox(height: 12),
                      CustomeTextField(textEditingController: confirmTextEditingController, iconData: Icons.lock_reset_outlined, hintString: "Confirm Password", isObsecure: true, enable: true),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      const Text('Location Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF09113C))),
                      const SizedBox(height: 16),

                      PlaceAutocompleteField(
                        controller: locationTextEditingController,
                        service: _placeService,
                        label: "My Home Base Address",
                        onClear: () {
                          setState(() {
                            locationTextEditingController.clear();
                            _baseLatitude = null;
                            _baseLongitude = null;
                          });
                        },
                        onPlacePicked: (PlaceDetail detail) async {
                          setState(() {
                            locationTextEditingController.text = detail.address;
                            _baseLatitude = detail.latLng.latitude;
                            _baseLongitude = detail.latLng.longitude;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            String address = await commonViewModel.getCurrentLocation();
                            setState(() {
                              locationTextEditingController.text = address;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1A2B7B), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          label: const Text("Fetch Current Address", style: TextStyle(color: Color(0xFF1A2B7B), fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.location_searching_rounded, color: Color(0xFF1A2B7B), size: 18),
                        ),
                      ),

                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSigningUp ? null : _handleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2B7B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isSigningUp
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text("Submit Registration", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Icon(Icons.assignment_ind_outlined, color: Colors.blue.shade800, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Applications are vetted within 24 hours. You will receive access updates immediately after approval.',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.4, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have an account? ", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              "Sign In",
                              style: TextStyle(color: Color(0xFF1A2B7B), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (formKey.currentState!.validate()) {
      if (profileImageFile == null) {
        commonViewModel.showSnackBar("Please add a profile picture", context);
        return;
      }
      if (nrcFrontImageFile == null || nrcBackImageFile == null) {
        commonViewModel.showSnackBar("Please upload both sides of your NRC", context);
        return;
      }
      if (nrcNumberTextEditingController.text.trim().isEmpty) {
        commonViewModel.showSnackBar("Please enter your NRC number", context);
        return;
      }
      if (locationTextEditingController.text.trim().isEmpty) {
        commonViewModel.showSnackBar("Please specify your home base address", context);
        return;
      }

      setState(() {
        _isSigningUp = true;
      });

      await authViewModel.validateSignUpForm(
        profileImageFile,
        nrcFrontImageFile,
        nrcBackImageFile,
        nrcNumberTextEditingController.text.trim(),
        passwordTextEditingController.text.trim(),
        confirmTextEditingController.text.trim(),
        emailTextEditingController.text.trim(),
        nameTextEditingController.text.trim(),
        phoneTextEditingController.text.trim(),
        selectedVehicleType ?? '',
        vehicleModelTextEditingController.text.trim(),
        vehicleColorTextEditingController.text.trim(),
        licensePlateTextEditingController.text.trim(),
        locationTextEditingController.text.trim(),
        context,
      );

      if (mounted) {
        setState(() {
          _isSigningUp = false;
        });
      }
    }
  }
}