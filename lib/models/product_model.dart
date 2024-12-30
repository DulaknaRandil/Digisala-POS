class Product {
  final int? id;
  final String barcode;
  final String name;
  final DateTime? expiryDate;
  final String productGroup;
  int quantity;
  double price;
  final DateTime createdDate;
  final DateTime updatedDate;
  final String status;

  Product({
    this.id,
    required this.barcode,
    required this.name,
    required this.expiryDate,
    required this.productGroup,
    required this.quantity,
    required this.price,
    required this.createdDate,
    required this.updatedDate,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'expiryDate': expiryDate?.toIso8601String(),
      'productGroup': productGroup,
      'quantity': quantity,
      'price': price,
      'createdDate': createdDate.toIso8601String(),
      'updatedDate': updatedDate.toIso8601String(),
      'status': status,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      expiryDate: map['expiryDate'] != null && map['expiryDate'].isNotEmpty
          ? DateTime.parse(map['expiryDate'])
          : null,
      productGroup: map['productGroup'],
      quantity: map['quantity'],
      price: map['price'],
      createdDate: DateTime.parse(map['createdDate']),
      updatedDate: DateTime.parse(map['updatedDate']),
      status: map['status'],
    );
  }
}
