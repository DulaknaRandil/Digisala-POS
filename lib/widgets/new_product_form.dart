import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paylink_pos/database/product_db_helper.dart';
import 'package:paylink_pos/models/group_model.dart';
import 'package:paylink_pos/models/product_model.dart';
import 'package:paylink_pos/widgets/product_add%20header.dart';
import 'package:paylink_pos/widgets/product_add_save_button.dart';

class ProductForm extends StatefulWidget {
  final Function(Map<String, dynamic>)? onSave;
  final VoidCallback? onClose;
  final String? initialName;
  final String? initialBarcode;
  final String? initialGroup;
  final String? initialQuantity;
  final String? initialPrice;
  final String? initialExpiry;
  final String? initialStatus;
  final FocusNode searchBarFocusNode;

  const ProductForm({
    Key? key,
    this.onSave,
    this.onClose,
    this.initialName,
    this.initialBarcode,
    this.initialGroup,
    this.initialQuantity,
    this.initialPrice,
    this.initialExpiry,
    this.initialStatus = 'Active',
    required this.searchBarFocusNode,
  }) : super(key: key);

  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _groupController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _expiryController;
  late String _status;
  List<Group> _groups = [];

  static const _inputBorderRadius = 55.0;
  static const _inputHeight = 43.0;
  static const _backgroundColor = Color(0xFF020A1B);
  static const _textColor = Colors.white;
  static const _borderColor = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _barcodeController = TextEditingController(text: widget.initialBarcode);
    _groupController = TextEditingController(text: widget.initialGroup);
    _quantityController = TextEditingController(text: widget.initialQuantity);
    _priceController = TextEditingController(text: widget.initialPrice);
    _expiryController = TextEditingController(text: widget.initialExpiry);
    _status = widget.initialStatus ?? 'Active';
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseHelper.instance.getAllGroups();
    setState(() {
      _groups = groups;
    });
  }

  Future<void> _addGroup() async {
    final TextEditingController groupNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Group'),
          content: TextField(
            controller: groupNameController,
            decoration: const InputDecoration(hintText: 'Enter group name'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final newGroup = Group(name: groupNameController.text);
                await DatabaseHelper.instance.insertGroup(newGroup);
                _loadGroups(); // Refresh the group list
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      Map<String, Object?> productData = {
        'name': _nameController.text,
        'barcode': _barcodeController.text,
        'productGroup': _groupController.text,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'expiryDate': _expiryController.text.isNotEmpty
            ? DateTime.parse(_expiryController.text).toIso8601String()
            : null,
        'status': _status,
      };

      final product = Product(
        name: productData['name'] as String,
        barcode: productData['barcode'] as String,
        expiryDate: productData['expiryDate'] != null
            ? DateTime.parse(productData['expiryDate'] as String)
            : null,
        productGroup: productData['productGroup'] as String,
        quantity: productData['quantity'] as int,
        price: productData['price'] as double,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
        status: productData['status'] as String,
      );

      final result = await DatabaseHelper.instance.insertProduct(product);

      if (!mounted) return;

      if (result != -1) {
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Header(
                title: 'New Products',
                onClose: _handleClose,
              ),
              const SizedBox(height: 24),
              _buildFormFields(),
              const SizedBox(height: 32),
              SaveButton(
                onPressed: _handleSave,
                width: double.infinity,
                height: 48,
                borderRadius: 8,
                text: 'Save',
                backgroundColor: _borderColor,
                textStyle: const TextStyle(
                  color: _backgroundColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildFormRow(
          leftField: _buildFieldColumn(
            'Name',
            _nameController,
            'Add item name here',
          ),
          rightField: _buildFieldColumn(
            'Barcode',
            _barcodeController,
            'Scan barcode',
          ),
        ),
        const SizedBox(height: 24),
        _buildFormRow(
          leftField: _buildGroupAutocomplete(),
          rightField: _buildFieldColumn(
            'Quantity',
            _quantityController,
            'Enter quantity',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(height: 24),
        _buildFormRow(
          leftField: _buildFieldColumn(
            'Price',
            _priceController,
            'Enter price',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
          rightField: _buildFieldColumn(
            'Expire',
            _expiryController,
            'Select expiry date',
            readOnly: true,
            onTap: _showDatePicker,
          ),
        ),
        const SizedBox(height: 24),
        _buildStatusField(),
      ],
    );
  }

  Widget _buildFormRow({
    required Widget leftField,
    required Widget rightField,
  }) {
    return Row(
      children: [
        Expanded(child: leftField),
        const SizedBox(width: 24),
        Expanded(child: rightField),
      ],
    );
  }

  Widget _buildFieldColumn(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        _buildInputField(
          controller: controller,
          hintText: hint,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
        ),
      ],
    );
  }

  Widget _buildGroupAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Group'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: _inputHeight,
                decoration: _getFieldDecoration(),
                child: Autocomplete<Group>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _groups; // Show all groups when input is empty
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
                      _groupController.text = selection.name;
                    });
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onEditingComplete) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w300,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type to search groups',
                        hintStyle: TextStyle(
                          color: _textColor.withOpacity(0.8),
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w300,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10),
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
                                title: Text(option.name,
                                    style: const TextStyle(
                                      color: _textColor,
                                      fontSize: 18,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w300,
                                    )),
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
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _addGroup,
              child: Image.network(
                'https://dashboard.codeparrot.ai/api/assets/Z3rqw4H_EXkqg65T',
                width: 38,
                height: 38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Status'),
        _buildInputField(
          controller: TextEditingController(text: _status),
          readOnly: true,
          onTap: _showStatusPicker,
          suffixIcon: const Icon(Icons.arrow_drop_down, color: _textColor),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _textColor,
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Container(
      height: _inputHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_inputBorderRadius),
        border: Border.all(
          color: _borderColor,
          width: 2,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        onTap: onTap,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _textColor,
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w300,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: _textColor.withOpacity(0.8),
            fontSize: 18,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w300,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _borderColor,
              surface: _backgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _expiryController.text = date.toString().split(' ')[0];
      });
    }
  }

  void _showStatusPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _backgroundColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Active', 'Inactive']
              .map(
                (status) => ListTile(
                  title: Text(
                    status,
                    style: const TextStyle(color: _textColor),
                  ),
                  onTap: () {
                    setState(() => _status = status);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _handleClose() {
    widget.onClose?.call();
    widget.searchBarFocusNode.requestFocus();
  }

  BoxDecoration _getFieldDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(_inputBorderRadius),
      border: Border.all(
        color: _borderColor,
        width: 2,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _groupController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _expiryController.dispose();
    super.dispose();
  }
}
