import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TogetherAIService {
  static const _apiKey = 'tgp_v1_4g2MHcOfbm6Yeh-ix_DZtoUyrVCM5UOxCgG25WI5mB4';
  static const _baseUrl = 'https://api.together.xyz/v1/chat/completions';

  static Stream<String> sendPrompt(List<Map<String, String>> messages) async* {
    const systemPrompt = '''
You are HomeEaseAI, a smart home assistant that helps users manage household tasks like cleaning, fitness, decor suggestions, and utility bills. Respond clearly and helpfully.
''';

    final String fullPrompt = _buildLlamaPrompt(systemPrompt, messages);

    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    });

    request.body = json.encode({
      "model": "meta-llama/Llama-4-Scout-17B-16E-Instruct",
      "messages": [
        {
          "role": "user",
          "content": fullPrompt,
        }
      ],
      "stream": true,
    });

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw Exception('Together AI request failed: $errorBody');
    }

    final utf8Stream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in utf8Stream) {
      if (line.startsWith('data: ')) {
        final jsonString = line.substring(6).trim();

        if (jsonString == '[DONE]') break;

        try {
          final Map<String, dynamic> data = json.decode(jsonString);
          final chunk = data['choices']?[0]?['delta']?['content'];

          if (chunk != null) {
            yield chunk;
          }
        } catch (e) {
          print('⚠️ Error parsing chunk: $e\nLine: $line');
        }
      }
    }
  }

  static String _buildLlamaPrompt(String systemPrompt, List<Map<String, String>> messages) {
    final buffer = StringBuffer();

    buffer.writeln('[INST] <<SYS>>');
    buffer.writeln(systemPrompt.trim());
    buffer.writeln('<</SYS>>\n');

    // Only take last 5 turns to keep context tight
    final recentMessages = messages.length > 5 ? messages.sublist(messages.length - 5) : messages;

    for (int i = 0; i < recentMessages.length; i++) {
      final role = recentMessages[i]['role'];
      final content = recentMessages[i]['content']?.trim() ?? '';

      if (role == 'user') {
        buffer.writeln('[INST]');
        buffer.writeln(content);
        buffer.writeln('[/INST]');
      } else if (role == 'assistant') {
        buffer.writeln(content);
      }
    }

    return buffer.toString();
  }

}
