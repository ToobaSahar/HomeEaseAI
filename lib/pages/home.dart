import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:day35/pages/userdetails.dart';
import 'package:day35/pages/SignupLogin.dart'; // Import the login screen

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String username = "Loading...";
  String email = "Loading...";

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot<Map<String, dynamic>> userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          username = userDoc.data()?['username'] ?? 'Unknown';
          email = userDoc.data()?['email'] ?? 'No Email';
        });
      }
    }
  }

  void logoutUser() async {
    await FirebaseAuth.instance.signOut();

    // Use a fade transition when navigating to login screen
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeInUp(child: LoginSignupScreen());
        },
        transitionDuration: Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Dashboard', style: TextStyle(color: Colors.black)),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications_none, color: Colors.grey.shade700, size: 30),
          )
        ],
        leading: GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/login');
          },
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage(
                  'https://uifaces.co/our-content/donated/NY9hnAbp.jpg'),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Information Card
            FadeInUp(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.blue.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 2,
                      offset: Offset(2, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    SizedBox(height: 15),

                    // View Profile & Logout Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // View Profile Button
                        BounceInLeft(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blueAccent,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ProfileScreen()),
                              );
                            },
                            icon: Icon(Icons.person, size: 20),
                            label: Text("View Profile"),
                          ),
                        ),
                        SizedBox(width: 15),

                        // Logout Button
                        BounceInRight(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text("Logout"),
                                  content: Text("Are you sure you want to logout?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Future.delayed(Duration(milliseconds: 500), logoutUser);
                                      },
                                      child: Text("Logout", style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: Icon(Icons.exit_to_app, size: 20),
                            label: Text("Logout"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Categories Section
            FadeInUp(
              child: Padding(
                padding: EdgeInsets.only(left: 10.0, right: 10.0),
                child: Text(
                  'Categories',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 10),

            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: NeverScrollableScrollPhysics(),
              children: [
                categoryCard("Smart Shopping", Icons.shopping_cart),
                categoryCard("Meal Planning", Icons.restaurant_menu),
                categoryCard("Budgeting", Icons.account_balance_wallet),
                categoryCard("Energy Use", Icons.electric_bolt),
              ],
            ),
          ],
        ),
      ),

      // Floating Action Button (FAB) for Chatbot
      floatingActionButton: BounceInUp(
        child: FloatingActionButton(
          backgroundColor: Colors.blueAccent,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatScreen()), // Updated!
            );
          },
          child: Icon(Icons.chat, size: 32, color: Colors.white),
        ),
      ),
    );
  }

  // Category Card Widget
  Widget categoryCard(String title, IconData icon) {
    return FadeInUp(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade200, Colors.blue.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 6,
              spreadRadius: 2,
              offset: Offset(2, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// Chatbot Placeholder with Animation
class ChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chatbot')),
      body: Center(
        child: FadeInDown(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.smart_toy, size: 100, color: Colors.blueAccent),
              SizedBox(height: 20),
              Text('Chatbot feature coming soon!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
