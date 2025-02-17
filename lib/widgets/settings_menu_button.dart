import 'package:digisala_pos/widgets/settings_pin_confirmation.dart';
import 'package:flutter/material.dart';

class SettingsMenuButton extends StatelessWidget {
  final Function() onPrinterSettings;
  final Function() onReceiptSetup;
  final Future<bool> Function() onExportDatabase;
  final Future<bool> Function() onImportDatabase;
  final Function(String, bool) onShowSnackBar;

  const SettingsMenuButton({
    Key? key,
    required this.onPrinterSettings,
    required this.onReceiptSetup,
    required this.onExportDatabase,
    required this.onImportDatabase,
    required this.onShowSnackBar,
  }) : super(key: key);

  Future<void> _handleSettingsAction(BuildContext context, String value) async {
    bool success;
    switch (value) {
      case 'Printer Settings':
        onPrinterSettings();
        break;
      case 'Export Database':
        success = await onExportDatabase();
        onShowSnackBar(
          success
              ? 'Database exported successfully!'
              : 'Failed to export database.',
          success,
        );
        break;
      case 'Import Database':
        success = await onImportDatabase();
        onShowSnackBar(
          success
              ? 'Database imported successfully!'
              : 'Failed to import database.',
          success,
        );
        break;
      case 'Receipt Setup':
        onReceiptSetup();
        break;
    }
  }

  Future<void> _showSettingsMenu(BuildContext context) async {
    // First show the PIN confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SettingsPinDialog(
          onSuccess: () {},
          onCancel: () {},
        );
      },
    );

    // If PIN is correct, show the settings menu
    if (confirmed == true) {
      // Using a delayed future to avoid buildContext issues
      Future.microtask(() {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            MediaQuery.of(context).size.width - 200,
            80, // Adjust this value based on your app bar height
            MediaQuery.of(context).size.width - 10,
            100,
          ),
          items: <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'Printer Settings',
              child: Text('Printer Settings',
                  style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem<String>(
              value: 'Export Database',
              child: Text('Export Database',
                  style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem<String>(
              value: 'Import Database',
              child: Text('Import Database',
                  style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem<String>(
              value: 'Receipt Setup',
              child:
                  Text('Receipt Setup', style: TextStyle(color: Colors.white)),
            ),
          ],
          color: const Color(0xFF2D2D2D),
        ).then((String? value) {
          if (value != null) {
            _handleSettingsAction(context, value);
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.settings_applications_outlined,
        size: 50,
        color: Colors.white,
      ),
      tooltip: 'Settings',
      onPressed: () => _showSettingsMenu(context),
    );
  }
}
