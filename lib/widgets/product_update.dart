import 'package:flutter/material.dart';
import 'package:paylink_pos/database/product_db_helper.dart';
import 'package:paylink_pos/database/group_db_helper.dart';
import 'package:paylink_pos/models/product_model.dart';
import 'package:paylink_pos/models/group_model.dart';
import 'package:intl/intl.dart';

class ProductUpdateForm extends StatefulWidget {
  @override
  _ProductUpdateFormState createState() => _ProductUpdateFormState();
}

class _ProductUpdateFormState extends State<ProductUpdateForm> {
  final _searchController = TextEditingController();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<TextEditingController> _nameControllers = [];
  List<TextEditingController> _barcodeControllers = [];
  List<TextEditingController> _quantityControllers = [];
  List<TextEditingController> _priceControllers = [];
  List<TextEditingController> _expiryControllers = [];
  List<String> _statusOptions = ['Active', 'Inactive'];
  List<String> _selectedStatus = [];
  List<Group> _groups = [];
  List<TextEditingController> _groupControllers = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadGroups();
    _searchController.addListener(_filterProducts);
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _products = products;
      _filteredProducts = products;
      _nameControllers =
          products.map((p) => TextEditingController(text: p.name)).toList();
      _barcodeControllers =
          products.map((p) => TextEditingController(text: p.barcode)).toList();
      _quantityControllers = products
          .map((p) => TextEditingController(text: p.quantity.toString()))
          .toList();
      _priceControllers = products
          .map((p) => TextEditingController(text: p.price.toString()))
          .toList();
      _expiryControllers = products
          .map((p) => TextEditingController(
              text: p.expiryDate != null
                  ? DateFormat('yyyy-MM-dd').format(p.expiryDate!)
                  : ''))
          .toList();
      _selectedStatus = products.map((p) => p.status).toList();
      _groupControllers = products
          .map((p) => TextEditingController(text: p.productGroup))
          .toList();
    });
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseHelper.instance.getAllGroups();
    setState(() {
      _groups = groups;
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products
          .where((product) => product.name.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _deleteProduct(int index) async {
    final productId = _filteredProducts[index].id;
    await DatabaseHelper.instance.deleteProduct(productId!);
    _loadProducts();
    _showSnackBar('Product deleted successfully!', Colors.red);
  }

  Future<void> _saveUpdates() async {
    for (int i = 0; i < _filteredProducts.length; i++) {
      if (_nameControllers[i].text.isEmpty) {
        _showSnackBar('Product name cannot be empty', Colors.red);
        return;
      }
      final updatedProduct = Product(
        id: _filteredProducts[i].id,
        name: _nameControllers[i].text,
        barcode: _barcodeControllers[i].text,
        expiryDate: DateTime.tryParse(_expiryControllers[i].text),
        productGroup: _groupControllers[i].text,
        quantity: int.parse(_quantityControllers[i].text),
        price: double.parse(_priceControllers[i].text),
        createdDate: _filteredProducts[i].createdDate,
        updatedDate: DateTime.now(),
        status: _selectedStatus[i],
      );
      await DatabaseHelper.instance.updateProduct(updatedProduct);
    }
    _showSnackBar('Products updated successfully!', Colors.green);
    Navigator.of(context).pop();
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
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
                      icon:
                          const Icon(Icons.picture_as_pdf, color: Colors.white),
                      onPressed: () {
                        // Implement PDF export functionality
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.white),
                      onPressed: () {
                        // Implement print functionality
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
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
                child: DataTable(
                  columns: const [
                    DataColumn(
                        label:
                            Text('ID', style: TextStyle(color: Colors.white))),
                    DataColumn(
                        label: Text('Barcode',
                            style: TextStyle(color: Colors.white))),
                    DataColumn(
                        label: Text('Name',
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
                        label: Text('Price',
                            style: TextStyle(color: Colors.white))),
                    DataColumn(
                        label: Text('Status',
                            style: TextStyle(color: Colors.white))),
                    DataColumn(
                        label: Text('Actions',
                            style: TextStyle(color: Colors.white))),
                  ],
                  rows: List<DataRow>.generate(
                    _filteredProducts.length,
                    (index) => DataRow(
                      cells: [
                        DataCell(Text(_filteredProducts[index].id.toString(),
                            style: TextStyle(color: Colors.white))),
                        DataCell(
                          TextFormField(
                            controller: _barcodeControllers[index],
                            style: const TextStyle(color: Colors.white),
                            decoration:
                                const InputDecoration(border: InputBorder.none),
                          ),
                        ),
                        DataCell(
                          TextFormField(
                            controller: _nameControllers[index],
                            style: const TextStyle(color: Colors.white),
                            decoration:
                                const InputDecoration(border: InputBorder.none),
                          ),
                        ),
                        DataCell(
                          TextFormField(
                            controller: _expiryControllers[index],
                            style: const TextStyle(color: Colors.white),
                            decoration:
                                const InputDecoration(border: InputBorder.none),
                            onTap: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  _expiryControllers[index].text =
                                      DateFormat('yyyy-MM-dd')
                                          .format(pickedDate);
                                });
                              }
                            },
                          ),
                        ),
                        DataCell(
                          Container(
                            width: 150, // Adjust width as needed
                            child: RawAutocomplete<Group>(
                              textEditingController: _groupControllers[index],
                              focusNode: FocusNode(),
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<Group>.empty();
                                }
                                return _groups.where((Group group) {
                                  return group.name.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase());
                                });
                              },
                              displayStringForOption: (Group group) =>
                                  group.name,
                              onSelected: (Group selection) {
                                setState(() {
                                  _groupControllers[index].text =
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
                                      width: 200, // Adjust width as needed
                                      color: const Color(0xFF020A1B),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          final Group option =
                                              options.elementAt(index);
                                          return ListTile(
                                            title: Text(
                                              option.name,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
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
                              fieldViewBuilder: (context, textEditingController,
                                  focusNode, onFieldSubmitted) {
                                return TextFormField(
                                  controller: _groupControllers[index],
                                  focusNode: focusNode,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Type to search groups',
                                    hintStyle: TextStyle(color: Colors.grey),
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
                            controller: _quantityControllers[index],
                            style: const TextStyle(color: Colors.white),
                            decoration:
                                const InputDecoration(border: InputBorder.none),
                          ),
                        ),
                        DataCell(
                          TextFormField(
                            controller: _priceControllers[index],
                            style: const TextStyle(color: Colors.white),
                            decoration:
                                const InputDecoration(border: InputBorder.none),
                          ),
                        ),
                        DataCell(
                          DropdownButton<String>(
                            value: _selectedStatus[index],
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
                                _selectedStatus[index] = newValue!;
                              });
                            },
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteProduct(index),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveUpdates,
              child: const Text('Save & Update'),
            ),
          ],
        ),
      ),
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
    super.dispose();
  }
}
