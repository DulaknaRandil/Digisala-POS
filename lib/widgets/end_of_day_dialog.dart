import 'dart:io';
import 'dart:typed_data';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:digisala_pos/widgets/drawer_amount_dialog.dart';
import 'package:flutter/material.dart';
import 'package:digisala_pos/models/salesItem_model.dart';
import 'package:digisala_pos/models/sales_model.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EndOfDayDialog extends StatefulWidget {
  final FocusNode searchBarFocusNode;
  const EndOfDayDialog({Key? key, required this.searchBarFocusNode})
      : super(key: key);

  @override
  _EndOfDayDialogState createState() => _EndOfDayDialogState();
}

class _EndOfDayDialogState extends State<EndOfDayDialog> {
  List<Sales> _salesList = [];
  List<SalesItem> _salesItems = [];
  int _salesCount = 0;
  double _totalAmount = 0.0;
  double _totalProfit = 0.0; // New variable for total profit
  final PrinterService _printerService = PrinterService();
  int _currentSalesPage = 1;
  final int _rowsPerPage = 10;
  @override
  void initState() {
    super.initState();
    _loadTodaySales();
  }

  double calculateProfit(
    double price,
    double buyingPrice,
    double totalDiscount,
    double originalQuantity,
    double remainingQuantity,
  ) {
    final proportionalDiscount =
        (remainingQuantity / originalQuantity) * totalDiscount;
    return (price - buyingPrice) * remainingQuantity - proportionalDiscount;
  }

  Future<void> _loadTodaySales() async {
    final today = DateTime.now();
    final sales = await DatabaseHelper.instance.getSalesByDate(today);

    double profit = 0.0;

    for (var sale in sales) {
      final items = await DatabaseHelper.instance.getSalesItems(sale.id!);

      for (var item in items) {
        final refunds =
            await DatabaseHelper.instance.getRefundsForSalesItem(item.id!);
        final totalRefunded = refunds.fold(0.0, (sum, r) => sum + r.quantity);
        final remainingQty = item.quantity - totalRefunded;

        if (remainingQty > 0) {
          profit += calculateProfit(
            item.price,
            item.buyingPrice,
            item.discount,
            item.quantity, // Original quantity
            remainingQty, // Remaining after refunds
          );
        }
      }
    }

    setState(() {
      _salesList = sales;
      _totalProfit = profit;
      _updateSalesSummary();
    });
  }

  void _updateSalesSummary() {
    _salesCount = _salesList.length;
    _totalAmount = _salesList.fold(0.0, (sum, sales) => sum + sales.total);
  }

