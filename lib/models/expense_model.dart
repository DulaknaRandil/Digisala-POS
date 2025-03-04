class Expense {
  int? id;
  DateTime date;
  String time;
  String category;
  String description;
  double amount;

  Expense({
    this.id,
    required this.date,
    required this.time,
    required this.category,
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': time,
      'category': category,
      'description': description,
      'amount': amount,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      date: DateTime.parse(map['date']),
      time: map['time'],
      category: map['category'],
      description: map['description'],
      amount: map['amount'],
    );
  }
}
