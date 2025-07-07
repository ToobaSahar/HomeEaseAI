import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'bill_ai_agent.dart';

class EnergyBillAnalyzerScreen extends StatefulWidget {
  @override
  _EnergyBillAnalyzerScreenState createState() => _EnergyBillAnalyzerScreenState();
}

class _EnergyBillAnalyzerScreenState extends State<EnergyBillAnalyzerScreen> {
  File? _image;
  bool _loading = false;
  String? _aiSuggestions;

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take Photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? picked = await picker.pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    setState(() {
                      _image = File(picked.path);
                      _aiSuggestions = null;
                    });
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() {
                      _image = File(picked.path);
                      _aiSuggestions = null;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _loading = true;
      _aiSuggestions = null;
    });

    try {
      final result = await sendImageToGemini(_image!);
      setState(() {
        _aiSuggestions = result;
      });
    } catch (e) {
      setState(() {
        _aiSuggestions = "Error: ${e.toString()}";
      });
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Energy Usage Optimizer")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _image!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.image, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No image selected',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.upload_file),
              label: Text("Upload Bill Image"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _image != null && !_loading ? _analyzeImage : null,
              child: _loading
                  ? CircularProgressIndicator()
                  : Text("Get Energy Suggestions"),
            ),
            const SizedBox(height: 20),
            if (_aiSuggestions != null)
              Expanded(child: SingleChildScrollView(child: Text(_aiSuggestions!))),
          ],
        ),
      ),
    );
  }
}
