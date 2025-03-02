import 'dart:io';
import 'package:digisala_pos/models/suppplier_model.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/utils/pdf_service_stock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as ex;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class StockDialog extends StatefulWidget {
  final FocusNode searchBarFocusNode;
  const StockDialog({Key? key, required this.searchBarFocusNode})
      : super(key: key);

  @override
  _StockDialogState createState() => _StockDialogState();
}

class _StockDialogState extends State<StockDialog> {
  List<Product> _products = [];
  List<Product> _displayedProducts = [];
  String _selectedGroup = 'All';
  String _searchQuery = '';
  String _selectedStockLevel = 'all';
  int _currentPage = 0;
  final int _itemsPerPage = 5;
  List<String> _groupSuggestions = [];
  List<Group> _groups = []; // Assuming you have a list of Group objects
  final TextEditingController _groupController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _products = products;
      _displayedProducts = _filterProducts();
      _groupSuggestions = _getUniqueGroups();
      _groups = _groupSuggestions.map((name) => Group(name: name)).toList();
    });
  }

  List<Product> _filterProducts() {
    List<Product> filtered = _products.where((product) {
      if (_selectedGroup == 'Group' && _searchQuery.isNotEmpty) {
        return product.productGroup == _searchQuery;
      }
      if (_selectedGroup != 'All' && product.productGroup != _selectedGroup) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !product.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !product.barcode.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !product.id.toString().contains(_searchQuery)) {
        return false;
      }
      switch (_selectedStockLevel) {
        case 'low':
          return product.quantity < 5;
        case 'medium':
          return product.quantity >= 5 && product.quantity < 15;
        case 'high':
          return product.quantity >= 15;
        default:
          return true;
      }
    }).toList();

    return filtered
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();
  }

  List<String> _getUniqueGroups() {
    return _products.map((product) => product.productGroup).toSet().toList();
  }

  void _resetFilters() {
    setState(() {
      _selectedGroup = 'All';
      _searchQuery = '';
      _selectedStockLevel = 'all';
      _currentPage = 0;
      _displayedProducts = _filterProducts();
    });
  }

  // ✅ Helper Function: Request Storage Permission
  Future<bool> _requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

