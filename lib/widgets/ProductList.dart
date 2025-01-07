import 'package:flutter/material.dart';
import 'package:digisala_pos/models/product_model.dart';

class ProductList extends StatelessWidget {
  final List<Product> products;
  final Function(String, int) onQuantityChange;
  final Function(String) onRemove;
  final FocusNode searchBarFocusNode;

  ProductList({
    Key? key,
    required this.products,
    required this.onQuantityChange,
    required this.onRemove,
    required this.searchBarFocusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: 100,
          headingRowColor: MaterialStateColor.resolveWith(
            (states) => Colors.blueGrey.shade900,
          ),
          columns: [
            DataColumn(
              label: Text(
                'Product Name',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Unit Price',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Total Price',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Quantity',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Actions',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: products.map((product) {
            return DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 150, // Set the maximum width of the cell
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 30,
                          child: TextField(
                            controller: TextEditingController(
                              text: product.quantity.toString(),
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            onSubmitted: (value) {
                              int? newQuantity = int.tryParse(value);
                              if (newQuantity != null) {
                                onQuantityChange(product.id.toString(),
                                    newQuantity - product.quantity);

                                // Show a snackbar confirmation with green color
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Quantity updated to $newQuantity for ${product.name}.',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                              searchBarFocusNode.requestFocus();
                            },
                          ),
                        ),
                      ),
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
                    onPressed: () {
                      onRemove(product.id.toString());
                      searchBarFocusNode.requestFocus();
                    },
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
