import 'dart:io';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class GRNForm extends StatefulWidget {
  final FocusNode searchBarFocusNode;
  GRNForm({required this.searchBarFocusNode});

  @override
  _GRNFormState createState() => _GRNFormState();
}

class _GRNFormState extends State<GRNForm> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  // Use a Map to associate each product ID with its TextEditingController.
  Map<int, TextEditingController> _quantityControllers = {};

  // For filtering in stock updates.
  final _searchController = TextEditingController();
  // For filtering in the update stock tab.
  final _productSearchController = TextEditingController();

  List<Map<String, dynamic>> _stockUpdates = [];

  // Date range for filtering stock updates.
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  // Map of supplierId to supplier name.
  Map<int, String> _supplierMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // First load suppliers so we can use their names.
    _loadSuppliers().then((_) {
      _loadProducts();
      _loadStockUpdates();
    });
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    setState(() {
      _supplierMap = {for (var s in suppliers) s.id!: s.name};
    });
  }

  (double, bool) _parseDiscount(String discount) {
    final cleanDiscount = discount.replaceAll('%', '').trim();
    final value = double.tryParse(cleanDiscount) ?? 0;
    final isPercentage = discount.contains('%');
    return (value, isPercentage);
  }

  double _calculateTotalDiscount(
      double price, double quantity, String discount) {
    final (discountValue, isPercentage) = _parseDiscount(discount);
    if (isPercentage) {
      return price * (discountValue / 100) * quantity;
    } else {
      return discountValue * quantity;
    }
  }

  double _applyDiscount(
      double originalPrice, double discount, bool isPercentage) {
    if (isPercentage) {
      return originalPrice * (1 - (discount / 100));
    } else {
      return originalPrice - discount;
    }
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _products = products;
      _filteredProducts = products;
      _quantityControllers.clear();
      for (var product in products) {
        _quantityControllers[product.id!] = TextEditingController(text: '0');
      }
    });
  }

  /// IMPORTANT:
  /// Make sure you add a method in your DatabaseHelper to query stock updates by date range.
  /// For example: getStockUpdatesByDateRange(DateTime start, DateTime end)
  Future<void> _loadStockUpdates() async {
    setState(() => _isLoading = true);
    try {
      final updates = await DatabaseHelper.instance
          .getStockUpdatesByDateRange(_startDate, _endDate);
      final List<Map<String, dynamic>> detailedUpdates = [];

      for (var update in updates) {
        final product =
            await DatabaseHelper.instance.getProductById(update['productId']);
        if (product != null) {
          // Replace the existing profit calculation with:
          final (discountValue, isPercentage) =
              _parseDiscount(product.discount);
          final discountedPrice =
              _applyDiscount(product.price, discountValue, isPercentage);
          final profit =
              (discountedPrice - product.buyingPrice) * update['quantityAdded'];
          // Look up the supplier name from _supplierMap using supplierId.
          final supplierName = _supplierMap[product.supplierId] != null
              ? _supplierMap[product.supplierId]
              : '';
          detailedUpdates.add({
            ...update,
            'productName': product.name,
            'barcode': product.barcode,
            'supplier': supplierName,
            'buyingPrice': product.buyingPrice,
            'sellingPrice': product.price,
            'discount': product.discount,
            'totalDiscount': _calculateTotalDiscount(
                product.price, update['quantityAdded'], product.discount),
            'profit': profit,
            'updateDate': DateFormat('yyyy-MM-dd HH:mm')
                .format(DateTime.parse(update['updateDate'])),
          });
        }
      }

      setState(() {
        _stockUpdates = detailedUpdates;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stock updates: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error loading stock updates', Colors.red);
    }
  }

  Future<void> _generateAndDownloadPDF() async {
    try {
      final pdf = pw.Document();

      // Add title and date range info.
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Stock Updates Report',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
                'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'Date/Time',
                'ID',
                'Name',
                'Barcode',
                'Supplier',
                'Updated Stock',
                'Discount',
                'Total Discount', // New column
                'Buying Price',
                'Selling Price',
                'Profit'
              ],
              data: _stockUpdates
                  .map((update) => [
                        update['updateDate'],
                        update['productId'].toString(),
                        update['productName'],
                        update['barcode'],
                        update['supplier'],
                        update['quantityAdded'].toString(),
                        update['discount'], // New data
                        update['totalDiscount'].toStringAsFixed(2), // New data
                        update['buyingPrice'].toString(),
                        update['sellingPrice'].toString(),
                        update['profit'].toStringAsFixed(2),
                      ])
                  .toList(),
            ),
          ],
        ),
      );
