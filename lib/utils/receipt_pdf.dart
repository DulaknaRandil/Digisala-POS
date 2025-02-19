import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';

class ThermalPrinterDialog extends StatefulWidget {
  const ThermalPrinterDialog({Key? key}) : super(key: key);

  @override
  _ThermalPrinterDialogState createState() => _ThermalPrinterDialogState();
}

class _ThermalPrinterDialogState extends State<ThermalPrinterDialog> {
  final _flutterThermalPrinterPlugin = FlutterThermalPrinter.instance;
  String _ip = '192.168.0.100';
  String _port = '9100';
  List<Printer> printers = [];
  StreamSubscription<List<Printer>>? _devicesStreamSubscription;

  @override
  void initState() {
    super.initState();
    startScan();
  }

  // Start scanning for available printers
  void startScan() async {
    _devicesStreamSubscription?.cancel();
    await _flutterThermalPrinterPlugin.getPrinters(connectionTypes: [
      ConnectionType.USB,
    ]);
    _devicesStreamSubscription = _flutterThermalPrinterPlugin.devicesStream
        .listen((List<Printer> event) {
      setState(() {
        printers = event;
        printers.removeWhere(
            (element) => element.name == null || element.name == '');
      });
    });
  }

  // Stop scanning for printers
  void stopScan() {
    _flutterThermalPrinterPlugin.stopScan();
  }

  // Generate a sample receipt
  Future<List<int>> _generateReceipt() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes += generator.text(
      "Teste Network print",
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.cut();
    return bytes;
  }

  @override
  void dispose() {
    _devicesStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Network Settings Section
            const Text('NETWORK'),
            TextField(
              controller: TextEditingController(text: _ip),
              decoration: const InputDecoration(labelText: 'Enter IP Address'),
              onChanged: (value) {
                _ip = value;
              },
            ),
            TextField(
              controller: TextEditingController(text: _port),
              decoration: const InputDecoration(labelText: 'Enter Port'),
              onChanged: (value) {
                _port = value;
              },
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final service = FlutterThermalPrinterNetwork(_ip,
                        port: int.parse(_port));
                    await service.connect();
                    final bytes = await _generateReceipt();
                    await service.printTicket(bytes);
                    await service.disconnect();
                  },
                  child: const Text('Test Network Printer'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final service = FlutterThermalPrinterNetwork(_ip,
                        port: int.parse(_port));
                    await service.connect();
                    final bytes = await _generateReceipt();
                    await service.printTicket(bytes);
                    await service.disconnect();
                  },
                  child: const Text('Test Network Printer Widget'),
                ),
              ],
            ),

            const Divider(),

            // USB/Bluetooth Printers Section
            const Text('USB/BLE Printers'),
            Row(
              children: [
                ElevatedButton(
                  onPressed: startScan,
                  child: const Text('Get Printers'),
                ),
                ElevatedButton(
                  onPressed: stopScan,
                  child: const Text('Stop Scan'),
                ),
              ],
            ),

            // Printer List
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: printers.length,
                itemBuilder: (context, index) {
                  return ListTile(
                      title: Text(printers[index].name ?? 'No Name'),
                      subtitle:
                          Text("Connected: ${printers[index].isConnected}"),
                      onTap: () async {
                        if (printers[index].isConnected ?? false) {
                          await _flutterThermalPrinterPlugin
                              .disconnect(printers[index]);
                        } else {
                          await _flutterThermalPrinterPlugin
                              .connect(printers[index]);
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.print),
                        onPressed: () async {
                          if (printers[index].connectionType ==
                              ConnectionType.USB) {
                            // For USB printers, check if the printer is connected
                            if (printers[index].isConnected ?? false) {
                              // Generate receipt bytes for printing
                              final bytes = await _generateReceipt();
                              // Print the receipt bytes to the USB printer
                              await _flutterThermalPrinterPlugin.printData(
                                  printers[index], bytes);
                            } else {
                              // If not connected, connect to the printer and print
                              await _flutterThermalPrinterPlugin
                                  .connect(printers[index]);
                              final bytes = await _generateReceipt();
                              await _flutterThermalPrinterPlugin.printData(
                                  printers[index], bytes);
                              await _flutterThermalPrinterPlugin
                                  .disconnect(printers[index]);
                            }
                          } else {
                            // Handle Network or other types of printers
                            final service = FlutterThermalPrinterNetwork(_ip,
                                port: int.parse(_port));
                            await service.connect();
                            final bytes = await _generateReceipt();
                            await service.printTicket(bytes);
                            await service.disconnect();
                          }
                        },
                      ));
                },
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  // A widget that represents the receipt content
  Widget _generateReceiptWidget() {
    return SizedBox(
      width: 380,
      child: Material(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                  child: Text('FLUTTER THERMAL PRINTER',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold))),
              const Divider(thickness: 2),
              const SizedBox(height: 10),
              _buildReceiptRow('Item', 'Price'),
              const Divider(),
              _buildReceiptRow('Apple', '\$1.00'),
              _buildReceiptRow('Banana', '\$0.50'),
              _buildReceiptRow('Orange', '\$0.75'),
              const Divider(thickness: 2),
              _buildReceiptRow('Total', '\$2.25', isBold: true),
              const SizedBox(height: 20),
              const Center(
                  child: Text('Thank you for your purchase!',
                      style: TextStyle(
                          fontSize: 16, fontStyle: FontStyle.italic))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String leftText, String rightText,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(leftText,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(rightText,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
