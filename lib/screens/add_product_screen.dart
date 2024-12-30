import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paylink_pos/database/product_db_helper.dart';
import 'package:paylink_pos/models/product_model.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _productGroupController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

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
          expiryDate: DateTime.parse(_expiryController.text),
          productGroup: _productGroupController.text,
          quantity: int.parse(_quantityController.text),
          price: double.parse(_priceController.text),
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
          status: _status,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
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
                          'Enter Expiry date'),
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
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) => _validateNumber(value, label.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _productGroupController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
