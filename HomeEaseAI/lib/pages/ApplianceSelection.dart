import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../widgets/Background_painter.dart';
import 'preferences.dart';
import 'package:day35/pages/SignupLogin.dart';

class ApplianceSelectionScreen extends StatefulWidget {
  final List<String> selectedAppliances; // Pass selected appliances
  final bool cameFromEditMode;
  final String? initialEmail;
  final String? initialPassword;
  final String? initialUsername;
  const ApplianceSelectionScreen({Key? key, required this.selectedAppliances,  this.cameFromEditMode = false, this.initialEmail,
    this.initialPassword,
    this.initialUsername, }) : super(key: key);

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
    if ((state == AppLifecycleState.detached || state == AppLifecycleState.inactive) &&
        !hasCompletedSelection && !widget.cameFromEditMode) {
      _deleteUserData();
    }
  }

  Future<void> _deleteUserData() async {
    try {
      if (userId != null) {
        await _firestore.collection("users").doc(userId).delete();
        await _auth.currentUser?.delete();
      }

      // 🚀 Go back to Signup screen with previous data if not from edit mode
      if (!widget.cameFromEditMode) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginSignupScreen(
              isEditProfileMode: false,
              initialEmail: widget.initialEmail,
              initialPassword: widget.initialPassword,
              initialUsername: widget.initialUsername,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error deleting user data: $e");
    }
  }

  void _checkUserStatus() async {
    await Future.delayed(Duration(milliseconds: 300)); // 🔧 Give Firebase time

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        userId = currentUser.uid;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginSignupScreen(
            isEditProfileMode: widget.cameFromEditMode, // 👈 if edit
          ),
        ),
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
          builder: (context) => PreferenceTagScreen(
            selectedAppliances: selected,
            cameFromEditMode: widget.cameFromEditMode,
            initialEmail: widget.initialEmail,
            initialPassword: widget.initialPassword,
            initialUsername: widget.initialUsername,
          ),
        ),
      );

    } catch (e) {
      print("Error saving appliances: $e");
    }
  }

  Widget buildApplianceForm(Color primaryBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Tap to Select",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
            fontFamily: 'FunnelDisplay',
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 1.15,
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
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryBlue : Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: isSelected ? primaryBlue : Colors.grey.shade300,
                      width: 3,
                    ),
                    boxShadow: const [
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
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          icon,
                          key: ValueKey<bool>(isSelected),
                          size: 40,
                          color: isSelected ? Colors.white : primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appliance,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'FunnelDisplay',
                          color: isSelected ? Colors.white : Color.fromRGBO(37, 138, 212, 1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
    Center(
    child: SizedBox(
    width: 180, // 👈 adjust as needed (e.g. 160–220)
    child: ElevatedButton(
    onPressed: saveSelections,
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
              "Save & Continue",
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
    );
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
              painter: BackgroundPainter(0), // waveValue can be 0 or animated if needed
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

          // Main Content
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
                  height: 500, // 📐 Consistent height with login/signup form
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
                    bottom: 10, // 👈 reduce this from 30 to 10 or smaller
                  ),

                  child: buildApplianceForm(primaryBlue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
