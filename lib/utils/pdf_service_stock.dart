import 'dart:typed_data';
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

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Stock Report', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text('Low Stock: $lowStock'),
              pw.Text('Medium Stock: $mediumStock'),
              pw.Text('High Stock: $highStock'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['ID', 'Name', 'Quantity', 'Group'],
                data: products.map((product) {
                  return [
                    product.id.toString(),
                    product.name,
                    product.quantity.toString(),
                    product.productGroup,
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> sharePdf(Uint8List pdfData, String fileName) async {
    await Printing.sharePdf(bytes: pdfData, filename: fileName);
  }

  static Future<void> printDocument(Uint8List pdfData) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
  }
}
