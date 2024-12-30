import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DiscountCalculator extends StatefulWidget {
  final Function(double, bool)? onDiscountSelected;
  final VoidCallback? onClose;
  final bool defaultIsPercentage;
  final String initialValue;

  const DiscountCalculator({
    Key? key,
    this.onDiscountSelected,
    this.onClose,
    this.defaultIsPercentage = true,
    this.initialValue = '',
  }) : super(key: key);

  @override
  _DiscountCalculatorState createState() => _DiscountCalculatorState();
}

class _DiscountCalculatorState extends State<DiscountCalculator> {
  late bool isPercentage;
  late String inputValue;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    isPercentage = widget.defaultIsPercentage;
    inputValue = widget.initialValue;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _applyDiscount();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onClose?.call();
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _handleInput('⌫');
      } else if (event.character != null) {
        final char = event.character!;
        if (_isValidInput(char)) {
          _handleInput(char);
        }
      }
    }
  }

  bool _isValidInput(String char) {
    if (char == '.') {
      return !inputValue.contains('.');
    }
    return RegExp(r'[0-9]').hasMatch(char);
  }

  void _handleInput(String value) {
    setState(() {
      if (value == '⌫') {
        if (inputValue.isNotEmpty) {
          inputValue = inputValue.substring(0, inputValue.length - 1);
        }
      } else if (value == '.' && !inputValue.contains('.')) {
        inputValue += value;
      } else if (RegExp(r'[0-9]').hasMatch(value)) {
        inputValue += value;
      }
    });
  }

  void _applyDiscount() {
    final discountValue = double.tryParse(inputValue) ?? 0.0;
    widget.onDiscountSelected?.call(discountValue, isPercentage);
  }

  Widget _buildToggleButton() {
    // Existing _buildToggleButton implementation...
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Color(0xFF434343),
        borderRadius: BorderRadius.circular(51),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildToggleOption('Percentage', isPercentage),
          _buildToggleOption('Amount', !isPercentage),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String text, bool isSelected) {
    // Existing _buildToggleOption implementation...
    return GestureDetector(
      onTap: () {
        setState(() {
          isPercentage = text == 'Percentage';
        });
        _focusNode.requestFocus(); // Maintain focus after toggle
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(55),
          border: isSelected
              ? Border.all(color: Color(0xFFF1F5F9), width: 2)
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isSelected ? Color(0xFF313131) : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Container(
      width: 60,
      height: 60,
      margin: EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Color(0xFFF1F5F9), width: 1),
      ),
      child: TextButton(
        onPressed: () {
          _handleInput(number);
          _focusNode.requestFocus(); // Maintain focus after button press
        },
        child: Text(
          number,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF1F5F9),
          ),
        ),
        style: TextButton.styleFrom(
          shape: CircleBorder(),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildPresetButton(String percentage) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(55),
          border: Border.all(color: Color(0xFFF1F5F9), width: 2),
        ),
        child: TextButton(
          onPressed: () {
            final value = double.parse(percentage.replaceAll('%', ''));
            widget.onDiscountSelected?.call(value, true);
          },
          child: Text(
            percentage,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF1F5F9),
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: SingleChildScrollView(
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: screenWidth * 0.2,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF020A1B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                _buildToggleButton(),
                SizedBox(height: 20),
                Text(
                  'Enter ${isPercentage ? "Percentage" : "Amount"}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF949391),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  inputValue + (isPercentage ? '%' : ''),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  width: screenWidth * 0.7,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['1', '2', '3']
                            .map((e) => _buildNumberButton(e))
                            .toList(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['4', '5', '6']
                            .map((e) => _buildNumberButton(e))
                            .toList(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['7', '8', '9']
                            .map((e) => _buildNumberButton(e))
                            .toList(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberButton('.'),
                          _buildNumberButton('0'),
                          _buildNumberButton('⌫'),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                if (isPercentage)
                  Container(
                    width: screenWidth * 0.7,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPresetButton('10%'),
                            _buildPresetButton('12%'),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPresetButton('15%'),
                            _buildPresetButton('20%'),
                          ],
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _applyDiscount,
                  child: Text('Apply Discount'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
