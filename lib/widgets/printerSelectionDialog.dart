import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

class PrinterSelectionDialog extends StatefulWidget {
  final Function(PrinterDevice) onPrinterSelected;

  const PrinterSelectionDialog({Key? key, required this.onPrinterSelected})
      : super(key: key);

  @override
  _PrinterSelectionDialogState createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  List<PrinterDevice> _printers = [];
  final _printerManager = PrinterManager.instance;

  @override
  void initState() {
    super.initState();
    _scanForPrinters();
  }

  Future<void> _scanForPrinters() async {
    log('[PrinterSelectionDialog] Scanning for printers...');
    _printerManager.discovery(type: PrinterType.usb).listen((printer) {
      setState(() {
        _printers.add(printer);
      });
    }).onError((error) {
      log('Error scanning for printers: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Printer'),
      content: _printers.isEmpty
          ? CircularProgressIndicator()
          : SizedBox(
              height: 300, // Set a fixed height
              width:
                  double.maxFinite, // Allow the width to be as wide as possible
              child: ListView.builder(
                shrinkWrap: true, // Use shrinkWrap to wrap content
                itemCount: _printers.length,
                itemBuilder: (context, index) {
                  final printer = _printers[index];
                  return ListTile(
                    title: Text(printer.name),
                    onTap: () {
                      widget.onPrinterSelected(printer);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
