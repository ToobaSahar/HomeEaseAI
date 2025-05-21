import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AIBudgetAgent {
  final String apiKey = 'AIzaSyC65G8I5yyBxvcjSKdWGhWVDNLMCnWjmQo'; // Replace with your Gemini API key

  final String geminiFlashEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  Future<Map<String, String>> analyzeExpensesWithAI({
    required double income,
    required Map<String, double> categoryTotals,
  }) async {
    final uri = Uri.parse('$geminiFlashEndpoint?key=$apiKey');

    final expenseDetails = categoryTotals.entries
        .map((e) => "- ${e.key}: Rs. ${e.value.toStringAsFixed(2)}")
        .join('\n');

    final userPrompt = '''
You are a smart, helpful budget planner AI.

A user earns Rs. ${income.toStringAsFixed(2)} per month and has reported the following monthly expenses:

$expenseDetails

Please perform the following:
1. Calculate the total monthly expenses (add all categories).
2. Calculate savings using: Savings = Income - Total Expenses.
3. Provide a brief summary showing:
   - Monthly Income
   - Total Expenses
   - Estimated Savings
   - (Include calculation steps clearly.)
4. Provide 2–3 smart and personalized suggestions to reduce overspending or improve savings.

📋 Your response must strictly follow this format:
Summary:
- Monthly Income: ...
- Total Expenses: ...
- Estimated Savings: ...
- Calculation: Income - Expenses = Savings

Suggestion:
1. ...
2. ...
3. ...
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
      final content = result['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

      final summaryMatch = RegExp(r'Summary:\s*(.*?)(?=Suggestion:)', dotAll: true).firstMatch(content);
      final suggestionMatch = RegExp(r'Suggestion:\s*(.*)', dotAll: true).firstMatch(content);

      return {
        'summary': summaryMatch?.group(1)?.trim() ?? '',
        'suggestion': suggestionMatch?.group(1)?.trim() ?? '',
      };
    } else {
      return {
        'summary': '⚠ Unable to generate summary.',
        'suggestion': 'Please try again later.',
      };
    }
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
      final content = result['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

      final summaryMatch = RegExp(r'Summary:\s*(.*?)(?=Suggestion:)', dotAll: true).firstMatch(content);
      final suggestionMatch = RegExp(r'Suggestion:\s*(.*)', dotAll: true).firstMatch(content);

      String cleanMarkdown(String text) {
        return text
            .replaceAll(RegExp(r'\*\*|\*|__|_'), '') // Remove bold/italic markers
            .replaceAll(RegExp(r'#+ '), '') // Remove headings
            .replaceAll(RegExp(r'^- ', multiLine: true), '') // Remove list markers
            .replaceAll(RegExp(r'\n{2,}'), '\n') // Limit multiple newlines
            .trim();
      }

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
    final uri = Uri.parse('$geminiFlashEndpoint?key=$apiKey');

    final userPrompt = '''
You are an intelligent budgeting assistant.

A user earns Rs. ${income.toStringAsFixed(2)} per month and wants to save Rs. ${savingGoal.toStringAsFixed(2)}.

Please follow these instructions carefully:

1. Subtract the savings (Rs. ${savingGoal.toStringAsFixed(2)}) from the income (Rs. ${income.toStringAsFixed(2)}). This gives the available amount for expenses: Rs. ${(income - savingGoal).toStringAsFixed(2)}.
2. Distribute **exactly Rs. ${(income - savingGoal).toStringAsFixed(2)}** into realistic Pakistani urban monthly expense categories using local cost-of-living standards. 
   Use these categories: Rent, Food, Transport, Utilities, Healthcare, Entertainment, Education, Miscellaneous.
3. The **sum of all categories must equal exactly Rs. ${(income - savingGoal).toStringAsFixed(2)}**. Double-check your totals before responding. 
   Do not exceed or fall short of this amount — you must verify the math.
4. Format your response like this:
Categories:
- Rent: Rs. XXXX
- Food: Rs. XXXX
- Transport: Rs. XXXX
...
Summary: (one-line summary)
Suggestion: (3 to 4 budgeting tips)

⚠️ Very Important:
- Do not write any explanation outside this format.
- Ensure all category values are whole numbers in Rs., no fractions or decimals.
- Ensure the total sum matches Rs. ${(income - savingGoal).toStringAsFixed(2)} exactly — verify this before finishing.

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

      // 🔍 Debugging the raw response
      print("Raw Gemini Response: ${response.body}");

      final content = result['candidates']?[0]?['content']?['parts']?[0]?['text'];

      if (content == null || content.trim().isEmpty) {
        print("⚠ No content returned by Gemini model.");
        return {
          'categories': {},
          'summary': '⚠ Empty response from Gemini model.',
          'suggestion': 'Try again with adjusted input or check Gemini API usage.'
        };
      }

      // ✅ More robust regex: allows commas, variable spacing, optional periods
      final categoryRegex = RegExp(
        r'-\s*(.*?):\s*Rs\.?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      );

      final categories = <String, double>{};

      for (final match in categoryRegex.allMatches(content)) {
        final name = match.group(1)?.trim() ?? '';
        final value = double.tryParse(match.group(2)!.replaceAll(',', '')) ?? 0.0;
        categories[name] = value;
      }

      final summary = RegExp(r'Summary:\s*(.*?)\n', dotAll: true)
          .firstMatch(content)
          ?.group(1)
          ?.trim() ?? '';

      final suggestion = RegExp(r'Suggestion:\s*(.*)', dotAll: true)
          .firstMatch(content)
          ?.group(1)
          ?.trim() ?? '';

      return {
        'categories': categories,
        'summary': summary,
        'suggestion': suggestion,
      };
    } else {
      print("❌ Failed response from Gemini API - Status: ${response.statusCode}");
      return {
        'categories': {},
        'summary': '⚠ Failed to generate summary.',
        'suggestion': 'Please try again later.',
      };
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
