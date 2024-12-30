import 'package:flutter/material.dart';
import 'package:paylink_pos/models/product_model.dart';

class ProductList extends StatelessWidget {
  final List<Product> products;
  final Function(String, int) onQuantityChange;
  final Function(String) onRemove;

  ProductList({
    Key? key,
    required this.products,
    required this.onQuantityChange,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith((states) =>
              Colors.blueGrey.shade900), // Header row background color
          columns: [
            DataColumn(
                label: Text(
              'Product Name',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )),
            DataColumn(
                label: Text(
              'Unit Price',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )),
            DataColumn(
                label: Text(
              'Total Price',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )),
            DataColumn(
                headingRowAlignment: MainAxisAlignment.center,
                label: Text(
                  'Quantity',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                )),
            DataColumn(
                label: Text(
              'Actions',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )),
          ],
          rows: products.map((product) {
            return DataRow(
              cells: [
                DataCell(Text(
                  product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white, // Name color
                  ),
                )),
                DataCell(Text(
                  '${product.price.toStringAsFixed(2)} LKR',
                  style: TextStyle(color: Colors.white),
                )),
                DataCell(Text(
                  '${(product.price * product.quantity).toStringAsFixed(2)} LKR',
                  style: TextStyle(color: Colors.white),
                )),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Decrease Button
                      InkWell(
                        onTap: () =>
                            onQuantityChange(product.id.toString(), -1),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.remove,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      // Quantity Text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          product.quantity.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // Increase Button
                      InkWell(
                        onTap: () => onQuantityChange(product.id.toString(), 1),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => onRemove(product.id.toString()),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
