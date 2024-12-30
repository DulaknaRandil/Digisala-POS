import 'package:flutter/material.dart';
import 'package:paylink_pos/models/product_model.dart';
import 'package:paylink_pos/widgets/OrderSummary.dart';
import 'package:paylink_pos/widgets/ProductList.dart';
import 'package:paylink_pos/widgets/action_buttons.dart';
import 'package:paylink_pos/widgets/add_group.dart';
import 'package:paylink_pos/widgets/discount_calculator.dart';
import 'package:paylink_pos/widgets/footer.dart';
import 'package:paylink_pos/widgets/logo_component.dart';
import 'package:paylink_pos/widgets/new_product_form.dart';
import 'package:paylink_pos/widgets/product_update.dart';
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
  double _discount = 0.0;
  bool _isPercentageDiscount = true;

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

  void _handlePayment() {
    print('Processing payment...');
  }

  void _handleCashPayment() {
    print('Processing cash payment...');
  }

  void _handleCardPayment() {
    print('Processing card payment...');
  }

  double _calculateActualDiscount() {
    if (_isPercentageDiscount) {
      return (_discount / 100) * _calculateSubtotal();
    }
    return _discount;
  }

  void _showDiscountCalculator() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DiscountCalculator(
          defaultIsPercentage: _isPercentageDiscount,
          initialValue: _isPercentageDiscount
              ? _discount.toStringAsFixed(2)
              : _discount.toStringAsFixed(2),
          onDiscountSelected: (value, isPercent) {
            setState(() {
              _discount = value;
              _isPercentageDiscount = isPercent;
            });
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
        return GroupForm(); // Show the GroupForm dialog
      },
    );
  }

  void _showProductUpdateForm() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProductUpdateForm(); // Show the ProductUpdateForm dialog
      },
    );
  }

  void _handleClose() {
    setState(() {
      _checkoutList.clear();
      _discount = 0.0;
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
                        onUpdatePressed:
                            _showProductUpdateForm, // Update button action
                        onHistoryPressed: () {},
                        onSecurityPressed: () {},
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
                    discount: _calculateActualDiscount(),
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
