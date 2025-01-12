import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

class ThermalPrinterService {
  static PrinterDevice? _printer;
  static final _printerManager = PrinterManager.instance;
  static bool _isConnected = false;

  static PrinterDevice? get selectedPrinter => _printer;
  static bool get isConnected => _isConnected && _printer != null;

  static Future<void> initialize() async {
    try {
      await scanPrinters();
    } catch (e) {
      debugPrint('Printer initialization error: $e');
    }
  }

  static Future<void> connectPrinter(PrinterDevice printer) async {
    try {
      _printer = printer;
      await _printerManager.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: printer.name,
          productId: printer.productId,
          vendorId: printer.vendorId,
        ),
      );
      _isConnected = true;
    } catch (e) {
      debugPrint('Printer connection error: $e');
      _isConnected = false;
      rethrow;
    }
  }

  static Future<List<PrinterDevice>> scanPrinters() async {
    List<PrinterDevice> devices = [];
    try {
      var completer = Completer<List<PrinterDevice>>();

      var subscription =
          _printerManager.discovery(type: PrinterType.usb).listen(
        (device) {
          devices.add(device);
        },
        onDone: () {
          completer.complete(devices);
        },
        onError: (error) {
          completer.completeError(error);
        },
      );

      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(devices);
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('Error scanning printers: $e');
      return [];
    }
  }

  static Future<void> printReceipt({
    required String storeName,
    required String address,
    required String date,
    required String time,
    required String salesId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required String paymentMethod,
  }) async {
    if (!isConnected) {
      throw Exception('Printer not connected');
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        address,
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text('\n');

      // Receipt Details
      bytes += generator.text('Date: $date');
      bytes += generator.text('Time: $time');
      bytes += generator.text('Receipt #: $salesId');
      bytes += generator.hr();

      // Items
      for (var item in items) {
        bytes += generator.row([
          PosColumn(
            text: '${item['name']}',
            width: 6,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: '${item['quantity']}x',
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: '${item['price']} LKR',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
        bytes += generator.row([
          PosColumn(
            text: '',
            width: 8,
          ),
          PosColumn(
            text:
                '${(item['quantity'] * item['price']).toStringAsFixed(2)} LKR',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.hr();

      // Totals
      bytes += generator.row([
        PosColumn(
          text: 'Subtotal:',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: '${subtotal.toStringAsFixed(2)} LKR',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      if (discount > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Discount:',
            width: 6,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: '${discount.toStringAsFixed(2)} LKR',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.row([
        PosColumn(
          text: 'Total:',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: '${total.toStringAsFixed(2)} LKR',
          width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      // Payment Method
      bytes += generator.text('\nPayment Method: $paymentMethod',
          styles: const PosStyles(align: PosAlign.left));

      // Footer
      bytes += generator.text('\n');
      bytes += generator.text(
        'Thank you for your business!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.cut();

      // Send to printer
      await _printerManager.send(
        type: PrinterType.usb,
        bytes: Uint8List.fromList(bytes),
      );
    } catch (e) {
      debugPrint('Print error: $e');
      rethrow;
    }
  }
}
