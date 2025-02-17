class Product {
  final int? id;
  final String barcode;
  final String name;
  final String secondaryName;
  final DateTime? expiryDate;
  final String productGroup;
  double quantity;
  double price;
  double buyingPrice;
  final String discount;
  final DateTime createdDate;
  final DateTime updatedDate;
  final String status;
  final int supplierId; // New field for supplier reference

  Product({
    this.id,
    required this.barcode,
    required this.name,
    required this.secondaryName,
    required this.expiryDate,
    required this.productGroup,
    required this.quantity,
    required this.price,
    required this.buyingPrice,
    required this.discount,
    required this.createdDate,
    required this.updatedDate,
    required this.status,
    required this.supplierId, // Initialize the new field
  });
  Product copyWith({
    int? id,
    String? name,
    String? secondaryName,
    String? barcode,
    DateTime? expiryDate,
    String? productGroup,
    double? quantity,
    double? price,
    double? buyingPrice,
    String? discount,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? status,
    int? supplierId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      secondaryName: secondaryName ?? this.secondaryName,
      barcode: barcode ?? this.barcode,
      expiryDate: expiryDate ?? this.expiryDate,
      productGroup: productGroup ?? this.productGroup,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      discount: discount ?? this.discount,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      status: status ?? this.status,
      supplierId: supplierId ?? this.supplierId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'secondaryName': secondaryName,
      'expiryDate': expiryDate?.toIso8601String(),
      'productGroup': productGroup,
      'quantity': quantity,
      'price': price,
      'buyingPrice': buyingPrice,
      'discount': discount,
      'createdDate': createdDate.toIso8601String(),
      'updatedDate': updatedDate.toIso8601String(),
      'status': status,
      'supplierId': supplierId, // Include the new field in the map
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      secondaryName: map['secondaryName'] ?? '',
      expiryDate:
          map['expiryDate'] != null ? DateTime.parse(map['expiryDate']) : null,
      productGroup: map['productGroup'],
      quantity: map['quantity'],
      price: map['price'],
      buyingPrice: map['buyingPrice'],
      discount: map['discount'] ?? '0',
      createdDate: DateTime.parse(map['createdDate']),
      updatedDate: DateTime.parse(map['updatedDate']),
      status: map['status'],
      supplierId: map['supplierId'], // Parse the new field
    );
  }
}
