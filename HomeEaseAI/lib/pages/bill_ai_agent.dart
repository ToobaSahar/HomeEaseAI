import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<String> sendImageToGemini(File imageFile) async {
  final uri = Uri.parse("https://homeeaseai-notifier-c3ueusidr-tooba-sahars-projects.vercel.app/api/analyze-bill");

  final bytes = await imageFile.readAsBytes();
  final base64Image = base64Encode(bytes);

  final response = await http.post(
    uri,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"base64Image": base64Image, "userId": "yourUserIdHere"}), // Include userId if needed
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data["message"] != null && data["message"].toString().trim().isNotEmpty) {
      return _stripMarkdown(data["message"]);
    } else {
      throw Exception("Empty AI response");
    }
  } else {
    print("Server response: ${response.body}");
    throw Exception("Failed: ${response.statusCode}");
  }
}

String _stripMarkdown(String input) {
  return input
      .replaceAll(RegExp(r'[*_`#\[\]\(\)]'), '') // Remove common markdown symbols
      .replaceAll(RegExp(r'-\s+'), '')           // Remove list dashes
      .replaceAll(RegExp(r'\n\s*\n'), '\n')      // Clean extra line breaks
      .trim();                                   // Remove leading/trailing spaces
}
