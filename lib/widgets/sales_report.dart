import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:digisala_pos/models/salesItem_model.dart';
import 'package:digisala_pos/models/sales_model.dart';
import 'package:digisala_pos/models/group_model.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';

import 'package:printing/printing.dart';

class SalesItemWithDate {
  final SalesItem item;
  final DateTime saleDate;
  final String category;

  SalesItemWithDate({
    required this.item,
    required this.saleDate,
    required this.category,
  });
}

class SalesReportDialog extends StatefulWidget {
  const SalesReportDialog({
    Key? key,
  }) : super(key: key);

  @override
  _SalesReportDialogState createState() => _SalesReportDialogState();
}

class _SalesReportDialogState extends State<SalesReportDialog> {
  List<SalesItemWithDate> _salesItemsList = [];
  List<String> _selectedFilters = [];
  List<String> _selectedCategories = [];
  DateTimeRange? _selectedDateRange;
  int _salesItemCount = 0;
  double _totalAmount = 0.0;
  List<String> _suggestions = [];
  List<Group> _categories = [];
  final PrinterService _printerService = PrinterService();
  // Add maps for quick lookups
  Map<String, List<String>> _categoryProducts = {};
  Map<String, String> _productCategories = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadCategories();
    await _loadProductCategories();
    await _loadSalesItems();
  }

  Future<void> _loadCategories() async {
    _categories = await DatabaseHelper.instance.getAllGroups();
    setState(() {});
  }

  Future<void> _loadProductCategories() async {
    List<Product> products = await DatabaseHelper.instance.getAllProducts();

    // Build category-products map
    _categoryProducts = {};
    _productCategories = {};

    for (var product in products) {
      if (!_categoryProducts.containsKey(product.productGroup)) {
        _categoryProducts[product.productGroup] = [];
      }
      _categoryProducts[product.productGroup]!.add(product.name);
      _productCategories[product.name] = product.productGroup;
    }
  }

  void _removeFilter(String filter) {
    setState(() {
      _selectedFilters.remove(filter);
    });
    _loadSalesItems();
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              surface: Color.fromRGBO(2, 10, 27, 1),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadSalesItems();
    }
  }

  Future<void> _loadSalesItems() async {
    try {
      List<Sales> allSales = await DatabaseHelper.instance.getAllSales();
      Map<int, DateTime> salesDates = {
        for (var sale in allSales)
          sale.id!: DateTime.parse(sale.date.toIso8601String())
      };

      List<SalesItem> salesItems =
          await DatabaseHelper.instance.getAllSalesItems();

      List<SalesItemWithDate> itemsWithDates = salesItems.map((item) {
        return SalesItemWithDate(
          item: item,
          saleDate: salesDates[item.salesId] ?? DateTime.now(),
          category: _productCategories[item.name] ?? 'Uncategorized',
        );
      }).toList();

      List<SalesItemWithDate> filteredItems =
          itemsWithDates.where((itemWithDate) {
        bool passDateRange = true;
        bool passSearch = true;
        bool passCategory = true;

        if (_selectedDateRange != null) {
          passDateRange =
              itemWithDate.saleDate.isAfter(_selectedDateRange!.start) &&
                  itemWithDate.saleDate.isBefore(
                      _selectedDateRange!.end.add(const Duration(days: 1)));
        }

        if (_selectedFilters.isNotEmpty) {
          passSearch = _selectedFilters.any((filter) {
            final lowerFilter = filter.toLowerCase();
            return itemWithDate.item.name.toLowerCase().contains(lowerFilter) ||
                itemWithDate.item.salesId
                    .toString()
                    .toLowerCase()
                    .contains(lowerFilter) ||
                itemWithDate.category.toLowerCase().contains(lowerFilter);
          });
        }

        if (_selectedCategories.isNotEmpty) {
          passCategory = _selectedCategories.contains(itemWithDate.category);
        }

        return passDateRange && passSearch && passCategory;
      }).toList();

      filteredItems.sort((a, b) => b.saleDate.compareTo(a.saleDate));

      setState(() {
        _salesItemsList = filteredItems;
        _updateSalesSummary();
      });
    } catch (e) {
      _showErrorDialog('Failed to load sales items: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _updateSalesSummary() {
    _salesItemCount = _salesItemsList.length;
    _totalAmount =
        _salesItemsList.fold(0.0, (sum, item) => sum + item.item.total);
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final lowerQuery = query.toLowerCase();
    Set<String> suggestions = {};

    // Add matching categories
    suggestions.addAll(_categories
        .where((category) => category.name.toLowerCase().contains(lowerQuery))
        .map((category) => "Category: ${category.name}"));

    // Add matching products
    suggestions.addAll(_productCategories.keys
        .where((product) => product.toLowerCase().contains(lowerQuery))
        .take(5));

    // Add matching sale IDs
    suggestions.addAll(_salesItemsList
        .map((item) => item.item.salesId.toString())
        .where((id) => id.toLowerCase().contains(lowerQuery))
        .map((id) => "Sale ID: $id")
        .take(3));

    setState(() {
      _suggestions = suggestions.take(8).toList();
    });
  }

  void _addFilter(String filter) {
    if (!_selectedFilters.contains(filter) && filter.isNotEmpty) {
      setState(() {
        if (filter.startsWith("Category: ")) {
          String category = filter.substring(10);
          _selectedCategories.add(category);
        } else if (filter.startsWith("Sale ID: ")) {
          _selectedFilters.add(filter.substring(9));
        } else {
          _selectedFilters.add(filter);
        }
        _searchController.clear();
        _suggestions = [];
      });
      _loadSalesItems();
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
    _loadSalesItems();
  }

  Future<void> _generateAndOpenPDF() async {
    try {
      final pdf = pw.Document();

      // Load receipt setup data from receipt_setup.json via your PrinterService.
      final receiptSetup = await _printerService.loadReceiptSetup();
      final storeName = receiptSetup['storeName'] ?? 'Store Name';
      final telephone = receiptSetup['telephone'] ?? 'N/A';
      final address = receiptSetup['address'] ?? '';
      final logoPath = receiptSetup['logoPath'];

      pw.MemoryImage? logoImage;
      if (logoPath != null && await File(logoPath).exists()) {
        final logoBytes = await File(logoPath).readAsBytes();
        logoImage = pw.MemoryImage(logoBytes);
      }

      // Generate a receipt number (for example, based on timestamp)
      //only date

      final receiptNumber = DateTime.now().toIso8601String().substring(0, 10);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Section: Logo, Store Name, Telephone and Receipt Number.
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Display logo if available.
                    if (logoImage != null)
                      pw.Container(
                        width: 80,
                        height: 80,
                        child: pw.Image(logoImage),
                      )
                    else
                      pw.Container(
                          width: 80, height: 80), // Placeholder if no logo.
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(storeName,
                            style: pw.TextStyle(
                                fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: $receiptNumber',
                            style: pw.TextStyle(fontSize: 12)),
                        pw.Text('Tel: $telephone',
                            style: pw.TextStyle(fontSize: 12)),
                        if (address.isNotEmpty)
                          pw.Text('Address: ${address}',
                              style: pw.TextStyle(fontSize: 12)),
                        pw.SizedBox(height: 20),
                        // Table Section for Sales Items
                      ],
                    ),
                  ],
                ),

                pw.Divider(color: PdfColors.grey),
                pw.SizedBox(height: 10),
                // Optionally display address or any other info.

                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  defaultVerticalAlignment:
                      pw.TableCellVerticalAlignment.middle,
                  children: [
                    // Table header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        for (final header in [
                          'Date',
                          'Item Name',
                          'Category',
                          'Sale ID',
                          'Qty',
                          'Unit Price',
                          'Discount',
                          'Total'
                        ])
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(header,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10)),
                          ),
                      ],
                    ),
                    // Data rows for each sales item.
                    ..._salesItemsList.map(
                      (item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                                item.saleDate.toString().split(' ')[0],
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item.item.name,
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item.category,
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item.item.salesId.toString(),
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item.item.quantity.toString(),
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item.item.price.toString(),
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item.item.discount.toString(),
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item.item.total.toString(),
                                style: const pw.TextStyle(fontSize: 10)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                // Summary Footer Section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Items: $_salesItemCount',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        'Total Amount: ${_totalAmount.toStringAsFixed(2)} LKR',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      // Save the PDF as bytes
      final pdfBytes = await pdf.save();

      // Get the current date for the filename
      final currentDate = DateTime.now();
      final formattedDate =
          "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";

      // Share the PDF using the Printing package
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'sales_report_$formattedDate.pdf',
      );

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generated and ready to share.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Handle any errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to generate PDF: ${e.toString()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      child: Container(
        width: 900,
        height: 750,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(color: Colors.white),
            _buildSearchAndFilterSection(),
            _buildFilterChips(),
            const SizedBox(height: 10),
            _buildSalesItemsTable(),
            const Divider(color: Colors.white),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Sales Report',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              label: const Text('Select Date Range',
                  style: TextStyle(color: Colors.white)),
              onPressed: _selectDateRange,
            ),
            IconButton(
              onPressed: _generateAndOpenPDF,
              icon: const Icon(Icons.picture_as_pdf,
                  color: Colors.white, size: 30),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _updateSuggestions,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Search by item name, category, or sale ID',
            labelStyle: const TextStyle(color: Colors.white),
            hintText: 'Type to search...',
            hintStyle: const TextStyle(color: Colors.white60),
            prefixIcon: const Icon(Icons.search, color: Colors.white),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                setState(() => _suggestions = []);
              },
            ),
            border: const OutlineInputBorder(),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: _suggestions
                  .map((suggestion) => ListTile(
                        title: Text(
                          suggestion,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () => _addFilter(suggestion),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        if (_selectedDateRange != null)
          Chip(
            label: Text(
              '${_selectedDateRange!.start.toString().split(' ')[0]} - ${_selectedDateRange!.end.toString().split(' ')[0]}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue,
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () {
              setState(() => _selectedDateRange = null);
              _loadSalesItems();
            },
          ),
        ..._selectedFilters.map((filter) => Chip(
              label: Text(filter, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.blue,
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => _removeFilter(filter),
            )),
        ..._selectedCategories.map((category) => Chip(
              label:
                  Text(category, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => _toggleCategory(category),
            )),
      ],
    );
  }

  Widget _buildSalesItemsTable() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[800]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              const Color.fromARGB(56, 131, 131, 128),
            ),
            dataRowColor: MaterialStateProperty.all(
              Colors.transparent,
            ),
            columns: const [
              DataColumn(
                label: Text('Date',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              DataColumn(
                label: Text('Item Name',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              DataColumn(
                label: Text('Category',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              DataColumn(
                label: Text('Sale ID',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              DataColumn(
                label: Text('Quantity',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              DataColumn(
                label: Text('Price',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              DataColumn(
                label: Text('Total',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
            rows: _salesItemsList
                .map((item) => DataRow(
                      cells: [
                        DataCell(Text(
                          item.saleDate.toString().split(' ')[0],
                          style: const TextStyle(color: Colors.white),
                        )),
                        DataCell(Text(
                          item.item.name,
                          style: const TextStyle(color: Colors.white),
                        )),
                        DataCell(Text(
                          item.category,
                          style: const TextStyle(color: Colors.white),
                        )),
                        DataCell(Text(
                          item.item.salesId.toString(),
                          style: const TextStyle(color: Colors.white),
                        )),
                        DataCell(Text(
                          item.item.quantity.toString(),
                          style: const TextStyle(color: Colors.white),
                        )),
                        DataCell(Text(
                          item.item.price.toString(),
                          style: const TextStyle(color: Colors.white),
                        )),
                        DataCell(Text(
                          item.item.total.toString(),
                          style: const TextStyle(color: Colors.white),
                        )),
                      ],
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Items: $_salesItemCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Total Amount: ${_totalAmount.toStringAsFixed(2)} LKR',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
