import 'dart:io';
import 'dart:typed_data';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/expense_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class ExpensesDialog extends StatefulWidget {
  final FocusNode searchBarFocusNode;

  const ExpensesDialog({required this.searchBarFocusNode});

  @override
  _ExpensesDialogState createState() => _ExpensesDialogState();
}

class _ExpensesDialogState extends State<ExpensesDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  late TabController _tabController;

  // Form controllers
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedTime = DateFormat('HH:mm').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExpenses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    _expenses = await DatabaseHelper.instance.getAllExpenses();
    _applyDateRangeFilter();
    setState(() => _isLoading = false);
  }

  void _applyDateRangeFilter() {
    _filteredExpenses = _expenses.where((expense) {
      return expense.date.isAfter(_startDate.subtract(Duration(days: 1))) &&
          expense.date.isBefore(_endDate.add(Duration(days: 1)));
    }).toList();

    if (_searchController.text.isNotEmpty) {
      _filteredExpenses = _filteredExpenses.where((expense) {
        return expense.category
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            expense.description
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            expense.id.toString().contains(_searchController.text);
      }).toList();
    }

    setState(() {});
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF1A2746),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Color(0xFF0A1428),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay currentTime = TimeOfDay.fromDateTime(DateTime.now());
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF1A2746),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Color(0xFF0A1428),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF1A2746),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Color(0xFF0A1428),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _applyDateRangeFilter();
      });
    }
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      final expense = Expense(
        date: _selectedDate,
        time: _selectedTime,
        category: _categoryController.text,
        description: _descriptionController.text,
        amount: double.parse(_amountController.text),
      );

      setState(() => _isLoading = true);
      await DatabaseHelper.instance.insertExpense(expense);
      await _loadExpenses();
      _clearForm();
      setState(() => _isLoading = false);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense saved successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Switch to view tab after saving
      _tabController.animateTo(1);
    }
  }

  void _clearForm() {
    _categoryController.clear();
    _descriptionController.clear();
    _amountController.clear();
    _selectedDate = DateTime.now();
    _selectedTime = DateFormat('HH:mm').format(DateTime.now());
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF0A1428),
        title: Text('Confirm Delete', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete this expense?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await DatabaseHelper.instance.deleteExpense(expense.id!);
      await _loadExpenses();
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense deleted'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _generatePdf() async {
    if (_filteredExpenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No expenses to generate report'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bytes = await _generateExpensesPdfContent();
      setState(() => _isLoading = false);

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'expenses_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      print('Error generating PDF: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Uint8List> _generateExpensesPdfContent() async {
    final pdf = pw.Document();
    final grnNumber =
        'EXP-${DateFormat('yyyyMMdd').format(DateTime.now())}-${_filteredExpenses.length}';
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

    // Footer Section
    pw.Widget buildFooter() {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 40),
        child: pw.Column(
          children: [
            pw.Divider(),
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

    // Item Table
    pw.Widget buildItemTable(List<Expense> items) {
      return pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1.5),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(2),
          4: const pw.FlexColumnWidth(3),
          5: const pw.FlexColumnWidth(1.5),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              'ID',
              'Date',
              'Time',
              'Category',
              'Description',
              'Amount (LKR)'
            ]
                .map((text) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(text,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ))
                .toList(),
          ),
          ...items
              .map((expense) => pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(expense.id.toString())),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                              DateFormat('yyyy-MM-dd').format(expense.date))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(expense.time)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(expense.category)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(expense.description)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(expense.amount.toStringAsFixed(2))),
                    ],
                  ))
              .toList(),
        ],
      );
    }

    // Calculate totals
    final totalAmount =
        _filteredExpenses.fold(0.0, (sum, expense) => sum + expense.amount);

    // Generate pages
    const itemsPerPage = 10;
    final totalPages = (_filteredExpenses.length / itemsPerPage).ceil();

    for (int page = 0; page < totalPages; page++) {
      final start = page * itemsPerPage;
      final end = (start + itemsPerPage < _filteredExpenses.length)
          ? start + itemsPerPage
          : _filteredExpenses.length;
      final currentItems = _filteredExpenses.sublist(start, end);

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
                pw.Text('Expenses Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Date Range: ${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                    style: pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 20),
                buildItemTable(currentItems),
                if (page == totalPages - 1) ...[
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Total Amount: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('LKR ${totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  buildFooter(),
                ],
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  margin: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(
                    'Page ${page + 1} of $totalPages',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Dialog(
        backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
        insetPadding: EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.85,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFF020A1B),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expense Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: Colors.white24),

              // Tabs
              Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Color(0xFF0A1428),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(25.0),
                    color: Colors.blue,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle),
                          SizedBox(width: 8),
                          Text('Add Expense'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt),
                          SizedBox(width: 8),
                          Text('View Expenses'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Tab Content
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Add Expense Tab
                          _buildAddExpenseTab(),

                          // View Expenses Tab
                          _buildViewExpensesTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddExpenseTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Expense Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),

              // Category Field
              TextFormField(
                controller: _categoryController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g., Utilities, Rent, Salary',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  labelStyle: TextStyle(color: Colors.white70),
                  hintStyle: TextStyle(color: Colors.white38),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Category is required' : null,
              ),
              SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of expense',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  labelStyle: TextStyle(color: Colors.white70),
                  hintStyle: TextStyle(color: Colors.white38),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Description is required' : null,
              ),
              SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter amount',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  labelStyle: TextStyle(color: Colors.white70),
                  hintStyle: TextStyle(color: Colors.white38),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Amount is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Date & Time Row
              Row(
                children: [
                  // Date Picker
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(_selectedDate),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),

                  // Time Picker
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Time',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          _selectedTime,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Clear Form',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: _clearForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton.icon(
                    icon: Icon(
                      Icons.save,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Save Expense',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: _saveExpense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewExpensesTab() {
    // Calculate total amount of filtered expenses
    double totalAmount =
        _filteredExpenses.fold(0, (sum, expense) => sum + expense.amount);

    return Column(
      children: [
        // Search & Filter Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.white),
                  onChanged: (value) => _applyDateRangeFilter(),
                  decoration: InputDecoration(
                    labelText: 'Search expenses',
                    hintText: 'Search by category or description',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              SizedBox(width: 12),
              OutlinedButton.icon(
                icon: Icon(
                  Icons.date_range,
                  color: Colors.white,
                ),
                label: Text(
                  'Date Range',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () => _selectDateRange(context),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                ),
              ),
              SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: _generatePdf,
                tooltip: 'Generate PDF Report',
              ),
            ],
          ),
        ),

        // Date Range Display
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Showing expenses from: ',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                DateFormat('yyyy-MM-dd').format(_startDate),
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                ' to ',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                DateFormat('yyyy-MM-dd').format(_endDate),
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Expense Count and Total
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Expenses: ${_filteredExpenses.length}',
                style: TextStyle(color: Colors.white),
              ),
              Text(
                'Total Amount: ${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Expenses Table
        Expanded(
          child: _filteredExpenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'No expenses found',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try adjusting your search or date range',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          MaterialStateProperty.all(Color(0xFF0A1428)),
                      dataRowColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.selected))
                            return Colors.blue.withOpacity(0.2);
                          if (states.contains(MaterialState.hovered))
                            return Colors.blue.withOpacity(0.1);
                          return Color(0xFF020A1B);
                        },
                      ),
                      border: TableBorder.all(color: Colors.white10),
                      columnSpacing: 16,
                      columns: [
                        DataColumn(
                          label: Text('ID',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          tooltip: 'Expense ID',
                        ),
                        DataColumn(
                          label: Text('Date',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          tooltip: 'Expense Date',
                        ),
                        DataColumn(
                          label: Text('Time',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          tooltip: 'Expense Time',
                        ),
                        DataColumn(
                          label: Text('Category',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          tooltip: 'Expense Category',
                        ),
                        DataColumn(
                          label: Text('Description',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          tooltip: 'Expense Description',
                        ),
                        DataColumn(
                          label: Text('Amount',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          tooltip: 'Expense Amount',
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('Actions',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          tooltip: 'Actions',
                        ),
                      ],
                      rows: _filteredExpenses.map((expense) {
                        return DataRow(
                          cells: [
                            DataCell(Text(
                              expense.id.toString(),
                              style: TextStyle(color: Colors.white),
                            )),
                            DataCell(Text(
                              DateFormat('yyyy-MM-dd').format(expense.date),
                              style: TextStyle(color: Colors.white),
                            )),
                            DataCell(Text(
                              expense.time,
                              style: TextStyle(color: Colors.white),
                            )),
                            DataCell(Text(
                              expense.category,
                              style: TextStyle(color: Colors.white),
                            )),
                            DataCell(Text(
                              expense.description,
                              style: TextStyle(color: Colors.white),
                            )),
                            DataCell(
                              Text(
                                expense.amount.toStringAsFixed(2),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteExpense(expense),
                                    tooltip: 'Delete Expense',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
