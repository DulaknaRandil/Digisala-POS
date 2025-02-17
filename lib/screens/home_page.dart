import 'dart:developer';
import 'dart:io';
import 'package:digisala_pos/utils/printer_service.dart';
import 'package:digisala_pos/utils/receipt_pdf.dart';
import 'package:digisala_pos/widgets/access_control.dart';
import 'package:digisala_pos/widgets/gnr_form.dart';
import 'package:digisala_pos/widgets/printerSelectionDialog.dart';
import 'package:digisala_pos/widgets/receipt_setup.dart';
import 'package:digisala_pos/widgets/settings_menu_button.dart';
import 'package:digisala_pos/widgets/supplier_form.dart';
import 'package:flutter/material.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/models/salesItem_model.dart';
import 'package:digisala_pos/models/sales_model.dart';
import 'package:digisala_pos/widgets/OrderSummary.dart';
import 'package:digisala_pos/widgets/ProductList.dart';
import 'package:digisala_pos/widgets/action_buttons.dart';
import 'package:digisala_pos/widgets/add_group.dart';
import 'package:digisala_pos/widgets/discount%20widgets/discount_manager.dart';
import 'package:digisala_pos/widgets/discount_calculator.dart';
import 'package:digisala_pos/widgets/footer.dart';
import 'package:digisala_pos/widgets/logo_component.dart';
import 'package:digisala_pos/widgets/new_product_form.dart';
import 'package:digisala_pos/widgets/payment%20widgets/payment_dialog.dart';
import 'package:digisala_pos/widgets/product_update.dart';
import 'package:digisala_pos/widgets/return_list.dart';
import 'package:digisala_pos/widgets/sales_history_dialog.dart' as salesHistory;
import 'package:digisala_pos/widgets/search_bar.dart' as custom;
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _products = [];
  List<Product> _checkoutList = [];
  final DiscountManager _discountManager = DiscountManager();
  final PrinterService _printerService = PrinterService();
  int _currentSalesId = 1;
  late FocusNode _searchBarFocusNode;

  @override
  void initState() {
    super.initState();
    _initializeSalesId();
    _loadProducts();
    _searchBarFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchBarFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _products = products;
    });
  }

  Future<void> _initializeSalesId() async {
    final latestSalesId = await DatabaseHelper.instance.getLatestSalesId();
    setState(() {
      _currentSalesId = latestSalesId + 1;
    });
  }

  void _addProductToCheckout(Product product) {
    setState(() {
      final existingProductIndex =
          _checkoutList.indexWhere((p) => p.id == product.id);

      if (existingProductIndex != -1) {
        // Allow adding decimal quantities
        if (_checkoutList[existingProductIndex].quantity < product.quantity) {
          _checkoutList[existingProductIndex].quantity +=
              1; // Example increment
        } else {
          _productaddshowSnackBar(
              'Cannot add more of ${product.name}, not enough stock.');
        }
      } else {
        if (product.quantity > 0) {
          product.quantity = 1; // Start with a decimal quantity
          _checkoutList.add(product);
        } else {
          _productaddshowSnackBar(
              'Cannot add ${product.name}, not enough stock.');
        }
      }
    });
  }

  void _updateProduct(Product product, double change) async {
    setState(() {
      product.quantity += change;
      if (product.quantity < 0.1) product.quantity = 0.1; // Minimum quantity
    });
    _loadProducts();
  }

  void _productaddshowSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _dbStatusshowSnackBar(String message, bool color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color ? Colors.green : Colors.red,
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _removeProduct(Product product) async {
    setState(() {
      _checkoutList.remove(product);
    });
    _loadProducts();
  }

  double _calculateSubtotal() {
    return _checkoutList.fold(
      0.0,
      (sum, product) => sum + (product.price * product.quantity),
    );
  }

  void _handleVoidOrder() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
          title: Text(
            'Confirm Void Order',
            style: TextStyle(color: Colors.white),
          ),
          content: Text('Are you sure you want to void the order?',
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _checkoutList.clear();
                  _discountManager.reset();
                });
                Navigator.of(context).pop();
                _searchBarFocusNode.requestFocus();
                print('Order has been voided.');
              },
              child: Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  double _calculateTotal() {
    // Calculate the subtotal by summing up the total price of each product in the checkout list
    final subtotal = _checkoutList.fold(
      0.0,
      (sum, product) => sum + (product.price * product.quantity),
    );

    // Calculate the total discount using the DiscountManager
    final discount = _discountManager.calculateDiscount(
      {
        for (var product in _checkoutList) product.id.toString(): product,
      },
    );

    // Return the total by subtracting the discount from the subtotal
    return subtotal - discount;
  }

  Future<void> _generatePdf(Sales sales, int salesId,
      List<Product> checkoutList, double paidAmount, double change) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Store Name: Your Store',
                  style: pw.TextStyle(fontSize: 18)),
              pw.Text('Address: 123 Main St',
                  style: pw.TextStyle(fontSize: 14)),
              pw.Text('Date: ${sales.date}', style: pw.TextStyle(fontSize: 14)),
              pw.Text('Time: ${sales.time}', style: pw.TextStyle(fontSize: 14)),
              pw.Text('Sales No: $salesId', style: pw.TextStyle(fontSize: 14)),
              pw.Divider(),
              ...checkoutList.map((product) => pw.Text(
                  '${product.name} x${product.quantity} - ${product.price * product.quantity} LKR')),
              pw.Divider(),
              pw.Text('Subtotal: ${sales.subtotal} LKR',
                  style: pw.TextStyle(fontSize: 14)),
              pw.Text('Discount: ${sales.discount} LKR',
                  style: pw.TextStyle(fontSize: 14)),
              pw.Text('Total: ${sales.total} LKR',
                  style: pw.TextStyle(fontSize: 14)),
              pw.Text('Paid: $paidAmount LKR',
                  style: pw.TextStyle(fontSize: 14)),
              pw.Text('Change: $change LKR', style: pw.TextStyle(fontSize: 14)),
              pw.Text('Payment Method: ${sales.paymentMethod}',
                  style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.Text('Thank you, come again!',
                  style: pw.TextStyle(fontSize: 14)),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/receipt_$salesId.pdf");
    await file.writeAsBytes(await pdf.save());

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );

    print('PDF generated at ${file.path}');
  }

  void _handlePayment(String paymentMethod) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PaymentDialog(
          total: _calculateTotal(),
          onPaidAmountChanged: (paidAmount) {
            print(_discountManager.calculateDiscount(
              {
                for (var product in _checkoutList)
                  product.id.toString(): product.price * product.quantity
              },
            ));
          },
          onClose: () {
            Navigator.of(context).pop();
          },
          onPrintReceipt: (double paidAmount, double balance) async {
            await _createSalesRecord(paymentMethod, balance, paidAmount);
            print('Print Receipt');
            Future.delayed(const Duration(seconds: 2), () {
              Navigator.of(context).pop();
            });
          },
          onPDF: (double paidAmount, double balance) async {
            final result =
                await _createSalesRecord(paymentMethod, balance, paidAmount);
            final sales = result['sales'];
            final salesId = result['salesId'];
            final checkoutList = result['checkoutList'];

            if (salesId != null) {
              await _generatePdf(
                  sales, salesId, checkoutList, paidAmount, balance);
            } else {
              print('Sales ID is null');
            }
            print('Generate PDF');
            Future.delayed(const Duration(seconds: 2), () {
              Navigator.of(context).pop();
            });
          },
          initialIsCashSelected: paymentMethod == 'Cash',
          onPaymentMethodChanged: (method) {
            paymentMethod = method;
          },
        );
      },
    );
  }

  Future<bool> _handleDatabaseExport() async {
    return await DatabaseHelper.instance.exportDatabase();
  }

  Future<bool> _handleDatabaseImport() async {
    return await DatabaseHelper.instance.importDatabase();
  }

  Future<Map<String, dynamic>> _createSalesRecord(
      String paymentMethod, double change, double paidAmount) async {
    final sales = Sales(
      date: DateTime.now(),
      time: TimeOfDay.now().format(context),
      paymentMethod: paymentMethod,
      subtotal: _calculateSubtotal(),
      discount: _discountManager.calculateDiscount(
        {
          for (var product in _checkoutList) product.id.toString(): product,
        },
      ),
      total: _calculateTotal(),
    );

    final salesId = await DatabaseHelper.instance.insertSales(sales);

    for (var product in _checkoutList) {
      final salesItem = SalesItem(
        salesId: salesId,
        name: product.name,
        quantity: product.quantity,
        price: product.price,
        buyingPrice: product.buyingPrice,
        discount: _discountManager.calculateItemDiscount(product.id.toString(),
            product.price * product.quantity, _calculateSubtotal(), product),
        total: product.price * product.quantity,
      );

      await DatabaseHelper.instance.insertSalesItem(salesItem);

      final originalProduct = _products.firstWhere((p) => p.id == product.id);
      originalProduct.quantity -= product.quantity;
      await DatabaseHelper.instance.updateProduct(originalProduct);
    }

    _printReceipt(sales, salesId, paidAmount, change, paymentMethod);

    final currentCheckoutList = List<Product>.from(_checkoutList);

    setState(() {
      _checkoutList.clear();
      _discountManager.reset();
      _searchBarFocusNode.requestFocus();
      _currentSalesId++;
    });

    return {
      'sales': sales,
      'salesId': salesId,
      'checkoutList': currentCheckoutList,
    };
  }

  Future<void> _printReceipt(Sales sales, int salesId, double paidAmount,
      double change, String paymentMethod) async {
    try {
      // Check if there's a selected printer
      if (_printerService.selectedPrinter == null) {
        _showSnackBar('Please select a printer first');
        _showPrinterSettingsDialog();
        return;
      }

      // Format items for printing
      final items = _checkoutList
          .map((product) => {
                'name': product.name,
                'quantity': product.quantity,
                'price': product.price,
              })
          .toList();

      // Load receipt setup and generate receipt
      final setupData = await _printerService.loadReceiptSetup();
      if (setupData.isEmpty) {
        _showSnackBar('Please configure receipt settings first');
        // Show receipt setup dialog
        await showDialog(
          context: context,
          builder: (context) => const ReceiptSetupDialog(),
        );
        return;
      }

      // Generate receipt bytes
      final bytes = await _printerService.generateReceipt(
        setupData,
        items,
        sales: sales,
        salesId: salesId,
        cashierName:
            'Cashier', // You might want to pass the actual cashier name

        paidAmount: paidAmount,
        change: change,
        paymentMethod: paymentMethod,
      );

      if (bytes.isEmpty) {
        _showSnackBar('Failed to generate receipt');
        return;
      }

      // Print the receipt
      await _printerService.printerPlugin.printData(
        _printerService.selectedPrinter!,
        bytes,
      );

      _showSnackBar('Receipt printed successfully');
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      _showSnackBar('Failed to print receipt: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleCashPayment() {
    _handlePayment('Cash');
  }

  void _handleCardPayment() {
    _handlePayment('Card');
  }

  void _showSalesHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return salesHistory.SalesHistoryDialog(
          searchBarFocusNode: _searchBarFocusNode,
        );
      },
    );
  }

  void _showReturnList() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReturnListDialog(
          searchBarFocusNode: _searchBarFocusNode,
        );
      },
    );
  }

  void _showDiscountCalculator() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DiscountCalculator(
          defaultIsPercentage: _discountManager.orderDiscountIsPercentage,
          initialValue: _discountManager.orderDiscountValue.toStringAsFixed(2),
          onDiscountSelected: (value, isPercent) {
            setState(() {
              _discountManager.setOrderDiscount(value, isPercent);
            });
            print('New Discount: $value');
            print('Is Percentage: $isPercent');
            Navigator.of(context).pop();
          },
          onClose: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void ThermalPrinterTestService(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => const ThermalPrinterDialog(),
    );
  }

  void _showNewProductForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProductForm(
          onSave: (productData) {
            print('New Product: $productData');
            Navigator.of(context).pushNamed('/dashboard');
          },
          onClose: () {
            Navigator.of(context).pop();
          },
          searchBarFocusNode: _searchBarFocusNode,
        );
      },
    );
  }

  void _showGroupForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GroupForm(
          searchBarFocusNode: _searchBarFocusNode,
        );
      },
    );
  }

  void _showProductUpdateForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProductUpdateForm(searchBarFocusNode: _searchBarFocusNode);
      },
    );
  }

  void _showGRNDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GRNForm(
          searchBarFocusNode: _searchBarFocusNode,
        );
      },
    );
  }

  void _showSupplierDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SupplierForm(
          searchBarFocusNode: _searchBarFocusNode,
        );
      },
    );
  }

  void _handleClose() {
    setState(() {
      _checkoutList.clear();
      _discountManager.reset();
    });
  }

  void _showUserAccessControl() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return UserAccessControlDialog();
      },
    );
  }

  void _showPrinterSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PrinterSettingsDialog();
      },
    );
  }

  void _showReceiptSetupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReceiptSetupDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                LogoComponent(
                  width: 100,
                  height: 80,
                  logoUrl: 'assets/logo.png',
                  backgroundColor: Color.fromRGBO(2, 10, 27, 1),
                ),
                custom.SearchBar(
                  onAddProduct: _addProductToCheckout,
                  focusNode: _searchBarFocusNode,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  color: const Color(0xFF2D2D2D),
                  popUpAnimationStyle: AnimationStyle(
                    curve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 200),
                  ),
                  icon: Icon(Icons.more_horiz_outlined,
                      size: 50, color: Colors.white),
                  onSelected: (value) async {
                    bool success;
                    switch (value) {
                      case 'Return Sales':
                        _showReturnList();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'Return Sales',
                      child: Text('Return Sales',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                SettingsMenuButton(
                  onPrinterSettings: _showPrinterSettingsDialog,
                  onReceiptSetup: _showReceiptSetupDialog,
                  onExportDatabase: _handleDatabaseExport,
                  onImportDatabase: _handleDatabaseImport,
                  onShowSnackBar: _dbStatusshowSnackBar,
                ),
              ],
            ),
            const Divider(color: Color(0xFF2D2D2D), thickness: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 25,
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: ProductList(
                          products: _checkoutList,
                          onQuantityChange: (String productId, double change) {
                            final product = _checkoutList.firstWhere(
                                (p) => p.id.toString() == productId);
                            _updateProduct(product, change);
                          },
                          onRemove: (String productId) {
                            final product = _checkoutList.firstWhere(
                                (p) => p.id.toString() == productId);
                            _removeProduct(product);
                          },
                          searchBarFocusNode: _searchBarFocusNode,
                        ),
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      ActionButtons(
                        onNewPressed: _showNewProductForm,
                        onGroupPressed: _showGroupForm,
                        onUpdatePressed: _showProductUpdateForm,
                        onHistoryPressed: _showSalesHistory,
                        onSecurityPressed: _showUserAccessControl,
                        onGRNPressed: _showGRNDialog,
                        onSuppliersPressed: _showSupplierDialog,
                      ),
                    ],
                  ),
                  const SizedBox(width: 70),
                  OrderSummary(
                    products: _checkoutList,
                    onClose: _handleVoidOrder,
                    onDiscount: _showDiscountCalculator,
                    onPayment: () => _handlePayment('Cash'),
                    onCashPayment: _handleCashPayment,
                    onCardPayment: _handleCardPayment,
                    discountManager: _discountManager,
                    salesId: _currentSalesId,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2D2D2D), thickness: 1),
            Footer(
              onVoidOrder: _handleVoidOrder,
              onPayment: () => _handlePayment('Cash'),
              requestFocusNode: _searchBarFocusNode,
              total: _calculateTotal(),
            ),
          ],
        ),
      ),
    );
  }
}
