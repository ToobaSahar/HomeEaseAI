import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expandable/expandable.dart';

class ProfileScreen extends StatelessWidget {
  final List<String> highEnergyAppliances = [
    "Refrigerator", "Microwave", "Dishwasher", "Oven",
    "Washing Machine", "Dryer", "Air Conditioner", "Heater", "Iron",
  ];

  final Map<String, IconData> applianceIcons = {
    "Refrigerator": Icons.kitchen,
    "Microwave": Icons.microwave,
    "Dishwasher": Icons.cleaning_services,
    "Oven": Icons.local_pizza,
    "Washing Machine": Icons.local_laundry_service,
    "Dryer": Icons.dry,
    "Air Conditioner": Icons.ac_unit,
    "Heater": Icons.heat_pump,
    "Iron": Icons.iron,
  };

  // User Preferences & Icons
  final Map<String, IconData> preferenceIcons = {
    "Energy Saving Mode": Icons.energy_savings_leaf,
    "Meal Plan Suggestions": Icons.restaurant_menu,
    "Daily Cleaning Schedule": Icons.cleaning_services,
    "Fitness Tracking": Icons.fitness_center,
    "Interior Design Suggestions": Icons.home,
    "Smart Shopping Recommendations": Icons.shopping_cart,
    "Low-Cost Utility Providers": Icons.attach_money,
    "Weekend Activity Suggestions": Icons.weekend,
    "Family Health Reminders": Icons.health_and_safety,
    "Customized Notifications": Icons.notifications_active,
    "Eco-Friendly Practices": Icons.eco,
    "Budget Tracking": Icons.account_balance_wallet,
    "Time-Saving Tips": Icons.timer,
    "Weather-Based Suggestions": Icons.wb_sunny,
    "Child Safety Alerts": Icons.child_care,
  };

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "No user found. Please log in.",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text("User Details", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading profile data."));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                "No profile data found.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            );
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>?;
          if (userData == null) {
            return Center(
              child: Text(
                "User data not found.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            );
          }

          List<dynamic> appliances = userData['appliances'] ?? [];
          List<dynamic> preferences = userData['selectedPreferences'] ?? [];
          String profilePic = userData['profile_picture'] ?? '';
          String username = userData['username'] ?? 'User';
          String email = userData['email'] ?? 'No Email';

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// Profile Picture
                CircleAvatar(
                  radius: 50,
                  backgroundImage: profilePic.isNotEmpty
                      ? NetworkImage(profilePic)
                      : AssetImage("assets/default_user.png") as ImageProvider,
                ),
                SizedBox(height: 15),

                /// User Info
                Text(
                  username,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  email,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                SizedBox(height: 20),

                /// Expandable Appliances Section
                ExpandableNotifier(
                  child: Column(
                    children: [
                      ExpandablePanel(
                        header: Row(
                          children: [
                            Icon(Icons.devices, color: Colors.blueAccent),
                            SizedBox(width: 10),
                            Text(
                              "Selected Appliances",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                          ],
                        ),
                        collapsed: Container(),
                        expanded: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: appliances.map((appliance) {
                            return Chip(
                              avatar: Icon(applianceIcons[appliance] ?? Icons.devices, color: Colors.white),
                              label: Text(appliance, style: TextStyle(color: Colors.white)),
                              backgroundColor: Colors.blueAccent,
                              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            );
                          }).toList(),
                        ),
                        theme: ExpandableThemeData(
                          tapHeaderToExpand: true,
                          tapBodyToCollapse: true,
                          hasIcon: true,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                /// Expandable Preferences Section
                ExpandableNotifier(
                  child: Column(
                    children: [
                      ExpandablePanel(
                        header: Row(
                          children: [
                            Icon(Icons.settings, color: Colors.green),
                            SizedBox(width: 10),
                            Text(
                              "User Preferences",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        collapsed: Container(),
                        expanded: Column(  // Change Wrap to Column to make each preference take full width
                          children: preferences.map((preference) {
                            return Container(
                              width: double.infinity, // Ensures full width
                              margin: EdgeInsets.symmetric(vertical: 4), // Adds spacing between items
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8), // Rounded corners
                              ),
                              child: Row(
                                children: [
                                  Icon(preferenceIcons[preference] ?? Icons.settings, color: Colors.white),
                                  SizedBox(width: 10),
                                  Expanded( // Ensures text takes the remaining space
                                    child: Text(
                                      preference,
                                      style: TextStyle(color: Colors.white, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        theme: ExpandableThemeData(
                          tapHeaderToExpand: true,
                          tapBodyToCollapse: true,
                          hasIcon: true,
                        ),
                      ),
                    ],
                  ),
                ),

              ],
            ),
          );
        },
      ),
    );
  }
}