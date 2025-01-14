import 'dart:async';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';

class PrinterSettingsDialog extends StatefulWidget {
  const PrinterSettingsDialog({Key? key}) : super(key: key);

  @override
  _PrinterSettingsDialogState createState() => _PrinterSettingsDialogState();
}

class _PrinterSettingsDialogState extends State<PrinterSettingsDialog> {
  final PrinterService _printerService = PrinterService();
  StreamSubscription<List<Printer>>? _devicesStreamSubscription;
  bool isLoading = false;
  final TextEditingController _portController =
      TextEditingController(text: '9100');

  @override
  void initState() {
    super.initState();
    _startScanning();
    _loadConnectedPrinters();
  }

  @override
  void dispose() {
    _devicesStreamSubscription?.cancel();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadConnectedPrinters() async {
    await _printerService.loadSelectedPrinter();
    setState(() {});
  }

  Future<void> _startScanning() async {
    setState(() {
      isLoading = true;
    });

    _devicesStreamSubscription?.cancel();
    _devicesStreamSubscription =
        _printerService.printerPlugin.devicesStream.listen(
      (List<Printer> devices) {
        setState(() {
          _printerService.printers = devices;
          _printerService.printers.removeWhere(
              (element) => element.name == null || element.name!.isEmpty);
        });
      },
      onError: (error) {
        _showSnackBar('Failed to scan for printers: $error');
      },
    );

    try {
      await _printerService.startScan();
    } catch (e) {
      _showSnackBar('Failed to start scanning: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _connectPrinter(Printer printer) async {
    try {
      await _printerService.printerPlugin.connect(printer);
      await _printerService.saveSelectedPrinter(printer);
      setState(() {
        _printerService.connectedPrinters.add(printer.name ?? '');
      });
      _showSnackBar('Connected to ${printer.name}');
    } catch (e) {
      _showSnackBar('Failed to connect to ${printer.name}: $e');
    }
  }

  Future<void> _printTest(Printer printer) async {
    if (_printerService.connectedPrinters.contains(printer.name ?? '')) {
      try {
        final bytes = await _printerService.generateTestReceipt();
        await _printerService.printerPlugin.printData(printer, bytes);
        _showSnackBar('Test print successful on ${printer.name}');
      } catch (e) {
        _showSnackBar('Failed to print on ${printer.name}: $e');
      }
    } else {
      _showSnackBar('Printer ${printer.name} is not connected');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Printer Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Available Printers:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : _printerService.printers.isEmpty
                    ? const Center(child: Text('No printers found'))
                    : SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: _printerService.printers.length,
                          itemBuilder: (context, index) {
                            final printer = _printerService.printers[index];
                            final isConnected =
                                _printerService.selectedPrinter?.name ==
                                    printer.name;
                            return ListTile(
                              title: Text(printer.name ?? 'Unknown Printer'),
                              subtitle:
                                  Text('Connection: ${printer.connectionType}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _connectPrinter(printer),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isConnected ? Colors.green : null,
                                    ),
                                    child: Text(
                                        isConnected ? 'Connected' : 'Connect'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: isConnected
                                        ? () => _printTest(printer)
                                        : null,
                                    child: const Text('Print Test'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _startScanning,
                  child: const Text('Refresh'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
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
