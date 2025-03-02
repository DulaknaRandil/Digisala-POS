import 'package:flutter/material.dart';

class SettingsPinDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  static const String adminPin = '1582';

  const SettingsPinDialog({
    Key? key,
    required this.onSuccess,
    required this.onCancel,
  }) : super(key: key);

  @override
  _SettingsPinDialogState createState() => _SettingsPinDialogState();
}

class _SettingsPinDialogState extends State<SettingsPinDialog>
    with SingleTickerProviderStateMixin {
  String currentPin = '';
  String headerText = 'Enter Vendor PIN';
  bool isError = false;
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _animationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleNumberPress(String number) {
    if (currentPin.length < 4) {
      setState(() {
        currentPin += number;
        if (currentPin.length == 4) {
          _validatePin();
        }
      });
    }
  }

  void _handleDelete() {
    if (currentPin.isNotEmpty) {
      setState(() {
        currentPin = currentPin.substring(0, currentPin.length - 1);
        if (isError) {
          headerText = 'Enter Vendor PIN';
          isError = false;
        }
      });
    }
  }

  void _validatePin() {
    if (currentPin == SettingsPinDialog.adminPin) {
      widget.onSuccess();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        headerText = 'Invalid Vendor PIN';
        isError = true;
        currentPin = '';
        _pinController.clear();
      });
      _animationController.forward(from: 0);
      _focusNode.requestFocus();
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
      width: 60,
      height: 60,
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
            fontSize: 24,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Dialog(
        backgroundColor: const Color(0xFF020A1B),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: SizedBox(
            width: 300,
            height: 420,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    children: [
                      const SizedBox(width: 85),
                      Text(
                        headerText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isError ? Colors.red : Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          widget.onCancel();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (index) => _buildPinDot(index < currentPin.length),
                  ),
                ),
                const SizedBox(height: 20),
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
                        const SizedBox(width: 76),
                        _buildNumberButton('0'),
                        SizedBox(
                          width: 60,
                          height: 60,
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
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
