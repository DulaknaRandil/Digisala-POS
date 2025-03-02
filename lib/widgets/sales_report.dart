import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/models/return_model.dart';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:digisala_pos/models/salesItem_model.dart';
import 'package:digisala_pos/models/sales_model.dart';
import 'package:digisala_pos/models/group_model.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';

import 'package:printing/printing.dart';

class SalesItemWithDate {
  final SalesItem item;
  final DateTime saleDate;
  final String category;
  final double refundQuantity;

  SalesItemWithDate({
    required this.item,
    required this.saleDate,
    required this.category,
    required this.refundQuantity,
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
  int _currentPage = 0;
  final int _itemsPerPage = 10;
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

      // Get all returns
      List<Return> allReturns = await DatabaseHelper.instance.getAllReturns();

      List<SalesItemWithDate> itemsWithDates = salesItems.map((item) {
        // Calculate total refund for this item
        double totalRefund = allReturns
            .where((r) => r.salesItemId == item.id)
            .fold(0.0, (sum, r) => sum + r.quantity);

        return SalesItemWithDate(
          item: item,
          saleDate: salesDates[item.salesId] ?? DateTime.now(),
          category: _productCategories[item.name] ?? 'Uncategorized',
          refundQuantity: totalRefund, // Add refund quantity
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
    _totalAmount = _salesItemsList.fold(0.0, (sum, item) {
      final netQty = item.item.quantity - item.refundQuantity;
      final unitPrice = item.item.price;
      final discountPerUnit = item.item.discount / item.item.quantity;

      return sum + (netQty * unitPrice) - (netQty * discountPerUnit);
    });
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

      // Load receipt setup data
      final receiptSetup = await _printerService.loadReceiptSetup();
      final storeName = receiptSetup['storeName'] ?? 'Store Name';
      final telephone = receiptSetup['telephone'] ?? 'N/A';
      final address = receiptSetup['address'] ?? '';
      final logoPath = receiptSetup['logoPath'];

      // Load logo image
      pw.MemoryImage? logoImage;
      if (logoPath != null && await File(logoPath).exists()) {
        final logoBytes = await File(logoPath).readAsBytes();
        logoImage = pw.MemoryImage(logoBytes);
      }

      final currentYear = DateTime.now().year;
      final date = DateTime.now().toIso8601String().substring(0, 10);
      const itemsPerPage = 20;
      final totalPages = (_salesItemsList.length / itemsPerPage).ceil();

      // Add pages only if there are items
      if (_salesItemsList.isNotEmpty) {
        for (int pageNum = 0; pageNum < totalPages; pageNum++) {
          final startIndex = pageNum * itemsPerPage;
          final endIndex = (startIndex + itemsPerPage < _salesItemsList.length)
              ? startIndex + itemsPerPage
              : _salesItemsList.length;
          final pageItems = _salesItemsList.sublist(startIndex, endIndex);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(24),
              build: (pw.Context context) {
                return pw.Column(
                  children: [
                    // Header Section
                    _buildPdfHeader(
                        logoImage, storeName, date, telephone, address),
                    pw.SizedBox(height: 10),
                    _buildPdfTable(pageItems),
                    pw.SizedBox(height: 10),
                    _buildPdfFooter(pageNum + 1, totalPages, currentYear),
                  ],
                );
              },
            ),
          );
        }
      } else {
        // Add empty state page
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Text('No sales data found',
                    style: const pw.TextStyle(fontSize: 24)),
              );
            },
          ),
        );
      }

      // Save and share the PDF
      final pdfBytes = await pdf.save();
      final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'sales_report_$formattedDate.pdf',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated and ready to share.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  pw.Widget _buildPdfHeader(
    pw.MemoryImage? logoImage,
    String storeName,
    String date,
    String telephone,
    String address,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            logoImage != null
                ? pw.Container(
                    width: 60,
                    height: 60,
                    child: pw.Image(logoImage),
                  )
                : pw.Container(),
            pw.Text('Sales Report',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(storeName,
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: $date', style: pw.TextStyle(fontSize: 10)),
            pw.Text('Tel: $telephone', style: pw.TextStyle(fontSize: 10)),
            if (address.isNotEmpty)
              pw.Text('Address: $address', style: pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfTable(List<SalesItemWithDate> pageItems) {
    return pw.Expanded(
      child: pw.Table.fromTextArray(
        context: null, // Remove context to prevent layout issues
        border: pw.TableBorder.all(width: 0.5),
        headerDecoration: pw.BoxDecoration(
          color: PdfColors.grey300,
        ),
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
        cellStyle: const pw.TextStyle(
          fontSize: 9,
        ),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.5),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FlexColumnWidth(1),
          5: const pw.FlexColumnWidth(1.5),
          6: const pw.FlexColumnWidth(1.5),
          7: const pw.FlexColumnWidth(1.5),
          8: const pw.FlexColumnWidth(1.5),
          9: const pw.FlexColumnWidth(2),
        },
        headers: [
          'Date',
          'Item Name',
          'Category',
          'Sale ID',
          'Qty',
          'Return Qty',
          'Net Qty',
          'Discount',
          'Price',
          'Total',
        ],
        data: pageItems.map((item) {
          final netQty = item.item.quantity - item.refundQuantity;
          final discount = (netQty / item.item.quantity) * item.item.discount;
          final total = (netQty * item.item.price) - discount;

          return [
            DateFormat('yyyy-MM-dd').format(item.saleDate),
            item.item.name,
            item.category,
            item.item.salesId.toString(),
            item.item.quantity.toStringAsFixed(2),
            item.refundQuantity.toStringAsFixed(2),
            netQty.toStringAsFixed(2),
            discount.toStringAsFixed(2),
            item.item.price.toStringAsFixed(2),
            total.toStringAsFixed(2),
          ];
        }).toList(),
      ),
    );
  }

  pw.Widget _buildPdfFooter(int currentPage, int totalPages, int currentYear) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Page $currentPage of $totalPages',
                style: const pw.TextStyle(fontSize: 10)),
            if (currentPage == totalPages)
              pw.Text(
                  'Total Net Amount: ${_totalAmount.toStringAsFixed(2)} LKR',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Center(
          child: pw.Text(
            '© $currentYear Digisala POS. All rights reserved',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      child: Container(
        width: 1300,
        height: 750,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(color: Colors.white),
            _buildSearchAndFilterSection(),
            const Divider(color: Colors.white),
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
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginatedItems = _salesItemsList.sublist(
      startIndex,
      endIndex.clamp(0, _salesItemsList.length),
    );
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
                  label: Text('Return Qty',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('Net Qty',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('Discount',
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
              rows: paginatedItems // Changed from _salesItemsList
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
                            item.refundQuantity.toStringAsFixed(2),
                            style: const TextStyle(color: Colors.white),
                          )),
                          DataCell(Text(
                            (item.item.quantity - item.refundQuantity)
                                .toStringAsFixed(2),
                            style: const TextStyle(color: Colors.white),
                          )),
                          DataCell(Text(
                            ((item.item.quantity - item.refundQuantity) *
                                    (item.item.discount / (item.item.quantity)))
                                .toString(),
                            style: const TextStyle(color: Colors.white),
                          )),
                          DataCell(Text(
                            item.item.price.toString(),
                            style: const TextStyle(color: Colors.white),
                          )),
                          DataCell(Text(
                            ((item.item.quantity - item.refundQuantity) *
                                        item.item.price -
                                    (item.item.discount *
                                        ((item.item.quantity -
                                                item.refundQuantity) /
                                            item.item.quantity)))
                                .toStringAsFixed(2),
                            style: const TextStyle(color: Colors.white),
                          )),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final totalPages = (_salesItemsList.length / _itemsPerPage).ceil();
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
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              Text(
                'Page ${_currentPage + 1} of $totalPages',
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
          Text(
            'Total Net Amount: ${_totalAmount.toStringAsFixed(2)} LKR',
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
