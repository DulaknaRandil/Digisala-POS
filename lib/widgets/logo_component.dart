import 'package:flutter/material.dart';

class LogoComponent extends StatelessWidget {
  final double width;
  final double height;
  final String logoUrl;
  final Color backgroundColor;

  const LogoComponent({
    Key? key,
    this.width = 480.0,
    this.height = 385.0,
    this.logoUrl = 'assets/logo.png',
    this.backgroundColor = Colors.white70,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Image.asset(
            logoUrl,
            width: width * 0.8, // 80% of container width
            height: height * 0.8, // 80% of container height
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
