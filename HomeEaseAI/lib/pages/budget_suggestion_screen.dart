import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ai_budget_agent.dart'; // Adjust the path if needed

class BudgetSuggestionScreen extends StatefulWidget {
  const BudgetSuggestionScreen({super.key});

  @override
  _BudgetSuggestionScreenState createState() => _BudgetSuggestionScreenState();
}

class _BudgetSuggestionScreenState extends State<BudgetSuggestionScreen> {
  final _savingGoalController = TextEditingController();
  final AIBudgetAgent _aiAgent = AIBudgetAgent();

  Map<String, double>? suggestedBudgets;
  String? aiSummary;
  String? aiSuggestion;
  double? _monthlyIncome;
  String? latestCalculationId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLatestIncome();
  }

  Future<void> _loadLatestIncome() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('budget')
          .doc(uid)
          .collection('calculations')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();

        setState(() {
          latestCalculationId = doc.id;
          _monthlyIncome = (data['income'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      print("Error fetching latest income: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateSuggestion() async {
    final text = _savingGoalController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your desired savings')),
      );
      return;
    }

    final double? savingGoal = double.tryParse(text);

    if (savingGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid number for savings')),
      );
      return;
    }

    final double income = _monthlyIncome ?? 0;
    final double available = income - savingGoal;

    if (available < 0) {
      setState(() {
        suggestedBudgets = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saving goal exceeds income!')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final budgetResult = await _aiAgent.generateBudgetPlan(
        income: income,
        savingGoal: savingGoal,
      );

// 🚨 Validate that the result is not empty
      if (budgetResult.isEmpty ||
          !(budgetResult['categories']?.isNotEmpty ?? false)) {
        throw Exception("Empty or invalid AI response");
      }

// ✅ SAFELY PARSE categories
      final rawCategories = budgetResult['categories'] as Map<String, dynamic>;
      final aiCategories = <String, double>{};
      rawCategories.forEach((key, value) {
        aiCategories[key] = (value is num)
            ? value.toDouble()
            : double.tryParse(value.toString()) ?? 0.0;
      });

      final String budgetSummary = budgetResult['summary'] ?? '';
      final String budgetSuggestion = budgetResult['suggestion'] ?? '';
      final double totalExpenses = aiCategories.values.fold(
          0.0, (a, b) => a + b);
      final double calculatedSavings = income - totalExpenses;

      await _aiAgent.saveBudgetSuggestionToFirestore(
        uid: uid,
        calculationId: latestCalculationId,
        income: income,
        savingGoal: savingGoal,
        categories: aiCategories,
        totalExpenses: totalExpenses,
        savings: calculatedSavings,
        summary: budgetSummary,
        suggestion: budgetSuggestion,
      );

      setState(() {
        suggestedBudgets = aiCategories;
        aiSummary = budgetSummary;
        aiSuggestion = budgetSuggestion;
      });
    }    catch (e) {
      print("❌ Error in budget suggestion: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get AI budget suggestion.")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Monthly Income: Rs. ${_monthlyIncome?.toStringAsFixed(0) ?? 'Not Available'}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E4620),
                fontFamily: 'FunnelDisplay',
              ),
            ),
            const SizedBox(height: 12),

            // Styled "Desired Savings" input
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: Color(0xFFAFFFB2),
                  selectionHandleColor: Color(0xFFAFFFB2),
                ),
              ),
              child: TextField(
                controller: _savingGoalController,
                keyboardType: TextInputType.number,
                cursorColor: Color(0xFFAFFFB2),
                style: TextStyle(
                  color: Color(0xFF1E4620),
                  fontFamily: 'FunnelDisplay',
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Desired Savings',
                  hintStyle: TextStyle(
                    color: Color(0xFF1E4620),
                    fontFamily: 'FunnelDisplay',
                    fontWeight: FontWeight.w600,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Color(0xFFC7EDC7),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Color(0xFFC7EDC7),
                      width: 2,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Styled Button Centered
            Center(
              child: ElevatedButton(
                onPressed:
                _monthlyIncome == null ? null : _calculateSuggestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFC7EDC7), // Button background
                  foregroundColor: Color(0xFF1E4620), // Text color
                  padding: EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: TextStyle(
                    fontFamily: 'FunnelDisplay',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                child: Text("Get AI Budget Suggestion"),
              ),
            ),

            const SizedBox(height: 30),

            if (suggestedBudgets != null) ...[
              Text(
                "Optimal Budget Allocation:",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'FunnelDisplay',
                    color: Color(0xFF1E4620)),
              ),
              const SizedBox(height: 10),
    ...suggestedBudgets!.entries.map((entry) {
    final category = entry.key.toLowerCase();
    IconData icon;

    switch (category) {
    case 'rent':
    icon = Icons.home;
    break;
    case 'food':
    icon = Icons.restaurant;
    break;
    case 'transport':
    icon = Icons.directions_car;
    break;
    case 'utilities':
    icon = Icons.lightbulb;
    break;
    case 'healthcare':
    icon = Icons.local_hospital;
    break;
    case 'entertainment':
    icon = Icons.movie;
    break;
    case 'education':
    icon = Icons.school;
    break;
    case 'miscellaneous':
    icon = Icons.more_horiz;
    break;
    default:
    icon = Icons.category;
    }

    return ListTile(
    leading: Icon(icon, color: Color(0xFF1E4620)),
    title: Text(
    entry.key,
    style: TextStyle(
    fontFamily: 'FunnelDisplay',
    color: Color(0xFF1E4620), // updated text color
    ),
    ),
    trailing: Text(
    'Rs ${entry.value.toStringAsFixed(0)}',
    style: TextStyle(
    fontFamily: 'FunnelDisplay',
    fontWeight: FontWeight.w600,
    color: Color(0xFF1E4620), // updated text color
    ),
    ),
    );
    }).toList(),


    if (aiSummary != null && aiSuggestion != null) ...[
              const SizedBox(height: 20),
              Text("AI Summary",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'FunnelDisplay',
                    color: Color(0xFF1E4620),
                  )),
              Text(
                aiSummary!,
                style: TextStyle(
                  fontFamily: 'FunnelDisplay',
                ),
              ),
              const SizedBox(height: 10),
              Text("AI Suggestions",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'FunnelDisplay',
                    color: Color(0xFF1E4620),
                  )),
              Text(
                aiSuggestion!,
                style: TextStyle(
                  fontFamily: 'FunnelDisplay',
                ),
              ),
            ]
          ],
        ],
      ),
      )
    );
  }

}
