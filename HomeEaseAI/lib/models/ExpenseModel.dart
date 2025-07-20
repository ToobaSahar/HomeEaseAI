class ExpenseModel {
  final String category;
  final double amount;
  final DateTime date;

  ExpenseModel({
    required this.category,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'amount': amount,
    'date': date.toIso8601String(),
  };
}
