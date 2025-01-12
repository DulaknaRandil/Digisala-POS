import 'package:digisala_pos/utils/printReceipt_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

class PrinterSelectionDialog extends StatefulWidget {
  final Function(PrinterDevice) onPrinterSelected;

  const PrinterSelectionDialog({
    Key? key,
    required this.onPrinterSelected,
  }) : super(key: key);

  @override
  State<PrinterSelectionDialog> createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  List<PrinterDevice> _printers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanPrinters();
  }

  Future<void> _scanPrinters() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final devices = await ThermalPrinterService.scanPrinters();

      setState(() {
        _printers = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to scan printers: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Printer'),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _scanPrinters,
          child: const Text('Rescan'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for printers...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_printers.isEmpty) {
      return const Center(
        child: Text('No printers found'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _printers.length,
      itemBuilder: (context, index) {
        final printer = _printers[index];
        return ListTile(
          leading: const Icon(Icons.print),
          title: Text(printer.name),
          subtitle: Text('ID: ${printer.vendorId}-${printer.productId}'),
          onTap: () {
            widget.onPrinterSelected(printer);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
