import 'dart:io';
import 'dart:typed_data';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:digisala_pos/models/product_model.dart';

class PdfService {
  static Future<Uint8List> generateStockReport({
    required List<Product> products,
    required int lowStock,
    required int mediumStock,
    required int highStock,
  }) async {
    final pdf = pw.Document();
    final digisalaLogo = await _loadDigisalaLogo();
    final currentYear = DateTime.now().year;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final PrinterService _printerService = PrinterService();
    // Load receipt setup data
    final receiptSetup = await _printerService.loadReceiptSetup();
    final storeName = receiptSetup['storeName'] ?? 'Store Name';
    final telephone = receiptSetup['telephone'] ?? 'N/A';
    final address = receiptSetup['address'] ?? '';
    final logoPath = receiptSetup['logoPath'];
    Uint8List? logoBytes;
    // Load logo images

    if (logoPath != null && await File(logoPath).exists()) {
      final logobytes = await File(logoPath).readAsBytes();
      logoBytes = logobytes;
    }

    // Pagination setup
    final itemsPerPage = 20;
    final totalPages = (products.length / itemsPerPage).ceil();

    for (var pageNum = 0; pageNum < totalPages; pageNum++) {
      final startIndex = pageNum * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage < products.length)
          ? startIndex + itemsPerPage
          : products.length;
      final pageItems = products.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeader(logoBytes, storeName, telephone, address, date),
                pw.SizedBox(height: 20),
                pw.Text('Stock Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.SizedBox(height: 10),

                // Stock Summary
                if (pageNum == 0)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Stock Levels:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Low Stock: $lowStock',
                              style: pw.TextStyle(color: PdfColors.red)),
                          pw.Text('Medium Stock: $mediumStock',
                              style: pw.TextStyle(color: PdfColors.orange)),
                          pw.Text('High Stock: $highStock',
                              style: pw.TextStyle(color: PdfColors.green)),
                        ],
                      ),
                      pw.SizedBox(height: 20),
                    ],
                  ),

                // Products Table
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(3),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      // Table header
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          'ID',
                          'Product Name',
                          'Quantity',
                          'Category',
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
                      ...pageItems.map((product) => pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(product.id.toString()),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(product.name),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(product.quantity.toString(),
                                    style: _getStockStyle(
                                        product.quantity.toInt())),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(product.productGroup),
                              ),
                            ],
                          )),
                    ],
                  ),
                ),

                // Footer
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 20),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (digisalaLogo != null)
                        pw.Container(
                          height: 30,
                          child: pw.Image(digisalaLogo),
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
                if (totalPages > 1)
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    margin: const pw.EdgeInsets.only(top: 10),
                    child: pw.Text(
                      'Page ${pageNum + 1} of $totalPages',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    // Add summary page if multiple pages
    if (totalPages > 1) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                _buildHeader(logoBytes, storeName, telephone, address, date),
                pw.SizedBox(height: 40),
                pw.Text('Stock Summary',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryCard('Total Products', products.length),
                    _buildSummaryCard('Low Stock', lowStock),
                    _buildSummaryCard('Medium Stock', mediumStock),
                    _buildSummaryCard('High Stock', highStock),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildHeader(Uint8List? logoBytes, String storeName,
      String telephone, String address, String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logoBytes != null)
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Image(pw.MemoryImage(logoBytes)),
          )
        else
          pw.Container(width: 80, height: 80),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(storeName,
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: $date', style: pw.TextStyle(fontSize: 12)),
            pw.Text('Tel: $telephone', style: pw.TextStyle(fontSize: 12)),
            if (address.isNotEmpty)
              pw.Text('Address: $address', style: pw.TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryCard(String title, int count) {
    return pw.Container(
      width: 120,
      height: 100,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 8),
          pw.Text(count.toString(),
              style:
                  pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.TextStyle _getStockStyle(int quantity) {
    if (quantity <= 10) return pw.TextStyle(color: PdfColors.red);
    if (quantity <= 25) return pw.TextStyle(color: PdfColors.orange);
    return pw.TextStyle(color: PdfColors.green);
  }

  static Future<pw.MemoryImage?> _loadDigisalaLogo() async {
    try {
      final logo = await rootBundle.load('assets/logo.png');
      return pw.MemoryImage(logo.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }

  static Future<void> sharePdf(Uint8List pdfData, String fileName) async {
    await Printing.sharePdf(bytes: pdfData, filename: fileName);
  }

  static Future<void> printDocument(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
  }
}
