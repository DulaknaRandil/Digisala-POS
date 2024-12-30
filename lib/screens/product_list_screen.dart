import 'package:flutter/material.dart';
import 'package:paylink_pos/database/product_db_helper.dart';
import 'package:paylink_pos/models/product_model.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/add-product');
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: DatabaseHelper.instance.getAllProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final product = snapshot.data![index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('Quantity: \\${product.quantity}'),
                  trailing: Text('\$${product.price.toStringAsFixed(2)}'),
                );
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
