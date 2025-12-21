import 'package:flutter/material.dart';
import '../../global/global_instances.dart';
import '../widgets/custom_text_field.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  TextEditingController emailTextEditngController = TextEditingController();
  TextEditingController passwordTextEditngController = TextEditingController();

  bool _isSigningIn = false;
  bool _obscurePassword = true; // <-- toggle state

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                "images/ubwinza-icon.jpeg",
                height: 270,
              ),
            ),
          ),
          Column(
            children: [
              CustomeTextField(
                textEditingController: emailTextEditngController,
                iconData: Icons.email,
                hintString: "Email",
                isObsecure: false,
                enable: true,
              ),
              CustomeTextField(
                textEditingController: passwordTextEditngController,
                iconData: Icons.lock,
                hintString: "Password",
                isObsecure: _obscurePassword, // <-- use toggle
                enable: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isSigningIn
                    ? null
                    : () async {
                  setState(() {
                    _isSigningIn = true;
                  });

                  await authViewModel.validateSignInForm(
                    emailTextEditngController.text.trim(),
                    passwordTextEditngController.text.trim(),
                    context,
                  );

                  setState(() {
                    _isSigningIn = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
                ),
                child: _isSigningIn
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  "Sign In",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
