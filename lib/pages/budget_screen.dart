import 'package:day35/pages/ai_budget_agent.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'add_expense.dart';  // Import the AddExpenseScreen file
import 'budget_suggestion_screen.dart';  // Import the BudgetSuggestionScreen file
import 'ai_tips_screen.dart';  // Import the AITipsScreen file

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  double _incomeFromAddExpense = 0;
  String? _calculationId;

  void updateIncome(double newIncome) {
    setState(() {
      _incomeFromAddExpense = newIncome;
    });
  }

  void updateCalculationId(String newId) {
    setState(() {
      _calculationId = newId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('💰 Budget Expense AI Agent'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Expense Calculator'),
              Tab(text: 'Budget Suggestion'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AddExpenseScreen(onIncomeChanged: updateIncome),  // 👈 Pass callback here
            BudgetSuggestionScreen(
              //incomeFromAddExpense: _incomeFromAddExpense,
              //calculationId: _calculationId,
            ),
          ],
        ),

      ),
    );
  }
}

class ExpenseChartTab extends StatelessWidget {
  const ExpenseChartTab({super.key});

  Future<double> _fetchIncome(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('budget')
          .doc(uid)
          .collection('profile')
          .doc('income') // This doc should contain a field like { amount: 50000 }
          .get();

      return (doc.data()?['amount'] ?? 0).toDouble();
    } catch (e) {
      debugPrint('⚠️ Error fetching income: $e');
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text("🔒 Please login to view expenses."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('budget')
          .doc(uid)
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("📉 No expenses added yet."));
        }

        final categoryTotals = <String, double>{};

        for (final doc in snapshot.data!.docs) {
          try {
            final category = doc['category'] as String;
            final amountRaw = doc['amount'];

            final amount = amountRaw is int
                ? amountRaw.toDouble()
                : amountRaw is double
                ? amountRaw
                : 0.0;

            if (amount > 0) {
              categoryTotals[category] =
                  (categoryTotals[category] ?? 0) + amount;
            }
          } catch (e) {
            debugPrint('⚠️ Skipping invalid expense doc: ${doc.id} — $e');
          }
        }

        if (categoryTotals.isEmpty) {
          return const Center(child: Text("🕵️‍♂️ No valid expenses found."));
        }

        return FutureBuilder<double>(
          future: _fetchIncome(uid),
          builder: (context, incomeSnapshot) {
            if (!incomeSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final income = incomeSnapshot.data!;

            return FutureBuilder<Map<String, dynamic>>(
              future: AIBudgetAgent().analyzeExpensesWithAI(
                income: income,
                categoryTotals: categoryTotals,
              ),
              builder: (context, aiSnapshot) {
                if (!aiSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final aiData = aiSnapshot.data!;
                final Map<String, dynamic> breakdown =
                Map<String, dynamic>.from(aiData['breakdown']);
                final List<dynamic> insights = aiData['insights'] ?? [];

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "Your AI-Powered Expense Breakdown",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      AspectRatio(
                        aspectRatio: 1.2,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                            sections: breakdown.entries.map((entry) {
                              return PieChartSectionData(
                                color: _getColorForCategory(entry.key),
                                value: entry.value.toDouble(),
                                title:
                                '${entry.key}\n${entry.value.toStringAsFixed(1)}%',
                                radius: 70,
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...insights.map((tip) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Text('💡 ',
                                style: TextStyle(fontSize: 16)),
                            Expanded(child: Text(tip.toString())),
                          ],
                        ),
                      )),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.green;
      case 'transport':
        return Colors.blue;
      case 'entertainment':
        return Colors.orange;
      case 'bills':
        return Colors.red;
      case 'health':
        return Colors.purple;
      case 'shopping':
        return Colors.pink;
      default:
        return Colors.grey.shade600;
    }
  }
}

