import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'item_ui_design_widget.dart';
import 'items.dart';
import 'items_upload_screen.dart';

class HomeDecor extends StatefulWidget {
  const HomeDecor({super.key});

  @override
  State<HomeDecor> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeDecor> {

  void _showDeleteOption(Items item) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('Delete Item'),
          onTap: () async {
            Navigator.pop(ctx);
            await _deleteItem(item);
          },
        );
      },
    );
  }

  Future<void> _deleteItem(Items item) async {
    try {
      final publicId = item.cloudinaryPublicId;
      final docId = item.docId;

      if (publicId == null || publicId.isEmpty) {
        throw Exception("Missing Cloudinary public ID.");
      }

      if (docId == null || docId.isEmpty) {
        throw Exception("Missing Firestore document ID.");
      }

      // Cloudinary credentials
      const cloudName = 'deezzpxep';
      const apiKey = '861134681647527';
      const apiSecret = 'iG2VKTQt61ZNMdBWDH8D-B4ka_U';

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Create a SHA-1 signature: "public_id=...&timestamp=...<api_secret>"
      final signatureRaw = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(signatureRaw)).toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');

      final response = await http.post(
        uri,
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp.toString(),
          'signature': signature,
        },
      );

      final result = jsonDecode(response.body);
      if (result['result'] == 'ok') {
        // Now delete from Firestore
        await FirebaseFirestore.instance.collection('items').doc(docId).delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item deleted successfully.")),
          );
        }
      } else {
        print("❌ Cloudinary delete failed: ${response.body}");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cloudinary deletion failed.")),
          );
        }
      }
    }  catch (e, stack) {
      print("❌ Exception: $e");
      print("❌ Stack Trace: $stack");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting item: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.purple.shade800,
        title: const Text(
          "Decor Fusion",
          style: TextStyle(
            fontSize: 18,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => ItemsUploadScreen()),
              );
            },
            icon: const Icon(
              Icons.add,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("items")
            .orderBy("publishedDate", descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> dataSnapshot) {
          if (dataSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (dataSnapshot.hasError) {
            return const Center(
              child: Text(
                "Something went wrong!",
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          if (dataSnapshot.hasData) {
            final documents = dataSnapshot.data!.docs;

            if (documents.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Text(
                    "No items available",
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: documents.length,
              itemBuilder: (context, index) {
                var doc = documents[index];
                Items eachItemInfo = Items.fromJson(doc.data() as Map<String, dynamic>);
                eachItemInfo.docId = doc.id; // capture Firestore document ID

                return GestureDetector(
                  onLongPress: () {
                    _showDeleteOption(eachItemInfo);
                  },
                  child: ItemUiDesignWidget(
                    itemsInfo: eachItemInfo,
                    context: context,
                  ),
                );
              },

            );
          }

          // fallback case
          return const Center(
            child: Text(
              "No data available",
              style: TextStyle(
                fontSize: 22,
                color: Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }
}
