import 'package:flutter/material.dart';
import 'package:paylink_pos/models/product_model.dart';
import 'package:paylink_pos/widgets/discount%20widgets/discount_manager.dart';
import 'package:paylink_pos/widgets/discount_calculator.dart';

class OrderSummary extends StatefulWidget {
  final List<Product> products;
  final Function() onClose;
  final Function() onPayment;
  final Function() onCashPayment;
  final Function() onCardPayment;
  final Function() onDiscount;
  final DiscountManager
      discountManager; // Use DiscountManager instead of discount

  const OrderSummary({
    Key? key,
    required this.products,
    required this.onClose,
    required this.onPayment,
    required this.onCashPayment,
    required this.onCardPayment,
    required this.onDiscount,
    required this.discountManager,
  }) : super(key: key);

  @override
  _OrderSummaryState createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<OrderSummary> {
  double get subtotal => widget.products
      .fold(0, (sum, product) => sum + product.price * product.quantity);

  double get totalDiscount {
    Map<String, double> items = {};
    for (var product in widget.products) {
      items[product.id.toString()] = product.price * product.quantity;
    }
    return widget.discountManager.calculateDiscount(items);
  }

  double get total => subtotal - totalDiscount;

  void _openItemDiscountCalculator(Product product) {
    if (product.price * product.quantity <= 0) return;

    final existingDiscount =
        widget.discountManager.itemDiscounts[product.id.toString()];

    showDialog(
      context: context,
      builder: (context) {
        return DiscountCalculator(
          defaultIsPercentage: existingDiscount?.isPercentage ?? true,
          initialValue: existingDiscount != null
              ? existingDiscount.value.toStringAsFixed(2)
              : '',
          onDiscountSelected: (value, isPercent) {
            setState(() {
              widget.discountManager
                  .setItemDiscount(product.id.toString(), value, isPercent);
            });
            Navigator.pop(context);
          },
          onClose: () => Navigator.pop(context),
        );
      },
    );
  }

  void _openOrderDiscountCalculator() {
    if (subtotal <= 0) return;

    showDialog(
      context: context,
      builder: (context) {
        return DiscountCalculator(
          defaultIsPercentage: widget.discountManager.orderDiscountIsPercentage,
          initialValue: widget.discountManager.orderDiscountValue > 0
              ? widget.discountManager.orderDiscountValue.toStringAsFixed(2)
              : '',
          onDiscountSelected: (value, isPercent) {
            setState(() {
              widget.discountManager.setOrderDiscount(value, isPercent);
            });
            print(
                'Order Discount Value: ${widget.discountManager.orderDiscountValue}');
            print(
                'Order Discount Is Percentage: ${widget.discountManager.orderDiscountIsPercentage}');
            Navigator.pop(context);
          },
          onClose: () => Navigator.pop(context),
        );
      },
    );
  }

  Widget _buildDiscountControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFAFAFAF)),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            children: [
              TextButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    !widget.discountManager.isItemMode
                        ? Colors.white.withAlpha(80)
                        : const Color(0xFF2D2D2D),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    if (widget.discountManager.isItemMode) {
                      widget.discountManager.toggleMode();
                    }
                  });
                },
                child: Text(
                  'Order',
                  style: TextStyle(
                    color: !widget.discountManager.isItemMode
                        ? Colors.white
                        : const Color(0xFFAFAFAF),
                  ),
                ),
              ),
              TextButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    widget.discountManager.isItemMode
                        ? Colors.white.withAlpha(80)
                        : const Color(0xFF2D2D2D),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    if (!widget.discountManager.isItemMode) {
                      widget.discountManager.toggleMode();
                    }
                  });
                },
                child: Text(
                  'Item',
                  style: TextStyle(
                    color: widget.discountManager.isItemMode
                        ? Colors.white
                        : const Color(0xFFAFAFAF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductList() {
    return Column(
      children: widget.products.map((product) {
        double itemTotal = product.price * product.quantity;
        double itemDiscount = widget.discountManager.calculateItemDiscount(
          product.id.toString(),
          itemTotal,
          subtotal,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${product.name} (${product.quantity}x)',
                  style: const TextStyle(
                    color: Color(0xFFAFAFAF),
                    fontSize: 16,
                  ),
                ),
              ),
              if (widget.discountManager.isItemMode)
                IconButton(
                  icon: const Icon(Icons.discount, color: Color(0xFFAFAFAF)),
                  onPressed: () => _openItemDiscountCalculator(product),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${itemTotal.toStringAsFixed(2)} LKR',
                    style: const TextStyle(
                      color: Color(0xFFAFAFAF),
                      fontSize: 16,
                    ),
                  ),
                  if (itemDiscount > 0)
                    Text(
                      '-${itemDiscount.toStringAsFixed(2)} LKR',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      widget.discountManager.reset();
    }

    return Expanded(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order : T7',
                    style: TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 22,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                    iconSize: 36,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.discountManager.isItemMode) _buildProductList(),
                    if (widget.discountManager.isItemMode)
                      const Divider(color: Color(0xFFAFAFAF)),
                    _buildSummaryItem(
                        'Subtotal', '${subtotal.toStringAsFixed(2)} LKR'),
                    if (totalDiscount > 0)
                      _buildSummaryItem('Discount',
                          '-${totalDiscount.toStringAsFixed(2)} LKR'),
                    const Divider(color: Color(0xFFAFAFAF)),
                    _buildTotalItem('Total', '${total.toStringAsFixed(2)} LKR'),
                    const SizedBox(height: 20),
                    _buildDiscountControls(),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildButton('Discount', _openOrderDiscountCalculator),
                        _buildButton('Payment', widget.onPayment),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFAFAFAF),
              fontSize: 16,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFAFAFAF),
              fontSize: 16,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFAFAFAF),
            fontSize: 22,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFAFAFAF),
            fontSize: 22,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String text, Function() onPressed) {
    return Container(
      width: 110,
      height: 45,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFAFAFAF), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFAFAFAF),
            fontSize: 18,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
