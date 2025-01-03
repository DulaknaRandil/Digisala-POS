class Sales {
  final int? id;
  final DateTime date;
  final String time;
  final String paymentMethod;
  final double subtotal;
  final double discount;
  final double total;

  Sales({
    this.id,
    required this.date,
    required this.time,
    required this.paymentMethod,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'time': time,
      'paymentMethod': paymentMethod,
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
    };
  }

  factory Sales.fromMap(Map<String, dynamic> map) {
    return Sales(
      id: map['id'],
      date: DateTime.parse(map['date']),
      time: map['time'],
      paymentMethod: map['paymentMethod'],
      subtotal: map['subtotal'],
      discount: map['discount'],
      total: map['total'],
    );
  }
}
