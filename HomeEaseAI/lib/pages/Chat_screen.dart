import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:together_ai_sdk/together_ai_sdk.dart' as together;
import 'package:day35/pages/together_ai_service.dart';

import '../widgets/Bottom_nav_bar.dart';



class Message {
  final String role;
  final String content;

  Message({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory Message.fromJson(Map<String, dynamic> json) =>
      Message(role: json['role'], content: json['content']);
}

class ChatScreen extends StatefulWidget {
  final String chatTitle;
  final String chatId;
  final String tabId;

  const ChatScreen({
    required this.chatTitle,
    required this.chatId,
    required this.tabId,
    Key? key,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool showScrollToBottomButton = false;
  bool suppressScrollButton = false;
  bool isSending = false;

  List<Message> messages = [];
  String? userId;
  String? chatId;
  String? tabId;

  @override
  void initState() {
    super.initState();
    chatId = widget.chatId;
    tabId = widget.tabId;
    _initializeChat();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || suppressScrollButton) return;
    final isAtBottom = (_scrollController.position.maxScrollExtent - _scrollController.offset).abs() < 50;
    setState(() {
      showScrollToBottomButton = !isAtBottom;
    });
  }

  Future<void> _initializeChat() async {
    final user = _auth.currentUser;
    if (user == null) return;
    userId = user.uid;

    try {
      if (chatId == null) {
        final chatSnapshot = await _firestore
            .collection('chats')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();
        if (chatSnapshot.docs.isNotEmpty) {
          chatId = chatSnapshot.docs.first.id;
        } else {
          final newChat = await _firestore.collection('chats').add({'userId': userId});
          chatId = newChat.id;
        }
      }

      if (tabId == null) {
        final tabSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('ChatTabs')
            .limit(1)
            .get();
        if (tabSnapshot.docs.isNotEmpty) {
          tabId = tabSnapshot.docs.first.id;
        } else {
          final newTab = await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('ChatTabs')
              .add({
            'title': widget.chatTitle,
            'createdAt': FieldValue.serverTimestamp(),
            'messages': [],
          });
          tabId = newTab.id;
        }
      }

      await _loadMessages();
    } catch (e) {
      print("Error initializing chat: $e");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (tabId == null) return;
    try {
      final tabDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('ChatTabs')
          .doc(tabId)
          .get();

      if (tabDoc.exists) {
        final data = tabDoc.data();
        if (data != null && data.containsKey('messages')) {
          messages = List.from(data['messages'])
              .map((item) => Message.fromJson(item))
              .toList();
        }
      }

      setState(() {});
    } catch (e) {
      print("Error loading messages: $e");
    }
  }

  Future<void> _saveMessage(Message message) async {
    if (tabId == null || chatId == null) return;
    try {
      final tabRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('ChatTabs')
          .doc(tabId);

      final tabSnapshot = await tabRef.get();

      if (tabSnapshot.exists) {
        await tabRef.update({
          'messages': FieldValue.arrayUnion([message.toJson()]),
        });
      } else {
        await tabRef.set({
          'title': widget.chatTitle,
          'createdAt': FieldValue.serverTimestamp(),
          'messages': [message.toJson()],
        });
      }
    } catch (e) {
      print("Error saving message: $e");
    }
  }
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || isSending) return;

    if (tabId == null || chatId == null) await _initializeChat();

    isSending = true;

    final userMessage = Message(role: 'user', content: text.trim());

    setState(() {
      messages.add(userMessage);
      _controller.clear();
    });

    await _saveMessage(userMessage);
    _scrollToBottom();

    // Start a placeholder for assistant message with empty content
    final assistantMessage = Message(role: 'assistant', content: '');
    setState(() {
      messages.add(assistantMessage);
    });

    try {
      final formattedMessages = messages.map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList();

      // Collect streamed chunks
      final buffer = StringBuffer();
      final stream = TogetherAIService.sendPrompt(formattedMessages);

      await for (final chunk in stream) {
        final plainChunk = chunk.replaceAll(RegExp(r'[*_`~]'), '');
        buffer.write(plainChunk);

        // Update assistant message in-place as stream progresses
        setState(() {
          messages[messages.length - 1] =
              Message(role: 'assistant', content: buffer.toString());
        });

        _scrollToBottom(); // Keep auto-scrolling as response grows
      }

      // Save full assistant message
      await _saveMessage(Message(role: 'assistant', content: buffer.toString()));

      // 🔄 Finalize the assistant message to ensure export compatibility
      setState(() {
        messages[messages.length - 1] = Message(
          role: 'assistant',
          content: buffer.toString(),
        );
        isSending = false;
      });
    } catch (e) {
      print("Streaming error: $e");
      setState(() {
        messages[messages.length - 1] = Message(
          role: 'assistant',
          content: 'Sorry, something went wrong while generating a response.',
        );
        isSending = false;
      });
    }
  }

  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $amPm';
  }

  Future<void> _clearChat() async {
    setState(() => messages.clear());

    if (tabId != null) {
      try {
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('ChatTabs')
            .doc(tabId)
            .delete();

        tabId = null;

        // Pop the current screen after deletion
        if (mounted) {
          Navigator.of(context).pop(); // Navigates back to home
        }
      } catch (e) {
        print("Error deleting chat: $e");
      }
    }
  }

  Future<void> _exportChat() async {
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chat is empty.")),
      );
      return;
    }

