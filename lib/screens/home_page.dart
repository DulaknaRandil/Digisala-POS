import 'package:flutter/material.dart';
import 'package:paylink_pos/models/product_model.dart';
import 'package:paylink_pos/models/salesItem_model.dart';
import 'package:paylink_pos/models/sales_model.dart';
import 'package:paylink_pos/widgets/OrderSummary.dart';
import 'package:paylink_pos/widgets/ProductList.dart';
import 'package:paylink_pos/widgets/action_buttons.dart';
import 'package:paylink_pos/widgets/add_group.dart';
import 'package:paylink_pos/widgets/discount%20widgets/discount_manager.dart';
import 'package:paylink_pos/widgets/discount_calculator.dart';
import 'package:paylink_pos/widgets/footer.dart';
import 'package:paylink_pos/widgets/logo_component.dart';
import 'package:paylink_pos/widgets/new_product_form.dart';
import 'package:paylink_pos/widgets/payment%20widgets/payment_dialog.dart';
import 'package:paylink_pos/widgets/product_update.dart';
import 'package:paylink_pos/widgets/return_list.dart';
import 'package:paylink_pos/widgets/sales_history_dialog.dart' as salesHistory;
import 'package:paylink_pos/widgets/search_bar.dart' as custom;
import 'package:paylink_pos/database/product_db_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _products = [];
  List<Product> _checkoutList = [];
  final DiscountManager _discountManager = DiscountManager();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _products = products;
    });
  }

  void _addProductToCheckout(Product product) {
    setState(() {
      product.quantity = 1; // Set initial quantity to 1
      _checkoutList.add(product);
    });
    print('Product added: ${product.name}');
  }

  void _updateProduct(Product product, int change) async {
    setState(() {
      product.quantity += change;
      if (product.quantity < 1)
        product.quantity = 1; // Ensure quantity is at least 1
    });
    _loadProducts();
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

  double _calculateTotal() {
    final subtotal = _calculateSubtotal();
    final discount = _discountManager.calculateDiscount(
      {
        for (var product in _checkoutList)
          product.id.toString(): product.price * product.quantity
      },
    );
    return subtotal - discount;
  }

  void _handlePayment() {
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
          onPrintReceipt: () {
            _createSalesRecord('Cash');
            print('Print Receipt');
          },
          onPDF: () {
            _createSalesRecord('Card');
            print('Generate PDF');
          },
        );
      },
    );
  }

  void _createSalesRecord(String paymentMethod) async {
    final sales = Sales(
      date: DateTime.now(),
      time: TimeOfDay.now().format(context),
      paymentMethod: paymentMethod,
      subtotal: _calculateSubtotal(),
      discount: _discountManager.calculateDiscount(
        {
          for (var product in _checkoutList)
            product.id.toString(): product.price * product.quantity
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
        discount: _discountManager.calculateItemDiscount(
          product.id.toString(),
          product.price * product.quantity,
          _calculateSubtotal(),
        ),
        total: product.price * product.quantity,
      );

      await DatabaseHelper.instance.insertSalesItem(salesItem);

      final originalProduct = _products.firstWhere((p) => p.id == product.id);
      originalProduct.quantity -= product.quantity;
      await DatabaseHelper.instance.updateProduct(originalProduct);
    }

    _printReceipt(sales, salesId);
  }

  void _printReceipt(Sales sales, int salesId) {
    print('Printing Receipt...');
    print('Store Name: Your Store');
    print('Address: 123 Main St');
    print('Date: ${sales.date}');
    print('Time: ${sales.time}');
    print('Sales No: $salesId');
    print('--------------------------------');
    for (var product in _checkoutList) {
      print(
          '${product.name} x${product.quantity} - ${product.price * product.quantity} LKR');
    }
    print('--------------------------------');
    print('Subtotal: ${sales.subtotal} LKR');
    print('Discount: ${sales.discount} LKR');
    print('Total: ${sales.total} LKR');
    print('Payment Method: ${sales.paymentMethod}');
    print('Thank you, come again!');
  }

  void _handleCashPayment() {
    print('Processing cash payment...');
  }

  void _handleCardPayment() {
    print('Processing card payment...');
  }

  void _showSalesHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const salesHistory.SalesHistoryDialog();
      },
    );
  }

  void _showReturnList() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const ReturnListDialog();
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

  void _showNewProductForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return NewProductForm(
          onSave: (productData) {
            print('New Product: $productData');
            Navigator.of(context).pushNamed('/dashboard');
          },
          onClose: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _showGroupForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GroupForm();
      },
    );
  }

  void _showProductUpdateForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProductUpdateForm();
      },
    );
  }

  void _handleClose() {
    setState(() {
      _checkoutList.clear();
      _discountManager.reset();
    });
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
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadProducts,
                  icon: Icon(Icons.settings_applications_outlined),
                  iconSize: 50,
                  color: Colors.white,
                ),
              ],
            ),
            const Divider(color: Color(0xFF2D2D2D), thickness: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                  ),
                  Column(
                    children: [
                      Expanded(
                        child: ProductList(
                          products: _checkoutList,
                          onQuantityChange: (String productId, int change) {
                            final product = _checkoutList.firstWhere(
                                (p) => p.id.toString() == productId);
                            _updateProduct(product, change);
                          },
                          onRemove: (String productId) {
                            final product = _checkoutList.firstWhere(
                                (p) => p.id.toString() == productId);
                            _removeProduct(product);
                          },
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      ActionButtons(
                        onNewPressed: _showNewProductForm,
                        onGroupPressed: _showGroupForm,
                        onUpdatePressed: _showProductUpdateForm,
                        onHistoryPressed: _showSalesHistory,
                        onSecurityPressed: _showReturnList,
                      ),
                    ],
                  ),
                  const SizedBox(width: 40),
                  OrderSummary(
                    products: _checkoutList,
                    onClose: _handleClose,
                    onDiscount: _showDiscountCalculator,
                    onPayment: _handlePayment,
                    onCashPayment: _handleCashPayment,
                    onCardPayment: _handleCardPayment,
                    discountManager:
                        _discountManager, // Pass the DiscountManager
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2D2D2D), thickness: 1),
            const Footer(),
          ],
        ),
      ),
    );
  }
}
