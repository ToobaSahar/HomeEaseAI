import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:day35/pages/userdetails.dart';
import 'package:day35/pages/SignupLogin.dart'; // Import the login screen
import 'package:day35/pages/Chat_screen.dart';
import 'package:day35/widgets/Bottom_nav_bar.dart'; // adjust the path as needed

class HomePage extends StatefulWidget {

  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController chatNameController = TextEditingController();
  String username = "Loading...";
  String email = "Loading...";

  @override
  void initState() {
    super.initState();
    fetchUserData();
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
            // Blue Top Section (User Info Card)
            FadeInUp(
              child: Container(
                padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 16),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.blue.shade300],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile picture (previously in AppBar)
                    Align(
                      alignment: Alignment.topLeft,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: NetworkImage(
                              'https://uifaces.co/our-content/donated/NY9hnAbp.jpg'),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
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

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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

            // Categories Title
            FadeInUp(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Categories',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),

            // Category Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  categoryCard("Home Decor", Icons.shopping_cart, '/smartShopping'),
                  categoryCard("Meal Planning", Icons.restaurant_menu, '/mealPlanning'),
                  categoryCard("Budgeting", Icons.account_balance_wallet, '/budgeting'),
                  categoryCard("Energy Use", Icons.electric_bolt, '/energyUsage'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        onChatPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
              return ChatTabPopup(chatNameController: chatNameController);
            },
          );
        },
      ),
    );
  }


  // Category Card Widget
  Widget categoryCard(String title, IconData icon, String route) {
    return FadeInUp(
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, route);  // Navigate to the page using the route
        },
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
      ),
    );
  }

}

class ChatTabPopup extends StatefulWidget {
  final TextEditingController chatNameController;

  ChatTabPopup({required this.chatNameController});

  @override
  _ChatTabPopupState createState() => _ChatTabPopupState();
}

class _ChatTabPopupState extends State<ChatTabPopup> {
  List<QueryDocumentSnapshot>? chatTabs;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTabs();
  }

  Future<void> fetchTabs() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot chatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('userId', isEqualTo: FirebaseFirestore.instance.doc('users/${user.uid}'))
          .limit(1)
          .get();

      if (chatQuery.docs.isNotEmpty) {
        DocumentReference chatDocRef = chatQuery.docs.first.reference;
        QuerySnapshot tabQuery = await chatDocRef.collection('ChatTabs')
            .orderBy('createdAt', descending: true)
            .get();

        setState(() {
          chatTabs = tabQuery.docs;
          isLoading = false;
        });
      } else {
        setState(() {
          chatTabs = [];
          isLoading = false;
        });
      }
    }
  }

  Future<void> startChat() async {
    String chatName = widget.chatNameController.text.trim();
    if (chatName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a chat name")),
      );
      return;
    }

    widget.chatNameController.clear(); // Optional: clear input field

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        QuerySnapshot chatQuery = await FirebaseFirestore.instance
            .collection('chats')
            .where('userId', isEqualTo: FirebaseFirestore.instance.doc('users/${user.uid}'))
            .limit(1)
            .get();

        DocumentReference chatDocRef;
        if (chatQuery.docs.isNotEmpty) {
          chatDocRef = chatQuery.docs.first.reference;
        } else {
          chatDocRef = await FirebaseFirestore.instance.collection('chats').add({
            'userId': FirebaseFirestore.instance.doc('users/${user.uid}'),
          });
        }

        QuerySnapshot tabQuery = await chatDocRef
            .collection('ChatTabs')
            .where('title', isEqualTo: chatName)
            .limit(1)
            .get();

        DocumentReference tabDocRef;
        if (tabQuery.docs.isNotEmpty) {
          tabDocRef = tabQuery.docs.first.reference;
        } else {
          tabDocRef = await chatDocRef.collection('ChatTabs').add({
            'title': chatName,
            'createdAt': FieldValue.serverTimestamp(),
            'messages': [],
          });
        }

        // ✅ Navigate first, then close the popup
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatTitle: chatName,
              chatId: chatDocRef.id,
              tabId: tabDocRef.id,
            ),
          ),
        ).then((_) {
          Navigator.pop(context); // Close the bottom sheet AFTER returning from ChatScreen
        });

      } catch (e) {
        print("Error starting chat: $e");
      }
    }


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0),
      body: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Start a New Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              TextField(
                controller: widget.chatNameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Chat Name',
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.arrow_forward),
                label: Text("Start Chat"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: startChat,
              ),
              SizedBox(height: 20),
              Divider(),
              Text('Your Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 10),
              if (isLoading)
                Center(child: CircularProgressIndicator())
              else if (chatTabs == null || chatTabs!.isEmpty)
                Text("No chat tabs yet.")
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(), // Prevent inner scroll conflict
                  itemCount: chatTabs!.length,
                  itemBuilder: (context, index) {
                    final tab = chatTabs![index];
                    return ListTile(
                      title: Text(tab['title']),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatTitle: tab['title'],
                              chatId: tab.reference.parent.parent!.id,
                              tabId: tab.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

}
