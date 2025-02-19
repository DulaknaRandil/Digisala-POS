class DeleteSaleItem {
  final int? id;
  final int deleteSaleId;
  final int deleteSaleItemId;
  final String name;
  final double quantity;
  final double buyingPrice;
  final double price;
  final double discount;
  final double total;
  final bool refund;

  DeleteSaleItem({
    this.id,
    required this.deleteSaleId,
    required this.deleteSaleItemId,
    required this.name,
    required this.quantity,
    required this.buyingPrice,
    required this.price,
    required this.discount,
    required this.total,
    required this.refund,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deleteSaleId': deleteSaleId,
      'deleteSaleItemId': deleteSaleItemId,
      'name': name,
      'quantity': quantity,
      'buyingPrice': buyingPrice,
      'price': price,
      'discount': discount,
      'total': total,
      'refund': refund ? 1 : 0,
    };
  }

  factory DeleteSaleItem.fromMap(Map<String, dynamic> map) {
    return DeleteSaleItem(
      id: map['id'],
      deleteSaleId: map['deleteSaleId'],
      deleteSaleItemId: map['deleteSaleItemId'],
      name: map['name'],
      quantity: map['quantity'],
      buyingPrice: map['buyingPrice'],
      price: map['price'],
      discount: map['discount'],
      total: map['total'],
      refund: map['refund'] == 1,
    );
  }
}
