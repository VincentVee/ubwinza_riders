import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../global/global_instances.dart';
import '../../global/global_vars.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/vehicle_type_dropdown.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  XFile? imageFile;
  ImagePicker pickerImage = ImagePicker();

  TextEditingController nameTextEditingController = TextEditingController();
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();
  TextEditingController confirmTextEditingController = TextEditingController();
  TextEditingController phoneTextEditingController = TextEditingController();
  TextEditingController vehicleModelTextEditingController =
  TextEditingController();
  TextEditingController vehicleColorTextEditingController =
  TextEditingController();
  TextEditingController licensePlateTextEditingController =
  TextEditingController();
  TextEditingController balanceTextEditingController =
  TextEditingController();
  TextEditingController commissionTextEditingController =
  TextEditingController();
  TextEditingController locationTextEditingController = TextEditingController();

  /// Null at start so user explicitly chooses a type
  String? selectedVehicleType;

  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool _isSigningUp = false;

  Future<void> pickImageFromGallery() async {
    imageFile = await pickerImage.pickImage(source: ImageSource.gallery);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 11),
          InkWell(
            onTap: pickImageFromGallery,
            child: CircleAvatar(
              radius: MediaQuery.of(context).size.width * 0.20,
              backgroundColor: Colors.white,
              backgroundImage:
              imageFile == null ? null : FileImage(File(imageFile!.path)),
              child: imageFile == null
                  ? Icon(
                Icons.add_photo_alternate,
                size: MediaQuery.of(context).size.width * 0.20,
                color: Colors.grey,
              )
                  : null,
            ),
          ),
          const SizedBox(height: 11),
          Form(
            key: formKey,
            child: Column(
              children: [
                CustomeTextField(
                  textEditingController: nameTextEditingController,
                  iconData: Icons.person,
                  hintString: "Full Name",
                  isObsecure: false,
                  enable: true,
                ),
                CustomeTextField(
                  textEditingController: emailTextEditingController,
                  iconData: Icons.email,
                  hintString: "Email",
                  isObsecure: false,
                  enable: true,
                ),
                CustomeTextField(
                  textEditingController: phoneTextEditingController,
                  iconData: Icons.phone,
                  hintString: "Phone (e.g., 0977774423)",
                  isObsecure: false,
                  enable: true,
                ),

                /// Vehicle Type Dropdown (styled like other fields)
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

                /// Only show the following fields when the vehicle type is Motorbike
                if (selectedVehicleType == 'motorbike') ...[
                  CustomeTextField(
                    textEditingController: vehicleModelTextEditingController,
                    iconData: Icons.directions_bike,
                    hintString: "Vehicle Model (e.g., Honda CG125)",
                    isObsecure: false,
                    enable: true,
                  ),
                  CustomeTextField(
                    textEditingController: vehicleColorTextEditingController,
                    iconData: Icons.color_lens,
                    hintString: "Vehicle Color",
                    isObsecure: false,
                    enable: true,
                  ),
                  CustomeTextField(
                    textEditingController: licensePlateTextEditingController,
                    iconData: Icons.confirmation_number,
                    hintString: "License Plate",
                    isObsecure: false,
                    enable: true,
                  ),
                ],

                CustomeTextField(
                  textEditingController: passwordTextEditingController,
                  iconData: Icons.lock,
                  hintString: "Password",
                  isObsecure: true,
                  enable: true,
                ),
                CustomeTextField(
                  textEditingController: confirmTextEditingController,
                  iconData: Icons.lock,
                  hintString: "Confirm Password",
                  isObsecure: true,
                  enable: true,
                ),
                CustomeTextField(
                  textEditingController: locationTextEditingController,
                  iconData: Icons.my_location,
                  hintString: "My Current Location",
                  isObsecure: false,
                  enable: true,
                ),
                Container(
                  width: 398,
                  height: 39,
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      String address =
                      await commonViewModel.getCurrentLocation();
                      setState(() {
                        locationTextEditingController.text = address;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    label: const Text(
                      "Get my current address",
                      style: TextStyle(color: Colors.white),
                    ),
                    icon: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                ElevatedButton(
                  onPressed: _isSigningUp
                      ? null
                      : () async {
                    if (formKey.currentState!.validate()) {
                      setState(() {
                        _isSigningUp = true;
                      });

                      await authViewModel.validateSignUpForm(
                        imageFile,
                        passwordTextEditingController.text.trim(),
                        confirmTextEditingController.text.trim(),
                        emailTextEditingController.text.trim(),
                        nameTextEditingController.text.trim(),
                        phoneTextEditingController.text.trim(),
                        selectedVehicleType ??
                            '', // dropdown validator ensures this is set
                        vehicleModelTextEditingController.text.trim(),
                        vehicleColorTextEditingController.text.trim(),
                        licensePlateTextEditingController.text.trim(),
                        locationTextEditingController.text.trim(),
                        (balanceTextEditingController.text.trim()?? 0) as double?,
                        (commissionTextEditingController.text.trim()?? 0) as double?,
                        context,
                      );

                      setState(() {
                        _isSigningUp = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 10),
                  ),
                  child: _isSigningUp
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    "Sign Up",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 37),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
