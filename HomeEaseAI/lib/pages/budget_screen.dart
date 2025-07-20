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
    return Scaffold(
      body: Stack(
        children: [
          // 🔸 Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/ai-generated-9010160_1280.webp'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 🔸 Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E4620),
                  Color(0xFF1E4620),
                  Colors.transparent,
                ],
                stops: [0.0, 0.3, 1.0],
              ),
            ),
          ),

          // 🔸 Foreground UI container
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.80,
                height: MediaQuery.of(context).size.height * 0.74,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: DefaultTabController(
                    length: 2,
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      appBar: AppBar(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,

                        toolbarHeight: 56,
                        titleSpacing: 0,
                        automaticallyImplyLeading: false, // Prevent default back arrow
                        title: Padding(
                          padding: EdgeInsets.only(left: 8, top: 6),
                          child: Row(
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                icon: Icon(Icons.arrow_back, size: 24, color:  Color(0xFF1E4620)),
                                onPressed: () => Navigator.pop(context),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Budgeting AI',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  color:  Color(0xFF1E4620),
                                  fontFamily: 'FunnelDisplay',
                                ),
                              ),
                            ],
                          ),
                        ),
                        bottom: PreferredSize(
                          preferredSize: Size.fromHeight(48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: TabBar(
                                isScrollable: false,
                                indicatorSize: TabBarIndicatorSize.tab,
                                indicator: BoxDecoration(
                                  color: Color(0xFF1E4620),
                                  borderRadius: BorderRadius.circular(30),
                                ),

                                dividerColor: Colors.transparent,

                                overlayColor: MaterialStateProperty.all(Colors.transparent), // Optional
                                indicatorColor: Colors.transparent, // Optional if using BoxDecoration
                                labelColor: Colors.white,
                                unselectedLabelColor: Color(0xFF1E4620),
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: 'FunnelDisplay',
                                ),
                                unselectedLabelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: 'FunnelDisplay',
                                ),
                                tabs: [
                                  Tab(text: 'Expense Calculator'),
                                  Tab(text: 'Budget Suggestion'),
                                ],
                              )

                            ),
                          ),
                        ),


                      ),

                      body: Container(
                        color: Colors.white,
                        child: TabBarView(
                          children: [
                            AddExpenseScreen(onIncomeChanged: updateIncome),
                            BudgetSuggestionScreen(),
                          ],
                        ),
                      ),

                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

