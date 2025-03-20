import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'preferences.dart';
import 'package:day35/pages/SignupLogin.dart';

class ApplianceSelectionScreen extends StatefulWidget {
  final List<String> selectedAppliances; // Pass selected appliances

  const ApplianceSelectionScreen({Key? key, required this.selectedAppliances}) : super(key: key);

  @override
  _ApplianceSelectionScreenState createState() => _ApplianceSelectionScreenState();
}

class _ApplianceSelectionScreenState extends State<ApplianceSelectionScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? userId;
  bool hasCompletedSelection = false; // To track if user completed selection

  final Map<String, IconData> appliancesWithIcons = {
    "Refrigerator": Icons.kitchen,
    "Microwave": Icons.microwave,
    "Dishwasher": Icons.local_dining,
    "Oven": Icons.local_fire_department,
    "Washing Machine": Icons.local_laundry_service,
    "Dryer": Icons.dry_cleaning,
    "Air Conditioner": Icons.ac_unit,
    "Heater": Icons.whatshot,
    "Iron": Icons.iron,
  };

  late Map<String, bool> selectedAppliances;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUserStatus();
    selectedAppliances = {for (var appliance in appliancesWithIcons.keys) appliance: false};
    for (var appliance in widget.selectedAppliances) {
      selectedAppliances[appliance] = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.detached || state == AppLifecycleState.inactive) && !hasCompletedSelection) {
      _deleteUserData();
    }
  }

  Future<void> _deleteUserData() async {
    try {
      if (userId != null) {
        await _firestore.collection("users").doc(userId).delete();
        await _auth.currentUser?.delete();
      }
    } catch (e) {
      print("Error deleting user data: $e");
    }
  }

  void _checkUserStatus() {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        userId = currentUser.uid;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginSignupScreen()),
      );
    }
  }

  Future<void> saveSelections() async {
    final selected = selectedAppliances.entries.where((entry) => entry.value).map((entry) => entry.key).toList();

    try {
      await _firestore.collection("users").doc(userId).set({
        "appliances": selected,
      }, SetOptions(merge: true));

      setState(() {
        hasCompletedSelection = true; // Mark selection as completed
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appliances saved successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PreferenceTagScreen(selectedAppliances: selected),
        ),
      );
    } catch (e) {
      print("Error saving appliances: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(16.0),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              alignment: Alignment.center,
              child: Text(
                "Tap to Select Your Appliances",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                  childAspectRatio: 1.2,
                ),
                itemCount: appliancesWithIcons.length,
                itemBuilder: (context, index) {
                  final appliance = appliancesWithIcons.keys.elementAt(index);
                  final icon = appliancesWithIcons[appliance]!;
                  final isSelected = selectedAppliances[appliance]!;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAppliances[appliance] = !isSelected;
                      });
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.shade600 : Colors.white,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: isSelected ? Colors.blue.shade900 : Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(2, 3),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) => ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                            child: Icon(
                              icon,
                              key: ValueKey<bool>(isSelected),
                              size: 40,
                              color: isSelected ? Colors.white : Colors.blue.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            appliance,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.bottomCenter,
              child: ElevatedButton(
                onPressed: saveSelections,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                  shadowColor: Colors.black45,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 32.0),
                  child: Text(
                    "Save & Continue",
                    style: TextStyle(fontSize: 18.0, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
