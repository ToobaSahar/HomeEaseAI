// items_upload_controller.dart
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_consumer.dart';

class ItemsUploadController {
  Uint8List? imageFileUint8List;
  String downloadUrlOfUploadedImage = "";
  String publicIdOfUploadedImage = "";

  final itemNameController = TextEditingController();
  final itemDescriptionController = TextEditingController();

  Future<void> pickImageFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      imageFileUint8List = await picked.readAsBytes();
      imageFileUint8List = await ApiConsumer().removeImageBackgroundApi(picked.path);
    }
  }

  Future<void> pickImageFromCamera() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      imageFileUint8List = await picked.readAsBytes();
      imageFileUint8List = await ApiConsumer().removeImageBackgroundApi(picked.path);
    }
  }

  Future<Map<String, String>> uploadToCloudinary(Uint8List imageBytes) async {
    const cloudName = 'deezzpxep';
    const uploadPreset = 'ar_images';

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'item.jpg'));

    final response = await request.send();
    final resStr = await response.stream.bytesToString();
    final jsonRes = jsonDecode(resStr);

    if (response.statusCode == 200) {
      return {
        'secure_url': jsonRes['secure_url'],
        'public_id': jsonRes['public_id'],
      };
    } else {
      throw Exception("Upload failed");
    }
  }

  Future<void> validateAndUpload(Function(bool) onUploadingStatus, Function onSuccess) async {
    if (imageFileUint8List == null) {
      Fluttertoast.showToast(msg: "Please select an image.");
      return;
    }

    if (itemNameController.text.isEmpty || itemDescriptionController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please complete the form.");
      return;
    }

    try {
      onUploadingStatus(true);
      final result = await uploadToCloudinary(imageFileUint8List!);
      downloadUrlOfUploadedImage = result['secure_url']!;
      publicIdOfUploadedImage = result['public_id']!;
      await _saveToFirestore();
      Fluttertoast.showToast(msg: "Item uploaded successfully.");
      onSuccess();
    } catch (e) {
      Fluttertoast.showToast(msg: "Upload failed: $e");
    } finally {
      onUploadingStatus(false);
    }
  }

  Future<void> _saveToFirestore() async {
    String itemDocId = FirebaseFirestore.instance.collection("items").doc().id;

    await FirebaseFirestore.instance.collection("items").doc(itemDocId).set({
      "itemID": itemDocId,
      "itemName": itemNameController.text,
      "itemDescription": itemDescriptionController.text,
      "itemImage": downloadUrlOfUploadedImage,
      "publicId": publicIdOfUploadedImage,
      "publishedDate": DateTime.now(),
    });
  }

  void reset() {
    imageFileUint8List = null;
    itemNameController.clear();
    itemDescriptionController.clear();
    downloadUrlOfUploadedImage = "";
    publicIdOfUploadedImage = "";
  }
}
