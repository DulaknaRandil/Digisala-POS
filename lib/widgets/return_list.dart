import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:digisala_pos/models/return_model.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:digisala_pos/utils/printer_service.dart';

class ReturnListDialog extends StatefulWidget {
  final FocusNode searchBarFocusNode;
  const ReturnListDialog({Key? key, required this.searchBarFocusNode})
      : super(key: key);

  @override
  _ReturnListDialogState createState() => _ReturnListDialogState();
}

class _ReturnListDialogState extends State<ReturnListDialog> {
  DateTimeRange? _selectedDateRange;
  List<Return> _returnList = [];
  final PrinterService _printerService = PrinterService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  Future<void> _loadReturns() async {
    final returns = await DatabaseHelper.instance.getAllReturns(
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
      searchQuery: _searchQuery,
    );
    setState(() => _returnList = returns);
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _loadReturns();
    }
  }

  Future<Uint8List> _generatePdfContent() async {
    final pdf = pw.Document();
    final receiptSetup = await _printerService.loadReceiptSetup();
    final storeName = receiptSetup['storeName'] ?? 'Store Name';
    final telephone = receiptSetup['telephone'] ?? 'N/A';
    final address = receiptSetup['address'] ?? '';
    final logoPath = receiptSetup['logoPath'];

    pw.MemoryImage? logoImage;
    if (logoPath != null && await File(logoPath).exists()) {
      logoImage = pw.MemoryImage(await File(logoPath).readAsBytes());
    }

    final currentYear = DateTime.now().year;
    final date = DateTime.now().toIso8601String().substring(0, 10);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 80,
                      height: 80,
                      child: pw.Image(logoImage),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(storeName,
                          style: pw.TextStyle(
                              fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: $date', style: pw.TextStyle(fontSize: 12)),
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
              pw.Text('Returns Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(1),
                  6: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      'Date',
                      'Time',
                      'Product',
                      'Product ID',
                      'Supplier',
                      'Quantity',
                      'Stock Updated',
                    ]
                        .map((text) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(text,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ..._returnList.map((item) {
                    final dateTime = DateTime.parse(item.returnDate);
                    return pw.TableRow(
                      children: [
                        pw.Text(DateFormat('yyyy-MM-dd').format(dateTime)),
                        pw.Text(DateFormat('HH:mm:ss').format(dateTime)),
                        pw.Text(item.name),
                        pw.Text(item.productId.toString()),
                        pw.Text(item.supplierName),
                        pw.Text(item.quantity.toString()),
                        pw.Text(item.stockUpdated ? 'Yes' : 'No',
                            style: pw.TextStyle(
                                color: item.stockUpdated
                                    ? PdfColors.green
                                    : PdfColors.red)),
                      ]
                          .map((w) => pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: w,
                              ))
                          .toList(),
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Return Summary',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Total Returns: ${_returnList.length}'),
                    pw.Text(
                        'Total Quantity Refunded: ${_returnList.fold(0.0, (sum, item) => sum + item.quantity)}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('© $currentYear Digisala POS. All rights reserved',
                      style:
                          pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _generatePdf() async {
    final bytes = await _generatePdfContent();
    await Printing.sharePdf(bytes: bytes, filename: 'returns_report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
                  'Return List',
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
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.searchBarFocusNode.requestFocus();
                      },
                    ),
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
                      setState(() => _searchQuery = value);
                      _loadReturns();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by Product, ID, or Supplier',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: _loadReturns,
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today, color: Colors.white),
                  label: const Text('Select Date Range',
                      style: TextStyle(color: Colors.white)),
                  onPressed: _selectDateRange,
                ),
                if (_selectedDateRange != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedDateRange = null);
                      _loadReturns();
                    },
                    child: const Text('Clear Filter',
                        style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _returnList.isEmpty
                  ? const Center(
                      child: Text('No returns found',
                          style: TextStyle(color: Colors.white)))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                            const Color.fromARGB(56, 131, 131, 128)),
                        columns: const [
                          DataColumn(
                              label: Text('Date',
                                  style: TextStyle(color: Colors.white))),
                          DataColumn(
                              label: Text('Time',
                                  style: TextStyle(color: Colors.white))),
                          DataColumn(
                              label: Text('Product',
                                  style: TextStyle(color: Colors.white))),
                          DataColumn(
                              label: Text('Product ID',
                                  style: TextStyle(color: Colors.white))),
                          DataColumn(
                              label: Text('Supplier',
                                  style: TextStyle(color: Colors.white))),
                          DataColumn(
                              label: Text('Quantity',
                                  style: TextStyle(color: Colors.white))),
                          DataColumn(
                              label: Text('Stock Updated',
                                  style: TextStyle(color: Colors.white))),
                        ],
                        rows: _returnList.map((item) {
                          final dateTime = DateTime.parse(item.returnDate);
                          return DataRow(
                            cells: [
                              DataCell(Text(
                                  DateFormat('yyyy-MM-dd').format(dateTime),
                                  style: const TextStyle(color: Colors.white))),
                              DataCell(Text(
                                  DateFormat('HH:mm:ss').format(dateTime),
                                  style: const TextStyle(color: Colors.white))),
                              DataCell(Text(item.name,
                                  style: const TextStyle(color: Colors.white))),
                              DataCell(Text(item.productId.toString(),
                                  style: const TextStyle(color: Colors.white))),
                              DataCell(Text(item.supplierName,
                                  style: const TextStyle(color: Colors.white))),
                              DataCell(Text(item.quantity.toString(),
                                  style: const TextStyle(color: Colors.white))),
                              DataCell(Text(
                                item.stockUpdated ? 'Yes' : 'No',
                                style: TextStyle(
                                  color: item.stockUpdated
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const Divider(color: Colors.white),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Returns: ${_returnList.length}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'Total Quantity: ${_returnList.fold(0.0, (sum, item) => sum + item.quantity)}',
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
    );
  }
}
