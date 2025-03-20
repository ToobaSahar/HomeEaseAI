import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ApplianceSelection.dart';
import 'package:animate_do/animate_do.dart';

class PreferenceTagScreen extends StatefulWidget {
  final List<String> selectedAppliances;

  const PreferenceTagScreen({Key? key, required this.selectedAppliances}) : super(key: key);

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
        // Delete user document from Firestore
        await _firestore.collection("users").doc(userId).delete();

        // Delete user authentication record
        await _auth.currentUser?.delete();

        // Clear SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove("selectedPreferences");
        await prefs.remove("preferencesSet");

        print("User data deleted successfully.");
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
      _deleteUserData(); // Delete user data when the app is closed
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
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ApplianceSelectionScreen(
                          selectedAppliances: widget.selectedAppliances,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: const Text(
                        "Select Your Preferences",
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
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
                              List<String> updatedPrefs = List.from(selectedPrefs);
                              if (isSelected) {
                                updatedPrefs.remove(preference["title"]);
                              } else {
                                updatedPrefs.add(preference["title"]!);
                              }
                              selectedPreferences.value = updatedPrefs;
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              margin: const EdgeInsets.only(bottom: 12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.shade900 : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isSelected ? Colors.blue.shade900 : Colors.grey.shade300,
                                    width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 5,
                                    offset: const Offset(2, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    preference["icon"]!,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      preference["title"]!,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
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
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  "Save Preferences",
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
