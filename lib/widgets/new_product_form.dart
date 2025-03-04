import 'dart:io';
import 'package:digisala_pos/models/supplier_model.dart';
import 'package:digisala_pos/widgets/product_add%20header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/group_model.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/widgets/product_add_save_button.dart';

// New package imports for Excel import/export:
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final int? initialSupplierId; // New field for initial supplier
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
    this.initialSupplierId, // Initialize the new field
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
  late final TextEditingController _supplierController; // For supplier

  late String _status;
  List<Group> _groups = [];
  List<Supplier> _suppliers = []; // List of suppliers
  Supplier? _selectedSupplier; // Selected supplier

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
    _supplierController =
        TextEditingController(); // Initialize supplier controller
    _status = widget.initialStatus ?? 'Active';
    _loadGroups();
    _loadSuppliers();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseHelper.instance.getAllGroups();
    setState(() {
      _groups = groups;
    });
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    setState(() {
      _suppliers = suppliers;
      if (widget.initialSupplierId != null) {
        _selectedSupplier = suppliers.firstWhere(
          (supplier) => supplier.id == widget.initialSupplierId,
          orElse: () => Supplier(id: -1, name: 'Unknown'),
        );
        if (_selectedSupplier != null) {
          _supplierController.text = _selectedSupplier!.name;
        }
      }
    });
  }

  Future<void> _convertSecondaryName() async {
    try {
      final response = await http.post(
        Uri.parse('https://easysinhalaunicode.com/api/convert'),
        body: {'data': _secondaryNameController.text},
      );
      if (response.statusCode == 200) {
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
              hintStyle: TextStyle(color: Colors.white38),
            ),
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

  /// ***************** New Function: Import Products from Excel *****************
  Future<void> _importProductsFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) return; // User cancelled

      final bytes = result.files.single.bytes ??
          await File(result.files.single.path!).readAsBytes();

      var excel = ex.Excel.decodeBytes(bytes);
      // We expect the sheet to be named "Products"
      final sheet = excel.tables['Products'];
      if (sheet == null) {
        _showMessage('No "Products" sheet found in Excel file', isError: true);
        return;
      }

      int count = 0;
      // Skip header row; process remaining rows only if there is data.
      for (var row in sheet.rows.skip(1)) {
        // Check if the row is empty (all cells null or empty)
        bool isEmpty = row.every((cell) =>
            cell == null ||
            cell.value == null ||
            cell.value.toString().trim().isEmpty);
        if (isEmpty) continue;

        // Expected order:
        // [barcode, name, secondaryName, expiryDate, productGroup, quantity, price, buyingPrice, discount, status, supplierName]
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
        final supplierName = row[10]?.value?.toString() ?? '';

        final expiryDate = DateTime.tryParse(expiryStr) ?? DateTime.now();
        final quantity = double.tryParse(quantityStr) ?? 0.0;
        final price = double.tryParse(priceStr) ?? 0.0;
        final buyingPrice = double.tryParse(buyingPriceStr) ?? 0.0;

        // Check (or create) supplier by name.
        int supplierId = -1;
        if (supplierName.isNotEmpty) {
          Supplier? supplier;
          try {
            supplier = _suppliers.firstWhere(
                (s) => s.name.toLowerCase() == supplierName.toLowerCase());
          } catch (e) {
            supplier = null;
          }
          if (supplier == null) {
            Supplier newSupplier = Supplier(name: supplierName);
            int newSupplierId =
                await DatabaseHelper.instance.insertSupplier(newSupplier);
            await _loadSuppliers();
            supplierId = newSupplierId;
          } else {
            supplierId = supplier.id!;
          }
        }

        // Check (or create) group.
        if (productGroup.isNotEmpty) {
          bool groupExists = _groups
              .any((g) => g.name.toLowerCase() == productGroup.toLowerCase());
          if (!groupExists) {
            Group newGroup = Group(name: productGroup);
            await DatabaseHelper.instance.insertGroup(newGroup);
            await _loadGroups();
          }
        }

        // ... inside your _importProductsFromExcel() function:
        final existingProduct =
            await DatabaseHelper.instance.getProductByName(name);
        if (existingProduct != null) {
          // Calculate delta between new and old quantity
          double oldQuantity = existingProduct.quantity;
          double delta = quantity - oldQuantity;

          // Use copyWith to create an updated instance
          final updatedProduct = existingProduct.copyWith(
            barcode: barcode,
            secondaryName: secondaryName,
            expiryDate: expiryDate,
            productGroup: productGroup,
            quantity: quantity,
            price: price,
            buyingPrice: buyingPrice,
            discount: discount,
            status: status,
            supplierId: supplierId,
          );
          await DatabaseHelper.instance.updateProduct(updatedProduct);
          // Insert stock update if there's a change
          if (delta != 0) {
            await DatabaseHelper.instance
                .insertStockUpdate(existingProduct.id!, delta);
          }
        } else {
          // Insert new product.
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
          int newProductId =
              await DatabaseHelper.instance.insertProduct(product);
          // Insert stock update for initial quantity
          await DatabaseHelper.instance
              .insertStockUpdate(newProductId, quantity);
        }
        count++;
      }
      _showMessage('Imported $count products', isError: false);
    } catch (e) {
      _showMessage('Error importing products: ${e.toString()}', isError: true);
      print('Error importing products: $e');
    }
  }

  /// ***************** New Function: Export Products to Excel *****************
  Future<void> _exportProductsToExcel() async {
    try {
      // Step 1: Request Storage Permission
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        _showMessage('Storage permission denied', isError: true);
        return;
      }

      // Step 2: Generate Excel File
      final products = await DatabaseHelper.instance.getAllProducts();
      var excel = ex.Excel.createExcel();
      ex.Sheet sheetObject = excel['Products'];

      // Header row
      List<ex.CellValue> header = [
        ex.TextCellValue('Barcode'),
        ex.TextCellValue('Name'),
        ex.TextCellValue('Secondary Name'),
        ex.TextCellValue('Expiry Date'),
        ex.TextCellValue('Product Group'),
        ex.TextCellValue('Quantity'),
        ex.TextCellValue('Price'),
        ex.TextCellValue('Buying Price'),
        ex.TextCellValue('Discount'),
        ex.TextCellValue('Status'),
        ex.TextCellValue('Supplier'),
      ];
      sheetObject.appendRow(header);

      // Mock data row
      List<ex.CellValue> mockRow = [
        ex.TextCellValue('MOCK001'),
        ex.TextCellValue('Sample Product'),
        ex.TextCellValue('නම්බු කෙටි නාමය'),
        ex.TextCellValue('2024-12-31'),
        ex.TextCellValue('Demo Group'),
        ex.DoubleCellValue(100),
        ex.DoubleCellValue(1500.00),
        ex.DoubleCellValue(1200.00),
        ex.TextCellValue('10%'),
        ex.TextCellValue('Active'),
        ex.TextCellValue('Sample Supplier'),
      ];
      sheetObject.appendRow(mockRow);

      // Step 3: Let User Choose Directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        _showMessage('Export cancelled by user', isError: true);
        return;
      }

      // Step 4: Save the File
      final outputFile = File('$selectedDirectory/products_export.xlsx');
      await outputFile.writeAsBytes(excel.encode()!);

      _showMessage('Products exported to ${outputFile.path}', isError: false);
    } catch (e) {
      _showMessage('Error exporting products: ${e.toString()}', isError: true);
      print('Error exporting products: $e');
    }
  }

