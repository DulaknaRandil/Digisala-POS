import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:digisala_pos/widgets/end_of_day_dialog.dart';
import 'dart:async';

import 'package:digisala_pos/widgets/stock_dialog.dart';

class Footer extends StatefulWidget {
  final String userRole;
  final String username; // Add username parameter
  final String? avatarUrl;
  final VoidCallback onVoidOrder;
  final Function onPayment;
  final FocusNode requestFocusNode;
  final double total;

  const Footer({
    Key? key,
    required this.userRole,
    required this.username, // Make username required
    this.avatarUrl = 'assets/user.png',
    required this.onVoidOrder,
    required this.onPayment,
    required this.requestFocusNode,
    required this.total,
  }) : super(key: key);

  @override
  _FooterState createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  late String _timeString;
  late Timer _timer;
  List<Product> products = [];
  int lowStockCount = 0;
  int mediumStockCount = 0;
  int highStockCount = 0; // Add this line if needed

  Future<void> _loadProducts() async {
    final _products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      products = _products;
    });
    // _fetchStockCounts(); // Call this after products are loaded
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _timeString = _formatDateTime(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer t) {
      if (mounted) {
        setState(() {
          _timeString = _formatDateTime(DateTime.now());
          _loadProducts();
          _fetchStockCounts(); // Update stock counts every second
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

  void _fetchStockCounts() {
    final allFilteredProducts = products.where((product) {
      return true;
    }).toList();
    print('Filtered products: ${allFilteredProducts.length}');
    print(
        'Low stock count: ${allFilteredProducts.where((p) => p.quantity < 5).length}');
    print(
        'Medium stock count: ${allFilteredProducts.where((p) => p.quantity >= 5 && p.quantity < 15).length}');
    print(
        'High stock count: ${allFilteredProducts.where((p) => p.quantity >= 15).length}');

    setState(() {
      _loadProducts();
      lowStockCount = allFilteredProducts.where((p) => p.quantity < 5).length;
      mediumStockCount = allFilteredProducts
          .where((p) => p.quantity >= 5 && p.quantity < 15)
          .length;
      highStockCount =
          allFilteredProducts.where((p) => p.quantity >= 15).length;
    });
  }

  void _showStockDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StockDialog(
          searchBarFocusNode: widget.requestFocusNode,
        );
      },
    );
  }

  void _showEndOfDayDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EndOfDayDialog(
          searchBarFocusNode: widget.requestFocusNode,
        ); // Use the EndOfDayDialog
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes
        final isSmallScreen = constraints.maxWidth < 800;
        final isMediumScreen = constraints.maxWidth < 1200;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10 : 20,
          ),
          height: isSmallScreen ? 90 : 75,
          decoration: BoxDecoration(
            color: const Color(0xFF313131),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFDBDBDB),
              width: 1,
            ),
          ),
          // Constrain the inner Row to the max width so we can use spaceBetween
          child: SizedBox(
            width: constraints.maxWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // LEFT GROUP: Logout, Avatar, Time & User Info
                Row(
                  children: [
                    // Logout Button
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 4 : 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          HugeIcons.strokeRoundedLogin02,
                          color: Colors.black,
                        ),
                        onPressed: _showLogoutConfirmationDialog,
                        iconSize: isSmallScreen ? 20 : 24,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 16),
                    // Avatar
                    CircleAvatar(
                      radius: isSmallScreen ? 24 : 32,
                      backgroundImage: AssetImage(widget.avatarUrl ?? ''),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 16),
                    // Time and User Info
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _timeString,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize:
                                isSmallScreen ? 18 : (isMediumScreen ? 20 : 24),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${widget.username} (${widget.userRole})',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize:
                                isSmallScreen ? 16 : (isMediumScreen ? 18 : 22),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // RIGHT GROUP: Action Buttons
                Row(
                  children: [
                    _buildResponsiveActionButton(
                      'Void Order',
                      Colors.red,
                      widget.onVoidOrder,
                      isSmallScreen,
                      isMediumScreen,
                    ),
                    _buildResponsiveActionButton(
                      'End of Day',
                      Colors.lightBlue,
                      _showEndOfDayDialog,
                      isSmallScreen,
                      isMediumScreen,
                    ),
                    // Stock Button with Bubbles
                    Stack(
                      children: [
                        _buildResponsiveActionButton(
                          'Stock',
                          Colors.teal,
                          _showStockDialog,
                          isSmallScreen,
                          isMediumScreen,
                        ),
                        Positioned(
                          right: 1,
                          top: -5,
                          child: _buildResponsiveStockBubble(
                            lowStockCount,
                            Colors.red,
                            isSmallScreen,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 6,
                          child: _buildResponsiveStockBubble(
                            mediumStockCount,
                            Colors.yellow,
                            isSmallScreen,
                          ),
                        ),
                      ],
                    ),
                    _buildResponsiveActionButton(
                      'Payment',
                      Colors.green,
                      (widget.total > 0 ? widget.onPayment : null)
                          as VoidCallback?,
                      isSmallScreen,
                      isMediumScreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveActionButton(
    String text,
    Color color,
    VoidCallback? onPressed,
    bool isSmallScreen,
    bool isMediumScreen,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 4 : (isMediumScreen ? 6 : 8),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : (isMediumScreen ? 12 : 16),
            vertical: isSmallScreen ? 6 : (isMediumScreen ? 8 : 10),
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: isSmallScreen ? 16 : (isMediumScreen ? 20 : 24),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveStockBubble(
    int count,
    Color color,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: isSmallScreen ? 10 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
