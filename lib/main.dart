import 'package:flutter/material.dart';
import 'package:paylink_pos/screens/home_page.dart';
import 'package:paylink_pos/screens/home_screen.dart';
import 'package:paylink_pos/screens/login_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/product_list_screen.dart';
import 'screens/add_product_screen.dart';
import 'screens/selling_screen.dart';
import 'screens/bill_screen.dart';

void main() {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI loader
  sqfliteFfiInit();

  // Set the database factory
  databaseFactory = databaseFactoryFfi;
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      restorationScopeId: "Test", // <-- Add this line
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
