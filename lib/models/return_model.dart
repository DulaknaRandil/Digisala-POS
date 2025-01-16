class Return {
  final int? id;
  final int salesItemId;
  final String name;
  final double discount;
  final double total;
  final String returnDate;
  final double quantity;

  Return({
    this.id,
    required this.salesItemId,
    required this.name,
    required this.discount,
    required this.total,
    required this.returnDate,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'salesItemId': salesItemId,
      'name': name,
      'discount': discount,
      'total': total,
      'returnDate': returnDate,
      'quantity': quantity,
    };
  }

  factory Return.fromMap(Map<String, dynamic> map) {
    return Return(
      id: map['id'],
      salesItemId: map['salesItemId'],
      name: map['name'],
      discount: map['discount'],
      total: map['total'],
      returnDate: map['returnDate'],
      quantity: map['quantity'],
    );
  }
}
