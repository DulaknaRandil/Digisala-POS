import 'package:flutter/material.dart';

class DrawerAmountDialog extends StatefulWidget {
  final double totalAmount;
  final Function(double, double) onSubmit;

  const DrawerAmountDialog({
    Key? key,
    required this.totalAmount,
    required this.onSubmit,
  }) : super(key: key);

  @override
  _DrawerAmountDialogState createState() => _DrawerAmountDialogState();
}

class _DrawerAmountDialogState extends State<DrawerAmountDialog> {
  final _startDrawerController = TextEditingController();
  final _endDrawerController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
      title: const Text('Enter Drawer Amounts',
          style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _startDrawerController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Start Day Drawer Amount',
              labelStyle: TextStyle(color: Colors.white),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _endDrawerController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'End Day Drawer Amount',
              labelStyle: TextStyle(color: Colors.white),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () {
            final startAmount =
                double.tryParse(_startDrawerController.text) ?? 0;
            final endAmount = double.tryParse(_endDrawerController.text) ?? 0;
            widget.onSubmit(startAmount, endAmount);
            Navigator.pop(context);
          },
          child: const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
