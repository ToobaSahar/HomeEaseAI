import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../widgets/Background_painter.dart';
import 'ApplianceSelection.dart';

class LoginSignupScreen extends StatefulWidget {
  final bool isEditProfileMode;
  final String? initialEmail;
  final String? initialPassword;
  final String? initialUsername;
  const LoginSignupScreen({
    Key? key,
    this.isEditProfileMode = false,
    this.initialEmail,
    this.initialPassword,
    this.initialUsername,
  }) : super(key: key);

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

    if (widget.isEditProfileMode) {
      isLogin = false; // ❗set first
      // ✅ only populate fields if we're actually in edit mode AND on signup screen
      emailController.text = widget.initialEmail ?? '';
      passwordController.text = widget.initialPassword ?? '';
      usernameController.text = widget.initialUsername ?? '';
    }

    checkAutoLogin();
  }



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> checkAutoLogin() async {
    if (widget.isEditProfileMode) return; // 🚫 skip auto-login in edit mode

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
    if (widget.isEditProfileMode) {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          // ✅ Update username
          await _firestore.collection('users').doc(user.uid).update({
            'username': usernameController.text.trim(),
          });

          // ✅ Fetch selected appliances
          final snapshot = await _firestore.collection('users').doc(user.uid).get();
          final List<String> selectedAppliances = List<String>.from(snapshot.data()?['appliances'] ?? []);

          // ✅ Navigate to ApplianceSelectionScreen with those appliances
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ApplianceSelectionScreen(selectedAppliances: selectedAppliances, cameFromEditMode: true, initialEmail: emailController.text,
                initialPassword: passwordController.text,
                initialUsername: usernameController.text,),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Username updated successfully!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating username: $e"), backgroundColor: Colors.red),
        );
      }
      return;
    }


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
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isPassword = false,
        bool isDisabled = false,
        String? errorText,
      }) {
    return TextField(
      controller: controller,
      enabled: !isDisabled, // 🔐 disable if required
      obscureText: isPassword ? !_isPasswordVisible : false,
      cursorColor: const Color.fromRGBO(37, 138, 212, 1),
      style: const TextStyle(
        color: Color.fromRGBO(37, 138, 212, 1),
        fontFamily: 'FunnelDisplay',
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontFamily: 'FunnelDisplay',
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey.shade500,
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
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color.fromRGBO(37, 138, 212, 1)),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      body: Stack(
        children: [
          // ✅ Keep background gradient as bottom-most
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPainter(_waveAnimation.value),
            ),
          ),

          // ✅ Show Lottie animation ABOVE the gradient and move it up
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 40), // 👈 adjust this value to move it higher/lower
                child: Lottie.asset(
                  'assets/animations/Fgk7yLhCCa.json',
                  width: 450, // optional: control width
                  height: 450, // optional: control height
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 60),
              Text(
                'HomeEaseAI',
                style: TextStyle(
                  fontSize: isWide ? 34 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'FunnelDisplay',
                ),
              ),
              const SizedBox(height: 20),

              const Spacer(), // Push the container to the bottom

              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: size.width * 0.90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                      // bottom corners remain square
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: 30,
                    horizontal: isWide ? 40 : 25,
                  ),
                  child: SizedBox(
                    height: 430, // ✅ This ensures consistent height for both forms
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isLogin ? 'Login' : 'Sign Up',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isWide ? 28 : 24,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromRGBO(37, 138, 212, 1),
                            fontFamily: 'FunnelDisplay',
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!isLogin || widget.isEditProfileMode) ...[
                          _buildTextField(
                            usernameController,
                            'Username',
                            Icons.person,
                            errorText: usernameError.isNotEmpty ? usernameError : null,
                          ),
                          const SizedBox(height: 15),
                        ],


                        _buildTextField(
                            emailController,
                            'Email',
                            Icons.email,
                            errorText: emailError.isNotEmpty ? emailError : null,
                            isDisabled: widget.isEditProfileMode && !isLogin

                        ),

                        const SizedBox(height: 15),
                        _buildTextField(
                            passwordController,
                            'Password',
                            Icons.lock,
                            isPassword: true,
                            errorText: passwordError.isNotEmpty ? passwordError : null,
                            isDisabled: widget.isEditProfileMode && !isLogin
                          // 🔒
                        ),


                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: staySignedIn,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      staySignedIn = value ?? false;
                                    });
                                  },
                                  checkColor: Colors.white,
                                  activeColor: const Color.fromRGBO(37, 138, 212, 1),
                                ),
                                Text(
                                  "Remember me",
                                  style: TextStyle(
                                    color: staySignedIn
                                        ? const Color.fromRGBO(37, 138, 212, 1)
                                        : Colors.grey,
                                    fontFamily: 'FunnelDisplay',
                                  ),
                                ),
                              ],
                            ),

                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDBEEFF),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isLogin ? "Log In" : "Sign Up",
                            style: const TextStyle(
                              color: Color.fromRGBO(37, 138, 212, 1),
                              fontFamily: 'FunnelDisplay',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!widget.isEditProfileMode)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isLogin = !isLogin;
                              });
                            },
                            child: Text(
                              isLogin
                                  ? "Don't have an account? Sign Up"
                                  : "Already have an account? Log In",
                              style: const TextStyle(
                                color: Color.fromRGBO(37, 138, 212, 1),
                                fontFamily: 'FunnelDisplay',
                              ),
                            ),
                          ),

                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

