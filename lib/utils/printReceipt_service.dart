import 'dart:async';
import 'dart:developer';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

class CustomPrinterService {
  static PrinterDevice? _printer;
  static final _printerManager = PrinterManager.instance;
  static bool _isPrinterAvailable = false;

  static Future<void> init() async {
    log('[CustomPrinterService] Initializing...');
    await scanForPrinters();
  }

  static Future<void> scanForPrinters() async {
    log('[CustomPrinterService] Scanning for printers...');
    _printerManager.discovery(type: PrinterType.usb).listen((printer) {
      log('Found printer: ${printer.name}');
      _printer = printer;
      _isPrinterAvailable = true;
    }).onError((error) {
      log('Error scanning for printers: $error');
      _isPrinterAvailable = false;
    });
  }

  static void setPrinter(PrinterDevice printer) {
    _printer = printer;
    _isPrinterAvailable = true;
    log('Printer set: ${printer.name}');
  }

  static Future<void> connectToPrinter() async {
    if (_isPrinterAvailable && _printer != null) {
      try {
        await _printerManager.connect(
          type: PrinterType.usb,
          model: UsbPrinterInput(
            name: _printer!.name,
            productId: _printer!.productId,
            vendorId: _printer!.vendorId,
          ),
        );
        log('Connected to printer: ${_printer!.name}');
      } catch (e) {
        log('Failed to connect to printer: $e');
      }
    } else {
      log('No printer available to connect.');
    }
  }

  static Future<void> printReceipt(String receiptText) async {
    if (_isPrinterAvailable && _printer != null) {
      List<int> bytes = [];
      final generator =
          Generator(PaperSize.mm58, await CapabilityProfile.load());
      bytes += generator.text(receiptText);
      bytes += generator.cut();

      try {
        await _printerManager.send(type: PrinterType.usb, bytes: bytes);
        log('Receipt printed successfully.');
      } catch (e) {
        log('Failed to print receipt: $e');
      }
    } else {
      log('Printer is not available.');
    }
  }
}
