import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AIBudgetAgent {
  final String apiKey = 'AIzaSyC65G8I5yyBxvcjSKdWGhWVDNLMCnWjmQo'; // Replace with your Gemini API key

  final String geminiFlashEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  Future<Map<String, String>> analyzeExpensesWithAI({
    required double income,
    required Map<String, double> categoryTotals,
  }) async {
    final response = await http.post(
      Uri.parse('https://homeeaseai-notifier-c3ueusidr-tooba-sahars-projects.vercel.app/api/aiBudgetAgent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'income': income,
        'expenses': categoryTotals,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'summary': data['summary'] ?? '',
        'suggestion': data['suggestion'] ?? '',
      };
    } else {
      return {
        'summary': '⚠️ Failed to get summary.',
        'suggestion': 'Try again later.',
      };
    }
  }

  String cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*|\*|__|_|•|▪️|●|–'), '') // Remove bold, italic, and bullet markers
        .replaceAll(RegExp(r'^\s*[-–•▪️●]\s*', multiLine: true), '') // Remove leading bullets
    // ❌ Removed the risky line that strips numbers with periods
        .replaceAll(RegExp(r'#+\s*'), '') // Remove markdown headers
        .replaceAll(RegExp(r'\n{2,}'), '\n') // Collapse multiple newlines
        .replaceAll(RegExp(r'\s{2,}'), ' ') // Collapse multiple spaces
        .replaceAll(RegExp(r'\\n'), '\n') // Replace escaped \n with actual line breaks
        .trim();
  }


  Future<Map<String, String>> fetchAISummaryAndSuggestions({
    required double income,
    required Map<String, double> expenses,
  }) async {
    final uri = Uri.parse('$geminiFlashEndpoint?key=$apiKey');

    final expenseDetails = expenses.entries
        .map((e) => "- ${e.key}: Rs. ${e.value.toStringAsFixed(2)}")
        .join('\n');

    final userPrompt = '''
You are a budget planner AI. A user earns Rs. ${income.toStringAsFixed(2)} per month and has the following expenses:

$expenseDetails

Based on this, calculate:
1. A brief savings summary.
2. Smart personalized suggestions to reduce overspending or improve savings.

Return your answer in this format:
Summary: ...
Suggestion: ...
''';

    final body = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": userPrompt}
          ]
        }
      ]
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      print("📦 Full Gemini Response: ${response.body}");
      final content = result['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

      final summaryMatch = RegExp(r'Summary:\s*(.*?)(?=Suggestion:)', dotAll: true).firstMatch(content);
      final suggestionMatch = RegExp(r'Suggestion:\s*(.*)', dotAll: true).firstMatch(content);

      final rawSummary = summaryMatch?.group(1)?.trim() ?? '';
      final rawSuggestion = suggestionMatch?.group(1)?.trim() ?? '';

      return {
        'summary': cleanMarkdown(rawSummary),
        'suggestion': cleanMarkdown(rawSuggestion),
      };
    } else {
      return {
        'summary': '⚠ Unable to generate summary.',
        'suggestion': 'Please try again later.',
      };
    }
  }

  Future<String> saveSummaryToFirestore({
    required String uid,
    required double income,
    required Map<String, double> expenses,
    required double totalExpenses,
    required double savings,
    required String summary,
    required String suggestion,
    String? calculationId,
  }) async {
    final formattedExpenses = expenses.map((k, v) => MapEntry(k, v.toDouble()));

    final collectionRef = FirebaseFirestore.instance
        .collection('budget')
        .doc(uid)
        .collection('calculations');

    final docRef = calculationId != null
        ? collectionRef.doc(calculationId)
        : collectionRef.doc();

    await docRef.set({
      'income': income,
      'expenses': formattedExpenses,
      'totalExpenses': totalExpenses,
      'savings': savings,
      'summary': summary,
      'suggestion': suggestion,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return docRef.id;
  }

  Future<Map<String, dynamic>> generateBudgetPlan({
    required double income,
    required double savingGoal,
  }) async {
    final response = await http.post(
      Uri.parse('https://homeeaseai-notifier-c3ueusidr-tooba-sahars-projects.vercel.app/api/generate-budget-plan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'income': income,
        'savingGoal': savingGoal,
      }),
    );

    print("📡 Request status: ${response.statusCode}");
    print("📡 Response body: ${response.body}");

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);

        final Map<String, dynamic> rawCategories = data['categories'] ?? {};
        final parsedCategories = <String, double>{};

        rawCategories.forEach((key, value) {
          parsedCategories[key] = (value is num)
              ? value.toDouble()
              : double.tryParse(value.toString()) ?? 0.0;
        });

        return {
          'categories': parsedCategories,
          'summary': data['summary'] ?? '',
          'suggestion': data['suggestion'] ?? '',
        };
      } catch (e) {
        print("❌ JSON parsing error: $e");
        throw Exception("Invalid response format");
      }
    } else {
      print("❌ API error ${response.statusCode}: ${response.body}");
      throw Exception("Failed to fetch budget plan from server.");
    }
  }


  Future<void> saveBudgetSuggestionToFirestore({
    required String uid,
    required String? calculationId,
    required double income,
    required double savingGoal,
    required Map<String, double> categories,
    required double totalExpenses,
    required double savings,
    required String summary,
    required String suggestion,
  }) async {
    final collectionRef = FirebaseFirestore.instance
        .collection('budget')
        .doc(uid)
        .collection('calculations');

    final docRef = collectionRef.doc(calculationId);

    await docRef.set({
      'income': income,
      'savingGoal': savingGoal,
      'budgetCategories': categories,
      'totalExpenses': totalExpenses,
      'savings': savings,
      'summary': summary,
      'suggestion': suggestion,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
