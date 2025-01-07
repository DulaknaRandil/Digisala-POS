import 'package:flutter/material.dart';
import 'package:digisala_pos/models/return_model.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReturnListDialog extends StatelessWidget {
  final FocusNode searchBarFocusNode;
  const ReturnListDialog({Key? key, required this.searchBarFocusNode})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
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
                  'Return List',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pop();
                      searchBarFocusNode.requestFocus();
                    }),
              ],
            ),
            const Divider(color: Colors.white),
            Expanded(
              child: FutureBuilder<List<Return>>(
                future: DatabaseHelper.instance.getAllReturns(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final returnList = snapshot.data!;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(
                            label: Text('Return Date',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Return Time',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Name',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Sales Item ID',
                                style: TextStyle(color: Colors.white))),
                        DataColumn(
                            label: Text('Quantity',
                                style: TextStyle(color: Colors.white))),
                      ],
                      rows: returnList.map((returnItem) {
                        final dateTime = DateTime.parse(returnItem.returnDate);
                        final date = DateFormat('yyyy-MM-dd').format(dateTime);
                        final time = DateFormat('HH:mm:ss').format(dateTime);
                        return DataRow(cells: [
                          DataCell(Text(date,
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(time,
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(returnItem.name,
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(returnItem.salesItemId.toString(),
                              style: const TextStyle(color: Colors.white))),
                          DataCell(Text(returnItem.quantity.toString(),
                              style: const TextStyle(color: Colors.white))),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _generatePdfAndPrint(context),
                  child: const Text('Print PDF'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    searchBarFocusNode.requestFocus();
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

  Future<void> _generatePdfAndPrint(BuildContext context) async {
    final pdf = pw.Document();

    final returnList = await DatabaseHelper.instance.getAllReturns();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Return List', style: pw.TextStyle(fontSize: 24)),
            pw.Divider(),
            pw.Table.fromTextArray(
              context: context,
              data: <List<String>>[
                <String>[
                  'Return Date',
                  'Return Time',
                  'Name',
                  'Sales Item ID',
                  'Quantity'
                ],
                ...returnList.map((item) {
                  final dateTime = DateTime.parse(item.returnDate);
                  final date = DateFormat('yyyy-MM-dd').format(dateTime);
                  final time = DateFormat('HH:mm:ss').format(dateTime);
                  return [
                    date,
                    time,
                    item.name,
                    item.salesItemId.toString(),
                    item.quantity.toString(),
                  ];
                })
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
