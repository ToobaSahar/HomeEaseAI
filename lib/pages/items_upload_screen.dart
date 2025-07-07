import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'HomeDecor.dart';
import 'api_consumer.dart';

class ItemsUploadScreen extends StatefulWidget {
  const ItemsUploadScreen({super.key});

  @override
  State<ItemsUploadScreen> createState() => _ItemsUploadScreenState();
}

class _ItemsUploadScreenState extends State<ItemsUploadScreen> {
  Uint8List? imageFileUint8List;
  String publicIdOfUploadedImage = "";

  TextEditingController itemNameTextEditingController = TextEditingController();
  TextEditingController itemDescriptionTextEditingController = TextEditingController();

  bool isUploading = false;
  String downloadUrlOfUploadedImage = "";

  Future<Map<String, String>> uploadImageToCloudinary(Uint8List imageBytes) async {

    const String cloudName = 'deezzpxep'; // Replace with your Cloudinary cloud name
    const String uploadPreset = 'ar_images'; // Replace with your upload preset

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/deezzpxep/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'item_image.jpg',
      ));

    final response = await request.send();

    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final json = jsonDecode(resStr);
      return {
        'secure_url': json['secure_url'],
        'public_id': json['public_id'],
      };
    }
    else {
      throw Exception('Cloudinary upload failed');
    }
  }

  Widget uploadFormScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Upload New Item", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: IconButton(
              onPressed: () {
                if (!isUploading) validateUploadFormAndUploadItemInfo();
              },
              icon: const Icon(Icons.cloud_upload, color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (isUploading) const LinearProgressIndicator(color: Colors.purpleAccent),

          SizedBox(
            height: 230,
            child: Center(
              child: imageFileUint8List != null
                  ? Image.memory(imageFileUint8List!)
                  : const Icon(Icons.image_not_supported, color: Colors.grey, size: 80),
            ),
          ),
          const Divider(color: Colors.white70, thickness: 3),

          ListTile(
            leading: const Icon(Icons.title, color: Colors.white),
            title: TextField(
              style: const TextStyle(color: Colors.grey),
              controller: itemNameTextEditingController,
              decoration: const InputDecoration(
                hintText: "Item Name",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(color: Colors.white70, thickness: 2),

          ListTile(
            leading: const Icon(Icons.description, color: Colors.white),
            title: TextField(
              style: const TextStyle(color: Colors.grey),
              controller: itemDescriptionTextEditingController,
              decoration: const InputDecoration(
                hintText: "Item Description",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(color: Colors.white70, thickness: 2),
        ],
      ),
    );
  }

  validateUploadFormAndUploadItemInfo() async {
    if (imageFileUint8List == null) {
      Fluttertoast.showToast(msg: "Please select an image.");
      return;
    }

    if (itemNameTextEditingController.text.isEmpty ||
        itemDescriptionTextEditingController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please complete the form.");
      return;
    }

    try {
      setState(() {
        isUploading = true;
      });

      // Upload to Cloudinary
      final uploadResult = await uploadImageToCloudinary(imageFileUint8List!);
      downloadUrlOfUploadedImage = uploadResult['secure_url']!;
      publicIdOfUploadedImage = uploadResult['public_id']!;

      // Save to Firestore
      saveItemInfoToFirestore();
    } catch (e) {
      Fluttertoast.showToast(msg: "Upload failed: $e");
      setState(() {
        isUploading = false;
      });
    }
  }

  saveItemInfoToFirestore() {
    String itemDocId = FirebaseFirestore.instance.collection("items").doc().id;

    FirebaseFirestore.instance.collection("items").doc(itemDocId).set({
      "itemID": itemDocId,
      "itemName": itemNameTextEditingController.text,
      "itemDescription": itemDescriptionTextEditingController.text,
      "itemImage": downloadUrlOfUploadedImage,
      "publicId": publicIdOfUploadedImage,
      "publishedDate": DateTime.now(),
    });

    Fluttertoast.showToast(msg: "Item uploaded successfully.");
    setState(() {
      isUploading = false;
      imageFileUint8List = null;
    });

    Navigator.push(context, MaterialPageRoute(builder: (c) => const HomeDecor()));
  }

  Widget defaultScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Upload New Item", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate, color: Colors.white, size: 200),
            ElevatedButton(
              onPressed: showDialogBox,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black54),
              child: const Text("Add New Item", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  showDialogBox() {
    showDialog(
      context: context,
      builder: (c) {
        return SimpleDialog(
          backgroundColor: Colors.black,
          title: const Text("Item Image",
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          children: [
            SimpleDialogOption(
              onPressed: captureImageWithPhoneCamera,
              child: const Text("Capture with Camera", style: TextStyle(color: Colors.grey)),
            ),
            SimpleDialogOption(
              onPressed: chooseImageFromGallery,
              child: const Text("Choose from Gallery", style: TextStyle(color: Colors.grey)),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  captureImageWithPhoneCamera() async {
    Navigator.pop(context);
    try {
      final pickedImage = await ImagePicker().pickImage(source: ImageSource.camera);
      if (pickedImage != null) {
        final imagePath = pickedImage.path;
        imageFileUint8List = await pickedImage.readAsBytes();
        imageFileUint8List = await ApiConsumer().removeImageBackgroundApi(imagePath);
        setState(() {});
      }
    } catch (e) {
      print(e);
      setState(() {
        imageFileUint8List = null;
      });
    }
  }

  chooseImageFromGallery() async {
    Navigator.pop(context);
    try {
      final pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedImage != null) {
        final imagePath = pickedImage.path;
        imageFileUint8List = await pickedImage.readAsBytes();
        imageFileUint8List = await ApiConsumer().removeImageBackgroundApi(imagePath);
        setState(() {});
      }
    } catch (e) {
      print(e);
      setState(() {
        imageFileUint8List = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return imageFileUint8List == null ? defaultScreen() : uploadFormScreen();
  }
}
