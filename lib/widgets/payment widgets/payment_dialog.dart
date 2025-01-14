import 'package:flutter/material.dart';
import 'package:digisala_pos/widgets/logo_component.dart';

class PaymentDialog extends StatefulWidget {
  final double total;
  final Function(double) onPaidAmountChanged;
  final VoidCallback onClose;
  final Function onPrintReceipt;
  final Function(double, double) onPDF;
  final bool initialIsCashSelected;
  final Function(String) onPaymentMethodChanged; // Add this line

  const PaymentDialog({
    Key? key,
    this.total = 0,
    required this.onPaidAmountChanged,
    required this.onClose,
    required this.onPrintReceipt,
    required this.onPDF,
    this.initialIsCashSelected = true,
    required this.onPaymentMethodChanged, // Add this line
  }) : super(key: key);

  @override
  _PaymentDialogState createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  double paidAmount = 0;
  final TextEditingController _paidController = TextEditingController();
  bool showAnimation = false;
  bool isPaymentSuccessful = true;
  late bool isCashSelected;

  @override
  void initState() {
    super.initState();
    isCashSelected = widget.initialIsCashSelected;
    _paidController.addListener(_updatePaidAmount);
  }

  void _updatePaidAmount() {
    if (_paidController.text.isNotEmpty) {
      setState(() {
        paidAmount = double.tryParse(_paidController.text) ?? 0;
        widget.onPaidAmountChanged(paidAmount);
      });
    }
  }

  double get balance => paidAmount - widget.total;

  void _showPaymentAnimation(bool success) {
    setState(() {
      showAnimation = true;
      isPaymentSuccessful = success;
    });
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        showAnimation = false;
      });
    });
  }

  void _togglePaymentMethod(bool isCash) {
    setState(() {
      isCashSelected = isCash;
      widget.onPaymentMethodChanged(isCash ? 'Cash' : 'Card'); // Notify parent
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SingleChildScrollView(
          child: Dialog(
            backgroundColor: const Color(0xFF121315),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            child: Container(
              width: 897,
              height: 701,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close button and header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 446, height: 36),
                      IconButton(
                        icon: Image.asset(
                          'assets/cross_1.png',
                          width: 36,
                          height: 36,
                        ),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Payment method toggle
                  Center(
                    child: Container(
                      width: 307,
                      height: 45,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF434343),
                        borderRadius: BorderRadius.circular(51),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _togglePaymentMethod(true),
                              child: Container(
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isCashSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(55),
                                ),
                                child: Center(
                                  child: Text(
                                    'Cash',
                                    style: TextStyle(
                                      color: isCashSelected
                                          ? const Color(0xFF313131)
                                          : Colors.white,
                                      fontSize: 18,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _togglePaymentMethod(false),
                              child: Container(
                                height: 34,
                                decoration: BoxDecoration(
                                  color: !isCashSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(55),
                                ),
                                child: Center(
                                  child: Text(
                                    'Card',
                                    style: TextStyle(
                                      color: !isCashSelected
                                          ? const Color(0xFF313131)
                                          : Colors.white,
                                      fontSize: 18,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Amount details
                  _buildAmountRow(
                      'Total :', widget.total, const Color(0xFFF1F5F9)),
                  if (isCashSelected) ...[
                    const SizedBox(height: 30),
                    _buildPaidAmountRow(),
                    const SizedBox(height: 30),
                    _buildAmountRow('Balance :', balance,
                        balance >= 0 ? const Color(0xFFD3E955) : Colors.red),
                  ],
                  const Spacer(),
                  // Footer buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LogoComponent(
                        width: 100,
                        height: 80,
                        logoUrl: 'assets/logo.png',
                        backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
                      ),
                      const Spacer(),
                      Container(
                        width: 200,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextButton(
                          onPressed: () {
                            widget.onPrintReceipt(paidAmount, balance);
                            _showPaymentAnimation(
                                true); // Show success animation
                          },
                          child: const Text(
                            'Print Receipt',
                            style: TextStyle(
                              color: Color(0xFF313131),
                              fontSize: 24,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 180),
                      Container(
                        width: 100,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextButton(
                          onPressed: () {
                            widget.onPDF(paidAmount, balance);
                            _showPaymentAnimation(
                                true); // Show success animation
                          },
                          child: const Text(
                            'PDF',
                            style: TextStyle(
                              color: Color(0xFF313131),
                              fontSize: 24,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showAnimation)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Icon(
                  isPaymentSuccessful ? Icons.check_circle : Icons.error,
                  color: isPaymentSuccessful ? Colors.green : Colors.red,
                  size: 100,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAmountRow(String label, double amount, Color amountColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 176,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF949391),
              fontSize: 24,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        Text(
          '${amount.toStringAsFixed(2)} LKR',
          style: TextStyle(
            color: amountColor,
            fontSize: 40,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 100),
      ],
    );
  }

  Widget _buildPaidAmountRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 176,
          child: Text(
            'Paid :',
            style: const TextStyle(
              color: Color(0xFF949391),
              fontSize: 24,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 300,
          child: TextField(
            textDirection: TextDirection.ltr,
            controller: _paidController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Color(0xFF55E9A7),
              fontSize: 40,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
            onChanged: (value) {
              setState(() {
                paidAmount = double.tryParse(value) ?? 0.0;
              });
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '0',
              hintStyle: TextStyle(
                color: Color(0xFF55E9A7),
                fontSize: 40,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
              suffixText: 'LKR',
              suffixStyle: TextStyle(
                color: Color(0xFF55E9A7),
                fontSize: 40,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 100),
      ],
    );
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }
}
