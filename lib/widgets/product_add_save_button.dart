import 'package:flutter/material.dart';

class SaveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final String text;
  final TextStyle? textStyle;
  final Color backgroundColor;

  const SaveButton({
    Key? key,
    this.onPressed,
    this.width = 368,
    this.height = 60, // Increased height based on screenshot
    this.borderRadius = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.text = 'Save',
    this.textStyle,
    this.backgroundColor = const Color(0xFFF1F5F9),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: MaterialButton(
        onPressed: onPressed,
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Text(
            text,
            style: textStyle ??
                const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF313131),
                ),
          ),
        ),
      ),
    );
  }

  // Default props factory constructor
  factory SaveButton.defaultProps() {
    return const SaveButton(
      width: 368,
      height: 60,
      borderRadius: 10,
      padding: EdgeInsets.symmetric(horizontal: 16),
      text: 'Save',
      backgroundColor: Color(0xFFF1F5F9),
      textStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF313131),
      ),
    );
  }
}
