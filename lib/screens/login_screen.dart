import 'package:flutter/material.dart';
import 'package:paylink_pos/widgets/logo_component.dart';
import 'package:paylink_pos/widgets/pin_entry_component.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            Expanded(
              child: Center(
                child: LogoComponent(
                  width: 300,
                  height: 250,
                  logoUrl: 'assets/logo.png',
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: PinEntryComponent(
                onPinComplete: (pin) {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                showLogo: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