// in  to save to selected dictionary

      final output = await getDownloadsDirectory();
      final file = File(
          '${output?.path}/stock_updates_${DateFormat('yyyyMMdd').format(_startDate)}-${DateFormat('yyyyMMdd').format(_endDate)}.pdf');
      await file.writeAsBytes(await pdf.save());

      _showSnackBar('PDF saved to ${file.path}', Colors.green);
    } catch (e) {
      print('Error generating PDF: $e');
      _showSnackBar('Error generating PDF', Colors.red);
    }
  }

  Future<void> _printStockUpdates() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Stock Updates Report',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
                'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'Date/Time',
                'ID',
                'Name',
                'Barcode',
                'Supplier',
                'Updated Stock',
                'Discount',
                'Total Discount', // New column
                'Buying Price',
                'Selling Price',
                'Profit'
              ],
              data: _stockUpdates
                  .map((update) => [
                        update['updateDate'],
                        update['productId'].toString(),
                        update['productName'],
                        update['barcode'],
                        update['supplier'],
                        update['quantityAdded'].toString(),
                        update['discount'], // New data
                        update['totalDiscount'].toStringAsFixed(2), // New data
                        update['buyingPrice'].toString(),
                        update['sellingPrice'].toString(),
                        update['profit'].toStringAsFixed(2),
                      ])
                  .toList(),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      print('Error printing: $e');
      _showSnackBar('Error printing report', Colors.red);
    }
  }

  void _filterStockUpdates(String query) {
    if (query.isEmpty) {
      _loadStockUpdates();
      return;
    }
    setState(() {
      _stockUpdates = _stockUpdates.where((update) {
        return update['productName']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            update['barcode']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            update['productId'].toString().contains(query) ||
            (update['supplier'] != null &&
                update['supplier']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()));
      }).toList();
    });
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _products;
      });
      return;
    }
    setState(() {
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase()) ||
            product.barcode.toLowerCase().contains(query.toLowerCase()) ||
            product.id.toString().contains(query) ||
            // Lookup the supplier name using supplierId.
            (_supplierMap[product.supplierId] != null &&
                _supplierMap[product.supplierId]!
                    .toLowerCase()
                    .contains(query.toLowerCase()));
      }).toList();
    });
  }

  Future<void> _updateStock(Product product) async {
    final controller = _quantityControllers[product.id];
    if (_formKey.currentState!.validate()) {
      final quantity = double.tryParse(controller?.text ?? '0') ?? 0;
      if (quantity == 0) {
        _showSnackBar('Enter a quantity greater than 0', Colors.red);
        return;
      }
      setState(() {
        product.quantity += quantity;
      });
      await DatabaseHelper.instance.updateProduct(product);
      await DatabaseHelper.instance.insertStockUpdate(product.id!, quantity);
      _showSnackBar('Stock updated successfully!', Colors.green);
      _loadStockUpdates();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Widget _buildStockUpdateTab() {
    return Column(
      children: [
        // Search and date range picker row.
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by ID, name, barcode, or supplier',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Colors.white),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _filterStockUpdates,
                ),
              ),
              SizedBox(width: 16),
              TextButton.icon(
                icon: Icon(Icons.date_range, color: Colors.white),
                label: Text(
                  '${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  final pickedRange = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange:
                        DateTimeRange(start: _startDate, end: _endDate),
                  );
                  if (pickedRange != null) {
                    setState(() {
                      _startDate = pickedRange.start;
                      _endDate = pickedRange.end;
                    });
                    _loadStockUpdates();
                  }
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    // In _buildStockUpdateTab():
                    columns: const [
                      DataColumn(
                          label: Text('Date/Time',
                              style: TextStyle(color: Colors.white))),
                      DataColumn(
                          label: Text('ID',
                              style: TextStyle(color: Colors.white))),
                      DataColumn(
                          label: Text('Name',
                              style: TextStyle(color: Colors.white))),
                      DataColumn(
                          label: Text('Barcode',
                              style: TextStyle(color: Colors.white))),
                      DataColumn(
                          label: Text('Supplier',
                              style: TextStyle(color: Colors.white))),
                      DataColumn(
                          label: Text('Qty Added',
                              style: TextStyle(color: Colors.white))),
                      // New
                      DataColumn(
                          label: Text('Buy Price',
                              style: TextStyle(color: Colors.white))),
                      DataColumn(
                          label: Text('Sell Price',
                              style: TextStyle(color: Colors.white))),
                      DataColumn(
                          label: Text('Discount',
                              style: TextStyle(color: Colors.white))), // New
                      DataColumn(
                          label: Text('Total Disc.',
                              style: TextStyle(color: Colors.white))),
                      DataColumn(
                          label: Text('Profit',
                              style: TextStyle(color: Colors.white))),
                    ],
                    rows: _stockUpdates.map((update) {
                      return DataRow(
                        cells: [
                          DataCell(Text(update['updateDate'],
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['productId'].toString(),
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['productName'],
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['barcode'],
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['supplier'],
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['quantityAdded'].toString(),
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['buyingPrice'].toString(),
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['sellingPrice'].toString(),
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['discount'].toString(),
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['totalDiscount'].toString(),
                              style: TextStyle(color: Colors.white))),
                          DataCell(Text(update['profit'].toStringAsFixed(2),
                              style: TextStyle(color: Colors.white))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        Divider(color: Colors.white),
        // PDF and Print icons placed below the divider.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.print, color: Colors.white),
                onPressed: _printStockUpdates,
                tooltip: 'Print Report',
              ),
              IconButton(
                icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: _generateAndDownloadPDF,
                tooltip: 'Download PDF',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateStockTab() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Search field for filtering products.
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _productSearchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by ID, name, barcode, or supplier',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterProducts,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(
                      label: Text('Product',
                          style: TextStyle(color: Colors.white))),
                  DataColumn(
                      label: Text('Current Quantity',
                          style: TextStyle(color: Colors.white))),
                  DataColumn(
                      label: Text('Add Quantity',
                          style: TextStyle(color: Colors.white))),
                  DataColumn(
                      label: Text('Supplier',
                          style: TextStyle(color: Colors.white))),
                  DataColumn(
                      label: Text('Actions',
                          style: TextStyle(color: Colors.white))),
                ],
                rows: _filteredProducts.map((product) {
                  return DataRow(
                    cells: [
                      DataCell(Text(product.name,
                          style: TextStyle(color: Colors.white))),
                      DataCell(Text(product.quantity.toString(),
                          style: TextStyle(color: Colors.white))),
                      DataCell(
                        TextFormField(
                          controller: _quantityControllers[product.id],
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              const InputDecoration(border: InputBorder.none),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter quantity';
                            }
                            return null;
                          },
                        ),
                      ),
                      // Use the supplier name from _supplierMap based on supplierId.
                      DataCell(Text(_supplierMap[product.supplierId] ?? '',
                          style: TextStyle(color: Colors.white))),
                      DataCell(
                        IconButton(
                          icon: Icon(Icons.update, color: Colors.green),
                          onPressed: () => _updateStock(product),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF020A1B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header and close button.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stock Management',
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
                  },
                ),
              ],
            ),
            // Tab bar for Update Stock and Stock Updates.
            TabBar(
              indicatorColor: Color.fromARGB(255, 197, 196, 196),
              labelColor: Color.fromARGB(255, 197, 196, 196),
              controller: _tabController,
              tabs: const [
                Tab(
                  text: 'Update Stock',
                ),
                Tab(text: 'Stock Updates'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUpdateStockTab(),
                  _buildStockUpdateTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _productSearchController.dispose();
    _quantityControllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }
}
