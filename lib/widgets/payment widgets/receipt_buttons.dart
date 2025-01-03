import 'package:flutter/material.dart';

class ReceiptButtons extends StatelessWidget {
  final VoidCallback onPrintReceipt;
  final VoidCallback onPDF;

  const ReceiptButtons({
    Key? key,
    this.onPrintReceipt = _defaultPrint,
    this.onPDF = _defaultPDF,
  }) : super(key: key);

  static void _defaultPrint() {
    print('Print Receipt');
  }

  static void _defaultPDF() {
    print('Generate PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 200,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton(
            onPressed: onPrintReceipt,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Print Receipt',
              style: TextStyle(
                color: Color(0xFF313131),
                fontSize: 18,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Container(
          width: 78,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton(
            onPressed: onPDF,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Color(0xFF313131),
                fontSize: 18,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
