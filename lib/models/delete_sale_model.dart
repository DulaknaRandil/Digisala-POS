class DeleteSale {
  final int? id;
  final String date;
  final String time;
  final String paymentMethod;
  final double subtotal;
  final double discount;
  final double total;
  final bool stockUpdated;

  DeleteSale({
    this.id,
    required this.date,
    required this.time,
    required this.paymentMethod,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.stockUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'time': time,
      'paymentMethod': paymentMethod,
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'stockUpdated': stockUpdated ? 1 : 0,
    };
  }

  factory DeleteSale.fromMap(Map<String, dynamic> map) {
    return DeleteSale(
      id: map['id'],
      date: map['date'],
      time: map['time'],
      paymentMethod: map['paymentMethod'],
      subtotal: map['subtotal'],
      discount: map['discount'],
      total: map['total'],
      stockUpdated: map['stockUpdated'] == 1,
    );
  }
}
