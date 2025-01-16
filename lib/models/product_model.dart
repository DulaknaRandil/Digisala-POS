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
  });

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
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      secondaryName:
          map['secondaryName'] != null && map['secondaryName'].isNotEmpty
              ? map['secondaryName']
              : '',
      expiryDate: map['expiryDate'] != null && map['expiryDate'].isNotEmpty
          ? DateTime.parse(map['expiryDate'])
          : null,
      productGroup: map['productGroup'],
      quantity: map['quantity'],
      price: map['price'],
      buyingPrice: map['buyingPrice'],
      discount: map['discount'] != null && map['discount'].isNotEmpty
          ? map['discount']
          : 0,
      createdDate: DateTime.parse(map['createdDate']),
      updatedDate: DateTime.parse(map['updatedDate']),
      status: map['status'],
    );
  }
}
