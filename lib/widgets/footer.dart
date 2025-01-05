import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:paylink_pos/widgets/end_of_day_dialog.dart';
import 'dart:async';

import 'package:paylink_pos/widgets/stock_dialog.dart';

class Footer extends StatefulWidget {
  final String userRole;
  final String? avatarUrl;
  final VoidCallback onVoidOrder;
  final VoidCallback onPayment;

  const Footer({
    Key? key,
    this.userRole = 'Admin',
    this.avatarUrl =
        'https://dashboard.codeparrot.ai/api/assets/Z3Ars5_bRV0pnkce',
    required this.onVoidOrder,
    required this.onPayment,
  }) : super(key: key);

  @override
  _FooterState createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  late String _timeString;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timeString = _formatDateTime(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() {
          _timeString = _formatDateTime(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    final String hour = dateTime.hour > 12
        ? (dateTime.hour - 12).toString().padLeft(2, '0')
        : dateTime.hour.toString().padLeft(2, '0');
    final String period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')} $period';
  }

  void _showStockDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const StockDialog();
      },
    );
  }

  void _showEndOfDayDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const EndOfDayDialog(); // Use the EndOfDayDialog
      },
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(2, 10, 27, 1),
          title: const Text(
            'Confirm Logout',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(color: Colors.white),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/login');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 75,
      decoration: BoxDecoration(
        color: const Color(0xFF313131),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFDBDBDB),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(HugeIcons.strokeRoundedLogin02,
                  color: Colors.black),
              onPressed: _showLogoutConfirmationDialog,
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 32,
            backgroundImage: NetworkImage(widget.avatarUrl ?? ''),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _timeString,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                widget.userRole,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildActionButton('Void Order', Colors.red, widget.onVoidOrder),
          _buildActionButton(
              'End of Day', Colors.lightBlue, _showEndOfDayDialog),
          _buildActionButton('Stock', Colors.pinkAccent, () {
            _showStockDialog();
          }),
          _buildActionButton('Payment', Colors.green, widget.onPayment),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
