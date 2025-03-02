import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:digisala_pos/widgets/delete_history_dialog.dart';
import 'package:digisala_pos/widgets/sales_report.dart';
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
  // For sales table pagination
  int _currentSalesPage = 1;
  final int _rowsPerPage = 10;

// For sales items table pagination
  int _currentItemsPage = 1;
  final int _itemsPerPage = 5;
  List<Sales> _salesList = [];
  List<SalesItem> _salesItems = [];
  Map<int, double> _refundedQuantities = {};
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  int _salesCount = 0;
  double _totalAmount = 0.0;
  List<Product> _products = [];
  final PrinterService _printerService = PrinterService();
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

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _products = products;
    });
  }

  _openSalesReport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SalesReportDialog();
      },
    );
  }

  Future<void> _searchSales() async {
    if (_searchQuery.isNotEmpty) {
      final sales = await DatabaseHelper.instance.searchSalesById(_searchQuery);
      setState(() {
        _salesList = sales;
        _currentSalesPage = 1; // Reset to first page
        _updateSalesSummary();
      });
    } else if (_selectedDateRange != null) {
      final sales = await DatabaseHelper.instance.searchSalesByDateRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );
      setState(() {
        _salesList = sales;
        _currentSalesPage = 1; // Reset to first page
        _updateSalesSummary();
      });
    } else if (_selectedDateRange == null) {
      final today = DateTime.now();
      final sales = await DatabaseHelper.instance.searchSalesByDateRange(
        DateTime(today.year, today.month, today.day, 0, 0, 0), // Today 00:00:00
        DateTime(
            today.year, today.month, today.day, 23, 59, 59), // Today 23:59:59
      );
      setState(() {
        _salesList = sales;
        _currentSalesPage = 1; // Reset to first page
        _updateSalesSummary();
      });
    } else {
      _loadSales();
    }
  }

  Future<void> _loadSalesItems(int salesId) async {
    final items = await DatabaseHelper.instance.getSalesItems(salesId);
    final refunds = await DatabaseHelper.instance.getRefundsForSales(salesId);

    // Create a map to track total refunded quantity per sales item
    Map<int, double> refundedQty = {};

    // Calculate total refunded quantity for each sales item
    for (var refund in refunds) {
      refundedQty[refund.salesItemId] =
          (refundedQty[refund.salesItemId] ?? 0) + refund.quantity;
    }

    setState(() {
      _salesItems = items;
      _refundedQuantities = refundedQty;
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
        _currentSalesPage = 1; // Reset to first page
      });
      _searchSales();
    }
  }

  void _handleRefund(SalesItem item, double refundQuantity) async {
    // Get total already refunded
    final existingRefunds =
        await DatabaseHelper.instance.getRefundsForSalesItem(item.id!);
    final totalRefunded =
        existingRefunds.fold(0.0, (sum, r) => sum + r.quantity);
    final remainingQuantity = item.quantity - totalRefunded;

    if (refundQuantity <= 0 || refundQuantity > remainingQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Invalid refund quantity. Max available: $remainingQuantity')),
      );
      return;
    }

    // Show confirmation dialog
    bool? updateStock = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
          title: const Text(
            'Refund Options',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Update product stock when refunding?',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.red),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Refund Without Updating Stock',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.green.shade500),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Refund and Update Stock',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (updateStock == null) return;

    final db = await DatabaseHelper.instance.database;

    // Get product and supplier details
    final product = await db.query(
      'products',
      where: 'name = ?',
      whereArgs: [item.name],
    );

    if (product.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product not found: ${item.name}')),
      );
      return;
    }

    final supplier = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [product.first['supplierId']],
    );

    // Create return item with stockUpdated status
    final returnItem = Return(
      salesItemId: item.id!,
      name: item.name,
      discount: item.discount,
      total: item.total,
      returnDate: DateTime.now().toIso8601String(),
      quantity: refundQuantity,
      stockUpdated: updateStock,
      productId: product.first['id'] as int,
      supplierName: supplier.isNotEmpty
          ? supplier.first['name'] as String
          : 'Unknown Supplier',
    );

    // Insert the return record
    await DatabaseHelper.instance.insertReturn(returnItem);

    // Update product stock if selected
    if (updateStock) {
      await db.transaction((txn) async {
        final product = await txn.query(
          'products',
          where: 'name = ?',
          whereArgs: [item.name],
        );
        if (product.isNotEmpty) {
          final currentQuantity = product.first['quantity'] as num;
          await txn.update(
            'products',
            {
              'quantity': currentQuantity + refundQuantity,
              'updatedDate': DateTime.now().toIso8601String(),
            },
            where: 'name = ?',
            whereArgs: [item.name],
          );
        }
      });
    }

    // Calculate the total refunded quantity after this refund
    final newTotalRefunded = totalRefunded + refundQuantity;

    // Check if the item is now fully refunded
    final isFullyRefunded = newTotalRefunded >= item.quantity;

    // Update sales total but do NOT mark the item as refunded unless fully refunded
    await db.transaction((txn) async {
      // Only set refund flag if the item is now fully refunded
      await txn.update(
        'sales_items',
        {
          'refund': isFullyRefunded ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );

      // Update parent sale total
      final sale = (await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [item.salesId],
      ))
          .first;

      final updatedSale = Sales(
        id: sale['id'] as int,
        date: DateTime.parse(sale['date'] as String),
        time: sale['time'] as String,
        paymentMethod: sale['paymentMethod'] as String,
        subtotal: (sale['subtotal'] as num) - (refundQuantity * item.price),
        discount: sale['discount'] as double,
        total: (sale['total'] as num) - (refundQuantity * item.price),
      );

      await txn.update(
        'sales',
        updatedSale.toMap(),
        where: 'id = ?',
        whereArgs: [item.salesId],
      );
    });

    // Refresh all data
    await _loadSales();
    await _loadSalesItems(item.salesId);
    _updateSalesSummary();
  }

  void _updateSalesSummary() {
    _salesCount = _salesList.length;
    _totalAmount = _salesList.fold(0.0, (sum, sales) => sum + sales.total);
  }

  Future<Uint8List> _generatePdfContent() async {
    final pdf = pw.Document();

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

    // Create item summary data
    Map<String, Map<String, dynamic>> itemSummary = {};

    // Fetch all sales items for the sales in the report
    for (var sale in _salesList) {
      final items = await DatabaseHelper.instance.getSalesItems(sale.id!);
      for (var item in items) {
        // Get total refunded quantity for this item
        final refunds =
            await DatabaseHelper.instance.getRefundsForSalesItem(item.id!);
        final totalRefunded = refunds.fold(0.0, (sum, r) => sum + r.quantity);
        // Calculate actual sold quantity and proportional discount
        final remainingQty = item.quantity - totalRefunded;
        final unitPrice = item.price;
        final proportionalDiscount =
            remainingQty * (item.discount / item.quantity);
        if (!itemSummary.containsKey(item.name)) {
          itemSummary[item.name] = {
            'quantity': 0.0,
            'Return Qty': 0.0,
            'remainingQty': 0.0,
            'totalSales': 0.0,
            'totalDiscount': 0.0,
            'netEarnings': 0.0,
            'salesCount': 0,
          };
        }

        itemSummary[item.name]!['quantity'] += item.quantity;
        itemSummary[item.name]!['Return Qty'] += totalRefunded;
        itemSummary[item.name]!['remainingQty'] += remainingQty;
        itemSummary[item.name]!['totalSales'] += remainingQty * unitPrice;
        itemSummary[item.name]!['totalDiscount'] += proportionalDiscount;
        itemSummary[item.name]!['netEarnings'] +=
            (remainingQty * unitPrice) - proportionalDiscount;
        itemSummary[item.name]!['salesCount'] += 1;
      }
    }

    // Convert to sortable list and sort by net earnings (descending)
    final itemSummaryList = itemSummary.entries.map((entry) {
      return {
        'name': entry.key,
        'quantity': entry.value['quantity'],
        'Return Qty': entry.value['Return Qty'],
        'remainingQty': entry.value['remainingQty'],
        'totalSales': entry.value['totalSales'],
        'totalDiscount': entry.value['totalDiscount'],
        'netEarnings': entry.value['netEarnings'],
        'salesCount': entry.value['salesCount'],
      };
    }).toList();

    itemSummaryList.sort((a, b) =>
        (b['netEarnings'] as double).compareTo(a['netEarnings'] as double));

    // Calculate items per page for sales table
    final salesItemsPerPage = 15; // Show 15 sales rows per page
    final totalSalesPages = (_salesList.length / salesItemsPerPage).ceil();

    // 1. FIRST, GENERATE SALES TABLES PAGES
    for (var pageNum = 0; pageNum < totalSalesPages; pageNum++) {
      final startIndex = pageNum * salesItemsPerPage;
      final endIndex = min(startIndex + salesItemsPerPage, _salesList.length);
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
                pw.Text('Sales History Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.SizedBox(height: 10),

                // Sales Table Header
                pw.Text(
                    'Sales Records (${startIndex + 1} - $endIndex of ${_salesList.length})',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),

                // Sales Table
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
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
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

                // Add sales summary only on the last page of sales records
                if (pageNum == totalSalesPages - 1)
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
                        pw.Text('Sales History Summary',
                            style: pw.TextStyle(
                                fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 10),
                        pw.Text('Sales Count: $_salesCount'),
                        pw.Text('Total Amount: $_totalAmount LKR'),
                        pw.Text(
                            'Total Items Sold: ${itemSummaryList.fold(0.0, (sum, item) => sum + (item['quantity'] as double)).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),

                // Footer
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Row(
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
                      // Page number - Include total pages counting both sales and items pages
                      pw.Container(
                        alignment: pw.Alignment.centerRight,
                        margin: const pw.EdgeInsets.only(top: 10),
                        child: pw.Text(
                          'Page ${pageNum + 1} of ${totalSalesPages + (itemSummaryList.length / 10).ceil()}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // 2. THEN, GENERATE ITEM-WISE SALES SUMMARY PAGES
    // Calculate how many pages we need for item summary (10 items per page)
    final itemsPerPage = 10;
    final totalItemPages = (itemSummaryList.length / itemsPerPage).ceil();

    for (var pageNum = 0; pageNum < totalItemPages; pageNum++) {
      final startIndex = pageNum * itemsPerPage;
      final endIndex = min(startIndex + itemsPerPage, itemSummaryList.length);
      final pageItems = itemSummaryList.sublist(startIndex, endIndex);

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
                pw.Text('Item-wise Sales Summary',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.SizedBox(height: 10),

                // Item-wise Sales Summary Table Header
                pw.Text(
                    'Items Summary (${startIndex + 1} - $endIndex of ${itemSummaryList.length})',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),

                // Item Summary Table
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(
                        2.5), // Item Name (reduced from 3)
                    1: const pw.FlexColumnWidth(1.3), // Quantity
                    2: const pw.FlexColumnWidth(1.3), // Returned
                    3: const pw.FlexColumnWidth(1.3), // Remaining
                    4: const pw.FlexColumnWidth(1.2), // Sales Count
                    5: const pw.FlexColumnWidth(1.5), // Total Sales
                    6: const pw.FlexColumnWidth(1.5), // Total Discount
                    7: const pw.FlexColumnWidth(1.5), // Net Earnings
                  },
                  children: [
                    // Table header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        'Item Name',
                        'Quantity',
                        'Return Qty',
                        'Net Qty',
                        'Sales Count',
                        'Total Sales',
                        'Total Discount',
                        'Net Earnings',
                      ]
                          .map((text) => pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(text,
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold)),
                              ))
                          .toList(),
                    ),
                    // Data rows - Show items for this page
                    ...pageItems.map((item) => pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(item['name'] as String),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text((item['quantity'] as double)
                                  .toStringAsFixed(2)),
                            ),
                            pw.Padding(
                              // New returned quantity cell
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text((item['Return Qty'] as double)
                                  .toStringAsFixed(2)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text((item['remainingQty'] as double)
                                  .toStringAsFixed(2)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(item['salesCount'].toString()),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text((item['totalSales'] as double)
                                  .toStringAsFixed(2)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text((item['totalDiscount'] as double)
                                  .toStringAsFixed(2)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text((item['netEarnings'] as double)
                                  .toStringAsFixed(2)),
                            ),
                          ],
                        )),
                  ],
                ),

                // Add item summary info on the last page
                if (pageNum == totalItemPages - 1)
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
                        pw.Text('Items Summary Statistics',
                            style: pw.TextStyle(
                                fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 10),
                        pw.Text(
                            'Most Sold Item: ${itemSummaryList.isNotEmpty ? itemSummaryList.reduce((a, b) => (a['quantity'] as double) > (b['quantity'] as double) ? a : b)['name'] : 'N/A'}'),
                        pw.Text(
                            'Highest Earning Item: ${itemSummaryList.isNotEmpty ? itemSummaryList[0]['name'] : 'N/A'}'),
                      ],
                    ),
                  ),

                // Footer
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Row(
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
                      // Page number
                      pw.Container(
                        alignment: pw.Alignment.centerRight,
                        margin: const pw.EdgeInsets.only(top: 10),
                        child: pw.Text(
                          'Page ${totalSalesPages + pageNum + 1} of ${totalSalesPages + totalItemPages}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
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
    await Printing.sharePdf(bytes: bytes, filename: 'sales_history.pdf');
  }

  // Add this method to your SalesHistoryDialog class
  void _openDeletedSalesHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const DeleteSalesHistoryDialog();
      },
    );
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
              // Update the top buttons row in build method to include Deleted Sales button
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
                      // Add the new Deleted Sales button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Deleted Sales'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _openDeletedSalesHistory,
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.assessment),
                        label: const Text('Sales Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _openSalesReport,
                      ),
                      const SizedBox(width: 10),
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
                    Row(
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
                        SizedBox(
                          width: 280,
                        ),
                        _buildSalesPagination(),
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
                        SizedBox(
                          width: 225,
                        ),
                        _buildItemsPagination(),
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
    final startIndex = (_currentSalesPage - 1) * _rowsPerPage;
    final endIndex = min(startIndex + _rowsPerPage, _salesList.length);
    final paginatedSales = _salesList.sublist(startIndex, endIndex);
    return SizedBox(
      height: 250, // Adjust height to show three rows
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
                  label: Text('Gross Price',
                      style: TextStyle(color: Colors.white))),
              DataColumn(
                  label:
                      Text('Discount', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Total', style: TextStyle(color: Colors.white))),
              DataColumn(
                label: Text('Actions', style: TextStyle(color: Colors.white)),
              ),
            ],
            rows: paginatedSales.map((sales) {
              return DataRow(
                color: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
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
                  DataCell(
                    PopupMenuButton<String>(
                      color: const Color.fromRGBO(2, 10, 27, 1),
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (String choice) async {
                        if (choice == 'Delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor:
                                    const Color.fromRGBO(2, 10, 27, 1),
                                title: const Text(
                                  'Confirm Delete',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  'Are you sure you want to delete this sale? This action cannot be undone.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                  ),
                                  TextButton(
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed == true) {
                            await DatabaseHelper.instance
                                .deleteSaleAndItems(sales.id!, false);
                            await _loadProducts();
                            _loadSales();
                          }
                        } else if (choice == 'Delete and Update') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor:
                                    const Color.fromRGBO(2, 10, 27, 1),
                                title: const Text(
                                  'Confirm Delete and Update Stock',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  'Are you sure you want to delete this sale and update the product stock? This action cannot be undone.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                  ),
                                  TextButton(
                                    child: const Text(
                                      'Delete and Update',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed == true) {
                            await DatabaseHelper.instance
                                .deleteSaleAndItems(sales.id!, true);
                            await _loadProducts();
                            _loadSales();
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'Delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'Delete and Update',
                          child: Text(
                            'Delete and Update Stock',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelectChanged: (selected) {
                  if (selected == true) {
                    _currentItemsPage = 1; // Reset items pagination
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

  Widget _buildItemsTable() {
    final startIndex = (_currentItemsPage - 1) * _itemsPerPage;
    final endIndex = min(startIndex + _itemsPerPage, _salesItems.length);
    final paginatedItems = _salesItems.sublist(startIndex, endIndex);
    return SizedBox(
      height: 180, // Adjust height to show three rows
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
                  label: Text('Gross Price',
                      style: TextStyle(color: Colors.white))),
              DataColumn(
                  label:
                      Text('Discount', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Total', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label:
                      Text('Refunded', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Refund', style: TextStyle(color: Colors.white))),
            ],
            rows: paginatedItems.map((item) {
              final refundedQuantity = _refundedQuantities[item.id] ?? 0;
              final remainingQuantity = item.quantity - refundedQuantity;
              final isFullyRefunded = remainingQuantity <= 0;

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
                  DataCell(Text('${item.total}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${item.discount}',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(Text('${item.total - item.discount}',
                      style: const TextStyle(color: Colors.white))),
                  // Add a cell to show how many items have been refunded already
                  DataCell(Text('$refundedQuantity',
                      style: const TextStyle(color: Colors.white))),
                  DataCell(
                    isFullyRefunded
                        ? const Text('Fully Refunded',
                            style: TextStyle(color: Colors.green))
                        : Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  style: const TextStyle(color: Colors.white),
                                  initialValue:
                                      '1', // Set default to 1 instead of max
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Qty (Max: $remainingQuantity)',
                                    labelStyle:
                                        const TextStyle(color: Colors.white54),
                                  ),
                                  validator: (value) {
                                    final enteredQty =
                                        double.tryParse(value ?? '') ?? 0;
                                    if (enteredQty <= 0 ||
                                        enteredQty > remainingQuantity) {
                                      return 'Max $remainingQuantity';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (value) {
                                    final refundQty =
                                        double.tryParse(value) ?? 0;
                                    if (refundQty > 0 &&
                                        refundQty <= remainingQuantity) {
                                      _handleRefund(item, refundQty);
                                    }
                                  },
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _handleRefund(item, remainingQuantity),
                                child: const Text('Refund All',
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

  Widget _buildItemsPagination() {
    final totalPages = (_salesItems.length / _itemsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: _currentItemsPage > 1
              ? () => setState(() => _currentItemsPage--)
              : null,
        ),
        Text(
          'Page $_currentItemsPage of $totalPages',
          style: const TextStyle(color: Colors.white),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white),
          onPressed: _currentItemsPage < totalPages
              ? () => setState(() => _currentItemsPage++)
              : null,
        ),
      ],
    );
  }
}
