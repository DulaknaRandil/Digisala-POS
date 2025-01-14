import 'package:flutter/material.dart';

class PinInputComponent extends StatefulWidget {
  @override
  _PinInputComponentState createState() => _PinInputComponentState();
}

class _PinInputComponentState extends State<PinInputComponent> {
  String pin = '';
  final String correctPin = '';

  void _handleButtonClick(String value) {
    setState(() {
      if (pin.length < 4) {
        pin += value;
      }
      if (pin.length == 4) {
        if (pin == correctPin) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Correct PIN!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Wrong PIN, try again!')),
          );
          pin = '';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          pin.length == 4 && pin != correctPin
              ? 'Wrong PIN, try again!'
              : 'Enter your PIN',
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
        SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(10, (index) {
            return ElevatedButton(
              onPressed: () => _handleButtonClick(index.toString()),
              child: Text(index.toString()),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
              ),
            );
          }),
        ),
      ],
    );
  }
}
