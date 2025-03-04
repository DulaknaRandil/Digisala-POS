import 'dart:io';
import 'dart:typed_data';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
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
  Map<int, String> _supplierDiscounts = {};
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
      final bytes = await _generateStockUpdatesPdfContent();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'stock_updates_${DateFormat('yyyyMMdd').format(_startDate)}-${DateFormat('yyyyMMdd').format(_endDate)}.pdf',
      );
    } catch (e) {
      print('Error generating PDF: $e');
      _showSnackBar('Error generating PDF', Colors.red);
    }
  }

  Future<void> _printStockUpdates() async {
    try {
      final bytes = await _generateStockUpdatesPdfContent();
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
      );
    } catch (e) {
      print('Error printing: $e');
      _showSnackBar('Error printing report', Colors.red);
    }
  }

  Future<Uint8List> _generateStockUpdatesPdfContent() async {
    final pdf = pw.Document();
    final currentYear = DateTime.now().year;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Load receipt setup data
    final receiptSetup = await PrinterService().loadReceiptSetup();
    final storeName = receiptSetup['storeName'] ?? 'Store Name';
    final telephone = receiptSetup['telephone'] ?? 'N/A';
    final address = receiptSetup['address'] ?? '';
    final logoPath = receiptSetup['logoPath'];

    // Load store logo
    pw.MemoryImage? logoImage;
    if (logoPath != null && await File(logoPath).exists()) {
      final logoBytes = await File(logoPath).readAsBytes();
      logoImage = pw.MemoryImage(logoBytes);
    }

    // Header Section
    pw.Widget buildHeader() {
      return pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(
                  width: 80,
                  height: 80,
                  child: pw.Image(logoImage),
                )
              else
                pw.Container(width: 80, height: 80),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(storeName,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: $date', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Tel: $telephone', style: pw.TextStyle(fontSize: 12)),
                  if (address.isNotEmpty)
                    pw.Text('Address: $address',
                        style: pw.TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
        ],
      );
    }

    // Footer Section
    pw.Widget buildFooter() {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 40),
        child: pw.Column(
          children: [
            pw.Divider(),
            pw.Text('© $currentYear Digisala POS. All rights reserved',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
      );
    }

    // Item Table
    pw.Widget buildItemTable(List<Map<String, dynamic>> items) {
      return pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.5),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FlexColumnWidth(1.5),
          5: const pw.FlexColumnWidth(1.5),
          6: const pw.FlexColumnWidth(1.5),
          7: const pw.FlexColumnWidth(1.5),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              'Date/Time',
              'Name',
              'Supplier',
              'Barcode',
              'Qty Added',
              'Buy Price',
              'Sell Price',
              'Profit'
            ]
                .map((text) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(text,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ))
                .toList(),
          ),
          ...items
              .map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item['updateDate'])),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item['productName'])),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item['supplier']?.toString() ?? '')),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item['barcode'])),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item['quantityAdded'].toString())),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child:
                              pw.Text(item['buyingPrice'].toStringAsFixed(2))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child:
                              pw.Text(item['sellingPrice'].toStringAsFixed(2))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item['profit'].toStringAsFixed(2))),
                    ],
                  ))
              .toList(),
        ],
      );
    }

    // Generate pages
    const itemsPerPage = 10;
    final totalPages = (_stockUpdates.length / itemsPerPage).ceil();

    for (int page = 0; page < totalPages; page++) {
      final start = page * itemsPerPage;
      final end = (start + itemsPerPage < _stockUpdates.length)
          ? start + itemsPerPage
          : _stockUpdates.length;
      final currentItems = _stockUpdates.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildHeader(),
                pw.SizedBox(height: 10),
                pw.Text('Stock Updates Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(
                    'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                    style: pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 20),
                buildItemTable(currentItems),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  margin: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    'Page ${page + 1} of $totalPages',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
                if (page == totalPages - 1) buildFooter(),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
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

// Add these new methods to the _GRNFormState class
  void _showDiscountDialog() async {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
            title: Text(
              "Enter Supplier Discounts",
              style: TextStyle(color: Colors.white),
            ),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _stockUpdates.length,
                itemBuilder: (context, index) {
                  final item = _stockUpdates[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            item['productName'],
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            style: TextStyle(color: Colors.white),
                            initialValue:
                                _supplierDiscounts[item['productId']] ?? '',
                            decoration: InputDecoration(
                              labelText: 'Discount',
                              labelStyle: TextStyle(color: Colors.white),
                              hintText: 'e.g., 10% or 50',
                              hintStyle: TextStyle(color: Colors.grey),
                              fillColor: Colors.white,
                              focusColor: Colors.white,
                              hoverColor: Colors.green,
                              helperStyle: TextStyle(color: Colors.white),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              floatingLabelStyle:
                                  TextStyle(color: Colors.white),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _supplierDiscounts[item['productId']] = value;
                            },
                            validator: (value) {
                              if (value?.isNotEmpty ?? false) {
                                final cleanValue =
                                    value!.replaceAll('%', '').trim();
                                if (double.tryParse(cleanValue) == null) {
                                  return 'Invalid value';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.red)),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ElevatedButton(
                style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.green)),
                onPressed: () {
                  if (_validateDiscounts()) {
                    Navigator.pop(context);
                    _generateGnrReport();
                  }
                },
                child: Text('Generate Report',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _validateDiscounts() {
    for (var entry in _supplierDiscounts.entries) {
      final value = entry.value;
      if (value.isNotEmpty) {
        final cleanValue = value.replaceAll('%', '').trim();
        if (double.tryParse(cleanValue) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Invalid discount value for product ID ${entry.key}')),
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<Uint8List> _generateGnrPdfContent() async {
    final pdf = pw.Document();
    final grnNumber =
        'GRN-${DateFormat('yyyyMMdd').format(DateTime.now())}-${_stockUpdates.length}';
    final preparedBy = 'Inventory Manager';
    final currentYear = DateTime.now().year;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Load receipt setup data
    final receiptSetup = await PrinterService().loadReceiptSetup();
    final storeName = receiptSetup['storeName'] ?? 'Store Name';
    final telephone = receiptSetup['telephone'] ?? 'N/A';
    final address = receiptSetup['address'] ?? '';
    final logoPath = receiptSetup['logoPath'];

    // Load store logo
    pw.MemoryImage? logoImage;
    if (logoPath != null && await File(logoPath).exists()) {
      final logoBytes = await File(logoPath).readAsBytes();
      logoImage = pw.MemoryImage(logoBytes);
    }

    // Load Digisala logo
    pw.MemoryImage? digisalaLogoImage;
    final digisalaLogoPath = 'assets/logo.png';
    if (await File(digisalaLogoPath).exists()) {
      final logoBytes = await File(digisalaLogoPath).readAsBytes();
      digisalaLogoImage = pw.MemoryImage(logoBytes);
    }

    // Header Section
    pw.Widget buildHeader() {
      return pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(
                  width: 80,
                  height: 80,
                  child: pw.Image(logoImage),
                )
              else
                pw.Container(width: 80, height: 80),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(storeName,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: $date', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Tel: $telephone', style: pw.TextStyle(fontSize: 12)),
                  if (address.isNotEmpty)
                    pw.Text('Address: $address',
                        style: pw.TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
        ],
      );
    }

    // Supplier Information (only on first page)
    pw.Widget buildSupplierInfo() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Supplier Details:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Row(
              children: [
                pw.Text('GRN Number: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(grnNumber),
                pw.Spacer(),
                pw.Text('Date: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd-MMM-yyyy').format(DateTime.now())),
              ],
            ),
          ],
        ),
      );
    }

    // Item Table for a subset of items
    pw.Widget buildItemTable(List<Map<String, dynamic>> items) {
      return pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(1.2), // Unit Price
          5: const pw.FlexColumnWidth(1.3), // Discount
          6: const pw.FlexColumnWidth(1.5), // Total
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              'Item Code',
              'Description',
              'Supplier',
              'Qty',
              'Unit Price (LKR)',
              'Discount', // New column
              'Total (LKR)'
            ]
                .map((text) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(text,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ))
                .toList(),
          ),
          ...items.map((item) {
            final discount = _supplierDiscounts[item['productId']] ?? '0%';
            final (discountValue, isPercentage) = _parseDiscount(discount);
            final buyingPrice = item['buyingPrice'] as double;
            final quantity = item['quantityAdded'] as double;
            final total = (buyingPrice * quantity) -
                (isPercentage
                    ? (buyingPrice * quantity * discountValue / 100)
                    : discountValue);

            return pw.TableRow(
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(item['productId'].toString())),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(item['productName'])),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(item['supplier']?.toString() ?? '')),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(quantity.toStringAsFixed(2))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(buyingPrice.toStringAsFixed(2))),
                // New Discount Cell
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(discount)), // Display entered discount
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(total.toStringAsFixed(2))),
              ],
            );
          }).toList(),
        ],
      );
    }

    // Totals Section
    pw.Widget buildTotals() {
      final grandTotal = _stockUpdates.fold(0.0, (sum, item) {
        final discount = _supplierDiscounts[item['productId']] ?? '';
        final (discountValue, isPercentage) = _parseDiscount(discount);
        final buyingPrice = item['buyingPrice'] as double;
        final quantity = item['quantityAdded'] as double;
        return sum +
            (buyingPrice * quantity) -
            (isPercentage
                ? (buyingPrice * quantity * discountValue / 100)
                : discountValue);
      });

      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Grand Total: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('LKR ${grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
    }

    // Authorization Section
    pw.Widget buildAuthorization() {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 40),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Column(
              children: [
                pw.Text('Prepared By:'),
                pw.SizedBox(height: 20),
                pw.Text('_________________________'),
                pw.Text(preparedBy),
              ],
            ),
            pw.Column(
              children: [
                pw.Text('Authorized By:'),
                pw.SizedBox(height: 20),
                pw.Text('_________________________'),
                pw.Text('Signature & Stamp'),
              ],
            ),
          ],
        ),
      );
    }

    // Footer Section
    pw.Widget buildFooter() {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 40),
        child: pw.Column(
          children: [
            pw.Divider(),
            pw.Text('Terms & Conditions:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('1. Goods received in good condition'),
            pw.Text('2. Shortages must be reported within 48 hours'),
            pw.Text('3. Prices subject to verification'),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (digisalaLogoImage != null)
                  pw.Container(
                    height: 30,
                    child: pw.Image(digisalaLogoImage),
                  ),
                pw.Text(
                  '© $currentYear Digisala POS. All rights reserved',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Generate Item Pages
    const itemsPerPage = 10;
    final totalPages = (_stockUpdates.length / itemsPerPage).ceil();

    for (int page = 0; page < totalPages; page++) {
      final start = page * itemsPerPage;
      final end = (start + itemsPerPage < _stockUpdates.length)
          ? start + itemsPerPage
          : _stockUpdates.length;
      final currentItems = _stockUpdates.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildHeader(),
                if (page == 0) ...[
                  buildSupplierInfo(),
                  pw.SizedBox(height: 20),
                ],
                buildItemTable(currentItems),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  margin: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    'Page ${page + 1} of ${totalPages + 1}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // Final Page with Totals, Authorization, and Footer
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader(),
              buildTotals(),
              buildAuthorization(),
              buildFooter(),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(top: 10),
                child: pw.Text(
                  'Page ${totalPages + 1} of ${totalPages + 1}',
                  style: pw.TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _generateGnrReport() async {
    try {
      final bytes = await _generateGnrPdfContent();
      final dateStamp = DateFormat('yyyyMMdd').format(DateTime.now());
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'gnr_report_$dateStamp.pdf',
      );
    } catch (e) {
      print('Error generating GNR report: $e');
      _showSnackBar('Error generating GNR report', Colors.red);
    }
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
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
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
        ),
        Divider(color: Colors.white),
        // PDF and Print icons placed below the divider.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.assignment, color: Colors.white),
                onPressed: _showDiscountDialog,
                tooltip: 'Generate GNR Report',
              ),
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