// ✅ Helper Function: Show Messages
  void _showMessage(String message, {bool isError = false}) {
    print(isError ? "❌ Error: $message" : "✅ Success: $message");
  }

  Future<void> _exportStockToExcel() async {
    try {
      // Step 1: Request Storage Permission
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        _showMessage('Storage permission denied', isError: true);
        return;
      }

      // Step 2: Fetch All Products & Suppliers
      final products = await DatabaseHelper.instance.getAllProducts();
      final suppliers = await DatabaseHelper.instance.getAllSuppliers();

      // Step 3: Create Excel Document
      var excel = ex.Excel.createExcel();
      ex.Sheet sheetObject = excel['Stock'];

      // Header row with supplier name.
      List<ex.CellValue> headerRow = [
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
      sheetObject.appendRow(headerRow);

      // Append a row for each product.
      for (var product in products) {
        // Look up the supplier name.
        String supplierName = 'Unknown';
        try {
          final supplier = suppliers.firstWhere(
              (s) => s.id == product.supplierId,
              orElse: () => Supplier(id: -1, name: 'Unknown'));
          supplierName = supplier.name;
        } catch (e) {
          supplierName = 'Unknown';
        }

        List<ex.CellValue> row = [
          ex.TextCellValue(product.barcode),
          ex.TextCellValue(product.name),
          ex.TextCellValue(product.secondaryName),
          ex.TextCellValue(product.expiryDate != null
              ? DateFormat('yyyy-MM-dd').format(product.expiryDate!)
              : ''),
          ex.TextCellValue(product.productGroup),
          ex.DoubleCellValue(product.quantity.toDouble()),
          ex.DoubleCellValue(product.price.toDouble()),
          ex.DoubleCellValue(product.buyingPrice.toDouble()),
          ex.TextCellValue(product.discount),
          ex.TextCellValue(product.status),
          ex.TextCellValue(supplierName),
        ];
        sheetObject.appendRow(row);
      }

      // Step 4: Let User Choose Directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) {
        _showMessage('Export cancelled by user', isError: true);
        return;
      }

      // Step 5: Save the File
      final outputFile = File('$selectedDirectory/stock_export.xlsx');
      await outputFile.writeAsBytes(excel.encode()!);

      _showMessage('Stock exported to ${outputFile.path}', isError: false);
    } catch (e) {
      _showMessage('Error exporting stock: ${e.toString()}', isError: true);
      print('Error exporting stock: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allFilteredProducts = _products.where((product) {
      if (_selectedGroup == 'Group' && _searchQuery.isNotEmpty) {
        return product.productGroup == _searchQuery;
      }
      if (_selectedGroup != 'All' && product.productGroup != _selectedGroup) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !product.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !product.barcode.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !product.id.toString().contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();

    final lowStock = allFilteredProducts.where((p) => p.quantity < 5).length;
    final mediumStock = allFilteredProducts
        .where((p) => p.quantity >= 5 && p.quantity < 15)
        .length;
    final highStock = allFilteredProducts.where((p) => p.quantity >= 15).length;
    final totalPages = (allFilteredProducts.length / _itemsPerPage).ceil();

    return Dialog(
      backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      child: Container(
        width: 1000,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Title and action buttons.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    // New: Export button placed after Import.
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _exportStockToExcel,
                      child: const Text('Export'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        try {
                          final pdfData = await PdfService.generateStockReport(
                            products: allFilteredProducts,
                            lowStock: lowStock,
                            mediumStock: mediumStock,
                            highStock: highStock,
                          );
                          await PdfService.sharePdf(
                              pdfData, 'stock_report.pdf');
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error generating PDF: $e')),
                          );
                        }
                      },
                      child: const Text('PDF'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        try {
                          final pdfData = await PdfService.generateStockReport(
                            products: allFilteredProducts,
                            lowStock: lowStock,
                            mediumStock: mediumStock,
                            highStock: highStock,
                          );
                          await PdfService.printDocument(pdfData);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error printing: $e')),
                          );
                        }
                      },
                      child: const Text('Print'),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.searchBarFocusNode.requestFocus();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white),
            Row(
              children: [
                Expanded(
                  child: _selectedGroup == 'Group'
                      ? _buildGroupAutocomplete()
                      : TextField(
                          style: const TextStyle(color: Colors.white),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _displayedProducts = _filterProducts();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by name, barcode, or ID',
                            hintStyle: const TextStyle(color: Colors.white54),
                            suffixIcon: IconButton(
                              icon:
                                  const Icon(Icons.search, color: Colors.white),
                              onPressed: () {},
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedGroup,
                  dropdownColor: const Color(0xFF121315),
                  style: const TextStyle(color: Colors.white),
                  items: <String>['All', 'Group'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGroup = value!;
                      _searchQuery = '';
                      _displayedProducts = _filterProducts();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStockButton('Low Stock', lowStock, Colors.red, 'low'),
                _buildStockButton(
                    'Medium Stock', mediumStock, Colors.yellow, 'medium'),
                _buildStockButton(
                    'High Stock', highStock, Colors.green, 'high'),
                ElevatedButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      const Color.fromARGB(56, 131, 131, 128),
                    ),
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
                    ],
                    rows: _displayedProducts.map((product) {
                      Color rowColor;
                      if (product.quantity < 5) {
                        rowColor = Colors.red.withOpacity(0.2);
                      } else if (product.quantity < 15) {
                        rowColor = Colors.yellow.withOpacity(0.2);
                      } else {
                        rowColor = Colors.green.withOpacity(0.2);
                      }
                      return DataRow(
                        color: MaterialStateProperty.all(rowColor),
                        cells: [
                          DataCell(Text('${product.id}',
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(product.barcode,
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(product.name,
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(
                              product.expiryDate != null
                                  ? product.expiryDate!
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0]
                                  : 'N/A',
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(product.productGroup,
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text('${product.quantity}',
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(
                              '${product.price.toStringAsFixed(2)} LKR',
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(product.status,
                              style: const TextStyle(color: Colors.white))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Items: ${allFilteredProducts.length}',
                  style: const TextStyle(color: Colors.white),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: _currentPage > 0
                          ? () => setState(() {
                                _currentPage--;
                                _displayedProducts = _filterProducts();
                              })
                          : null,
                    ),
                    Text(
                      'Page ${_currentPage + 1} of $totalPages',
                      style: const TextStyle(color: Colors.white),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.chevron_right, color: Colors.white),
                      onPressed: _currentPage < totalPages - 1
                          ? () => setState(() {
                                _currentPage++;
                                _displayedProducts = _filterProducts();
                              })
                          : null,
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.searchBarFocusNode.requestFocus();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockButton(String label, int count, Color color, String level) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      onPressed: () {
        setState(() {
          _selectedStockLevel = level == _selectedStockLevel ? 'all' : level;
          _displayedProducts = _filterProducts();
        });
      },
      child: Text(
        '$label ($count)',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildGroupAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
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
                      _searchQuery = selection.name;
                      _displayedProducts = _filterProducts();
                    });
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onEditingComplete) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Type to search groups',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 18,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: InputBorder.none,
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: const Color.fromRGBO(2, 10, 27, 1),
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
                                        color: Colors.white, fontSize: 18)),
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
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class Group {
  final String name;
  Group({required this.name});
}
