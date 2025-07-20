import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:day35/pages/virtual_ar_view_screen.dart';
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
  Items? selectedItem;
  bool showUploadScreen = false;

  bool showARView = false;
  void _showDeleteOption(Items item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text('Delete Item'),
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
        await FirebaseFirestore.instance.collection('items').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item deleted successfully.")),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cloudinary deletion failed.")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting item: $e")),
        );
      }
    }
  }
  Widget _buildDetailsView() {
    return SizedBox.expand(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color:Color(0xFFCAA54D)),
                  onPressed: () {
                    setState(() {
                      selectedItem = null;
                      showARView = false;
                    });
                  },
                ),
              ),

              // Item Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  selectedItem!.itemImage.toString(),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: 16),

              // Item Name
              Text(
                selectedItem!.itemName.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCAA54D),
                  fontFamily: 'FunnelDisplay',
                ),
              ),
              const SizedBox(height: 12),

              // Item Description
              Text(
                selectedItem!.itemDescription.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFCAA54D),
                  height: 1.4,
                ),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 24),

              // TRY VIRTUALLY Button pinned to bottom of scroll
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE2C0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => VirtualARViewScreen(
    clickedItemImageLink: selectedItem!.itemImage.toString(),
    ),
    ),
    );


                  },
                  icon: const Icon(Icons.mobile_screen_share_rounded, color: Color(0xFFCAA54D)),
                  label: const Text(
                    style: TextStyle(color: Color(0xFFCAA54D),fontFamily: "FunnelDisplay",fontWeight: FontWeight.w600),
                    "TRY VIRTUALLY (AR VIEW)",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildItemListView() {
    return Column(
      children: [
        // App Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFFCAA54D)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Home Decor",
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCAA54D),
                      fontFamily: 'FunnelDisplay',
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    showUploadScreen = true;
                    selectedItem = null;
                    showARView = false;
                  });
                },
                icon: const Icon(Icons.add, color: Color(0xFFCAA54D)),
              ),

            ],
          ),
        ),

        // Item List
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection("items")
                .orderBy("publishedDate", descending: true)
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text("Something went wrong!", style: TextStyle(color: Colors.red)));
              }

              final documents = snapshot.data?.docs ?? [];
              if (documents.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Text("No items available", style: TextStyle(fontSize: 22, color: Colors.grey)),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 0),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  var doc = documents[index];
                  Items item = Items.fromJson(doc.data() as Map<String, dynamic>);
                  item.docId = doc.id;

                  return ItemUiDesignWidget(
                    itemsInfo: item,
                    onTap: () => setState(() => selectedItem = item),
                    onLongPress: () => _showDeleteOption(item),
                  );

                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              child: Image.asset(
                'assets/images/pexels-falling4utah-1080696.webp',
                width: 500,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Foreground Container
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.90,
                height: MediaQuery.of(context).size.height * 0.72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, spreadRadius: 2)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                    child: showUploadScreen
                        ? ItemsUploadScreen(
                      onUploadComplete: () {
                        setState(() {
                          showUploadScreen = false;
                        });
                      },
                    )
                        : selectedItem == null
                        ? _buildItemListView()
                        : (showARView
                        ? VirtualARViewScreen(
                      clickedItemImageLink: selectedItem!.itemImage.toString(),
                    )
                        : _buildDetailsView()),



                ),

              ),
            ),
          ),
        ],
      ),
    );
  }
}
