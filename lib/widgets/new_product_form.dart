import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paylink_pos/database/product_db_helper.dart';
import 'package:paylink_pos/database/group_db_helper.dart';
import 'package:intl/intl.dart';
import 'package:paylink_pos/models/product_model.dart';
import 'package:paylink_pos/models/group_model.dart';

class NewProductForm extends StatefulWidget {
  final Function(Map<String, dynamic>)? onSave;
  final VoidCallback? onClose;

  const NewProductForm({
    super.key,
    this.onSave,
    this.onClose,
  });

  @override
  State<NewProductForm> createState() => _NewProductFormState();
}

class _NewProductFormState extends State<NewProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  DateTime? _selectedExpiryDate;
  String _status = 'Active';
  List<Group> _groups = [];
  String? _selectedGroup;

  static const _inputHeight = 45.0;
  static const _borderRadius = 55.0;
  static const _fontSize = 18.0;
  static const _primaryColor = Color(0xFFF1F5F9);
  static const _backgroundColor = Color(0xFF020A1B);

  static const _textStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: _fontSize,
    fontWeight: FontWeight.w700,
    color: _primaryColor,
  );

  static const _labelStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: _fontSize,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static final _inputFields = {
    'name': InputFieldConfig(
      label: 'Name',
      hint: 'Type your name here',
    ),
    'barcode': InputFieldConfig(
      label: 'Barcode',
      hint: 'Scan your barcode',
    ),
    'quantity': InputFieldConfig(
      label: 'Quantity',
      hint: 'Add your quantity',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    ),
    'price': InputFieldConfig(
      label: 'Price',
      hint: 'Add your Price',
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    _controllers = Map.fromEntries(_inputFields.keys
        .map((field) => MapEntry(field, TextEditingController())));
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseHelper.instance.getAllGroups();
    setState(() {
      _groups = groups;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _primaryColor,
              surface: _backgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedExpiryDate = picked;
      });
    }
  }

  String? _validateField(String? value, String fieldName) {
    if (value?.isEmpty ?? true) {
      return 'Please enter $fieldName';
    }
    if (fieldName == 'quantity' || fieldName == 'price') {
      final isNumeric = double.tryParse(value!) != null;
      if (!isNumeric) {
        return 'Please enter a valid $fieldName';
      }
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final productData = Map.fromEntries(
        _controllers.entries.map((e) => MapEntry(e.key, e.value.text)),
      )..addAll({
          'status': _status,
          'expiryDate': _selectedExpiryDate?.toIso8601String() ?? '',
          'productGroup': _selectedGroup ?? '',
        });

      final product = Product(
        name: productData['name']!,
        barcode: productData['barcode']!,
        expiryDate: _selectedExpiryDate ?? DateTime.now(),
        productGroup: productData['productGroup']!,
        quantity: int.parse(productData['quantity']!),
        price: double.parse(productData['price']!),
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
        status: _status,
      );

      final result = await DatabaseHelper.instance.insertProduct(product);

      if (!mounted) return;

      if (result != -1) {
        Navigator.pop(context); // Close dialog before showing success message
        _showMessage('Product saved successfully!', isError: false);
        widget.onSave?.call(productData);
      } else {
        throw Exception('Failed to insert product');
      }
    } catch (e) {
      _showMessage('Error saving product: ${e.toString()}', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildInputField(String fieldName, InputFieldConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(config.label, style: _labelStyle),
        const SizedBox(height: 8),
        Container(
          height: _inputHeight,
          decoration: _getFieldDecoration(),
          child: TextFormField(
            controller: _controllers[fieldName],
            keyboardType: config.keyboardType,
            inputFormatters: config.inputFormatters,
            textAlign: TextAlign.center,
            style: _textStyle,
            decoration: InputDecoration(
              hintText: config.hint,
              hintStyle: _textStyle,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            validator: (value) => _validateField(value, config.label),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildExpiryDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Expiry Date (Optional)', style: _labelStyle),
        const SizedBox(height: 8),
        Container(
          height: _inputHeight,
          decoration: _getFieldDecoration(),
          child: InkWell(
            onTap: () => _selectDate(context),
            child: Center(
              child: Text(
                _selectedExpiryDate != null
                    ? DateFormat('MMM dd, yyyy').format(_selectedExpiryDate!)
                    : 'Select expiry date',
                style: _textStyle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGroupAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Group', style: _labelStyle),
        const SizedBox(height: 8),
        Container(
          height: _inputHeight,
          decoration: _getFieldDecoration(),
          child: Autocomplete<Group>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<Group>.empty();
              }
              return _groups.where((Group group) {
                return group.name
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase());
              });
            },
            displayStringForOption: (Group group) => group.name,
            onSelected: (Group selection) {
              setState(() {
                _selectedGroup = selection.name;
              });
            },
            fieldViewBuilder:
                (context, controller, focusNode, onEditingComplete) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: _textStyle,
                decoration: InputDecoration(
                  hintText: 'Type to search groups',
                  hintStyle: _textStyle,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  border: InputBorder.none,
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: _backgroundColor,
                  elevation: 4.0,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.25,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Group option = options.elementAt(index);
                        return ListTile(
                          title: Text(option.name, style: _textStyle),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status', style: _labelStyle),
        const SizedBox(height: 8),
        Container(
          height: _inputHeight,
          decoration: _getFieldDecoration(),
          child: Center(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _status,
                dropdownColor: _backgroundColor,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: _primaryColor),
                style: _textStyle,
                items: ['Active', 'Inactive'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Center(child: Text(value)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _status = newValue;
                    });
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  BoxDecoration _getFieldDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(_borderRadius),
      border: Border.all(
        color: _primaryColor,
        width: 2,
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'New Product',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Color(0xFF949391),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onClose,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextButton(
        onPressed: _handleSave,
        child: const Text(
          'Save',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: _fontSize,
            fontWeight: FontWeight.w700,
            color: Color(0xFF313131),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width *
              0.3, // Adjusted width for responsiveness
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._inputFields.entries.map(
                        (entry) => _buildInputField(entry.key, entry.value)),
                    _buildGroupAutocomplete(),
                    _buildExpiryDateField(),
                    _buildStatusField(),
                    const SizedBox(height: 20),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class InputFieldConfig {
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const InputFieldConfig({
    required this.label,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
  });
}
