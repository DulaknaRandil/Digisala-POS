import 'package:flutter/material.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/delete_sale_item_model.dart';
import 'package:digisala_pos/models/delete_sale_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class DeleteSalesHistoryDialog extends StatefulWidget {
  const DeleteSalesHistoryDialog({Key? key}) : super(key: key);

  @override
  _DeleteSalesHistoryDialogState createState() =>
      _DeleteSalesHistoryDialogState();
}

class _DeleteSalesHistoryDialogState extends State<DeleteSalesHistoryDialog> {
  List<DeleteSale> _allDeleteSales = [];
  List<DeleteSale> _filteredSales = [];
  List<DeleteSaleItem> _deleteSalesItems = [];

  // Pagination
  int _currentPage = 1;
  final int _rowsPerPage = 10;

  // Date filtering
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadDeleteSales();
  }

  Future<void> _loadDeleteSales() async {
    final sales = await DatabaseHelper.instance.getAllDeleteSales();
    setState(() {
      _allDeleteSales = sales;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var filtered = List<DeleteSale>.from(_allDeleteSales);

    if (_startDate != null) {
      filtered = filtered.where((sale) {
        final saleDate = DateFormat('yyyy-MM-dd').parse(sale.date);
        return saleDate.isAfter(_startDate!) ||
            saleDate.isAtSameMomentAs(_startDate!);
      }).toList();
    }

    if (_endDate != null) {
      filtered = filtered.where((sale) {
        final saleDate = DateFormat('yyyy-MM-dd').parse(sale.date);
        return saleDate.isBefore(_endDate!) ||
            saleDate.isAtSameMomentAs(_endDate!);
      }).toList();
    }

    setState(() {
      _filteredSales = filtered;
      _currentPage = 1;
    });
  }

  Future<void> _loadDeleteSalesItems(int deleteSaleId) async {
    final items =
        await DatabaseHelper.instance.getDeleteSaleItems(deleteSaleId);
    setState(() {
      _deleteSalesItems = items;
    });
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            children: [
              pw.Header(text: 'Deleted Sales Report'),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['ID', 'Date', 'Time', 'Payment', 'Total', 'Stock Updated'],
                  ..._filteredSales
                      .map((sale) => [
                            sale.id.toString(),
                            sale.date,
                            sale.time,
                            sale.paymentMethod,
                            sale.total.toString(),
                            sale.stockUpdated ? 'Yes' : 'No',
                          ])
                      .toList(),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'deleted_sales_report.pdf');
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
            _buildFilterSection(),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: 300, // Fixed height for first table
                      child: _buildDeleteSalesTable(),
                    ),
                    const Divider(color: Colors.white),
                    SizedBox(
                      height: 250, // Fixed height for second table
                      child: _buildDeleteSalesItemsTable(),
                    ),
                  ],
                ),
              ),
            ),
            _buildPagination(),
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
          'Deleted Sales History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              onPressed: _generatePDF,
              tooltip: 'Export to PDF',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Row(
      children: [
        TextButton.icon(
          icon: const Icon(Icons.calendar_today, color: Colors.white),
          label: Text(
            _startDate == null
                ? 'Start Date'
                : DateFormat('yyyy-MM-dd').format(_startDate!),
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _startDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                _startDate = date;
                _applyFilters();
              });
            }
          },
        ),
        const SizedBox(width: 10),
        TextButton.icon(
          icon: const Icon(Icons.calendar_today, color: Colors.white),
          label: Text(
            _endDate == null
                ? 'End Date'
                : DateFormat('yyyy-MM-dd').format(_endDate!),
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _endDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                _endDate = date;
                _applyFilters();
              });
            }
          },
        ),
        const SizedBox(width: 10),
        TextButton.icon(
          icon: const Icon(Icons.clear, color: Colors.white),
          label: const Text('Clear Filters',
              style: TextStyle(color: Colors.white)),
          onPressed: () {
            setState(() {
              _startDate = null;
              _endDate = null;
              _applyFilters();
            });
          },
        ),
      ],
    );
  }

  Widget _buildDeleteSalesTable() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    final paginatedSales =
        _filteredSales.skip(startIndex).take(_rowsPerPage).toList();

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(
          const Color.fromARGB(56, 131, 131, 128),
        ),
        columns: const [
          DataColumn(label: Text('ID', style: TextStyle(color: Colors.white))),
          DataColumn(
              label: Text('Date', style: TextStyle(color: Colors.white))),
          DataColumn(
              label: Text('Time', style: TextStyle(color: Colors.white))),
          DataColumn(
              label: Text('Payment', style: TextStyle(color: Colors.white))),
          DataColumn(
              label: Text('Total', style: TextStyle(color: Colors.white))),
          DataColumn(
              label:
                  Text('Stock Updated', style: TextStyle(color: Colors.white))),
        ],
        rows: paginatedSales.map((sale) {
          return DataRow(
            cells: [
              DataCell(Text('${sale.id}',
                  style: const TextStyle(color: Colors.white))),
              DataCell(
                  Text(sale.date, style: const TextStyle(color: Colors.white))),
              DataCell(
                  Text(sale.time, style: const TextStyle(color: Colors.white))),
              DataCell(Text(sale.paymentMethod,
                  style: const TextStyle(color: Colors.white))),
              DataCell(Text('${sale.total}',
                  style: const TextStyle(color: Colors.white))),
              DataCell(Text(
                sale.stockUpdated ? 'Yes' : 'No',
                style: TextStyle(
                    color: sale.stockUpdated ? Colors.green : Colors.red),
              )),
            ],
            onSelectChanged: (selected) {
              if (selected == true) {
                _loadDeleteSalesItems(sale.id!);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeleteSalesItemsTable() {
    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(
          const Color.fromARGB(56, 131, 131, 128),
        ),
        columns: const [
          DataColumn(
              label: Text('Name', style: TextStyle(color: Colors.white))),
          DataColumn(
              label: Text('Quantity', style: TextStyle(color: Colors.white))),
          DataColumn(
              label: Text('Price', style: TextStyle(color: Colors.white))),
          DataColumn(
              label: Text('Total', style: TextStyle(color: Colors.white))),
        ],
        rows: _deleteSalesItems.map((item) {
          return DataRow(
            cells: [
              DataCell(
                  Text(item.name, style: const TextStyle(color: Colors.white))),
              DataCell(Text('${item.quantity}',
                  style: const TextStyle(color: Colors.white))),
              DataCell(Text('${item.price}',
                  style: const TextStyle(color: Colors.white))),
              DataCell(Text('${item.total}',
                  style: const TextStyle(color: Colors.white))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_filteredSales.length / _rowsPerPage).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
        ),
        Text(
          'Page $_currentPage of $totalPages',
          style: const TextStyle(color: Colors.white),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white),
          onPressed: _currentPage < totalPages
              ? () => setState(() => _currentPage++)
              : null,
        ),
      ],
    );
  }
}
