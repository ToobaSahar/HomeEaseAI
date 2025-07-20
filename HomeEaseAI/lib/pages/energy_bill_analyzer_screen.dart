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
      body: Stack(
        children: [
          // 🔸 Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/energy-bill-hero-image.webp'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 🔸 Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(71, 43, 34, 1.0),
                  Color.fromRGBO(71, 43, 34, 1.0),
                  Colors.transparent,
                ],
                stops: [0.0, 0.3, 1.0],
              ),
            ),
          ),

          // 🔸 Foreground card
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.82,
                height: MediaQuery.of(context).size.height * 0.76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Scaffold(
                    backgroundColor: Colors.white,
                    appBar: AppBar(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      toolbarHeight: 56,
                      automaticallyImplyLeading: false,
                      titleSpacing: 0,
                      title: Padding(
                        padding: const EdgeInsets.only(left: 8, top: 6),
                        child: Row(
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              icon: Icon(Icons.arrow_back, size: 24, color:Color.fromRGBO(71, 43, 34, 1.0)),
                              onPressed: () => Navigator.pop(context),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Energy Usage Optimizer',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Color.fromRGBO(71, 43, 34, 1.0),
                                fontFamily: 'FunnelDisplay',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 🔸 New top image
                          Center(
                            child: Image.asset(
                              'assets/images/finance-2837085_1280-removebg-preview.webp',
                              height: 200,
                              width: 190,
                            ),
                          ),
                          const SizedBox(height: 25),

                          GestureDetector(
                            onTap: _pickImage,
                            child: Center(
                              child: _image != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _image!,
                                  height: 120,
                                  width: 160,
                                  fit: BoxFit.cover,
                                ),
                              )
                                  : Container(
                                height: 120,
                                width: 160,
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(250, 232, 229, 1.0),
                                  border: Border.all(color: Color.fromRGBO(71, 43, 34, 1.0)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.image, size: 48, color: Color.fromRGBO(71, 43, 34, 1.0)),
                                      SizedBox(height: 8),
                                      Text("Tap to upload", style: TextStyle(color: Color.fromRGBO(71, 43, 34, 1.0))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 🔸 Analyze Button
                          Center(
                            child: ElevatedButton(
                              onPressed: _image != null && !_loading ? _analyzeImage : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromRGBO(250, 232, 229, 1.0),
                                foregroundColor: Color.fromRGBO(71, 43, 34, 1.0),
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                textStyle: TextStyle(
                                  fontFamily: 'FunnelDisplay',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              child: _loading
                                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text("Get Energy Suggestions"),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 🔸 AI Suggestions
                          // 🔸 AI Suggestions
                          if (_aiSuggestions != null)
                            Center(
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(250, 232, 229, 1.0), // ✅ updated background
                                  border: Border.all(color: Color.fromRGBO(71, 43, 34, 1.0), width: 1.5), // ✅ updated border
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _aiSuggestions!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'FunnelDisplay',
                                    color: Color.fromRGBO(71, 43, 34, 1.0), // optional: match text color
                                  ),
                                ),
                              ),
                            ),

                        ],
                      ),
                    ),

                  ),
    ),
    ),
    ),
    ),
    ]
    ),

    );
  }
}
