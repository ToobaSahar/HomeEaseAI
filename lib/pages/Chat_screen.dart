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
                (msg) {
              if (msg is Message) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(
                    "${msg.role.toUpperCase()}: ${msg.content}",
                    style: pw.TextStyle(fontSize: 12),
                  ),
                );
              } else {
                return pw.SizedBox(); // fallback for unexpected entries
              }
            },
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

      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chat exported to $path")),
      );

      final result = await OpenFile.open(path);
      print("OpenFile result: ${result.type} - ${result.message}");

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
      appBar: AppBar(
        title: Text(widget.chatTitle),
        centerTitle: true,

        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_chat') _clearChat();
              if (value == 'export_chat') _exportChat();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'clear_chat', child: Text('Clear Chat')),
              PopupMenuItem(value: 'export_chat', child: Text('Export Chat')),
            ],
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
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
                        alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                  MediaQuery.of(context).size.width * 0.8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                isUser ? Colors.blueAccent : Colors.grey[300],
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                  bottomLeft:
                                  isUser ? Radius.circular(15) : Radius.zero,
                                  bottomRight:
                                  isUser ? Radius.zero : Radius.circular(15),
                                ),
                              ),
                              child: SelectableText(
                                msg.content,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: msg.content));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Copied to clipboard")),

                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(Icons.copy,
                                    size: 14, color: Colors.blue),
                              ),
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !isSending, // 👈 disable when sending
                        decoration: InputDecoration(
                          hintText: "Type your message...",
                          filled: true,
                          fillColor: isSending ? Colors.grey[300] : Colors.grey[200], // optional: visually indicate disabled
                        ),
                      ),

                    ),
                    SizedBox(width: 10),
                    isSending
                        ? const SizedBox(
                      width: 50,
                      height: 50,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                          strokeWidth: 3,
                        ),
                      ),
                    )
                        : GestureDetector(
                      onTap: () => _sendMessage(_controller.text),
                      child: const CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        radius: 25,
                        child: Icon(Icons.send, color: Colors.white),
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
          if (showScrollToBottomButton)
            Positioned(
              bottom: 80,
              right: 20,
              child: FloatingActionButton(
                onPressed: _scrollToBottom,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.arrow_downward, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}