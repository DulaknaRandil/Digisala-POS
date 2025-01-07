import 'package:digisala_pos/models/group_model.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/models/salesItem_model.dart';
import 'package:digisala_pos/models/sales_model.dart';
import 'package:digisala_pos/models/return_model.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT NOT NULL,
        name TEXT NOT NULL,
        expiryDate TEXT,
        productGroup TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        createdDate TEXT NOT NULL,
        updatedDate TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE groups(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL,
        total REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        salesId INTEGER NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        discount REAL NOT NULL,
        total REAL NOT NULL,
        refund INTEGER NOT NULL,
        FOREIGN KEY (salesId) REFERENCES sales (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE returns(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        salesItemId INTEGER NOT NULL,
        name TEXT NOT NULL,
        discount REAL NOT NULL,
        total REAL NOT NULL,
        returnDate TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        FOREIGN KEY (salesItemId) REFERENCES sales_items (id)
      )
    ''');
  }

  Future<int> insertProduct(Product product) async {
    try {
      final db = await instance.database;
      return await db.insert('products', product.toMap());
    } catch (e) {
      print('Error inserting product: $e');
      return -1;
    }
  }

  Future<List<Product>> getAllProducts() async {
    try {
      final db = await instance.database;
      final List<Map<String, dynamic>> maps = await db.query('products');
      return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Future<Product?> getProductById(int id) async {
    try {
      final db = await instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Product.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error fetching product by ID: $e');
      return null;
    }
  }

  Future<int> getLatestSalesId() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT MAX(id) as maxId FROM sales');
    return (result.first['maxId'] as int?) ?? 0;
  }

  Future<int> updateProduct(Product product) async {
    try {
      final db = await instance.database;
      return await db.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
    } catch (e) {
      print('Error updating product: $e');
      return -1;
    }
  }

  Future<int> insertGroup(Group group) async {
    final db = await instance.database;
    return await db.insert('groups', group.toMap());
  }

  Future<List<Group>> getAllGroups() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('groups');
    return List.generate(maps.length, (i) => Group.fromMap(maps[i]));
  }

  Future<int> updateGroup(Group group) async {
    final db = await instance.database;
    return await db.update(
      'groups',
      group.toMap(),
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  Future<List<Sales>> getSalesByDate(DateTime date) async {
    final db = await instance.database;
    final String formattedDate =
        date.toIso8601String().split('T').first; // Extract the date part
    print('Querying sales for date: $formattedDate');

    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'date LIKE ?',
      whereArgs: ['$formattedDate%'], // Use LIKE to match the date part
    );

    print('Sales fetched: ${maps.length}');
    return List.generate(maps.length, (i) => Sales.fromMap(maps[i]));
  }

  Future<SalesItem?> getTopSoldItem() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T').first;
    print('Querying top sold item for date: $today');

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
  SELECT name, SUM(quantity) as totalQuantity
  FROM sales_items
  WHERE salesId IN (SELECT id FROM sales WHERE date LIKE ?)
  GROUP BY name
  ORDER BY totalQuantity DESC
  LIMIT 1
  ''', ['$today%']); // Use LIKE to ensure date format matches

    if (maps.isNotEmpty) {
      final map = maps.first;
      print('Top sold item: ${map['name']}, Quantity: ${map['totalQuantity']}');
      return SalesItem(
        id: null,
        salesId: 0,
        name: map['name'],
        quantity: map['totalQuantity'],
        price: 0.0,
        discount: 0.0,
        total: 0.0,
        refund: false,
      );
    }
    return null;
  }

  Future<SalesItem?> getLeastSoldItem() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T').first;
    print('Querying least sold item for date: $today');

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
  SELECT name, SUM(quantity) as totalQuantity
  FROM sales_items
  WHERE salesId IN (SELECT id FROM sales WHERE date LIKE ?)
  GROUP BY name
  ORDER BY totalQuantity ASC
  LIMIT 1
  ''', ['$today%']); // Use LIKE to ensure date format matches

    if (maps.isNotEmpty) {
      final map = maps.first;
      print(
          'Least sold item: ${map['name']}, Quantity: ${map['totalQuantity']}');
      return SalesItem(
        id: null,
        salesId: 0,
        name: map['name'],
        quantity: map['totalQuantity'],
        price: 0.0,
        discount: 0.0,
        total: 0.0,
        refund: false,
      );
    }
    return null;
  }

  Future<int> deleteGroup(int id) async {
    final db = await instance.database;
    return await db.delete(
      'groups',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProduct(int id) async {
    try {
      final db = await instance.database;
      return await db.delete(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting product: $e');
      return -1;
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      final db = await instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'barcode LIKE ? OR name LIKE ? OR id LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
      );
      return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  Future<int> insertSales(Sales sales) async {
    final db = await instance.database;
    return await db.insert('sales', sales.toMap());
  }

  Future<int> insertSalesItem(SalesItem salesItem) async {
    final db = await instance.database;
    return await db.insert('sales_items', salesItem.toMap());
  }

  Future<int> updateSalesItem(SalesItem salesItem) async {
    final db = await instance.database;
    return await db.update(
      'sales_items',
      salesItem.toMap(),
      where: 'id = ?',
      whereArgs: [salesItem.id],
    );
  }

  Future<int> insertReturn(Return returnItem) async {
    final db = await instance.database;
    return await db.insert('returns', returnItem.toMap());
  }

  Future<List<Sales>> getAllSales() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('sales');
    return List.generate(maps.length, (i) => Sales.fromMap(maps[i]));
  }

  Future<List<SalesItem>> getSalesItems(int salesId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales_items',
      where: 'salesId = ?',
      whereArgs: [salesId],
    );
    return List.generate(maps.length, (i) => SalesItem.fromMap(maps[i]));
  }

  Future<List<Sales>> searchSalesById(String salesId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'id LIKE ?',
      whereArgs: ['%$salesId%'],
    );
    return List.generate(maps.length, (i) => Sales.fromMap(maps[i]));
  }

  Future<List<Sales>> searchSalesByDateRange(
      DateTime start, DateTime end) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return List.generate(maps.length, (i) => Sales.fromMap(maps[i]));
  }

  Future<List<Return>> getAllReturns() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('returns');
    return List.generate(maps.length, (i) => Return.fromMap(maps[i]));
  }

  Future<List<Return>> getRefundsForSales(int salesId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'returns',
      where: 'salesItemId IN (SELECT id FROM sales_items WHERE salesId = ?)',
      whereArgs: [salesId],
    );
    return List.generate(maps.length, (i) => Return.fromMap(maps[i]));
  }
}