// ✅ Step 1: Request Storage Permission
  Future<bool> _requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

// ✅ Step 3: Alternative - Save in Scoped Storage (Android 10+)
  Future<String> _getSavePath() async {
    Directory? directory;

    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory(); // App-specific storage
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    return "${directory!.path}/products_export.xlsx";
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
            : "0",
        'status': _status,
        'supplierId': _selectedSupplier?.id ?? -1,
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
            ? productData['discount'].toString()
            : "0",
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
        status: productData['status'] as String,
        supplierId: productData['supplierId'] as int,
      );

      final result = await DatabaseHelper.instance.insertProduct(product);

      if (!mounted) return;
      if (result != -1) {
        // Insert stock update for initial quantity
        await DatabaseHelper.instance
            .insertStockUpdate(result, product.quantity);
        Navigator.pop(context);
        _showMessage('Product saved successfully!', isError: false);
        widget.onSave?.call(productData);
      } else {
        throw Exception('Failed to insert product');
      }
    } catch (e) {
      _showMessage('Error saving product: ${e.toString()}', isError: true);
      print('Error saving product: ${e.toString()}');
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

  void _handleClose() {
    widget.onClose?.call();
    widget.searchBarFocusNode.requestFocus();
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
                  onImport: _importProductsFromExcel,
                  onExport: _exportProductsToExcel,
                  onClose: _handleClose,
                ),
                // Row for Import/Export actions:
                const SizedBox(height: 16),

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
          leftField:
              _buildFieldColumn('Name', _nameController, 'Add item name here'),
          rightField: _buildFieldColumn(
              'Barcode', _barcodeController, 'Enter Barcode here'),
        ),
        const SizedBox(height: 24),
        _buildFormRow(
          leftField: _buildFieldColumn(
            'Secondary Name',
            _secondaryNameController,
            'Add secondary name here',
            onChanged: (value) => _convertSecondaryName(),
          ),
          rightField: _buildFieldColumn('Converted Name',
              _convertedNameController, 'Converted name will appear here',
              readOnly: true),
        ),
        const SizedBox(height: 24),
        _buildFormRow(
          leftField: _buildGroupAutocomplete(),
          rightField: _buildFieldColumn(
              'Quantity', _quantityController, 'Enter quantity',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        ),
        const SizedBox(height: 24),
        _buildFormRow(
          leftField: _buildFieldColumn(
              'Buying Price', _buyingPriceController, 'Enter buying price',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
              ]),
          rightField: _buildFieldColumn(
              'Selling Price', _priceController, 'Enter selling price',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
              ]),
        ),
        const SizedBox(height: 24),
        _buildFormRow(
          leftField: _buildFieldColumn(
            'Discount',
            _discountController,
            'Enter discount',
          ),
          rightField: _buildFieldColumn(
              'Expire', _expiryController, 'Select expiry date',
              readOnly: true, onTap: _showDatePicker),
        ),
        const SizedBox(height: 24),
        _buildFormRow(
          leftField: _buildSupplierAutocomplete(),
          rightField: _buildStatusField(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildFormRow(
      {required Widget leftField, required Widget rightField}) {
    return Row(
      children: [
        Expanded(child: leftField),
        const SizedBox(width: 24),
        Expanded(child: rightField),
      ],
    );
  }

  Widget _buildFieldColumn(
      String label, TextEditingController controller, String hint,
      {TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters,
      bool readOnly = false,
      VoidCallback? onTap,
      ValueChanged<String>? onChanged}) {
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
            onChanged: onChanged),
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
                    if (textEditingValue.text.isEmpty) return _groups;
                    return _groups.where((Group group) => group.name
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
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
                          fontWeight: FontWeight.w300),
                      decoration: InputDecoration(
                        hintText: 'Type to search groups',
                        hintStyle: TextStyle(
                            color: _textColor.withOpacity(0.8),
                            fontSize: 18,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w300),
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
                                        fontWeight: FontWeight.w300)),
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
              child: Image.asset('assets/add.png', width: 38, height: 38),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSupplierAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Supplier'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: _inputHeight,
                decoration: _getFieldDecoration(),
                child: Autocomplete<Supplier>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) return _suppliers;
                    return _suppliers.where((Supplier supplier) => supplier.name
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
                  },
                  displayStringForOption: (Supplier supplier) => supplier.name,
                  onSelected: (Supplier selection) {
                    setState(() {
                      _selectedSupplier = selection;
                      _supplierController.text = selection.name;
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
                          fontWeight: FontWeight.w300),
                      decoration: InputDecoration(
                        hintText: 'Type to search suppliers',
                        hintStyle: TextStyle(
                            color: _textColor.withOpacity(0.8),
                            fontSize: 18,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w300),
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
                              final Supplier option = options.elementAt(index);
                              return ListTile(
                                title: Text(option.name,
                                    style: const TextStyle(
                                        color: _textColor,
                                        fontSize: 18,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w300)),
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
              onTap: _addSupplier,
              child: Image.asset('assets/add.png', width: 38, height: 38),
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
            fontWeight: FontWeight.w700),
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
        border: Border.all(color: _borderColor, width: 2),
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
              fontWeight: FontWeight.w300),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
                color: _textColor.withOpacity(0.8),
                fontSize: 18,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w300),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: InputBorder.none,
            suffixIcon: suffixIcon,
          ),
          // In the _buildInputField widget, modify the validator:
          validator: (value) {
            // List of non-required controllers
            final optionalControllers = [
              _expiryController,
              _discountController,
              _secondaryNameController,
              _convertedNameController
            ];

            // Only validate required fields
            if (!optionalControllers.contains(controller) &&
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
                primary: _borderColor, surface: _backgroundColor),
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
              .map((status) => ListTile(
                    title:
                        Text(status, style: const TextStyle(color: _textColor)),
                    onTap: () {
                      setState(() => _status = status);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _addSupplier() async {
    final TextEditingController supplierNameController =
        TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _backgroundColor,
          title: const Text('Add New Supplier',
              style: TextStyle(color: _textColor)),
          content: TextField(
            style: const TextStyle(color: Colors.white),
            controller: supplierNameController,
            decoration: const InputDecoration(
              hintText: 'Enter supplier name',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final newSupplier = Supplier(name: supplierNameController.text);
                await DatabaseHelper.instance.insertSupplier(newSupplier);
                _loadSuppliers();
                Navigator.of(context).pop();
              },
              child: const Text('Add', style: TextStyle(color: _textColor)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: _textColor)),
            ),
          ],
        );
      },
    );
  }

  BoxDecoration _getFieldDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(_inputBorderRadius),
      border: Border.all(color: _borderColor, width: 2),
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
    _supplierController.dispose();
    super.dispose();
  }
}
