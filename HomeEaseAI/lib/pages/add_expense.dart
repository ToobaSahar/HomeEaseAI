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

      _incomeController.text = '';

      for (int i = 0; i < _categories.length; i++) {
        final category = _categories[i];
        if (parsedExpenses.containsKey(category)) {
          // 👇 Skip setting values for index 0 and 1 (i.e., Food and Transport)
          if (i == 0 || i == 1) {
            _expenseControllers[i].text = '';
          } else {
            _expenseControllers[i].text = parsedExpenses[category]!.toStringAsFixed(0);
          }
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _currentExpenses.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(entry.key),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${entry.key}: Rs. ${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E4620), // ✅ applied
                      fontFamily: 'FunnelDisplay', // ✅ applied
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 32), // Extra space at bottom

        child: Column(
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: Color(0xFFAFFFB2),
                  selectionHandleColor: Color(0xFFAFFFB2),
                ),
              ),
              child: TextField(
                controller: _incomeController,
                keyboardType: TextInputType.number,
                cursorColor: Color(0xFFAFFFB2),
                style: TextStyle(
                  color: Color(0xFF1E4620),
                  fontFamily: 'FunnelDisplay',
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Monthly Income',
                  hintStyle: TextStyle(
                    color: Color(0xFF1E4620),
                    fontFamily: 'FunnelDisplay',
                    fontWeight: FontWeight.w600,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Color(0xFFC7EDC7), // ✅ New border color
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Color(0xFFC7EDC7), // ✅ New border color
                      width: 2,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

            SizedBox(height: 12),
            ..._categories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textSelectionTheme: TextSelectionThemeData(
                      cursorColor: Color(0xFFC7EDC7),
                      selectionHandleColor: Color(0xFFC7EDC7),
                    ),
                  ),
                  child: TextField(
                    controller: _expenseControllers[index],
                    keyboardType: TextInputType.number,
                    cursorColor: Color(0xFFC7EDC7), // ✅ Cursor color
                    style: TextStyle(
                      color: Color(0xFF1E4620),
                      fontFamily: 'FunnelDisplay',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '$category Expense',
                      hintStyle: TextStyle(
                        color: Color(0xFF1E4620),
                        fontFamily: 'FunnelDisplay',
                        fontWeight: FontWeight.w600,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: Color(0xFFC7EDC7), // ✅ Border color
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: Color(0xFFC7EDC7), // ✅ Border color
                          width: 2,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              );
            }),

            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _calculateAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFC7EDC7), // Button background
                foregroundColor: Color(0xFF1E4620), // Text color
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: TextStyle(
                  fontFamily: 'FunnelDisplay',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              child: Text('Calculate & Get AI Advice'),
            ),

            SizedBox(height: 16),
            if (_summary.isNotEmpty)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFAFFFB2), // ✅ Updated background
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xFF1E4620), width: 2), // ✅ Updated border
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _summary,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'FunnelDisplay', // ✅ Font
                        color: Color(0xFF1E4620), // ✅ Updated summary color
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '🧠 AI Suggestion:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'FunnelDisplay', // ✅ Font
                        color: Colors.blueAccent,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _aiSuggestion,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'FunnelDisplay', // ✅ Font
                        color: Colors.black87,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),


            SizedBox(height: 20),
            if (_currentExpenses.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💹 Expense Breakdown Chart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'FunnelDisplay', // ✅ Font
                      color: Color(0xFF1E4620), // ✅ Updated color
                    ),
                  ),
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