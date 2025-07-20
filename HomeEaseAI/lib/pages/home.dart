import 'package:animate_do/animate_do.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:day35/pages/userdetails.dart';
import 'package:day35/pages/SignupLogin.dart'; // Import the login screen
import 'package:day35/pages/Chat_screen.dart';
import 'package:day35/widgets/Bottom_nav_bar.dart'; // adjust the path as needed
import 'package:day35/services/fcm_service.dart';
import '../widgets/chat_tab_popup.dart';
import '../widgets/AnimatedText.dart'; // Update with your actual app name

class HomePage extends StatefulWidget {

  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController chatNameController = TextEditingController();
  String username = "Loading...";
  String email = "Loading...";
  int currentIndex = 0;
  @override
  void initState() {
    super.initState();
    fetchUserData();

    // 🔔 Listen for foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print("🔔 Foreground message received: ${message.notification!.title}");
        // Optional: You could show a snackbar/dialog here
      }
    });

    // 🔁 Listen for taps on notifications when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📨 Notification clicked!');
      // Optional: Handle navigation or alert here
    });
  }

  @override
  void dispose() {
    chatNameController.dispose();
    super.dispose();
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

        // 🔔 Initialize FCM after fetching user info
        await initFCM(user.uid);
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
    final double topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            FadeInUp(
              child: Container(
                height: 250, // 🔼 Increased height of top bar
                // 🔼 Increased height of top bar
          alignment: Alignment.center,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92, // 👈 85% of screen width
            height: 250,
            decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/freepik_assistant_1751829836437.webp'),
                    fit: BoxFit.cover, // 📌 Makes sure image fills the container
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade100.withOpacity(0.8),
                      Colors.blue.shade300.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 2,
                      offset: Offset(2, 4),
                    )
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, topPadding + 30, 16, 20),
                  child: AnimatedTextSwitcher(
                    fixedHeight: 80,
                    texts: [
                      Text(
                        'Welcome to\nHomeEaseAI',
                        style: TextStyle(
                          fontFamily: 'FunnelDisplay',
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          color: Colors.white.withOpacity(0.95),
                          height: 1.5,
                        ),
                      ),
                      Text(
                        'Your AI assistant for\nhome chores,\nplanning & comfort',
                        style: TextStyle(
                          fontFamily: 'FunnelDisplay',
                          fontWeight: FontWeight.w600,
                          fontSize: 22,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
          )
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                physics: NeverScrollableScrollPhysics(),
                childAspectRatio: 0.9, // 👈 Adjust this value to increase card height
                children: [
                  categoryCard("Home Decor", Icons.home_filled, '/homeDecor'),
                  categoryCard("Meal Planning", Icons.restaurant_menu, '/mealPlanning'),
                  categoryCard("Budgeting", Icons.account_balance_wallet, '/budgeting'),
                  categoryCard("Energy Use", Icons.electric_bolt, '/energyBillAnalyzer'),
                ],
              ),

            ),
          ],
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
            currentIndex = 0; // switch back to home icon after popup closed
          });
        },
        onLogoutPressed: logoutUser,
      ),

    );
  }

  Widget categoryCard(String title, IconData icon, String route) {
    return FadeInUp(
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, route);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey.shade200, Colors.grey.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),

          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (title == "Meal Planning")
                Image.asset(
                  'assets/images/Recipe book-pana.webp',
                  height: 140,
                  fit: BoxFit.contain,
                )
              else if (title == "Home Decor")
                Image.asset(
                  'assets/images/8422359_3838823.webp',
                  height: 140,
                  fit: BoxFit.contain,
                )
              else if (title == "Budgeting")
                  Image.asset(
                    'assets/images/10780299_19197027.webp',
                    height: 140,
                    fit: BoxFit.contain,
                  )
                else if (title == "Energy Use")
                    Image.asset(
                      'assets/images/18953916_6052389.webp',
                      height: 140,
                      fit: BoxFit.contain,
                    )
                  else
                    Icon(icon, size: 40, color: Colors.black87),

              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, // 🔹 Increased font size
                  fontWeight: FontWeight.w600, // 🔹 Font weight 500
                  fontFamily: 'FunnelDisplay', // 🔹 Font family
                  color: Color.fromRGBO(37, 138, 212, 1), // 🔹 Text color
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
