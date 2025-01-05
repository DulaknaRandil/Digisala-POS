import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:paylink_pos/models/salesItem_model.dart';
import 'package:paylink_pos/models/sales_model.dart';
import 'package:paylink_pos/database/product_db_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EndOfDayDialog extends StatefulWidget {
  const EndOfDayDialog({Key? key}) : super(key: key);

  @override
  _EndOfDayDialogState createState() => _EndOfDayDialogState();
}

class _EndOfDayDialogState extends State<EndOfDayDialog> {
  List<Sales> _salesList = [];
  List<SalesItem> _salesItems = [];
  int _salesCount = 0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTodaySales();
  }

  Future<void> _loadTodaySales() async {
    final today = DateTime.now();
    final String formattedDate = today.toIso8601String().split('T').first;
    print('Querying sales for date: $formattedDate');

    final sales = await DatabaseHelper.instance.getSalesByDate(today);
    print('Sales fetched: ${sales.length}');

    setState(() {
      _salesList = sales;
      _updateSalesSummary();
    });
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
              pw.Text('End of Day Report', style: pw.TextStyle(fontSize: 24)),
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
    await Printing.sharePdf(bytes: bytes, filename: 'end_of_day_report.pdf');
  }

  Future<void> _printDocument() async {
    final bytes = await _generatePdfContent();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }

  void _loadSalesItems(int salesId) async {
    final items = await DatabaseHelper.instance.getSalesItems(salesId);
    setState(() {
      _salesItems = items;
    });
  }

  void _showSalesItemsDialog(int salesId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
          title: const Text(
            'Sales Items',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: _salesItems.length,
              itemBuilder: (context, index) {
                final item = _salesItems[index];
                return ListTile(
                  title: Text(item.name, style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                      'Quantity: ${item.quantity}, Total: ${item.total}',
                      style: TextStyle(color: Colors.white)),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showMostSoldItems() async {
    final mostSoldItems = await DatabaseHelper.instance.getMostSoldItems();
    print('Most sold items to display: ${mostSoldItems.length}');
    for (var item in mostSoldItems) {
      print('Item: ${item.name}, Quantity: ${item.quantity}');
    }
    _showItemsDialog('Most Sold Items', mostSoldItems);
  }

  void _showLeastSoldItems() async {
    final leastSoldItems = await DatabaseHelper.instance.getLeastSoldItems();
    _showItemsDialog('Least Sold Items', leastSoldItems);
  }

  void _showItemsDialog(String title, List<SalesItem> items) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
          title: Text(
            title,
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(
                    item.name,
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Quantity: ${item.quantity}',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'End of Day Report',
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white),
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
                  ],
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _showMostSoldItems,
                    child: const Text('Most Sold Items'),
                  ),
                  ElevatedButton(
                    onPressed: _showLeastSoldItems,
                    child: const Text('Least Sold Items'),
                  ),
                ],
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
                    onPressed: () => Navigator.of(context).pop(),
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
      height: 250, // Adjust height to show rows
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
                    _showSalesItemsDialog(sales.id!);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
