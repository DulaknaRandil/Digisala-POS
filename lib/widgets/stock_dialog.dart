import 'package:flutter/material.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/utils/pdf_service_stock.dart';

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
    });
  }

  List<Product> _filterProducts() {
    List<Product> filtered = _products.where((product) {
      if (_selectedGroup == 'Group' && _searchQuery.isNotEmpty) {
        return product.productGroup
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
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

  void _resetFilters() {
    setState(() {
      _selectedGroup = 'All';
      _searchQuery = '';
      _selectedStockLevel = 'all';
      _currentPage = 0;
      _displayedProducts = _filterProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stock levels for all filtered products, not just displayed ones
    final allFilteredProducts = _products.where((product) {
      if (_selectedGroup == 'Group' && _searchQuery.isNotEmpty) {
        return product.productGroup
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
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
      backgroundColor: Color.fromRGBO(2, 10, 27, 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _displayedProducts = _filterProducts();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: _selectedGroup == 'Group'
                          ? 'Search by group'
                          : 'Search by name, barcode, or ID',
                      hintStyle: const TextStyle(color: Colors.white54),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
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
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    const Color.fromARGB(56, 131, 131, 128),
                  ),
                  columns: const [
                    DataColumn(
                        label:
                            Text('ID', style: TextStyle(color: Colors.white))),
                    DataColumn(
                        label: Text('Name',
                            style: TextStyle(color: Colors.white))),
                    DataColumn(
                        label: Text('Quantity',
                            style: TextStyle(color: Colors.white))),
                    DataColumn(
                        label: Text('Group',
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
                        DataCell(Text(product.name,
                            style: const TextStyle(color: Colors.white))),
                        DataCell(Text('${product.quantity}',
                            style: const TextStyle(color: Colors.white))),
                        DataCell(Text(product.productGroup,
                            style: const TextStyle(color: Colors.white))),
                      ],
                    );
                  }).toList(),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      totalPages,
                      (index) => TextButton(
                        onPressed: () {
                          setState(() {
                            _currentPage = index;
                            _displayedProducts = _filterProducts();
                          });
                        },
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: _currentPage == index
                                ? Colors.lightBlue
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
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

  List<String> _getUniqueGroups() {
    return _products.map((product) => product.productGroup).toSet().toList();
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
}
