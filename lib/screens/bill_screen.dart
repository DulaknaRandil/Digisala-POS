// lib/screens/bill_screen.dart
import 'package:flutter/material.dart';
import 'package:digisala_pos/models/bill_model.dart';

class BillScreen extends StatelessWidget {
  const BillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bill = ModalRoute.of(context)!.settings.arguments as Bill;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date: ${bill.dateTime.toString()}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Table(
                    border: TableBorder.all(),
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(2),
                    },
                    children: [
                      const TableRow(
                        children: [
                          TableCell(
                              child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Item'),
                          )),
                          TableCell(
                              child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Qty'),
                          )),
                          TableCell(
                              child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Price'),
                          )),
                        ],
                      ),
                      ...bill.items
                          .map((item) => TableRow(
                                children: [
                                  TableCell(
                                      child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(item.productName),
                                  )),
                                  TableCell(
                                      child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('${item.quantity}'),
                                  )),
                                  TableCell(
                                      child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                        '\$${item.total.toStringAsFixed(2)}'),
                                  )),
                                ],
                              ))
                          ,
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Total Amount: \$${bill.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement printing functionality
                // You can use packages like 'printing' or 'pdf' to generate PDF
                // and then use platform-specific printing capabilities
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Printing bill...')),
                );
              },
              child: const Text('Print Bill'),
            ),
          ),
        ],
      ),
    );
  }
}
