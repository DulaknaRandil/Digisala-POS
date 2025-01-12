import 'dart:io'; // Required for Platform checks
import 'package:digisala_pos/utils/printReceipt_service.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/home_page.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/add_product_screen.dart';
import 'screens/selling_screen.dart';
import 'screens/bill_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized

  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the service
  await ThermalPrinterService.initialize();

  // Check platform and initialize SQLite database factory
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      restorationScopeId: "Test",
      title: 'POS System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => LoginScreen(),
        '/products': (context) => const ProductListScreen(),
        '/add-product': (context) => const AddProductScreen(),
        '/selling': (context) => const SellingScreen(),
        '/bill': (context) => const BillScreen(),
        '/dashboard': (context) => const HomeScreen(),
      },
    );
  }
}
