import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final VoidCallback? onClose;
  final VoidCallback? onImport;
  final VoidCallback? onExport;
  final String title;
  final Color textColor;

  const Header({
    Key? key,
    this.onClose,
    this.onImport,
    this.onExport,
    this.title = 'New Products', // Default title
    this.textColor = Colors.white, // Default text color
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Color(0xFF949391),
            ),
          ),
          Row(
            children: [
              // Import button
              IconButton(
                icon: const Icon(Icons.upload_file, color: Colors.white),
                tooltip: 'Import Products from Excel',
                onPressed: onImport,
                splashRadius: 24,
              ),
              // Export button
              IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                tooltip: 'Export Products to Excel',
                onPressed: onExport,
                splashRadius: 24,
              ),
              // Space between action buttons and close button
              const SizedBox(width: 30),
              // Close button
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
