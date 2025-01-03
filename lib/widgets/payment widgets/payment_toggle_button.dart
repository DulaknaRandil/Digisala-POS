import 'package:flutter/material.dart';

class PaymentToggleButton extends StatefulWidget {
  final Function(bool) onToggle;
  final bool initialValue;

  const PaymentToggleButton({
    Key? key,
    this.initialValue = false,
    required this.onToggle,
  }) : super(key: key);

  @override
  _PaymentToggleButtonState createState() => _PaymentToggleButtonState();
}

class _PaymentToggleButtonState extends State<PaymentToggleButton> {
  late bool _isCashSelected;

  @override
  void initState() {
    super.initState();
    _isCashSelected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 307,
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFF434343),
        borderRadius: BorderRadius.circular(51),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isCashSelected = true;
              });
              widget.onToggle(_isCashSelected);
            },
            child: Container(
              width: 87,
              height: 34,
              decoration: BoxDecoration(
                color: _isCashSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(55),
                border: Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: _isCashSelected ? 2 : 0,
                ),
              ),
              child: Center(
                child: Text(
                  'Cash',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _isCashSelected
                        ? const Color(0xFF313131)
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isCashSelected = false;
              });
              widget.onToggle(_isCashSelected);
            },
            child: Container(
              width: 87,
              height: 34,
              decoration: BoxDecoration(
                color: !_isCashSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(55),
                border: Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: !_isCashSelected ? 2 : 0,
                ),
              ),
              child: Center(
                child: Text(
                  'Card',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: !_isCashSelected
                        ? const Color(0xFF313131)
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
