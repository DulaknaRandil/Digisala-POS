import 'dart:io';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ReceiptSetupDialog extends StatefulWidget {
  const ReceiptSetupDialog({Key? key}) : super(key: key);

  @override
  _ReceiptSetupDialogState createState() => _ReceiptSetupDialogState();
}

class _ReceiptSetupDialogState extends State<ReceiptSetupDialog> {
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _invoiceTextController = TextEditingController();
  final TextEditingController _footerTextController = TextEditingController();
  String? logoPath;
  bool isLoading = true;
  final PrinterService _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressController.dispose();
    _telephoneController.dispose();
    _invoiceTextController.dispose();
    _footerTextController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    try {
      setState(() => isLoading = true);
      final savedSettings = await _printerService.loadReceiptSetup();

      if (savedSettings.isNotEmpty) {
        setState(() {
          _storeNameController.text = savedSettings['storeName'] ?? '';
          _addressController.text = savedSettings['address'] ?? '';
          _telephoneController.text = savedSettings['telephone'] ?? '';
          _invoiceTextController.text = savedSettings['invoiceText'] ?? '';
          _footerTextController.text = savedSettings['footerText'] ?? '';
          logoPath = savedSettings['logoPath'];
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load saved settings: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowCompression: true,
        compressionQuality:
            0, // Disable compression to avoid temp file creation issues
        allowMultiple: true,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'store_logo${DateTime.now().millisecondsSinceEpoch}.png';
        final savedImage = await file.copy('${appDir.path}/$fileName');

        setState(() {
          logoPath = savedImage.path;
        });
        _showSnackBar('Logo selected successfully');
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final setupData = {
        'logoPath': logoPath,
        'storeName': _storeNameController.text,
        'address': _addressController.text,
        'telephone': _telephoneController.text,
        'invoiceText': _invoiceTextController.text,
        'footerText': _footerTextController.text,
      };

      await _printerService.saveReceiptSetup(setupData);
      _showSnackBar('Settings saved successfully');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to save settings: $e');
    }
  }

  Future<void> _printSetupReceipt() async {
    try {
      if (_printerService.selectedPrinter == null) {
        _showSnackBar('Please select a printer first in Printer Settings');
        return;
      }

      final setupData = {
        'logoPath': logoPath,
        'storeName': _storeNameController.text,
        'address': _addressController.text,
        'telephone': _telephoneController.text,
        'invoiceText': _invoiceTextController.text,
        'footerText': _footerTextController.text,
      };

      // Save current settings before printing
      await _printerService.saveReceiptSetup(setupData);

      // Generate and print receipt
      final bytes = await _printerService.generateSetupReceipt(setupData);
      if (bytes.isEmpty) {
        _showSnackBar('Failed to generate receipt');
        return;
      }

      await _printerService.printerPlugin
          .printData(_printerService.selectedPrinter!, bytes);
      _showSnackBar('Setup receipt printed successfully');
    } catch (e) {
      _showSnackBar('Failed to print setup receipt: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Receipt Setup',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Logo Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Store Logo',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.image),
                              label: const Text('Set Logo'),
                            ),
                            if (logoPath != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    setState(() => logoPath = null),
                                color: Colors.red,
                              ),
                            ],
                          ],
                        ),
                        if (logoPath != null) ...[
                          const SizedBox(height: 8),
                          Text('Logo selected: ${logoPath!.split('/').last}'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Store Information Fields
                    TextField(
                      controller: _storeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Store Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telephoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telephone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _invoiceTextController,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Text',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _footerTextController,
                      decoration: const InputDecoration(
                        labelText: 'Footer Text',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Settings'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _printSetupReceipt,
                          icon: const Icon(Icons.print),
                          label: const Text('Print Test'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
