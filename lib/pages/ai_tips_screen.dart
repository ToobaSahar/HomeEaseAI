import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AITipsScreen extends StatefulWidget {
  @override
  _AITipsScreenState createState() => _AITipsScreenState();
}

class _AITipsScreenState extends State<AITipsScreen> {
  String _tips = '';
  bool _isLoading = false;

  Future<void> _getSavingTips() async {
    setState(() {
      _isLoading = true;
      _tips = '';
    });

    const apiKey = 'tgp_v1_4g2MHcOfbm6Yeh-ix_DZtoUyrVCM5UOxCgG25WI5mB4';
    const model = 'meta-llama/Llama-4-8B-Instruct';
    const apiUrl = 'https://api.together.xyz/v1/chat/completions';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": model,
        "messages": [
          {
            "role": "system",
            "content": "You're a smart financial assistant. Based on a user's typical monthly expenses, provide simple, creative and effective money-saving tips. Keep the tips friendly, easy-to-read, and actionable. Return only plain text."
          },
          {
            "role": "user",
            "content": "Give me personalized tips to save money based on my spending habits."
          }
        ],
        "temperature": 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final result = data['choices'][0]['message']['content'];
      setState(() {
        _tips = result.trim();
        _isLoading = false;
      });
    } else {
      setState(() {
        _tips = 'Failed to fetch AI tips. Try again later.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _getSavingTips,
            icon: Icon(Icons.lightbulb),
            label: Text("Generate AI Saving Tips"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
          ),
          SizedBox(height: 20),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Expanded(
            child: SingleChildScrollView(
              child: Text(
                _tips,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}