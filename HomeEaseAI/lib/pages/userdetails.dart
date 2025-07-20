import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expandable/expandable.dart';

import '../widgets/Bottom_nav_bar.dart';
import '../pages/SignupLogin.dart';
import '../widgets/chat_tab_popup.dart'; // 🔽 Needed for logout redirect

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  void logoutUser(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginSignupScreen(),
        transitionDuration: Duration(milliseconds: 800),
      ),
    );
  }
  final TextEditingController chatNameController = TextEditingController();
  int currentIndex = 2; // Active tab for Profile


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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot>(
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

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Profile",
                            style: TextStyle(
                              color: Color.fromRGBO(37, 138, 212, 1),
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'FunnelDisplay',
                            ),
                          ),
                        ),
                        SizedBox(height: 10),

                        CircleAvatar(
                          radius: 50,
                          backgroundImage: profilePic.isNotEmpty
                              ? NetworkImage(profilePic)
                              : AssetImage("assets/images/default_user.webp") as ImageProvider,
                        ),
                        SizedBox(height: 15),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              username,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Color.fromRGBO(37, 138, 212, 1),
                                fontFamily: 'FunnelDisplay',
                              ),
                            ),
                            SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoginSignupScreen(
                                      isEditProfileMode: true,
                                      initialEmail: email,
                                      initialPassword: '********', // dummy
                                      initialUsername: username,
                                    ),
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.edit,
                                size: 20,
                                color: Color.fromRGBO(37, 138, 212, 1),
                              ),
                            ),


                          ],
                        ),

                        SizedBox(height: 5),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color.fromRGBO(37, 138, 212, 1),
                            fontFamily: 'FunnelDisplay',
                          ),
                        ),
                        SizedBox(height: 20),

                        ExpandableNotifier(
                          child: Column(
                            children: [
                              ExpandablePanel(
                                header: Row(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Icon(Icons.devices, color: Color.fromRGBO(142, 98, 255, 1)),
                                    ),
                                    SizedBox(width: 10),
                                    Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text(
                                        "Selected Appliances",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'FunnelDisplay',
                                          color: Color.fromRGBO(142, 98, 255, 1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                collapsed: Container(),
                                expanded: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: appliances.map((appliance) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Color.fromRGBO(142, 98, 255, 1)),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            applianceIcons[appliance] ?? Icons.devices_outlined,
                                            color: Color.fromRGBO(142, 98, 255, 1),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            appliance,
                                            style: TextStyle(
                                              fontFamily: 'FunnelDisplay',
                                              fontSize: 16,
                                              color: Color.fromRGBO(142, 98, 255, 1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                theme: ExpandableThemeData(
                                  iconColor: Color.fromRGBO(142, 98, 255, 1),
                                  tapHeaderToExpand: true,
                                  tapBodyToCollapse: true,
                                  hasIcon: true,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20),

                        ExpandableNotifier(
                          child: Column(
                            children: [
                              ExpandablePanel(
                                header: Row(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Icon(Icons.settings, color: Color.fromRGBO(142, 98, 255, 1)),
                                    ),
                                    SizedBox(width: 10),
                                    Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text(
                                        "User Preferences",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'FunnelDisplay',
                                          color: Color.fromRGBO(142, 98, 255, 1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                collapsed: Container(),
                                expanded: Column(
                                  children: preferences.map((preference) {
                                    return Container(
                                      width: double.infinity,
                                      margin: EdgeInsets.symmetric(vertical: 5),
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Color.fromRGBO(142, 98, 255, 1)),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            preferenceIcons[preference] ?? Icons.settings_outlined,
                                            color: Color.fromRGBO(142, 98, 255, 1),
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              preference,
                                              style: TextStyle(
                                                fontFamily: 'FunnelDisplay',
                                                fontSize: 16,
                                                color: Color.fromRGBO(142, 98, 255, 1),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                theme: ExpandableThemeData(
                                  iconColor: Color.fromRGBO(142, 98, 255, 1),
                                  tapHeaderToExpand: true,
                                  tapBodyToCollapse: true,
                                  hasIcon: true,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),

                // 🔴 Logout Button at the bottom, scrolls naturally
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: ElevatedButton.icon(
                    onPressed: () => logoutUser(context),
                    icon: Icon(Icons.logout),
                    label: Text("Logout"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(255, 19, 19, 1.0),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'FunnelDisplay',
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: currentIndex,
        onChatPressed: () async {
          setState(() {
            currentIndex = 1; // chat icon active
          });

          await showDialog(
            context: context,
            builder: (context) {
              return ChatTabPopup(
                chatNameController: chatNameController,
                onPopupClose: () {},
              );
            },
          );

          setState(() {
          });
          currentIndex = 2;
        },
        onLogoutPressed: () => logoutUser(context),
      ),


    );
  }
}