  Future<Uint8List> _generatePdfContent() async {
    double startDrawerAmount = 0;
    double endDrawerAmount = 0;

    // Show drawer amount dialog
    await showDialog(
      context: context,
      builder: (context) => DrawerAmountDialog(
        totalAmount: _totalAmount,
        onSubmit: (start, end) {
          startDrawerAmount = start;
          endDrawerAmount = end;
        },
      ),
    );

    final pdf = pw.Document();
    final drawerDifference = endDrawerAmount - startDrawerAmount;
    final isTallied = (drawerDifference - _totalAmount).abs() < 0.01;
    final drawerStatus = isTallied ? 'Tallied' : 'Not Tallied';

    // Load receipt setup data
    final receiptSetup = await _printerService.loadReceiptSetup();
    final storeName = receiptSetup['storeName'] ?? 'Store Name';
    final telephone = receiptSetup['telephone'] ?? 'N/A';
    final address = receiptSetup['address'] ?? '';
    final logoPath = receiptSetup['logoPath'];

    // Load logo images
    pw.MemoryImage? logoImage;
    if (logoPath != null && await File(logoPath).exists()) {
      final logoBytes = await File(logoPath).readAsBytes();
      logoImage = pw.MemoryImage(logoBytes);
    }

    pw.MemoryImage? digisalaLogoImage;
    var digisalaLogoPath = 'assets/logo.png';
    if (await File(digisalaLogoPath).exists()) {
      final logoBytes = await File(digisalaLogoPath).readAsBytes();
      digisalaLogoImage = pw.MemoryImage(logoBytes);
    }

    final currentYear = DateTime.now().year;
    final date = DateTime.now().toIso8601String().substring(0, 10);

    // Fetch all sales items for the day
    List<SalesItem> allSalesItems = [];
    Map<String, Map<String, dynamic>> itemSummary = {};

    for (var sale in _salesList) {
      final items = await DatabaseHelper.instance.getSalesItems(sale.id!);
      allSalesItems.addAll(items);

      // Create summary for each unique item
      for (var item in items) {
        // Get total refunded quantity for this item
        final refunds =
            await DatabaseHelper.instance.getRefundsForSalesItem(item.id!);
        final totalRefunded = refunds.fold(0.0, (sum, r) => sum + r.quantity);

        // Calculate actual sold quantity and proportional values
        final remainingQty = item.quantity - totalRefunded;
        final unitPrice = item.price;
        final proportionalDiscount = totalRefunded > 0
            ? (remainingQty / item.quantity) * item.discount
            : item.discount;
        if (itemSummary.containsKey(item.name)) {
          itemSummary[item.name]!['quantity'] += item.quantity;
          itemSummary[item.name]!['returnQty'] += totalRefunded;
          itemSummary[item.name]!['remainingQty'] += remainingQty;
          itemSummary[item.name]!['total'] += remainingQty * unitPrice;
          itemSummary[item.name]!['discount'] += proportionalDiscount;
        } else {
          itemSummary[item.name] = {
            'quantity': item.quantity,
            'returnQty': totalRefunded,
            'remainingQty': remainingQty,
            'total': remainingQty * unitPrice,
            'discount': proportionalDiscount,
            'buyingPrice': item.buyingPrice,
          };
        }
      }
    }

    // Convert summary to a list for easier sorting and display
    List<Map<String, dynamic>> itemsList = [];
    itemSummary.forEach((name, data) {
      itemsList.add({
        'name': name,
        'totalQty': data['quantity'],
        'returnQty': data['returnQty'],
        'remainingQty': data['remainingQty'],
        'total': data['total'],
        'discount': data['discount'],
        'finalPrice': data['total'] - data['discount'],
        'profit': (data['total'] - data['discount']) -
            (data['buyingPrice'] * data['remainingQty']),
      });
    });

    // Sort items by quantity (descending)
    itemsList.sort((a, b) => b['quantity'].compareTo(a['quantity']));

    // Calculate items per page
    final salesItemsPerPage = 20;
    final salesTotalPages = (_salesList.length / salesItemsPerPage).ceil();

    // Generate sales pages
    for (var pageNum = 0; pageNum < salesTotalPages; pageNum++) {
      final startIndex = pageNum * salesItemsPerPage;
      final endIndex = (startIndex + salesItemsPerPage < _salesList.length)
          ? startIndex + salesItemsPerPage
          : _salesList.length;

      final pageItems = _salesList.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 80,
                        height: 80,
                        child: pw.Image(logoImage),
                      )
                    else
                      pw.Container(width: 80, height: 80),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(storeName,
                            style: pw.TextStyle(
                                fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: $date',
                            style: pw.TextStyle(fontSize: 12)),
                        pw.Text('Tel: $telephone',
                            style: pw.TextStyle(fontSize: 12)),
                        if (address.isNotEmpty)
                          pw.Text('Address: $address',
                              style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('End of Day Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.SizedBox(height: 10),

                // Sales Table
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Table(
                        border: pw.TableBorder.all(),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(1),
                          1: const pw.FlexColumnWidth(2),
                          2: const pw.FlexColumnWidth(1.5),
                          3: const pw.FlexColumnWidth(1.5),
                          4: const pw.FlexColumnWidth(1.5),
                          5: const pw.FlexColumnWidth(1.5),
                          6: const pw.FlexColumnWidth(1.5),
                        },
                        children: [
                          // Table header
                          pw.TableRow(
                            decoration:
                                pw.BoxDecoration(color: PdfColors.grey300),
                            children: [
                              'ID',
                              'Date',
                              'Time',
                              'Method',
                              'Payment',
                              'Discount',
                              'Total',
                            ]
                                .map((text) => pw.Padding(
                                      padding: const pw.EdgeInsets.all(6),
                                      child: pw.Text(text,
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold)),
                                    ))
                                .toList(),
                          ),
                          // Data rows
                          ...pageItems.map((sales) => pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(sales.id.toString()),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                        '${sales.date.day}/${sales.date.month}/${sales.date.year}'),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(sales.time),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(sales.paymentMethod),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(sales.subtotal.toString()),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(sales.discount.toString()),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(sales.total.toString()),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ],
                  ),
                ),

                // Page information
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  margin: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    'Sales Report - Page ${pageNum + 1} of $salesTotalPages',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // Item-wise summary pages
    final itemsPerPage = 20;
    final itemsTotalPages = (itemsList.length / itemsPerPage).ceil();

    for (var pageNum = 0; pageNum < itemsTotalPages; pageNum++) {
      final startIndex = pageNum * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage < itemsList.length)
          ? startIndex + itemsPerPage
          : itemsList.length;

      final pageItems = itemsList.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 80,
                        height: 80,
                        child: pw.Image(logoImage),
                      )
                    else
                      pw.Container(width: 80, height: 80),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(storeName,
                            style: pw.TextStyle(
                                fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: $date',
                            style: pw.TextStyle(fontSize: 12)),
                        pw.Text('Tel: $telephone',
                            style: pw.TextStyle(fontSize: 12)),
                        if (address.isNotEmpty)
                          pw.Text('Address: $address',
                              style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('Items-wise Sales Summary',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.SizedBox(height: 10),

                // Items Table
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Table(
                        border: pw.TableBorder.all(),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2.2),
                          1: const pw.FlexColumnWidth(1.2),
                          2: const pw.FlexColumnWidth(1.2),
                          3: const pw.FlexColumnWidth(1.2),
                          4: const pw.FlexColumnWidth(1.3),
                          5: const pw.FlexColumnWidth(1.3),
                          6: const pw.FlexColumnWidth(1.3),
                          7: const pw.FlexColumnWidth(1.3),
                        },
                        children: [
                          // Table header
                          pw.TableRow(
                            decoration:
                                pw.BoxDecoration(color: PdfColors.grey300),
                            children: [
                              'Item Name',
                              'Total Qty',
                              'Return Qty',
                              'Net Qty',
                              'Total Sales',
                              'Discount',
                              'Net Sales',
                              'Profit',
                            ]
                                .map((text) => pw.Padding(
                                      padding: const pw.EdgeInsets.all(6),
                                      child: pw.Text(text,
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold)),
                                    ))
                                .toList(),
                          ),
                          // Data rows
                          ...pageItems.map((item) => pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(item['name']),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                        item['totalQty'].toStringAsFixed(2)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                        item['returnQty'].toStringAsFixed(2)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(item['remainingQty']
                                        .toStringAsFixed(2)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                        item['total'].toStringAsFixed(2)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                        item['discount'].toStringAsFixed(2)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                        item['finalPrice'].toStringAsFixed(2)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                        item['profit'].toStringAsFixed(2)),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ],
                  ),
                ),

