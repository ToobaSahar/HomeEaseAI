// widgets/expense_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ExpenseChart extends StatelessWidget {
  final Map<String, double> categoryTotals;

  ExpenseChart({required this.categoryTotals});

  @override
  Widget build(BuildContext context) {
    final sections = categoryTotals.entries.map((entry) {
      final color = _getColorForCategory(entry.key);
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${entry.key}\nRs. ${entry.value.toStringAsFixed(0)}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
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
      default:
        return Colors.grey;
    }
  }
}