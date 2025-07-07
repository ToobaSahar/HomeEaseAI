import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<String> sendImageToGemini(File imageFile) async {
  // 1. Convert image to base64
  final imageBytes = await imageFile.readAsBytes();
  final base64Image = base64Encode(imageBytes);

  // 2. Define your deployed Vercel endpoint
  final url = Uri.parse('https://homeeaseai-notifier-86euyje0a-tooba-sahars-projects.vercel.app/api/analyze-bill');

  // 3. Send POST request to your Node.js endpoint
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'base64Image': base64Image,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['message'] ?? 'No response';
  } else {
    throw Exception('API error: ${response.statusCode} ${response.body}');
  }
}
