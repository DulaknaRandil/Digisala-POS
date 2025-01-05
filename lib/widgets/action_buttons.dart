import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback? onNewPressed;
  final VoidCallback? onGroupPressed;
  final VoidCallback? onUpdatePressed;
  final VoidCallback? onHistoryPressed;
  final VoidCallback? onSecurityPressed;

  const ActionButtons({
    Key? key,
    this.onNewPressed,
    this.onGroupPressed,
    this.onUpdatePressed,
    this.onHistoryPressed,
    this.onSecurityPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildActionButton(
            text: 'New +',
            backgroundColor: const Color(0xFF00E0FF),
            textColor: Colors.black,
            onPressed: onNewPressed,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            text: 'Group',
            backgroundColor: const Color(0xFFFFE500),
            textColor: Colors.black,
            onPressed: onGroupPressed,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            text: 'Update',
            backgroundColor: const Color(0xFF39B54A),
            textColor: Colors.white,
            onPressed: onUpdatePressed,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            text: 'History',
            backgroundColor: const Color(0xFF6B42FF),
            textColor: Colors.white,
            onPressed: onHistoryPressed,
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            text: 'Security',
            backgroundColor: const Color(0xFFFF4244),
            textColor: Colors.white,
            onPressed: onSecurityPressed,
          ),
          SizedBox(
            width: 300,
          )
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