                // Summary on last items page
                if (pageNum == itemsTotalPages - 1)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(top: 20),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('End of Day Summary',
                            style: pw.TextStyle(
                                fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 10),
                        pw.Text('Sales Count: $_salesCount'),
                        pw.Text(
                            'Total Profit: ${_totalProfit.toStringAsFixed(2)} LKR'),
                        pw.Text(
                            'Start Day Drawer Amount: $startDrawerAmount LKR'),
                        pw.Text('End Day Drawer Amount: $endDrawerAmount LKR'),
                        pw.Text('Total Sales Amount: $_totalAmount LKR'),
                        pw.Text('Status: $drawerStatus',
                            style: pw.TextStyle(
                                color:
                                    isTallied ? PdfColors.green : PdfColors.red,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),

                // Footer
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 20),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (digisalaLogoImage != null)
                        pw.Container(
                          height: 30,
                          child: pw.Image(digisalaLogoImage),
                        ),
                      pw.Text(
                        '© $currentYear Digisala POS. All rights reserved',
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),

                // Page number
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  margin: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    'Items Report - Page ${pageNum + 1} of $itemsTotalPages',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

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
                        Padding(
                          padding: const EdgeInsets.only(left: 200),
                          child: SizedBox(
                            width: 800,
                            height: 600,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                      const Color.fromARGB(56, 131, 131, 128)),
                                  dataRowColor:
                                      WidgetStateProperty.resolveWith<Color>(
                                    (Set<WidgetState> states) {
                                      if (states
                                          .contains(WidgetState.selected)) {
                                        return Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.08);
                                      }
                                      return Colors.white.withAlpha(8);
                                    },
                                  ),
                                  columns: const [
                                    DataColumn(
                                        label: Text('Name',
                                            style: TextStyle(
                                                color: Colors.white))),
                                    DataColumn(
                                        label: Text('Quantity',
                                            style: TextStyle(
                                                color: Colors.white))),
                                    DataColumn(
                                        label: Text('Total',
                                            style: TextStyle(
                                                color: Colors.white))),
                                    DataColumn(
                                        label: Text('Discount',
                                            style: TextStyle(
                                                color: Colors.white))),
                                    DataColumn(
                                        label: Text('Final Price',
                                            style: TextStyle(
                                                color: Colors.white))),
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
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.searchBarFocusNode.requestFocus();
                        }),
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
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.searchBarFocusNode.requestFocus(); //
                          }),
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
                    _buildSalesPagination(),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Profit: $_totalProfit LKR',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
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
    final startIndex = (_currentSalesPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    final paginatedSales = _salesList.sublist(
      startIndex,
      endIndex.clamp(0, _salesList.length),
    );

    return SizedBox(
      height: 390, // Adjust height to show rows
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
                const Color.fromARGB(56, 131, 131, 128)),
            dataRowColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08);
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
            rows: paginatedSales.map((sales) {
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

  Widget _buildSalesPagination() {
    final totalPages = (_salesList.length / _rowsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: _currentSalesPage > 1
              ? () => setState(() => _currentSalesPage--)
              : null,
        ),
        Text(
          'Page $_currentSalesPage of $totalPages',
          style: const TextStyle(color: Colors.white),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white),
          onPressed: _currentSalesPage < totalPages
              ? () => setState(() => _currentSalesPage++)
              : null,
        ),
      ],
    );
  }
}
