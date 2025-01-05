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
        return LayoutBuilder(
          builder: (context, constraints) {
            return AlertDialog(
              backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
              contentPadding: EdgeInsets.zero,
              content: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Text(
                          'Sales Items',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 800,
                          height: 600,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                    const Color.fromARGB(56, 131, 131, 128)),
                                dataRowColor:
                                    MaterialStateProperty.resolveWith<Color>(
                                  (Set<MaterialState> states) {
                                    if (states
                                        .contains(MaterialState.selected)) {
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
                                      label: Text('Name',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  DataColumn(
                                      label: Text('Quantity',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  DataColumn(
                                      label: Text('Total',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  DataColumn(
                                      label: Text('Discount',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  DataColumn(
                                      label: Text('Final Price',
                                          style:
                                              TextStyle(color: Colors.white))),
                                ],
                                rows: _salesItems.map((item) {
                                  final double finalPrice =
                                      item.total - item.discount;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(item.name,
                                          style: const TextStyle(
                                              color: Colors.white))),
                                      DataCell(Text('${item.quantity}',
                                          style: const TextStyle(
                                              color: Colors.white))),
                                      DataCell(Text('${item.total}',
                                          style: const TextStyle(
                                              color: Colors.white))),
                                      DataCell(Text('${item.discount}',
                                          style: const TextStyle(
                                              color: Colors.white))),
                                      DataCell(Text('${finalPrice}',
                                          style: const TextStyle(
                                              color: Colors.white))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTopSoldItem() async {
    final topSoldItem = await DatabaseHelper.instance.getTopSoldItem();
    if (topSoldItem != null) {
      _showItemDialog('Top Sold Item', topSoldItem);
    } else {
      _showMessageDialog('No sales data available for today.');
    }
  }

  void _showLeastSoldItem() async {
    final leastSoldItem = await DatabaseHelper.instance.getLeastSoldItem();
    if (leastSoldItem != null) {
      _showItemDialog('Least Sold Item', leastSoldItem);
    } else {
      _showMessageDialog('No sales data available for today.');
    }
  }

  void _showItemDialog(String title, SalesItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
          title: Text(
            title,
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Item: ${item.name}\nQuantity: ${item.quantity}',
            style: TextStyle(color: Colors.white),
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

  void _showMessageDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
          title: const Text(
            'Information',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white),
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
              const Divider(color: Colors.white),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoContainer(
                      'Sales Count',
                      '$_salesCount',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8), // Space between containers
                  Expanded(
                    child: _buildInfoContainer(
                      'Total Amount',
                      '$_totalAmount LKR',
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8), // Space between containers
                  Expanded(
                    child: FutureBuilder<SalesItem?>(
                      future: DatabaseHelper.instance.getTopSoldItem(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasData && snapshot.data != null) {
                          final item = snapshot.data!;
                          return _buildInfoContainer(
                            'Top Sold Item',
                            '${item.name}\n' '''       ''' '(${item.quantity})',
                            Colors.amber,
                          );
                        } else {
                          return _buildInfoContainer(
                            'Top Sold Item',
                            'No Data',
                            Colors.amber,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8), // Space between containers
                  Expanded(
                    child: FutureBuilder<SalesItem?>(
                      future: DatabaseHelper.instance.getLeastSoldItem(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasData && snapshot.data != null) {
                          final item = snapshot.data!;
                          return _buildInfoContainer(
                            'Least Sold Item',
                            '${item.name}\n'
                                '''              '''
                                '(${item.quantity})',
                            Colors.grey,
                          );
                        } else {
                          return _buildInfoContainer(
                            'Least Sold Item',
                            'No Data',
                            Colors.grey,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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

  Widget _buildInfoContainer(String title, String value, Color color) {
    return Container(
      height: 110, // Fixed height for all containers
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14, // Smaller font size for the title
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18, // Larger font size for the value
              ),
            ),
          ],
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
