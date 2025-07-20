import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/Chat_screen.dart';
import 'Bottom_nav_bar.dart';

class ChatTabPopup extends StatefulWidget {
  final TextEditingController chatNameController;
  final VoidCallback onPopupClose;
  const ChatTabPopup({
    super.key,
    required this.chatNameController,
    required this.onPopupClose,
  });

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
          .where('userId',
          isEqualTo:
          FirebaseFirestore.instance.doc('users/${user.uid}'))
          .limit(1)
          .get();

      if (chatQuery.docs.isNotEmpty) {
        DocumentReference chatDocRef = chatQuery.docs.first.reference;
        QuerySnapshot tabQuery = await chatDocRef
            .collection('ChatTabs')
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

    widget.chatNameController.clear();

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        QuerySnapshot chatQuery = await FirebaseFirestore.instance
            .collection('chats')
            .where('userId',
            isEqualTo:
            FirebaseFirestore.instance.doc('users/${user.uid}'))
            .limit(1)
            .get();

        DocumentReference chatDocRef;
        if (chatQuery.docs.isNotEmpty) {
          chatDocRef = chatQuery.docs.first.reference;
        } else {
          chatDocRef = await FirebaseFirestore.instance
              .collection('chats')
              .add({
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
          widget.onPopupClose();
          Navigator.pop(context);
        });
      } catch (e) {
        print("Error starting chat: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 100),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 380,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'FunnelDisplay',
                      color: Color.fromRGBO(37, 138, 212, 1), // Updated color
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(14, 0), // 👈 Move 8 pixels to the right
                    child: IconButton(
                      icon: Icon(Icons.close, size: 20),
                      color: Color.fromRGBO(37, 138, 212, 0.5),
                      onPressed: () {
                        widget.onPopupClose();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),

              /// Input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/virtual-assistant.webp',
                      height: 48,
                      width: 45,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 10),

                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              textSelectionTheme: TextSelectionThemeData(
                                cursorColor: Colors.black,
                                selectionColor: Colors.black26,
                                selectionHandleColor: Colors.black,
                              ),
                            ),
                            child: TextField(
                              controller: widget.chatNameController,
                              decoration: InputDecoration(
                                hintText: 'Enter chat name',
                                hintStyle: TextStyle(
                                  color: Color.fromRGBO(37, 138, 212, 0.5),
                                  fontFamily: 'FunnelDisplay',
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(37, 138, 212, 0.3),
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(0.5),
                          child: Transform(
                            transform: Matrix4.diagonal3Values(1.5, 1.0, 1.0),
                            alignment: Alignment.center,
                            child: IconButton(
                              icon: Icon(Icons.arrow_forward),
                              iconSize: 20,
                              color: Color.fromRGBO(37, 138, 212, 1),
                              onPressed: startChat,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your Chats',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    fontFamily: 'FunnelDisplay',
                    color: Color.fromRGBO(37, 138, 212, 1), // Updated color
                  ),
                ),
              ),
              SizedBox(height: 10),

              /// Chat Tabs List
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : (chatTabs == null || chatTabs!.isEmpty)
                    ? Center(child: Text("No chat tabs yet."))
                    : ScrollbarTheme(
                  data: ScrollbarThemeData(
                    thumbColor: MaterialStateProperty.all(Color.fromRGBO(37, 138, 212, 0.3)),
                    radius: Radius.circular(10),
                    thickness: MaterialStateProperty.all(4),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      padding: EdgeInsets.only(left: 0, right: 8), // Padding only on right for scrollbar
                      itemCount: chatTabs!.length,
                      itemBuilder: (context, index) {
                        final tab = chatTabs![index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0), // Only vertical spacing
                          child: Container(
                            // Aligned with 'Your Chats' title since no horizontal padding
                            margin: EdgeInsets.only(left: 0, right: 8), // Ensure it hugs the left
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(37, 138, 212, 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
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
                              child: Text(
                                tab['title'],
                                style: TextStyle(
                                  fontFamily: 'FunnelDisplay',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color:Color.fromRGBO(37, 138, 212, 1),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  ),
                ),


              ),

            ],
          ),
        ),
      ),
    );
  }
}