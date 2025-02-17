import 'dart:io';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _secondaryNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _productGroupController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _buyingPriceController = TextEditingController();
  final _discountController = TextEditingController();
  final _supplierController = TextEditingController();

  String _status = 'Active'; // Default value for status
  bool _isSaving = false; // For showing a loading indicator

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Please enter $fieldName';
    }
    try {
      if (fieldName == 'quantity') {
        int.parse(value);
      } else {
        double.parse(value);
      }
      return null;
    } catch (e) {
      return 'Please enter a valid $fieldName';
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        final product = Product(
          barcode: _barcodeController.text,
          name: _nameController.text,
          secondaryName: _secondaryNameController.text,
          expiryDate: DateTime.parse(_expiryController.text),
          productGroup: _productGroupController.text,
          quantity: double.parse(_quantityController.text),
          price: double.parse(_priceController.text),
          buyingPrice: double.parse(_buyingPriceController.text),
          discount: _discountController.text,
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
          status: _status,
          supplierId: int.parse(_supplierController.text),
        );

        final result = await DatabaseHelper.instance.insertProduct(product);

        if (result != -1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          throw Exception('Failed to insert product');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Imports product data from an Excel file.
  Future<void> _importProductsFromExcel() async {
    try {
      // Let the user pick an Excel file.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) {
        // User cancelled the picker.
        return;
      }
      // Read file bytes (supporting both web and mobile).
      final bytes = result.files.single.bytes ??
          await File(result.files.single.path!).readAsBytes();

      // Decode the Excel file.
      var excel = Excel.decodeBytes(bytes);
      // Get the first available sheet.
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];
      if (sheet == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No sheet found in Excel file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int count = 0;
      // Assuming the first row is a header.
      for (var row in sheet.rows.skip(1)) {
        try {
          // Adjust the index according to your Excel columns.
          // Expected order:
          // [barcode, name, secondaryName, expiryDate, productGroup, quantity, price, buyingPrice, discount, status, supplierId]
          final barcode = row[0]?.value?.toString() ?? '';
          final name = row[1]?.value?.toString() ?? '';
          final secondaryName = row[2]?.value?.toString() ?? '';
          final expiryStr = row[3]?.value?.toString() ?? '';
          final productGroup = row[4]?.value?.toString() ?? '';
          final quantityStr = row[5]?.value?.toString() ?? '0';
          final priceStr = row[6]?.value?.toString() ?? '0';
          final buyingPriceStr = row[7]?.value?.toString() ?? '0';
          final discount = row[8]?.value?.toString() ?? '';
          final status = row[9]?.value?.toString() ?? 'Active';
          final supplierIdStr = row[10]?.value?.toString() ?? '0';

          final expiryDate = DateTime.tryParse(expiryStr) ?? DateTime.now();
          final quantity = double.tryParse(quantityStr) ?? 0.0;
          final price = double.tryParse(priceStr) ?? 0.0;
          final buyingPrice = double.tryParse(buyingPriceStr) ?? 0.0;
          final supplierId = int.tryParse(supplierIdStr) ?? 0;

          final product = Product(
            barcode: barcode,
            name: name,
            secondaryName: secondaryName,
            expiryDate: expiryDate,
            productGroup: productGroup,
            quantity: quantity,
            price: price,
            buyingPrice: buyingPrice,
            discount: discount,
            createdDate: DateTime.now(),
            updatedDate: DateTime.now(),
            status: status,
            supplierId: supplierId,
          );

          await DatabaseHelper.instance.insertProduct(product);
          count++;
        } catch (e) {
          print('Error importing row: $e');
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $count products'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing products: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Exports all products from the database into an Excel file.
  Future<void> _exportProductsToExcel() async {
    try {
      final products = await DatabaseHelper.instance.getAllProducts();
      // Create a new Excel document.
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Products'];

      // Create a header row.
      List<dynamic> header = [
        'Barcode',
        'Name',
        'Secondary Name',
        'Expiry Date',
        'Product Group',
        'Quantity',
        'Price',
        'Buying Price',
        'Discount',
        'Status',
        'SupplierId'
      ];
      sheetObject.appendRow(header.cast<CellValue?>());

      // Append a row for each product.
      for (var product in products) {
        List<dynamic> row = [
          product.barcode,
          product.name,
          product.secondaryName,
          product.expiryDate?.toIso8601String(),
          product.productGroup,
          product.quantity,
          product.price,
          product.buyingPrice,
          product.discount,
          product.status,
          product.supplierId,
        ];
        sheetObject.appendRow(row.cast<CellValue?>());
      }

      // Save the Excel file.
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot access external storage'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final outputFile = File('${directory.path}/products_export.xlsx');
      await outputFile.writeAsBytes(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Products exported to ${outputFile.path}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting products: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _productGroupController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _buyingPriceController.dispose();
    _discountController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import from Excel',
            onPressed: _importProductsFromExcel,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: _exportProductsToExcel,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTextField(_barcodeController, 'Barcode',
                          'Enter product barcode'),
                      const SizedBox(height: 10),
                      _buildTextField(
                          _nameController, 'Item Name', 'Enter product name'),
                      const SizedBox(height: 10),
                      _buildTextField(_expiryController, 'Expiry date',
                          'Enter Expiry date (YYYY-MM-DD)'),
                      const SizedBox(height: 10),
                      _buildTextField(_productGroupController, 'Product Group',
                          'Enter product group'),
                      const SizedBox(height: 10),
                      _buildNumberField(
                          _quantityController, 'Quantity', 'Enter quantity'),
                      const SizedBox(height: 10),
                      _buildNumberField(
                          _priceController, 'Price', 'Enter product price'),
                      const SizedBox(height: 10),
                      _buildNumberField(_buyingPriceController, 'Buying Price',
                          'Enter buying price'),
                      const SizedBox(height: 10),
                      _buildTextField(
                          _discountController, 'Discount', 'Enter discount'),
                      const SizedBox(height: 10),
                      _buildTextField(_supplierController, 'Supplier ID',
                          'Enter supplier ID'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: ['Active', 'Inactive']
                            .map((status) => DropdownMenuItem(
                                value: status, child: Text(status)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _status = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saveProduct,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Save Product'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildNumberField(
      TextEditingController controller, String label, String hint) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) => _validateNumber(value, label.toLowerCase()),
    );
  }
}
