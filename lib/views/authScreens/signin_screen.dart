import 'package:flutter/material.dart';
import '../../global/global_instances.dart';
import '../widgets/custom_text_field.dart';
import 'signup_screen.dart'; // Ensure correct path import

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController emailTextEditingController = TextEditingController();
  final TextEditingController passwordTextEditingController = TextEditingController();

  bool _isSigningIn = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailTextEditingController.dispose();
    passwordTextEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Welcome Back",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF09113C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Sign in to secure your route and start earning",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),

          Column(
            children: [
              CustomeTextField(
                textEditingController: emailTextEditingController,
                iconData: Icons.email_outlined,
                hintString: "Email Address",
                isObsecure: false,
                enable: !_isSigningIn,
              ),
              const SizedBox(height: 16),
              CustomeTextField(
                textEditingController: passwordTextEditingController,
                iconData: Icons.lock_outline_rounded,
                hintString: "Password",
                isObsecure: _obscurePassword,
                enable: !_isSigningIn,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey.shade500,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSigningIn ? null : _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2B7B),
                    disabledBackgroundColor: const Color(0xFF1A2B7B).withOpacity(0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSigningIn
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Text(
                    "Sign In",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // LINK TO SIGN UP PAGE
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      "Register Here",
                      style: TextStyle(
                        color: Color(0xFF1A2B7B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });

    await authViewModel.validateSignInForm(
      emailTextEditingController.text.trim(),
      passwordTextEditingController.text.trim(),
      context,
    );

    if (mounted) {
      setState(() {
        _isSigningIn = false;
      });
    }
  }
}