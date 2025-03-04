import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/group_model.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/models/supplier_model.dart';
import 'package:digisala_pos/widgets/admin_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductUpdateForm extends StatefulWidget {
  final FocusNode searchBarFocusNode;

  ProductUpdateForm({required this.searchBarFocusNode});

  @override
  _ProductUpdateFormState createState() => _ProductUpdateFormState();
}

class _ProductUpdateFormState extends State<ProductUpdateForm> {
  final _searchController = TextEditingController();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<TextEditingController> _nameControllers = [];
  List<TextEditingController> _secondaryNameControllers = [];
  List<TextEditingController> _barcodeControllers = [];
  List<TextEditingController> _quantityControllers = [];
  List<TextEditingController> _priceControllers = [];
  List<TextEditingController> _buyingPriceControllers = [];
  List<TextEditingController> _expiryControllers = [];
  List<TextEditingController> _discountControllers = [];
  List<TextEditingController> _supplierControllers = []; // Supplier controllers
  List<String> _statusOptions = ['Active', 'Inactive'];
  List<String> _selectedStatus = [];
  List<Group> _groups = [];
  List<Supplier> _suppliers = []; // List of suppliers
  List<TextEditingController> _groupControllers = [];
  int _currentPage = 1;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _initializeData(); // Load data in correct order
    _searchController.addListener(_filterProducts);
  }

  Future<void> _initializeData() async {
    await _loadSuppliers(); // Load suppliers first
    await _loadGroups(); // Then groups
    await _loadProducts(); // Finally products with dependent data
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _products = products;
      _initializeControllers(products); // Suppliers are now available
      _filterProducts();
    });
  }

  void _initializeControllers(List<Product> products) {
    _nameControllers =
        products.map((p) => TextEditingController(text: p.name)).toList();
    _secondaryNameControllers = products
        .map((p) => TextEditingController(text: p.secondaryName ?? ''))
        .toList();
    _barcodeControllers =
        products.map((p) => TextEditingController(text: p.barcode)).toList();
    _quantityControllers = products
        .map((p) => TextEditingController(text: p.quantity.toString()))
        .toList();
    _priceControllers = products
        .map((p) => TextEditingController(text: p.price.toString()))
        .toList();
    _buyingPriceControllers = products
        .map((p) => TextEditingController(text: p.buyingPrice.toString()))
        .toList();
    _expiryControllers = products
        .map((p) => TextEditingController(
            text: p.expiryDate != null
                ? DateFormat('yyyy-MM-dd').format(p.expiryDate!)
                : ''))
        .toList();
    _discountControllers = products
        .map((p) => TextEditingController(text: p.discount?.toString() ?? ''))
        .toList();
    _selectedStatus = products.map((p) => p.status).toList();
    _groupControllers = products
        .map((p) => TextEditingController(text: p.productGroup))
        .toList();
    _supplierControllers = products
        .map((p) => TextEditingController(
            text: _suppliers
                .firstWhere(
                  (s) => s.id == p.supplierId,
                  orElse: () => Supplier(id: -1, name: 'Unknown'),
                )
                .name))
        .toList();
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
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final nameMatches = product.name.toLowerCase().contains(query);
        final idMatches = product.id.toString().contains(query);
        final barcodeMatches = product.barcode.toLowerCase().contains(query);
        return nameMatches || idMatches || barcodeMatches;
      }).toList();
      _initializeControllers(_filteredProducts);
      _currentPage = 1; // Reset to first page
    });
  }

  Future<void> _deleteProduct(int index) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PinConfirmationDialog(
          onPinComplete: (pin) async {
            final productId = _filteredProducts[index].id;
            await DatabaseHelper.instance.deleteProduct(productId!);
            _loadProducts();
            _showSnackBar('Product deleted successfully!', Colors.red);
          },
        );
      },
    );
  }

  Future<void> _saveUpdates() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PinConfirmationDialog(
          onPinComplete: (pin) async {
            for (int i = 0; i < _filteredProducts.length; i++) {
              if (_nameControllers[i].text.isEmpty) {
                _showSnackBar('Product name cannot be empty', Colors.red);
                return;
              }
              final updatedProduct = Product(
                id: _filteredProducts[i].id,
                name: _nameControllers[i].text,
                secondaryName: _secondaryNameControllers[i].text,
                barcode: _barcodeControllers[i].text,
                expiryDate: DateTime.tryParse(_expiryControllers[i].text),
                productGroup: _groupControllers[i].text,
                quantity: double.parse(_quantityControllers[i].text),
                price: double.parse(_priceControllers[i].text),
                buyingPrice: double.parse(_buyingPriceControllers[i].text),
                discount: (_discountControllers[i].text),
                createdDate: _filteredProducts[i].createdDate,
                updatedDate: DateTime.now(),
                status: _selectedStatus[i],
                supplierId: _suppliers
                    .firstWhere((s) => s.name == _supplierControllers[i].text,
                        orElse: () => Supplier(id: -1, name: 'Unknown'))
                    .id!,
              );
              await DatabaseHelper.instance.updateProduct(updatedProduct);
            }
            _showSnackBar('Products updated successfully!', Colors.green);
            Navigator.of(context).pop();
            widget.searchBarFocusNode.requestFocus();
          },
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate pagination indices
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    final paginatedProducts = _filteredProducts.sublist(
      startIndex,
      endIndex.clamp(0, _filteredProducts.length),
    );
    return SingleChildScrollView(
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: screenWidth * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF020A1B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Update Products',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF949391),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          widget.searchBarFocusNode.requestFocus();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search products',
                  hintStyle: const TextStyle(color: Colors.white),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columns: const [
                        DataColumn(
                            label: Text('ID',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Barcode',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Name',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Secondary Name',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Expiry Date',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Group',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Quantity',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Buying Price',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Selling Price',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Discount',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Supplier',
                                style: TextStyle(
                                    color:
                                        Colors.white))), // New Supplier column
                        DataColumn(
                            label: Text('Status',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Actions',
                                style: TextStyle(color: Colors.white))),
                      ],
                      rows: List<DataRow>.generate(
                        paginatedProducts.length,
                        (i) {
                          final originalIndex = startIndex + i;
                          return DataRow(
                            cells: [
                              DataCell(Text(paginatedProducts[i].id.toString(),
                                  style: TextStyle(color: Colors.white))),
                              DataCell(
                                TextFormField(
                                  controller:
                                      _barcodeControllers[originalIndex],
                                  style: TextStyle(color: Colors.white),
                                  decoration:
                                      InputDecoration(border: InputBorder.none),
                                ),
                              ),
                              DataCell(
                                TextFormField(
                                  controller: _nameControllers[originalIndex],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none),
                                ),
                              ),
                              DataCell(
                                TextFormField(
                                  controller:
                                      _secondaryNameControllers[originalIndex],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none),
                                ),
                              ),
                              DataCell(
                                TextFormField(
                                  controller: _expiryControllers[originalIndex],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none),
                                  onTap: () async {
                                    DateTime? pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (pickedDate != null) {
                                      setState(() {
                                        _expiryControllers[originalIndex].text =
                                            DateFormat('yyyy-MM-dd')
                                                .format(pickedDate);
                                      });
                                    }
                                  },
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: 150,
                                  child: RawAutocomplete<Group>(
                                    textEditingController:
                                        _groupControllers[originalIndex],
                                    focusNode: FocusNode(),
                                    optionsBuilder:
                                        (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return const Iterable<Group>.empty();
                                      }
                                      return _groups.where((Group group) {
                                        return group.name
                                            .toLowerCase()
                                            .contains(textEditingValue.text
                                                .toLowerCase());
                                      });
                                    },
                                    displayStringForOption: (Group group) =>
                                        group.name,
                                    onSelected: (Group selection) {
                                      setState(() {
                                        _groupControllers[originalIndex].text =
                                            selection.name;
                                      });
                                    },
                                    optionsViewBuilder:
                                        (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4.0,
                                          child: Container(
                                            width: 200,
                                            color: const Color(0xFF020A1B),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              itemBuilder:
                                                  (BuildContext context,
                                                      int index) {
                                                final Group option =
                                                    options.elementAt(index);
                                                return ListTile(
                                                  title: Text(option.name,
                                                      style: const TextStyle(
                                                          color: Colors.white)),
                                                  onTap: () {
                                                    onSelected(option);
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    fieldViewBuilder: (context,
                                        textEditingController,
                                        focusNode,
                                        onFieldSubmitted) {
                                      return TextFormField(
                                        controller:
                                            _groupControllers[originalIndex],
                                        focusNode: focusNode,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          hintText: 'Type to search groups',
                                          hintStyle:
                                              TextStyle(color: Colors.grey),
                                        ),
                                        onChanged: (value) {
                                          textEditingController.text = value;
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                TextFormField(
                                  controller:
                                      _quantityControllers[originalIndex],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none),
                                ),
                              ),
                              DataCell(
                                TextFormField(
                                  controller:
                                      _buyingPriceControllers[originalIndex],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              DataCell(
                                TextFormField(
                                  controller: _priceControllers[originalIndex],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              DataCell(
                                TextFormField(
                                  controller:
                                      _discountControllers[originalIndex],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              DataCell(
                                Container(
                                  width: 150,
                                  child: RawAutocomplete<Supplier>(
                                    textEditingController:
                                        _supplierControllers[originalIndex],
                                    focusNode: FocusNode(),
                                    optionsBuilder:
                                        (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return const Iterable<Supplier>.empty();
                                      }
                                      return _suppliers
                                          .where((Supplier supplier) {
                                        return supplier.name
                                            .toLowerCase()
                                            .contains(textEditingValue.text
                                                .toLowerCase());
                                      });
                                    },
                                    displayStringForOption:
                                        (Supplier supplier) => supplier.name,
                                    onSelected: (Supplier selection) {
                                      setState(() {
                                        _supplierControllers[originalIndex]
                                            .text = selection.name;
                                      });
                                    },
                                    optionsViewBuilder:
                                        (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4.0,
                                          child: Container(
                                            width: 200,
                                            color: const Color(0xFF020A1B),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              itemBuilder:
                                                  (BuildContext context,
                                                      int index) {
                                                final Supplier option =
                                                    options.elementAt(index);
                                                return ListTile(
                                                  title: Text(option.name,
                                                      style: const TextStyle(
                                                          color: Colors.white)),
                                                  onTap: () {
                                                    onSelected(option);
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    fieldViewBuilder: (context,
                                        textEditingController,
                                        focusNode,
                                        onFieldSubmitted) {
                                      return TextFormField(
                                        controller:
                                            _supplierControllers[originalIndex],
                                        focusNode: focusNode,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          hintText: 'Type to search suppliers',
                                          hintStyle:
                                              TextStyle(color: Colors.grey),
                                        ),
                                        onChanged: (value) {
                                          textEditingController.text = value;
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                              DataCell(
                                DropdownButton<String>(
                                  value: _selectedStatus[originalIndex],
                                  dropdownColor: Colors.grey[800],
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: Colors.white),
                                  style: const TextStyle(color: Colors.white),
                                  items: _statusOptions.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedStatus[originalIndex] =
                                          newValue!;
                                    });
                                  },
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon:
                                          Icon(Icons.delete, color: Colors.red),
                                      onPressed: () =>
                                          _deleteProduct(originalIndex),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildPagination(),
              ElevatedButton(
                onPressed: _saveUpdates,
                child: const Text('Save & Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_filteredProducts.length / _rowsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: Colors.white),
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
        ),
        Text(
          'Page $_currentPage of $totalPages',
          style: TextStyle(color: Colors.white),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: Colors.white),
          onPressed: _currentPage < totalPages
              ? () => setState(() => _currentPage++)
              : null,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    for (final controller in _barcodeControllers) {
      controller.dispose();
    }
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    for (final controller in _priceControllers) {
      controller.dispose();
    }
    for (final controller in _expiryControllers) {
      controller.dispose();
    }
    for (final controller in _groupControllers) {
      controller.dispose();
    }
    for (final controller in _discountControllers) {
      controller.dispose();
    }
    for (final controller in _supplierControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
