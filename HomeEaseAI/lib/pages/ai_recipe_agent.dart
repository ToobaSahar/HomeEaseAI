import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AIRecipeAgent {
  static const _apiKey = 'tgp_v1_4g2MHcOfbm6Yeh-ix_DZtoUyrVCM5UOxCgG25WI5mB4';
  static const _baseUrl = 'https://api.together.xyz/v1/chat/completions';
  static const _model = 'meta-llama/Llama-4-Scout-17B-16E-Instruct';

  // --- 1. Recipe Generation ---
  static const _recipeSystemPrompt = '''
You are an expert AI chef. Respond with a **valid JSON object** that includes:

* title (string),
* ingredients (list of strings),
* instructions (list of steps),
* nutrition (object with calories, carbs, protein, fat as numbers).

Respond according to user preferences which may include spice level, dietary restrictions, and nutritional goals.

Do NOT include anything except the JSON object in your response.
''';

  static Future<Map<String, dynamic>> generateRecipe(String userPrompt) async {
    final messages = [
      {"role": "system", "content": _recipeSystemPrompt},
      {"role": "user", "content": userPrompt},
    ];

    final response = await _callAPI(messages, temperature: 0.7);
    final cleaned = _cleanJSON(response);
    return json.decode(cleaned);
  }

  static Future<void> saveRecipeToFirestore(dynamic rawRecipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("User not authenticated");

    Map<String, dynamic> recipe = rawRecipe is String
        ? json.decode(rawRecipe.replaceAll("'", '"'))
        : rawRecipe;

    await FirebaseFirestore.instance
        .collection('mealPlans')
        .doc(uid)
        .collection('recipes')
        .add({
      'title': recipe['title'],
      'ingredients': List<String>.from(recipe['ingredients']),
      'instructions': List<String>.from(recipe['instructions']),
      'nutrition': {
        'calories': _toNum(recipe['nutrition']?['calories']),
        'carbs': _toNum(recipe['nutrition']?['carbs']),
        'protein': _toNum(recipe['nutrition']?['protein']),
        'fat': _toNum(recipe['nutrition']?['fat']),
      },
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- 2. Weekly Meal Plan ---
  static const _weeklySystemPrompt = '''
You are a dietician AI. Return a 7-day meal plan with the following format:
- days: list of 7 objects
  - day (string: Monday, Tuesday...)
  - meals: list of meals (breakfast, lunch, dinner) with:
    - name
    - description
Respond with only valid JSON. No markdown, no explanation.
''';

  static Future<Map<String, dynamic>> generateWeeklyPlan({
    required String goal,
    required int mealsPerDay,
    required String allergies,
    required String dislikes,
    required String calories,
    required String cuisine,
  }) async {
    final prompt =
        "Generate a weekly meal plan for someone with the goal: $goal, $mealsPerDay meals per day, cuisine preference: $cuisine, calorie goal: $calories, allergies: $allergies, dislikes: $dislikes.";

    final messages = [
      {"role": "system", "content": _weeklySystemPrompt},
      {"role": "user", "content": prompt},
    ];

    final response = await _callAPI(messages, temperature: 0.6);
    final cleaned = _cleanJSON(response);
    final parsed = json.decode(cleaned);

    await _saveWeeklyPlanToFirestore(parsed);
    return parsed;
  }

  static Future<void> _saveWeeklyPlanToFirestore(Map<String, dynamic> weeklyPlan) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("User not authenticated");

    await FirebaseFirestore.instance
        .collection('mealPlans')
        .doc(uid)
        .collection('weeklyPlans')
        .add({
      'createdAt': FieldValue.serverTimestamp(),
      'days': weeklyPlan['days']
    });
  }

  // --- 3. Diet Compatibility Checker ---
  static const _compatibilitySystemPrompt = '''
You are a medical diet advisor AI. When given a user's health conditions and their current diet, return a plain text analysis of whether the diet is suitable.

Include:
- Compatibility analysis
- Potential health risks
- Suggested improvements
- Example swaps or changes

Respond in natural, human-like plain English. Do NOT return JSON.
''';

  static Future<String> checkDietCompatibility({
    required String healthConditions,
    required String currentDiet,
    required String planId, // NEW: associate result with a weekly plan
  }) async {
    final prompt =
        "Is this diet suitable for someone with the following health conditions: $healthConditions? Here is the current diet: $currentDiet";

    final messages = [
      {"role": "system", "content": _compatibilitySystemPrompt},
      {"role": "user", "content": prompt},
    ];

    final response = await _callAPI(messages, temperature: 0.65);

    // Save the result to Firestore under the corresponding weekly plan
    await _saveCompatibilityResultForPlan(
      planId: planId,
      healthConditions: healthConditions,
      result: response,
    );

    return _formatAsPlainText(response);

  }

  static String _formatAsPlainText(String input) {
    return input
        .replaceAll(RegExp(r'```(?:json)?|```'), '') // remove code blocks
        .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (match) => match.group(1) ?? '') // remove bold
        .replaceAllMapped(RegExp(r'_([^_]+)_'), (match) => match.group(1) ?? '')     // remove italics
        .replaceAll(RegExp(r'^\* ', multiLine: true), '• ') // convert asterisk bullets to real bullets
        .trim();
  }

  static Future<void> _saveCompatibilityResultForPlan({
    required String planId,
    required String healthConditions,
    required String result,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("User not authenticated");

    await FirebaseFirestore.instance
        .collection('mealPlans')
        .doc(uid)
        .collection('weeklyPlans')
        .doc(planId)
        .update({
      'dietCompatibility': {
        'healthConditions': healthConditions,
        'result': result,
        'checkedAt': FieldValue.serverTimestamp(),
      }
    });
  }

  // --- Utility Methods ---
  static Future<String> _callAPI(List<Map<String, String>> messages, {double temperature = 0.7}) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        "model": _model,
        "messages": messages,
        "temperature": temperature,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Request failed: ${response.body}');
    }

    final data = json.decode(response.body);
    final String? content = data['choices']?[0]?['message']?['content'];
    if (content == null) throw Exception("No content returned from model.");
    return content;
  }

  static String _cleanJSON(String raw) {
    return raw.replaceAll(RegExp(r'```json|```'), '').trim();
  }

  static num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }
}
