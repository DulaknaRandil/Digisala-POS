import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/supplier_model.dart';
import 'package:flutter/material.dart';

class SupplierForm extends StatefulWidget {
  final FocusNode searchBarFocusNode;
  SupplierForm({required this.searchBarFocusNode});

  @override
  _SupplierFormState createState() => _SupplierFormState();
}

class _SupplierFormState extends State<SupplierForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _searchController.addListener(_filterSuppliers);
  }

  Future<void> _loadSuppliers() async {
    // Load suppliers from the database
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    setState(() {
      _suppliers = suppliers;
      _filteredSuppliers = suppliers;
      _controllers = suppliers
          .map((supplier) => TextEditingController(text: supplier.name))
          .toList();
    });
  }

  void _filterSuppliers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSuppliers = _suppliers
          .where((supplier) => supplier.name.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _addSupplier() async {
    if (_formKey.currentState!.validate()) {
      final supplier = Supplier(name: _nameController.text);
      await DatabaseHelper.instance.insertSupplier(supplier);
      _nameController.clear();
      _loadSuppliers();
      _showSnackBar('Supplier added successfully!', Colors.green);
    }
  }

  Future<void> _deleteSupplier(int index) async {
    final supplierId = _filteredSuppliers[index].id;
    await DatabaseHelper.instance.deleteSupplier(supplierId!);
    _loadSuppliers();
    _showSnackBar('Supplier deleted successfully!', Colors.red);
  }

  Future<void> _saveUpdates() async {
    for (int i = 0; i < _filteredSuppliers.length; i++) {
      if (_controllers[i].text.isEmpty) {
        _showSnackBar('Supplier name cannot be empty', Colors.red);
        return;
      }
      final updatedSupplier =
          Supplier(id: _filteredSuppliers[i].id, name: _controllers[i].text);
      await DatabaseHelper.instance.updateSupplier(updatedSupplier);
    }
    _showSnackBar('Suppliers updated successfully!', Colors.green);
    Navigator.of(context).pop();
    widget.searchBarFocusNode.requestFocus();
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
    return SingleChildScrollView(
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.4,
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
                    'New Supplier',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF949391),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.searchBarFocusNode.requestFocus();
                      }),
                ],
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Type supplier name here',
                        hintStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF1F5F9),
                        ),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(55),
                          borderSide: BorderSide(
                            color: Color(0xFFF1F5F9),
                            width: 2,
                          ),
                        ),
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF1F5F9),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addSupplier,
                      child: const Text('Add New Supplier'),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF2D2D2D)),
                    const Text(
                      'Supplier List',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search suppliers',
                        hintStyle: const TextStyle(color: Colors.white),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Supplier Name',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DataColumn(
                              headingRowAlignment: MainAxisAlignment.end,
                              label: Text(
                                'Actions',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          rows: List<DataRow>.generate(
                            _filteredSuppliers.length,
                            (index) => DataRow(
                              cells: [
                                DataCell(
                                  TextFormField(
                                    controller: _controllers[index],
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Name cannot be empty';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .end, // Aligns the button to the end
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _deleteSupplier(index),
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
