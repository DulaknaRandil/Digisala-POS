import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinEntryComponent extends StatefulWidget {
  final Function(String) onPinComplete;
  final bool showLogo;

  const PinEntryComponent({
    Key? key,
    required this.onPinComplete,
    this.showLogo = false,
  }) : super(key: key);

  @override
  _PinEntryComponentState createState() => _PinEntryComponentState();
}

class _PinEntryComponentState extends State<PinEntryComponent> {
  String currentPin = '';
  String headerText = 'Enter your PIN';
  bool isError = false;

  void _handleNumberPress(String number) {
    if (currentPin.length < 4) {
      setState(() {
        currentPin += number;
        if (currentPin.length == 4) {
          widget.onPinComplete(currentPin);
        }
      });
    }
  }

  void _handleDelete() {
    if (currentPin.isNotEmpty) {
      setState(() {
        currentPin = currentPin.substring(0, currentPin.length - 1);
        if (isError) {
          headerText = 'Enter your PIN';
          isError = false;
        }
      });
    }
  }

  Widget _buildPinDot(bool isFilled) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled ? Colors.white : Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Container(
      width: 97.51,
      height: 97.51,
      margin: const EdgeInsets.all(8),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: Colors.white, width: 1),
        ),
        onPressed: () => _handleNumberPress(number),
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30.64,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final String? key = event.logicalKey.keyLabel;
      if (key != null && RegExp(r'^\d$').hasMatch(key)) {
        _handleNumberPress(key);
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _handleDelete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: _handleKeyPress,
      child: Container(
        color: const Color.fromRGBO(2, 10, 27, 1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.showLogo) ...[
              Image.network('assets/logo.png', height: 30),
              const SizedBox(height: 20),
            ],
            Text(
              headerText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => _buildPinDot(index < currentPin.length),
              ),
            ),
            const SizedBox(height: 40),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNumberButton('1'),
                    _buildNumberButton('2'),
                    _buildNumberButton('3'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNumberButton('4'),
                    _buildNumberButton('5'),
                    _buildNumberButton('6'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNumberButton('7'),
                    _buildNumberButton('8'),
                    _buildNumberButton('9'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 113),
                    _buildNumberButton('0'),
                    SizedBox(
                      width: 97.51,
                      height: 97.51,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: _handleDelete,
                        child: const Icon(
                          Icons.backspace_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 70),
            Text(
              '© 2025 Digisala POS. All rights reserved',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
