import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/pos_id_model.dart';
import 'package:digisala_pos/widgets/logo_component.dart';
import 'package:digisala_pos/widgets/pin_entry_component.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController _usernameController = TextEditingController();

  Future<void> loginUser(
      BuildContext context, String username, String pin) async {
    final dbHelper = DatabaseHelper.instance;

    try {
      final posId = await dbHelper.getPosId();

      if (await _isConnected()) {
        if (posId == null) {
          print('Attempting online login...');
          final loginResponse = await http.post(
            Uri.parse(
                'https://digisala-backend-6044368f3528.herokuapp.com/api/pos/pos/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'pin': pin}),
          );

          if (loginResponse.statusCode == 200) {
            final loginData = jsonDecode(loginResponse.body);
            final posIdValue = loginData['pos_id'];

            await dbHelper.insertPosId(
                PosId(posId: posIdValue.toString(), status: 'inactive'));

            final statusResponse = await http.post(
              Uri.parse(
                  'https://digisala-backend-6044368f3528.herokuapp.com/api/pos/get-status'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'id': posIdValue}),
            );

            if (statusResponse.statusCode == 200) {
              final statusData = jsonDecode(statusResponse.body);
              print('POS ID status: ${statusData['status']}');

              if (statusData['status'] == 'active') {
                await dbHelper.updatePosIdStatus(posIdValue, 'active');
                Navigator.pushReplacementNamed(context, '/dashboard');
                return;
              } else {
                print('POS ID not active');
                await dbHelper.updatePosIdStatus(posIdValue, 'inactive');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please contact the support team')),
                );
                return;
              }
            }
          }
        } else {
          print('Checking POS ID status online...');
          final statusResponse = await http.post(
            Uri.parse(
                'https://digisala-backend-6044368f3528.herokuapp.com/api/pos/get-status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': posId.posId}),
          );

          if (statusResponse.statusCode == 200) {
            final statusData = jsonDecode(statusResponse.body);
            print('POS ID status: ${statusData['status']}');

            if (statusData['status'] == 'active') {
              await dbHelper.updatePosIdStatus(posId.id!, 'active');
              Navigator.pushReplacementNamed(context, '/dashboard');
              return;
            } else {
              print('POS ID not active');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please contact the support team')),
              );
              return;
            }
          }
        }
      } else {
        print('No internet connection, checking offline access...');
        if (posId != null && posId.status == 'active') {
          final user = await dbHelper.getUserByUsername(username);
          if (user != null && user.password == pin) {
            print('User credentials valid, navigating to dashboard...');
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            print('Invalid username or password');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid username or password')),
            );
          }
        } else {
          print('POS ID not active');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please contact the support team')),
          );
        }
      }
    } catch (e) {
      print('Error during login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred, please try again')),
      );
    }
  }

  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LogoComponent(
                  width: 300,
                  height: 250,
                  logoUrl: 'assets/logo.png',
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 250,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.black,
                        width: 1.0,
                      ),
                    ),
                    child: TextField(
                      cursorColor: Colors.black54,
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Enter Username here',
                        hintStyle: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 20,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PinEntryComponent(
              onPinComplete: (pin) {
                final username = _usernameController.text;
                print('Username: $username, PIN: $pin');
                loginUser(context, username, pin);
              },
              showLogo: false,
            ),
          ),
        ],
      ),
    );
  }
}
