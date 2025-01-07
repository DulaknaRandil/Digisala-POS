import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:digisala_pos/models/salesItem_model.dart';
import 'package:digisala_pos/models/sales_model.dart';
import 'package:digisala_pos/models/return_model.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesHistoryDialog extends StatefulWidget {
  final FocusNode searchBarFocusNode;
  const SalesHistoryDialog({Key? key, required this.searchBarFocusNode})
      : super(key: key);

  @override
  _SalesHistoryDialogState createState() => _SalesHistoryDialogState();
}

class _SalesHistoryDialogState extends State<SalesHistoryDialog> {
  List<Sales> _salesList = [];
  List<SalesItem> _salesItems = [];
  Map<int, int> _refundedQuantities = {};
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  int _salesCount = 0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    final sales = await DatabaseHelper.instance.getAllSales();
    setState(() {
      _salesList = sales;
      _updateSalesSummary();
    });
  }

  Future<void> _searchSales() async {
    if (_searchQuery.isNotEmpty) {
      final sales = await DatabaseHelper.instance.searchSalesById(_searchQuery);
      setState(() {
        _salesList = sales;
        _updateSalesSummary();
      });
    } else if (_selectedDateRange != null) {
      final sales = await DatabaseHelper.instance.searchSalesByDateRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );
      setState(() {
        _salesList = sales;
        _updateSalesSummary();
      });
    } else {
      _loadSales();
    }
  }

  Future<void> _loadSalesItems(int salesId) async {
    final items = await DatabaseHelper.instance.getSalesItems(salesId);
    final refunds = await DatabaseHelper.instance.getRefundsForSales(salesId);
    setState(() {
      _salesItems = items;
      _refundedQuantities = {for (var r in refunds) r.salesItemId: r.quantity};
    });
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _searchSales();
    }
  }

  void _handleRefund(SalesItem item, int refundQuantity) async {
    if (refundQuantity > 0 && refundQuantity <= item.quantity) {
      final returnItem = Return(
        salesItemId: item.id!,
        name: item.name,
        discount: item.discount,
        total: item.total,
        returnDate: DateTime.now().toIso8601String(),
        quantity: refundQuantity,
      );
      await DatabaseHelper.instance.insertReturn(returnItem);
      item.refund = true;
      await DatabaseHelper.instance.updateSalesItem(item);
      _loadSalesItems(item.salesId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid refund quantity')),
      );
    }
  }

  void _updateSalesSummary() {
    _salesCount = _salesList.length;
    _totalAmount = _salesList.fold(0.0, (sum, sales) => sum + sales.total);
  }

  Future<Uint8List> _generatePdfContent() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sales History', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              // Sales Table
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header
                  pw.TableRow(
                    children: [
                      'ID',
                      'Date',
                      'Time',
                      'Payment Method',
                      'Payment',
                      'Discount',
                      'Total',
                    ]
                        .map((text) => pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(text),
                            ))
                        .toList(),
                  ),
                  // Data rows
                  ..._salesList.map((sales) => pw.TableRow(
                        children: [
                          sales.id.toString(),
                          '${sales.date.day}/${sales.date.month}/${sales.date.year}',
                          sales.time,
                          sales.paymentMethod,
                          sales.subtotal.toString(),
                          sales.discount.toString(),
                          sales.total.toString(),
                        ]
                            .map((text) => pw.Container(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(text),
                                ))
                            .toList(),
                      )),
                ],
              ),
              pw.SizedBox(height: 20),

              pw.Text('Summary', style: pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 2),
              pw.Text('Sales Count: $_salesCount'),
              pw.Text('Total Amount: $_totalAmount LKR'),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _generatePdf() async {
    final bytes = await _generatePdfContent();
    await Printing.sharePdf(bytes: bytes, filename: 'sales_history.pdf');
  }

  Future<void> _printDocument() async {
    final bytes = await _generatePdfContent();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Dialog(
        backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        child: Container(
          width: 900,
          height: 750,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // At the top of your SalesHistoryDialog class
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sales History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _generatePdf,
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _printDocument,
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.searchBarFocusNode.requestFocus();
                          }),
                    ],
                  ),
                ],
              ),

              const Divider(color: Colors.white),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by Sales ID',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: _searchSales,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                    ),
                    onPressed: _selectDateRange,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 40,
                        ),
                        Text('Sales',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ],
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    _buildSalesTable(),
                    const Divider(color: Colors.white),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 40,
                        ),
                        Text('Sales Items',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ],
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    _buildItemsTable(),
                  ],
                ),
              ),
              const Divider(color: Colors.white),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sales count: $_salesCount',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Total amount: $_totalAmount LKR',
                    style: const TextStyle(color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.searchBarFocusNode.requestFocus();
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesTable() {
    return SizedBox(
      height: 250, // Adjust height to show three rows
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
                const Color.fromARGB(56, 131, 131, 128)),
            dataRowColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.08);
                }
                return Colors.white.withAlpha(8);
              },
            ),
            columns: const [
              DataColumn(
                  label: Text('ID', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Date', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Time', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Method', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label:
                      Text('Payment', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label:
                      Text('Discount', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Total', style: TextStyle(color: Colors.white))),
            ],
            rows: _salesList.map((sales) {
              return DataRow(
                color: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.08);
                    }
                    return Colors.white.withAlpha(8);
                  },
                ),
                cells: [
                  DataCell(Text('${sales.id}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text(
                      '${sales.date.day}/${sales.date.month}/${sales.date.year}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${sales.time}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${sales.paymentMethod}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${sales.subtotal}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${sales.discount}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${sales.total}',
                      style: const TextStyle(color: Colors.white))),
                ],
                onSelectChanged: (selected) {
                  if (selected == true) {
                    _loadSalesItems(sales.id!);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    return SizedBox(
      height: 180, // Adjust height to show three rows
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
                const Color.fromARGB(56, 131, 131, 128)),
            dataRowColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.08);
                }
                return Colors.white.withAlpha(8);
              },
            ),
            columns: const [
              DataColumn(
                  label: Text('ID', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Name', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label:
                      Text('Quantity', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Price', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label:
                      Text('Discount', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Total', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Refund', style: TextStyle(color: Colors.white))),
            ],
            rows: _salesItems.map((item) {
              final refundedQuantity = _refundedQuantities[item.id] ?? 0;
              return DataRow(
                color: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.08);
                    }
                    return Colors.white.withAlpha(8);
                  },
                ),
                cells: [
                  DataCell(Text('${item.id}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${item.name}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${item.quantity}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${item.price}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${item.discount}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${item.total}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(
                    refundedQuantity > 0
                        ? Text('Refunded: $refundedQuantity',
                            style: const TextStyle(color: Colors.green))
                        : Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Qty',
                                    hintStyle: TextStyle(color: Colors.white54),
                                  ),
                                  onSubmitted: (value) {
                                    final refundQuantity =
                                        int.tryParse(value) ?? 0;
                                    _handleRefund(item, refundQuantity);
                                  },
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  final refundQuantity =
                                      item.quantity; // Default to full quantity
                                  _handleRefund(item, refundQuantity);
                                },
                                child: const Text('Refund',
                                    style: TextStyle(color: Colors.blue)),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
