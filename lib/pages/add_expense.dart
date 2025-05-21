import 'package:day35/pages/ai_budget_agent.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; // 👈 new import
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'budget_suggestion_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  final void Function(double)? onIncomeChanged; // <-- Optional callback
//  final void Function(String)? onCalculationIdGenerated;
  const AddExpenseScreen({
    super.key,
    this.onIncomeChanged,
    //this.onCalculationIdGenerated, // <-- Include it here
  });

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _incomeController = TextEditingController();
  final List<TextEditingController> _expenseControllers = [];
  final List<String> _categories = ['Food', 'Transport', 'Bills', 'Shopping', 'Entertainment'];
  final aiBudgetAgent = AIBudgetAgent();

  String _summary = '';
  String _aiSuggestion = '';
  Color _summaryColor = Colors.green;

  Map<String, double> _currentExpenses = {};

  @override
  void initState() {
    super.initState();
    _categories.forEach((_) => _expenseControllers.add(TextEditingController()));
    _loadSavedData(); // 👈 fetch saved data on init
  }

  Future<void> _loadSavedData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('budget')
        .orderBy('timestamp', descending: true) // 👈 get most recent entry
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();

      final double income = (data['income'] ?? 0).toDouble();
      final double totalExpenses = (data['totalExpenses'] ?? 0).toDouble();
      final double savings = (data['savings'] ?? 0).toDouble();
      final Map<String, dynamic> expensesMap = Map<String, dynamic>.from(data['expenses'] ?? {});
      final Map<String, double> parsedExpenses = expensesMap.map((key, value) => MapEntry(key, (value as num).toDouble()));

      _incomeController.text = income.toStringAsFixed(0);

      for (int i = 0; i < _categories.length; i++) {
        final category = _categories[i];
        if (parsedExpenses.containsKey(category)) {
          _expenseControllers[i].text = parsedExpenses[category]!.toStringAsFixed(0);
        }
      }

      widget.onIncomeChanged?.call(income); // refresh income upstream

      setState(() {
        _currentExpenses = parsedExpenses;
        _summary = data['summary'] ?? '';
        _aiSuggestion = data['suggestion'] ?? '';
        _summaryColor = savings < 0 ? Colors.red : Colors.green;
      });
    }
  }

  // keep _calculateAndSave and rest of your UI unchanged...
  void _calculateAndSave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    double income = double.tryParse(_incomeController.text.trim()) ?? 0;
    Map<String, double> expenses = {};

    for (int i = 0; i < _categories.length; i++) {
      double value = double.tryParse(_expenseControllers[i].text.trim()) ?? 0;
      expenses[_categories[i]] = value;
    }

    double totalExpenses = expenses.values.fold(0.0, (a, b) => a + b);
    double savings = income - totalExpenses;

    final aiResponse = await aiBudgetAgent.fetchAISummaryAndSuggestions(
      income: income,
      expenses: expenses,
    );

    // Generate new calculationId using Firebase
    final calculationId = FirebaseFirestore.instance
        .collection('budget')
        .doc(uid)
        .collection('calculations')
        .doc()
        .id;

   // widget.onCalculationIdGenerated?.call(calculationId); // <-- Inform parent widget

    await aiBudgetAgent.saveSummaryToFirestore(
      uid: uid,
      income: income,
      expenses: expenses,
      totalExpenses: totalExpenses,
      savings: savings,
      summary: aiResponse['summary'] ?? '',
      suggestion: aiResponse['suggestion'] ?? '',
      calculationId: calculationId,
    );

    // Just update the state, no navigation
    setState(() {
      _summary = aiResponse['summary'] ?? '';
      _aiSuggestion = aiResponse['suggestion'] ?? '';
      _summaryColor = savings < 0 ? Colors.red : Colors.green;
      _currentExpenses = expenses;
    });
  }


  List<PieChartSectionData> _buildPieChartSections() {
    double total = _currentExpenses.values.fold(0, (a, b) => a + b);
    return _currentExpenses.entries.map((entry) {
      final percentage = total == 0 ? 0 : (entry.value / total) * 100;
      final color = _getCategoryColor(entry.key);
      return PieChartSectionData(
        color: color,
        value: percentage.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food':
        return Colors.green;
      case 'Transport':
        return Colors.orange;
      case 'Bills':
        return Colors.blue;
      case 'Shopping':
        return Colors.purple;
      case 'Entertainment':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _currentExpenses.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(width: 14, height: 14, color: _getCategoryColor(entry.key)),
              SizedBox(width: 8),
              Text('${entry.key}: Rs. ${entry.value.toStringAsFixed(2)}'),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Expense Calculator + AI', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),
            TextField(
              controller: _incomeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Monthly Income'),
            ),
            SizedBox(height: 12),
            ..._categories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              return TextField(
                controller: _expenseControllers[index],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '$category Expense'),
              );
            }),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _calculateAndSave,
              child: Text('Calculate & Get AI Advice'),
            ),
            SizedBox(height: 16),
            if (_summary.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _summaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _summaryColor, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_summary, style: TextStyle(fontSize: 16, color: _summaryColor, fontWeight: FontWeight.w600)),
                    SizedBox(height: 12),
                    Text('🧠 AI Suggestion: ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    SizedBox(height: 4),
                    Text(_aiSuggestion, style: TextStyle(fontSize: 14, color: Colors.black87)),
                  ],
                ),
              ),
            SizedBox(height: 20),
            if (_currentExpenses.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💹 Expense Breakdown Chart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  AspectRatio(
                    aspectRatio: 1.4,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieChartSections(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildLegend(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _expenseControllers.forEach((c) => c.dispose());
    super.dispose();
  }
}