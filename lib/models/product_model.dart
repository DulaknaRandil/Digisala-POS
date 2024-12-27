// lib/models/product_model.dart
class Product {
  final int? id;
  final String barcode;
  final String name;
  final String category;
  int quantity;
  double price;

  Product({
    this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      category: map['category'],
      quantity: map['quantity'],
      price: map['price'],
    );
  }
}
