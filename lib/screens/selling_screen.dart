// lib/screens/selling_screen.dart
import 'package:flutter/material.dart';
import 'package:paylink_pos/database/db_helper.dart';
import 'package:paylink_pos/models/bill_model.dart';

class SellingScreen extends StatefulWidget {
  const SellingScreen({super.key});

  @override
  _SellingScreenState createState() => _SellingScreenState();
}

class _SellingScreenState extends State<SellingScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BillItem> cartItems = [];
  double totalAmount = 0;

  void _searchProduct(String id) async {
    if (id.isEmpty) return;

    try {
      final product =
          await DatabaseHelper.instance.getProductById(int.parse(id));
      if (product != null) {
        setState(() {
          cartItems.add(BillItem(
            productId: product.id!,
            productName: product.name,
            quantity: 1,
            price: product.price,
            total: product.price,
          ));
          _calculateTotal();
        });
        _searchController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid product ID')),
      );
    }
  }

  void _calculateTotal() {
    totalAmount = cartItems.fold(0, (sum, item) => sum + item.total);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selling Screen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Enter Product ID',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchProduct(_searchController.text),
                ),
              ),
              onSubmitted: _searchProduct,
              keyboardType: TextInputType.number,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return ListTile(
                  title: Text(item.productName),
                  subtitle: Text('Quantity: ${item.quantity}'),
                  trailing: Text('\$${item.total.toStringAsFixed(2)}'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Total: \$${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: cartItems.isEmpty
                      ? null
                      : () {
                          final bill = Bill(
                            dateTime: DateTime.now(),
                            items: List.from(cartItems),
                            totalAmount: totalAmount,
                          );
                          Navigator.pushNamed(
                            context,
                            '/bill',
                            arguments: bill,
                          );
                        },
                  child: const Text('Generate Bill'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
