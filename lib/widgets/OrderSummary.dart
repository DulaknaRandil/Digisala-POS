import 'package:flutter/material.dart';
import 'package:paylink_pos/models/product_model.dart';
import 'package:paylink_pos/widgets/discount_calculator.dart';

class OrderSummary extends StatefulWidget {
  final List<Product> products;
  final Function() onClose;
  final Function() onPayment;
  final Function() onCashPayment;
  final Function() onCardPayment;

  const OrderSummary({
    Key? key,
    required this.products,
    required this.onClose,
    required this.onPayment,
    required this.onCashPayment,
    required this.onCardPayment,
    required void Function() onDiscount,
    required double discount,
  }) : super(key: key);

  @override
  _OrderSummaryState createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<OrderSummary> {
  double discount = 0.0;
  bool isPercentage = true;

  double get subtotal => widget.products
      .fold(0, (sum, product) => sum + (product.price * product.quantity));

  double get total =>
      subtotal + 345 + 525 - discount; // Example service charge and VAT

  void _openDiscountCalculator() {
    showDialog(
      context: context,
      builder: (context) {
        return DiscountCalculator(
          defaultIsPercentage: isPercentage,
          initialValue: isPercentage
              ? (discount / subtotal * 100).toStringAsFixed(2)
              : discount.toStringAsFixed(2),
          onDiscountSelected: (value, isPercent) {
            // Modified to accept two parameters
            setState(() {
              isPercentage = isPercent;
              if (isPercent) {
                discount =
                    (value / 100) * subtotal; // Calculate percentage discount
              } else {
                discount = value; // Direct amount discount
              }
            });
            Navigator.pop(context);
          },
          onClose: () => Navigator.pop(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header
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

              // Payment details container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order summary items
                    _buildSummaryItem(
                        'Discount', '${discount.toStringAsFixed(2)} LKR'),
                    _buildSummaryItem('Service Charge', '345.00 LKR'),
                    _buildSummaryItem(
                        'Subtotal', '${subtotal.toStringAsFixed(2)} LKR'),
                    _buildSummaryItem('VAT', '525.00 LKR'),
                    const Divider(color: Color(0xFFAFAFAF)),
                    _buildTotalItem('Total', '${total.toStringAsFixed(2)} LKR'),
                    const SizedBox(height: 20),

                    // Discount and Payment buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildButton('Discount', _openDiscountCalculator),
                        _buildButton('Payment', widget.onPayment),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        color: Color(0xFFAFAFAF),
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Payment method buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPaymentButton(
                          Icons.attach_money,
                          widget.onCashPayment,
                        ),
                        _buildPaymentButton(
                          Icons.credit_card,
                          widget.onCardPayment,
                        ),
                      ],
                    ),
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

  Widget _buildPaymentButton(IconData icon, Function() onPressed) {
    return Container(
      width: 100,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFAFAFAF), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        iconSize: 40,
      ),
    );
  }
}