    if (!await Permission.storage.request().isGranted)
    {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Storage permission denied.")),
      );
      return;
    }

    String createdAtText = '';
    String chatTitle = 'Chat';
    if (chatId != null && tabId != null) {
      final tabDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('ChatTabs')
          .doc(tabId)
          .get();

      if (tabDoc.exists) {
        final data = tabDoc.data();
        if (data?['createdAt'] != null) {
          Timestamp createdAt = data!['createdAt'];
          DateTime dateTime = createdAt.toDate();
          final formattedDate = "${dateTime.day.toString().padLeft(2, '0')}-"
              "${dateTime.month.toString().padLeft(2, '0')}-"
              "${dateTime.year} ${_formatTime(dateTime)}";
          createdAtText = "Chat created at: $formattedDate";
        }

        if (data?['title'] != null) {
          chatTitle = data!['title'];
        }
      }
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            chatTitle,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          if (createdAtText.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                createdAtText,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.normal,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ...messages.map(
                (msg) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Paragraph(
                text: "${msg.role.toUpperCase()}: ${msg.content}",
                style: pw.TextStyle(fontSize: 12),
              ),
            ),
          ),

        ],
      ),
    );

    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final safeTitle = chatTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path =
          '${dir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      try {
        print("Saving PDF...");
        final file = File(path);
        await file.writeAsBytes(await pdf.save());
        print("PDF saved successfully to $path");

        final result = await OpenFile.open(path);
        print("OpenFile result: ${result.type} - ${result.message}");
      } catch (e, stacktrace) {
        print("PDF Save Error: $e");
        print(stacktrace);
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to export chat: $e")),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // 🔥 removes back arrow
        title: Text(
          widget.chatTitle,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'FunnelDisplay',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10), // pull the icon left
            child: PopupMenuButton<String>(
              offset: const Offset(50, kToolbarHeight - 15), // shift menu right from icon
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'clear_chat') _clearChat();
                if (value == 'export_chat') _exportChat();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'clear_chat',
                  child: Text(
                    'Clear Chat',
                    style: TextStyle(
                      color: Color.fromRGBO(37, 138, 212, 1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_chat',
                  child: Text(
                    'Export Chat',
                    style: TextStyle(
                      color: Color.fromRGBO(37, 138, 212, 1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )

        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg.role == 'user';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      child: Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? const Color.fromRGBO(37, 138, 212, 0.3) // ✅ user's background
                                    : Colors.transparent,                     // 🤖 assistant: no background
                                borderRadius: BorderRadius.circular(15),
                              ),

                              child: SelectableText(
                                msg.content,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'FunnelDisplay',
                                  fontWeight: FontWeight.w500,
                                  color: isUser
                                      ? Colors.black54
                                      : const Color.fromRGBO(37, 138, 212, 1),
                                ),
                              ),
                            ),

                            Row(
                              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: 4,
                                    left: isUser ? 0 : 25,  // 👈 AI copy icon moves a bit right
                                    right: isUser ? 25 : 0, // 👈 User copy icon moves a bit left
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: msg.content));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Copied to clipboard")),
                                      );
                                    },
                                    child: Icon(
                                      Icons.copy,
                                      size: 20,
                                      color: const Color.fromRGBO(37, 138, 212, 1),
                                      shadows: [
                                        Shadow(
                                          offset: Offset(0.5, 0.5),
                                          blurRadius: 1.5,
                                          color: Color.fromRGBO(37, 138, 212, 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child:Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5), // light shadow
                          blurRadius: 8,
                          offset: Offset(0, 3), // vertical shadow
                        ),
                      ],
                    ),

                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !isSending,
                            style: const TextStyle(
                              color: Color.fromRGBO(37, 138, 212, 1), // ✅ new text color
                              fontFamily: 'FunnelDisplay',
                              fontWeight: FontWeight.w500,
                            ),
                            cursorColor: Color.fromRGBO(37, 138, 212, 1), // ✅ new cursor color
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: "Type your message...",
                              hintStyle: const TextStyle(
                                color: Color.fromRGBO(37, 138, 212, 1),
                                fontFamily: 'FunnelDisplay',
                                fontWeight: FontWeight.w500,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20), // ✅ Matches outer container
                                borderSide: const BorderSide(
                                  color: Color.fromRGBO(37, 138, 212, 0.3), // optional subtle border
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20), // ✅ Matches outer container
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                  color: Color.fromRGBO(37, 138, 212, 1), // brighter blue on focus
                                  width: 1.5,
                                ),
                              ),
                            ),

                          ),


                        ),

                        isSending
                            ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                            : Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: IconButton(
                            onPressed: () => _sendMessage(_controller.text),
                            icon: const Icon(Icons.send),
                            color: Color.fromRGBO(37, 138, 212, 1), // solid color
                            iconSize: 30,
                            padding: EdgeInsets.zero,
                            splashRadius: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              ),

            ],
          ),
          if (showScrollToBottomButton)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80), // Distance from bottom
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(37, 138, 212, 1), // 🎯 rgba(37,138,212,100)
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _scrollToBottom,
                    icon: const Icon(Icons.arrow_downward),
                    color: Colors.white,
                    iconSize: 24,
                  ),
                ),
              ),
            ),

        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1, // 👈 Chat is active
        onChatPressed: () {
          // Already on chat screen, do nothing
        },
      ),
    );

  }
}