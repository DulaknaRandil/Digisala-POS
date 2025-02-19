import 'dart:convert';
import 'dart:io';
import 'package:digisala_pos/models/sales_model.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final FlutterThermalPrinter printerPlugin = FlutterThermalPrinter.instance;
  List<Printer> printers = [];
  Set<String> connectedPrinters = {};
  Printer? selectedPrinter;

  Future<void> startScan() async {
    try {
      await printerPlugin.getPrinters(connectionTypes: [
        ConnectionType.USB,
        ConnectionType.BLE,
        ConnectionType.NETWORK,
      ]);
    } catch (e) {
      print("Failed to start scanning: $e");
    }
  }

  Future<void> loadSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final printerName = prefs.getString('selectedPrinter');
    if (printerName != null && printers.isNotEmpty) {
      selectedPrinter = printers.firstWhere(
        (p) => p.name == printerName,
        orElse: () => printers.first,
      );
    }
  }

  List<int> getDrawerCommand() {
    // ESC/POS command for cash drawer: ESC p 0 25 250
    return [27, 112, 0, 25, 250];
  }

  Future<void> saveSelectedPrinter(Printer printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedPrinter', printer.name ?? '');
    selectedPrinter = printer;
  }

  Future<List<int>> generateTestReceipt() async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text(
        "Test Print",
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(2);
      bytes += generator.text('Print Test Successful!');
      bytes += getDrawerCommand();
      bytes += generator.feed(1);
      bytes += generator.cut();

      return bytes;
    } catch (e) {
      print("Failed to generate test receipt: $e");
      return [];
    }
  }

  Future<List<int>> generateReceipt(
    Map<String, dynamic> setupData,
    List<Map<String, dynamic>> items, {
    required Sales sales,
    required int salesId,
    required String cashierName,
    required double paidAmount,
    required double change,
    required String paymentMethod,
  }) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Print logo if available
      if (setupData['logoPath'] != null) {
        try {
          final file = File(setupData['logoPath']);
          if (await file.exists()) {
            final imageBytes = await file.readAsBytes();
            final image = img.decodeImage(imageBytes);
            if (image != null) {
              final resized = img.copyResize(image, width: 200);
              bytes += generator.image(resized);
            }
          }
        } catch (e) {
          print("Error processing logo: $e");
        }
      }

      // Store Information
      bytes += generator.text(
        setupData['storeName'] ?? 'STORE NAME',
        styles: const PosStyles(
          bold: true,
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        setupData['address'] ?? '',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'Tel: ${setupData['telephone'] ?? ''}',
        styles: const PosStyles(align: PosAlign.center),
      );

      // Additional Text after Telephone Number
      bytes += generator.text(
        setupData['invoiceText'] ?? 'RECEIPT SETUP TEST',
        styles: const PosStyles(
          underline: true,
          align: PosAlign.center,
        ),
      );

      bytes += generator.feed(1);

      // Receipt Information
      bytes += generator.text(
        'Sales No: $salesId',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      );
      bytes += generator.feed(1);

      // Date and Time
      final now = DateTime.now();
      bytes += generator.row([
        PosColumn(
          text: 'Date: ${now.toLocal().toString().split(' ')[0]}',
          width: 6,
        ),
        PosColumn(
          text:
              'Time: ${now.toLocal().toString().split(' ')[1].substring(0, 5)}',
          width: 6,
        ),
      ]);
      bytes += generator.feed(1);
      bytes += generator.text('Cashier: $cashierName');
      bytes += generator.feed(1);
      bytes += generator.hr();

      // Items
      for (final item in items) {
        double itemDiscount = item['discount'] ?? 0.0;
        bytes += generator.row([
          PosColumn(
            text: '${item['name']}',
            width: 6,
          ),
          PosColumn(
            text: '${item['quantity']}x',
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: '${item['price'].toStringAsFixed(2)} LKR',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);

        // Print item discount if applicable
        if (itemDiscount > 0) {
          bytes += generator.row([
            PosColumn(
              text: 'Discount:',
              width: 8,
              styles: const PosStyles(align: PosAlign.right),
            ),
            PosColumn(
              text: '-${itemDiscount.toStringAsFixed(2)} LKR',
              width: 4,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
        }
      }

      bytes += generator.hr();

      // Totals
      bytes += generator.row([
        PosColumn(text: 'Subtotal:', width: 6),
        PosColumn(
          text: '${sales.subtotal.toStringAsFixed(2)} LKR',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      if (sales.discount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Discount:', width: 6),
          PosColumn(
            text: '${sales.discount.toStringAsFixed(2)} LKR',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.row([
        PosColumn(
          text: 'TOTAL:',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: '${sales.total.toStringAsFixed(2)} LKR',
          width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      // Payment Details
      bytes += generator.feed(1);
      bytes += generator.row([
        PosColumn(text: 'Paid:', width: 6),
        PosColumn(
          text: '${paidAmount.toStringAsFixed(2)} LKR',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Change:', width: 6),
        PosColumn(
          text: '${change.toStringAsFixed(2)} LKR',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Payment Method:', width: 6),
        PosColumn(
          text: paymentMethod,
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Footer
      bytes += generator.text(
        setupData['footerText'] ?? 'Thank you for your business!',
        styles: const PosStyles(align: PosAlign.center),
      );

      // Additional Footer Text
      bytes += generator.text(
        'Software By Digisala - 078 74 51 715',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += getDrawerCommand();
      bytes += generator.feed(3);
      bytes += generator.cut();

      return bytes;
    } catch (e) {
      print("Failed to generate receipt: $e");
      return [];
    }
  }

  Future<List<int>> generateSetupReceipt(Map<String, dynamic> setupData) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Handle logo printing
      if (setupData['logoPath'] != null) {
        try {
          final file = File(setupData['logoPath']);
          if (await file.exists()) {
            final imageBytes = await file.readAsBytes();
            final image = img.decodeImage(imageBytes);
            if (image != null) {
              // Resize image if needed
              final resized = img.copyResize(image, width: 200);
              bytes += generator.image(resized);
            }
          }
        } catch (e) {
          print("Error processing logo: $e");
        }
      }

      // Store Information
      bytes += generator.text(setupData['storeName'] ?? 'STORE NAME',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));
      bytes += generator.feed(1);

      bytes += generator.text(setupData['address'] ?? 'ADDRESS',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Tel: ${setupData['telephone'] ?? 'TELEPHONE'}',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);

      bytes += generator.text(setupData['invoiceText'] ?? 'RECEIPT SETUP TEST',
          styles: const PosStyles(
            underline: true,
            align: PosAlign.center,
          ));
      bytes += generator.feed(1);

      // Date and Time
      final now = DateTime.now();
      bytes += generator.row([
        PosColumn(
            text: 'Date: ${now.toLocal().toString().split(' ')[0]}', width: 6),
        PosColumn(
            text:
                'Time: ${now.toLocal().toString().split(' ')[1].substring(0, 5)}',
            width: 6),
      ]);

      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Sample Items
      bytes += generator.text('SAMPLE ITEMS',
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.feed(1);

      bytes += generator.row([
        PosColumn(text: 'Item 1', width: 8),
        PosColumn(
            text: '1,000.00',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.feed(1);
      bytes += generator.hr();
      bytes += generator.feed(1);

      // Footer
      bytes += generator.text(
          setupData['footerText'] ?? 'Thank you come Again !',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.text('Setup Print Complete',
          styles: const PosStyles(align: PosAlign.center));
      bytes += getDrawerCommand();
      bytes += generator.feed(3);
      bytes += generator.cut();

      return bytes;
    } catch (e) {
      print("Failed to generate setup receipt: $e");
      return [];
    }
  }

  Future<void> saveReceiptSetup(Map<String, dynamic> setupData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/receipt_setup.json');
      await file.writeAsString(jsonEncode(setupData));
    } catch (e) {
      print("Failed to save receipt setup: $e");
    }
  }

  Future<Map<String, dynamic>> loadReceiptSetup() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/receipt_setup.json');
      if (await file.exists()) {
        return jsonDecode(await file.readAsString());
      }
    } catch (e) {
      print("Failed to load receipt setup: $e");
    }
    return {};
  }
}
