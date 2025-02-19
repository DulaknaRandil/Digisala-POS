import 'package:flutter/material.dart';
import 'package:digisala_pos/models/product_model.dart';

class ProductList extends StatelessWidget {
  final List<Product> products;
  final Function(String, double) onQuantityChange;
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
    return LayoutBuilder(builder: (context, constraints) {
      // Determine if we are on a small screen
      final bool isSmallScreen = constraints.maxWidth < 600;

      // Adjust sizes based on screen width
      final double baseTextSize = isSmallScreen ? 20.0 : 24.0;
      final double iconSize = isSmallScreen ? 24.0 : 26.0;
      final double columnSpacing = isSmallScreen ? 50 : 80;
      final double cellMaxWidth = isSmallScreen ? 100 : 150;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columnSpacing: columnSpacing,
            headingRowColor: WidgetStateColor.resolveWith(
              (states) => Colors.blueGrey.shade900,
            ),
            columns: [
              DataColumn(
                label: Text(
                  'Product Name',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: baseTextSize,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Unit Price',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: baseTextSize,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Total Price',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: baseTextSize,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Quantity',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: baseTextSize,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: baseTextSize,
                  ),
                ),
              ),
            ],
            rows: products.map((product) {
              return DataRow(
                cells: [
                  DataCell(
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cellMaxWidth, // Adjust cell width
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: baseTextSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${product.price.toStringAsFixed(2)} LKR',
                      style: TextStyle(
                          color: Colors.white, fontSize: baseTextSize),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${(product.price * product.quantity).toStringAsFixed(2)} LKR',
                      style: TextStyle(
                          color: Colors.white, fontSize: baseTextSize),
                    ),
                  ),
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
                            child: Icon(Icons.remove,
                                color: Colors.white, size: iconSize),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            width: isSmallScreen ? 40 : 30,
                            child: TextField(
                              controller: TextEditingController(
                                text: product.quantity.toString(),
                              ),
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: baseTextSize,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                              onSubmitted: (value) {
                                double? newQuantity = double.tryParse(value);
                                if (newQuantity != null) {
                                  onQuantityChange(product.id.toString(),
                                      newQuantity - product.quantity);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Quantity updated to $newQuantity for ${product.name}.',
                                        style:
                                            TextStyle(fontSize: baseTextSize),
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
                          onTap: () =>
                              onQuantityChange(product.id.toString(), 1),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add,
                                color: Colors.white, size: iconSize),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon:
                          Icon(Icons.delete, color: Colors.red, size: iconSize),
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
    });
  }
}
