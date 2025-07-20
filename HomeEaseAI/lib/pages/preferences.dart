import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ApplianceSelection.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lottie/lottie.dart';
import '../widgets/Background_painter.dart';

class PreferenceTagScreen extends StatefulWidget {
  final List<String> selectedAppliances;
  final bool cameFromEditMode;
  final String? initialEmail;
  final String? initialPassword;
  final String? initialUsername;
  const PreferenceTagScreen({
    Key? key,
    required this.selectedAppliances,
    this.cameFromEditMode = false,
    this.initialEmail,
    this.initialPassword,
    this.initialUsername,
  }) : super(key: key);

  @override
  _PreferenceTagScreenState createState() => _PreferenceTagScreenState();
}

class _PreferenceTagScreenState extends State<PreferenceTagScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? userId;
  ValueNotifier<List<String>> selectedPreferences = ValueNotifier<List<String>>([]);

  final List<Map<String, String>> preferences = [
    {"title": "Energy Saving Mode", "icon": "⚡"},
    {"title": "Meal Plan Suggestions", "icon": "🍽️"},
    {"title": "Daily Cleaning Schedule", "icon": "🧹"},
    {"title": "Fitness Tracking", "icon": "🏋️‍♂️"},
    {"title": "Interior Design Suggestions", "icon": "🖼️"},
    {"title": "Smart Shopping Recommendations", "icon": "🛍️"},
    {"title": "Low-Cost Utility Providers", "icon": "💡"},
    {"title": "Weekend Activity Suggestions", "icon": "🏞️"},
    {"title": "Family Health Reminders", "icon": "🩺"},
    {"title": "Customized Notifications", "icon": "🔔"},
    {"title": "Eco-Friendly Practices", "icon": "🌱"},
    {"title": "Budget Tracking", "icon": "💰"},
    {"title": "Time-Saving Tips", "icon": "⏳"},
    {"title": "Weather-Based Suggestions", "icon": "🌤️"},
  ];

  final Color primaryBlue = const Color.fromRGBO(37, 138, 212, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getUserId();
  }

  void _getUserId() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        userId = currentUser.uid;
      });
      _loadSelectedPreferences();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ApplianceSelectionScreen(
            selectedAppliances: widget.selectedAppliances,
            cameFromEditMode: widget.cameFromEditMode,
          ),
        ),
      );
    }
  }

  void _loadSelectedPreferences() async {
    if (userId != null) {
      DocumentSnapshot userDoc = await _firestore.collection("users").doc(userId).get();
      if (userDoc.exists && userDoc["selectedPreferences"] != null) {
        List<String> savedPrefs = List<String>.from(userDoc["selectedPreferences"]);
        selectedPreferences.value = savedPrefs;
      }
    }
  }

  Future<void> _deleteUserData() async {
    if (userId != null) {
      try {
        await _firestore.collection("users").doc(userId).delete();
        await _auth.currentUser?.delete();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove("selectedPreferences");
        await prefs.remove("preferencesSet");
      } catch (e) {
        print("Error deleting user data: $e");
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      _deleteUserData();
    }
  }

  Future<void> _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (userId != null) {
      await _firestore.collection("users").doc(userId).update({
        "selectedPreferences": selectedPreferences.value,
      });
      await prefs.setStringList("selectedPreferences", selectedPreferences.value);
      await prefs.setBool("preferencesSet", true);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const primaryBlue = Color.fromRGBO(37, 138, 212, 1);

    return Scaffold(
      body: Stack(
        children: [
          // 🌊 Background gradient
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPainter(0),
            ),
          ),

          // 🎞️ Lottie animation
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Lottie.asset(
                  'assets/animations/Fgk7yLhCCa.json',
                  width: 450,
                  height: 450,
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                ),
              ),
            ),
          ),

          // Main Content styled like ApplianceSelectionScreen
          Column(
            children: [
              const SizedBox(height: 60),
              Text(
                'HomeEaseAI',
                style: TextStyle(
                  fontSize: size.width > 600 ? 34 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'FunnelDisplay',
                ),
              ),
              const SizedBox(height: 20),
              const Spacer(),

              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: size.width * 0.90,
                  height: 500, // same height as appliance screen
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    top: 20,
                    left: size.width > 600 ? 30 : 15,
                    right: size.width > 600 ? 30 : 15,
                    bottom: 10, // reduced bottom padding
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Keep the original header and back button Row
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: primaryBlue),
                            onPressed: () {
                              if (widget.cameFromEditMode || !widget.cameFromEditMode) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ApplianceSelectionScreen(
                                      selectedAppliances: widget.selectedAppliances,
                                      cameFromEditMode: true,
                                      initialEmail: widget.initialEmail,
                                      initialPassword: widget.initialPassword,
                                      initialUsername: widget.initialUsername,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "Select Your Preferences",
                                style: TextStyle(
                                  fontSize: 22,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'FunnelDisplay',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // 🧭 Scrollable preferences list
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ValueListenableBuilder<List<String>>(
                            valueListenable: selectedPreferences,
                            builder: (context, selectedPrefs, _) {
                              return Column(
                                children: preferences.map((preference) {
                                  bool isSelected = selectedPrefs.contains(preference["title"]);
                                  return GestureDetector(
                                    onTap: () {
                                      List<String> updated = List.from(selectedPrefs);
                                      if (isSelected) {
                                        updated.remove(preference["title"]);
                                      } else {
                                        updated.add(preference["title"]!);
                                      }
                                      selectedPreferences.value = updated;
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: isSelected ? primaryBlue : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: primaryBlue, width: 2),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(2,3)),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Text(preference["icon"]!, style: const TextStyle(fontSize: 20)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              preference["title"]!,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : primaryBlue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                fontFamily: 'FunnelDisplay',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Matching button styling as appliance screen
                      Center(
                        child: SizedBox(
                          width: 180,
                          child: ElevatedButton(
                            onPressed: _savePreferences,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 6,
                              shadowColor: Colors.black45,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14.0),
                              child: Text(
                                "Save Preferences",
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'FunnelDisplay',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
