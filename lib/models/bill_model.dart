// lib/models/bill_model.dart
class BillItem {
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double total;

  BillItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
  });
}

class Bill {
  final int? id;
  final DateTime dateTime;
  final List<BillItem> items;
  final double totalAmount;

  Bill({
    this.id,
    required this.dateTime,
    required this.items,
    required this.totalAmount,
  });
}
