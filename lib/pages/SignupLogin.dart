import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({Key? key}) : super(key: key);

  @override
  _LoginSignupScreenState createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  bool isLogin = true; // Default login screen
  bool staySignedIn = false; // Stay signed-in checkbox

  String emailError = '';
  String passwordError = '';
  String usernameError = '';

  late AnimationController _controller;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _waveAnimation = Tween<double>(begin: 0, end: pi * 2).animate(_controller);

    checkAutoLogin(); // Check if user wants to stay signed in
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// *Check if "Stay Signed In" is enabled*
  Future<void> checkAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? stayLoggedIn = prefs.getBool("staySignedIn");

    if (stayLoggedIn == true) {
      User? user = _auth.currentUser;
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  /// *Email Validation Function*
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Simple email regex validation
    final RegExp emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  /// *Handle Login or Signup*
  Future<void> handleAuth() async {
    try {
      setState(() {
        emailError = '';
        passwordError = '';
        usernameError = '';
      });

      bool isValid = true;

      if (!isLogin) {
        // Username validation for Signup (only for signup)
        if (usernameController.text.trim().isEmpty) {
          setState(() {
            usernameError = "Username cannot be empty.";
          });
          isValid = false;
        }

        // Password format validation (only for signup)
        String password = passwordController.text.trim();
        if (password.length < 8 || password.length > 12 || !RegExp(r'^[A-Z]').hasMatch(password)) {
          setState(() {
            passwordError = "Password must start with an uppercase letter and be 8-12 characters long.";
          });
          isValid = false;
        }
      }

      // Updated Email validation using regex function
      String? emailValidationResult = _validateEmail(emailController.text.trim());
      if (emailValidationResult != null) {
        setState(() {
          emailError = emailValidationResult;
        });
        isValid = false;
      }

      if (!isValid) return;

      UserCredential userCredential;
      SharedPreferences prefs = await SharedPreferences.getInstance();

      if (isLogin) {
        try {
          userCredential = await _auth.signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

          await prefs.setBool("isNewUser", false);
          await prefs.setBool("staySignedIn", staySignedIn);

          Navigator.pushReplacementNamed(context, '/home');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Login Successful!"),
              backgroundColor: Colors.green,
            ),
          );
        } on FirebaseAuthException catch (e) {
          // Always show "Password and email don't match" for login errors
          setState(() {
            passwordError = "Password and email don't match";
          });
        }
      } else {
        try {
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

          String newUserId = userCredential.user!.uid;

          await _firestore.collection("users").doc(newUserId).set({
            "email": emailController.text.trim(),
            "username": usernameController.text.trim(),
          }, SetOptions(merge: true));

          await prefs.setBool("isNewUser", true);
          await prefs.setBool("staySignedIn", staySignedIn);

          Navigator.pushReplacementNamed(context, '/applianceSelection');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Signup Successful!"),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }


  /// *Reusable TextField Widget*
  bool _isPasswordVisible = false; // Define this variable in your State class

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isPassword = false, String? errorText}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? !_isPasswordVisible : false,  // Toggle visibility
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: Icon(icon, color: Colors.white),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        )
            : null,
        errorText: errorText,
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: BackgroundPainter(_waveAnimation.value),
                child: Container(),
              );
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 160, // Enlarged Logo
                  ),
                  const SizedBox(height: 25),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white.withOpacity(0.1),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isLogin) ...[
                            _buildTextField(usernameController, 'Username', Icons.person,
                                errorText: usernameError.isNotEmpty ? usernameError : null),
                            const SizedBox(height: 15),
                          ],
                          _buildTextField(emailController, 'Email', Icons.email,
                              errorText: emailError.isNotEmpty ? emailError : null),
                          const SizedBox(height: 15),
                          _buildTextField(passwordController, 'Password', Icons.lock,
                              isPassword: true, errorText: passwordError.isNotEmpty ? passwordError : null),
                          const SizedBox(height: 10),
                          // Stay Signed In Checkbox
                          Row(
                            children: [
                              Checkbox(
                                value: staySignedIn,
                                onChanged: (bool? value) {
                                  setState(() {
                                    staySignedIn = value ?? false;
                                  });
                                },
                                activeColor: Colors.blueAccent,
                              ),
                              const Text("Stay Signed In", style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: handleAuth,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(isLogin ? "Login" : "Sign Up"),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isLogin = !isLogin;
                              });
                            },
                            child: Text(
                              isLogin
                                  ? "Don't have an account? Sign up"
                                  : "Already have an account? Login",
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class BackgroundPainter extends CustomPainter {
  final double waveValue;

  BackgroundPainter(this.waveValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.blueGrey.shade900,
          Colors.blueGrey.shade700,
          Colors.blueGrey.shade500
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}