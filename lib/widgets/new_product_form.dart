import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/group_model.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/widgets/product_add%20header.dart';
import 'package:digisala_pos/widgets/product_add_save_button.dart';

class ProductForm extends StatefulWidget {
  final Function(Map<String, dynamic>)? onSave;
  final VoidCallback? onClose;
  final String? initialName;
  final String? intialSecondaryName;
  final String? initialBarcode;
  final String? initialGroup;
  final String? initialQuantity;
  final String? initialPrice;
  final String? initialBuyingPrice;
  final String? initialdiscount;
  final String? initialExpiry;
  final String? initialStatus;
  final FocusNode searchBarFocusNode;

  const ProductForm({
    Key? key,
    this.onSave,
    this.onClose,
    this.initialName,
    this.intialSecondaryName,
    this.initialBarcode,
    this.initialGroup,
    this.initialQuantity,
    this.initialPrice,
    this.initialBuyingPrice,
    this.initialdiscount,
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
  late final TextEditingController _secondaryNameController;
  late final TextEditingController _convertedNameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _groupController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _buyingPriceController;
  late final TextEditingController _expiryController;
  late final TextEditingController _discountController;
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
    _secondaryNameController =
        TextEditingController(text: widget.intialSecondaryName);
    _convertedNameController = TextEditingController();
    _barcodeController = TextEditingController(text: widget.initialBarcode);
    _groupController = TextEditingController(text: widget.initialGroup);
    _quantityController = TextEditingController(text: widget.initialQuantity);
    _priceController = TextEditingController(text: widget.initialPrice);
    _buyingPriceController =
        TextEditingController(text: widget.initialBuyingPrice);
    _discountController = TextEditingController(text: widget.initialdiscount);
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

  Future<void> _convertSecondaryName() async {
    try {
      final response = await http.post(
        Uri.parse('https://easysinhalaunicode.com/api/convert'),
        body: {'data': _secondaryNameController.text},
      );

      // Print the response body for debugging
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Treat the response as plain text
        setState(() {
          _convertedNameController.text = response.body;
        });
      } else {
        _showMessage('Failed to convert name', isError: true);
      }
    } catch (e) {
      _showMessage('Error converting name: ${e.toString()}', isError: true);
    }
  }

  Future<void> _addGroup() async {
    final TextEditingController groupNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _backgroundColor,
          title: const Text(
            'Add New Group',
            style: TextStyle(color: _textColor),
          ),
          content: TextField(
            style: const TextStyle(color: Colors.white),
            controller: groupNameController,
            decoration: const InputDecoration(
                hintText: 'Enter group name',
                hintStyle: TextStyle(color: Colors.white38)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final newGroup = Group(name: groupNameController.text);
                await DatabaseHelper.instance.insertGroup(newGroup);
                _loadGroups(); // Refresh the group list
                Navigator.of(context).pop();
              },
              child: const Text(
                'Add',
                style: TextStyle(color: _textColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _textColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _convertSecondaryName();

      Map<String, Object?> productData = {
        'name': _nameController.text,
        'secondaryName': _convertedNameController.text,
        'barcode': _barcodeController.text,
        'productGroup': _groupController.text,
        'quantity': double.tryParse(_quantityController.text) ?? 0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'buyingPrice': double.tryParse(_buyingPriceController.text) ?? 0.0,
        'expiryDate': _expiryController.text.isNotEmpty
            ? DateTime.parse(_expiryController.text).toIso8601String()
            : null,
        'discount': _discountController.text.isNotEmpty
            ? _discountController.text
            : 0.0,
        'status': _status,
      };

      final product = Product(
        name: productData['name'] as String,
        secondaryName: productData['secondaryName'] as String,
        barcode: productData['barcode'] as String,
        expiryDate: productData['expiryDate'] != null
            ? DateTime.parse(productData['expiryDate'] as String)
            : null,
        productGroup: productData['productGroup'] as String,
        quantity: productData['quantity'] as double,
        price: productData['price'] as double,
        buyingPrice: productData['buyingPrice'] as double,
        discount: productData['discount'] != null
            ? productData['discount'] as String
            : "0",
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
    return SingleChildScrollView(
      child: Dialog(
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
                const SizedBox(height: 10),
                Center(
                  child: SaveButton(
                    onPressed: _handleSave,
                    width: 300,
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
                ),
              ],
            ),
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
            'Enter Barcode here',
          ),
        ),
        const SizedBox(height: 24),
        _buildFormRow(
          leftField: _buildFieldColumn(
            'Secondary Name',
            _secondaryNameController,
            'Add secondary name here',
            onChanged: (value) => _convertSecondaryName(),
          ),
          rightField: _buildFieldColumn(
            'Converted Name',
            _convertedNameController,
            'Converted name will appear here',
            readOnly: true,
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
            'Buying Price',
            _buyingPriceController,
            'Enter buying price',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
          rightField: _buildFieldColumn(
            'Selling Price',
            _priceController,
            'Enter selling price',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildFormRow(
          leftField: _buildFieldColumn(
            'Discount',
            _discountController,
            'Enter discount',
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
        Center(
          child: SizedBox(
            width: 500,
            child: _buildStatusField(),
          ),
        ),
        const SizedBox(height: 32),
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
    ValueChanged<String>? onChanged,
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
          onChanged: onChanged,
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
                      return _groups;
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 34, vertical: 12),
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
              child: Image.asset(
                'assets/add.png',
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
    ValueChanged<String>? onChanged,
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
      child: Center(
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: InputBorder.none,
            suffixIcon: suffixIcon,
          ),
          validator: (value) {
            if (controller != _expiryController &&
                (value == null || value.isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
        ),
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
    _secondaryNameController.dispose();
    _convertedNameController.dispose();
    _barcodeController.dispose();
    _groupController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _buyingPriceController.dispose();
    _expiryController.dispose();
    _discountController.dispose();
    super.dispose();
  }
}
