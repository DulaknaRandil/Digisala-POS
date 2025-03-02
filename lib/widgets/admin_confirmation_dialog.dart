import 'package:flutter/material.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/user_model.dart';

class PinConfirmationDialog extends StatefulWidget {
  final Function(String) onPinComplete;
  final String? adminPin; // Optional parameter for direct PIN passing

  const PinConfirmationDialog({
    Key? key,
    required this.onPinComplete,
    this.adminPin,
  }) : super(key: key);

  @override
  _PinConfirmationDialogState createState() => _PinConfirmationDialogState();
}

class _PinConfirmationDialogState extends State<PinConfirmationDialog>
    with SingleTickerProviderStateMixin {
  String currentPin = '';
  String headerText = 'Enter Admin PIN';
  bool isError = false;
  bool isLoading = true;
  String correctPin = '';
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
        .chain(
          CurveTween(curve: Curves.elasticIn),
        )
        .animate(_animationController);

    // If adminPin is provided directly, use it, otherwise fetch from database
    if (widget.adminPin != null) {
      correctPin = widget.adminPin!;
      isLoading = false;
    } else {
      _loadAdminPin();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadAdminPin() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final users = await dbHelper.getAllUsers();

      // Find the admin user (assuming first user is admin or finding by role)
      User? adminUser = users.isNotEmpty
          ? users.firstWhere(
              (user) => user.role == 'Admin',
              orElse: () => users.first,
            )
          : null;

      if (adminUser != null) {
        setState(() {
          correctPin = adminUser.password;
          isLoading = false;
        });
      } else {
        // Fallback if no admin is found
        setState(() {
          headerText = 'No Admin Found';
          isError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        headerText = 'Error Loading PIN';
        isError = true;
        isLoading = false;
      });
      print('Error loading admin PIN: $e');
    }
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
          headerText = 'Enter Admin PIN';
          isError = false;
        }
      });
    }
  }

  void _validatePin() {
    if (currentPin == correctPin) {
      widget.onPinComplete(currentPin);
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        headerText = 'Wrong PIN';
        isError = true;
        currentPin = '';
        _pinController.clear();
      });
      _animationController.forward(from: 0);
      _focusNode.requestFocus(); // Ensure the TextField regains focus
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
        onPressed: isLoading ? null : () => _handleNumberPress(number),
        child: Text(
          number,
          style: TextStyle(
            color: isLoading ? Colors.grey : Colors.white,
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
    return Dialog(
      backgroundColor: const Color(0xFF020A1B),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Container(
          width: 300,
          height: 445,
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading Admin PIN...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
              : Column(
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
                              color: isError ? Colors.red : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        4,
                        (index) => _buildPinDot(index < currentPin.length),
                      ),
                    ),
                    const SizedBox(height: 30),
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
                                onPressed: isLoading ? null : _handleDelete,
                                child: Icon(
                                  Icons.backspace_outlined,
                                  color: isLoading ? Colors.grey : Colors.white,
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
    );
  }
}
