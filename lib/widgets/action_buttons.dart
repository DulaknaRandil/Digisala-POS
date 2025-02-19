import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback? onNewPressed;
  final VoidCallback? onGroupPressed;
  final VoidCallback? onUpdatePressed;
  final VoidCallback? onHistoryPressed;
  final VoidCallback? onSecurityPressed;
  final VoidCallback? onSuppliersPressed;
  final VoidCallback? onGRNPressed;

  const ActionButtons({
    Key? key,
    this.onNewPressed,
    this.onGroupPressed,
    this.onUpdatePressed,
    this.onHistoryPressed,
    this.onSecurityPressed,
    this.onSuppliersPressed,
    this.onGRNPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 60,
          width: constraints.maxWidth,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildActionButton(
                  text: 'New +',
                  backgroundColor: const Color(0xFF00E0FF),
                  textColor: Colors.black,
                  onPressed: onNewPressed,
                  constraints: constraints,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  text: 'Group',
                  backgroundColor: const Color(0xFFFFE500),
                  textColor: Colors.black,
                  onPressed: onGroupPressed,
                  constraints: constraints,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  text: 'Update',
                  backgroundColor: const Color(0xFF39B54A),
                  textColor: Colors.white,
                  onPressed: onUpdatePressed,
                  constraints: constraints,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  text: 'History',
                  backgroundColor: const Color(0xFF6B42FF),
                  textColor: Colors.white,
                  onPressed: onHistoryPressed,
                  constraints: constraints,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  text: 'Security',
                  backgroundColor: const Color(0xFFFF4244),
                  textColor: Colors.white,
                  onPressed: onSecurityPressed,
                  constraints: constraints,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  text: 'Suppliers',
                  backgroundColor: const Color(0xFF8A2BE2),
                  textColor: Colors.white,
                  onPressed: onSuppliersPressed,
                  constraints: constraints,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  text: 'GRN',
                  backgroundColor: const Color(0xFF4682B4),
                  textColor: Colors.white,
                  onPressed: onGRNPressed,
                  constraints: constraints,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required BoxConstraints constraints,
    VoidCallback? onPressed,
  }) {
    // Calculate dynamic button width based on available space
    double buttonWidth =
        _calculateButtonWidth(constraints.maxWidth, text.length);

    return Container(
      width: buttonWidth,
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: _calculateFontSize(constraints.maxWidth),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateButtonWidth(double availableWidth, int textLength) {
    // Base width calculation
    double baseWidth = textLength * 10.0 + 32; // 32 for padding

    // Minimum and maximum constraints
    const double minWidth = 80;
    const double maxWidth = 120;

    // Calculate proportional width based on available space
    double proportionalWidth =
        availableWidth / 8; // Divide by number of buttons + some spacing

    // Return the constrained width
    return clampDouble(
      proportionalWidth.clamp(minWidth, maxWidth),
      minWidth,
      maxWidth,
    );
  }

  double _calculateFontSize(double availableWidth) {
    // Scale font size based on available width
    if (availableWidth < 600) {
      return 14;
    } else if (availableWidth < 800) {
      return 15;
    } else {
      return 24;
    }
  }
}

// Helper function to clamp double values
double clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
