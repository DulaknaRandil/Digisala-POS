class Return {
  final int? id;
  final int salesItemId;
  final String name;
  final double discount;
  final double total;
  final String returnDate;
  final double quantity;
  final bool stockUpdated;
  final int productId; // Add this
  final String supplierName; // Add this

  Return({
    this.id,
    required this.salesItemId,
    required this.name,
    required this.discount,
    required this.total,
    required this.returnDate,
    required this.quantity,
    required this.stockUpdated,
    required this.productId, // Add this
    required this.supplierName, // Add this
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
      'stockUpdated': stockUpdated ? 1 : 0,
      'productId': productId, // Add this
      'supplierName': supplierName, // Add this
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
      stockUpdated: map['stockUpdated'] == 1,
      productId: map['productId'], // Add this
      supplierName: map['supplierName'], // Add this
    );
  }
}
