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

    final budgetResult = await _aiAgent.generateBudgetPlan(
      income: income,
      savingGoal: savingGoal,
    );

    final Map<String, double> aiCategories =
    Map<String, double>.from(budgetResult['categories'] ?? {});
    final String budgetSummary = budgetResult['summary'] ?? '';
    final String budgetSuggestion = budgetResult['suggestion'] ?? '';
    final double totalExpenses = aiCategories.values.fold(0.0, (a, b) => a + b);
    final double calculatedSavings = income - totalExpenses;

    await _aiAgent.saveBudgetSuggestionToFirestore(
      uid: uid,
      calculationId: latestCalculationId, // Optional – can be null
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
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Budget Suggestions")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Monthly Income: Rs. ${_monthlyIncome?.toStringAsFixed(0) ?? 'Not Available'}",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _savingGoalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Desired Savings",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
              _monthlyIncome == null ? null : _calculateSuggestion,
              child: Text("Get AI Budget Suggestion"),
            ),
            const SizedBox(height: 30),
            if (suggestedBudgets != null) ...[
              Text(
                "Optimal Budget Allocation:",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...suggestedBudgets!.entries.map((entry) {
                return ListTile(
                  leading: Icon(Icons.category),
                  title: Text(entry.key),
                  trailing:
                  Text('Rs ${entry.value.toStringAsFixed(0)}'),
                );
              }).toList(),
            ],
            if (aiSummary != null && aiSuggestion != null) ...[
              const SizedBox(height: 20),
              Text("AI Summary",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(aiSummary!),
              const SizedBox(height: 10),
              Text("AI Suggestions",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(aiSuggestion!),
            ]
          ],
        ),
      ),
    );
  }
}
