import 'dart:io';
import 'package:digisala_pos/models/group_model.dart';
import 'package:digisala_pos/models/pos_id_model.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/models/salesItem_model.dart';
import 'package:digisala_pos/models/sales_model.dart';
import 'package:digisala_pos/models/return_model.dart';
import 'package:digisala_pos/models/suppplier_model.dart';
import 'package:digisala_pos/models/user_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
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
  secondaryName TEXT,
  expiryDate TEXT,
  productGroup TEXT NOT NULL,
  quantity REAL NOT NULL,
  price REAL NOT NULL,
  buyingPrice REAL NOT NULL,
  discount TEXT,
  createdDate TEXT NOT NULL,
  updatedDate TEXT NOT NULL,
  status TEXT NOT NULL,
  supplierId INTEGER NOT NULL, -- New field
  FOREIGN KEY (supplierId) REFERENCES suppliers (id) -- Foreign key constraint
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
        quantity REAL NOT NULL,
        buyingPrice REAL NOT NULL,
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
        quantity REAL NOT NULL,
        FOREIGN KEY (salesItemId) REFERENCES sales_items (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE pos_id(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pos_id TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_table(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL
      )
    ''');
    await db.execute('''
  CREATE TABLE suppliers(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
  )
''');

    await db.execute(''' CREATE TABLE stock_updates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  productId INTEGER NOT NULL,
  quantityAdded REAL NOT NULL,
  updateDate TEXT NOT NULL,
  FOREIGN KEY (productId) REFERENCES products (id)
)   ''');
  }

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await instance.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getAllSuppliers() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('suppliers');
    return List.generate(maps.length, (i) => Supplier.fromMap(maps[i]));
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await instance.database;
    return await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> insertStockUpdate(int productId, double quantityAdded) async {
    final db = await instance.database;
    return await db.insert('stock_updates', {
      'productId': productId,
      'quantityAdded': quantityAdded,
      'updateDate': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getStockUpdatesByDate(
      DateTime date) async {
    final db = await instance.database;
    final String formattedDate = date.toIso8601String().split('T').first;
    return await db.query(
      'stock_updates',
      where: 'updateDate LIKE ?',
      whereArgs: ['$formattedDate%'],
    );
  }

  Future<List<Map<String, dynamic>>> getStockUpdatesByDateRange(
      DateTime start, DateTime end) async {
    final db = await instance.database;
    // Format the start date to include the beginning of the day.
    final String startIso =
        DateFormat("yyyy-MM-dd").format(start) + "T00:00:00";
    // Format the end date to include the end of the day.
    final String endIso = DateFormat("yyyy-MM-dd").format(end) + "T23:59:59";

    return await db.query(
      'stock_updates',
      where: 'updateDate BETWEEN ? AND ?',
      whereArgs: [startIso, endIso],
      orderBy: 'updateDate DESC', // Optional: order by most recent first.
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await instance.database;
    return await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Product?> getProductByName(String name) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'products',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null; // Return null if no product is found
  }

  Future<int> updatePosIdStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'pos_id',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<PosId?> getActivePosId() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pos_id',
      where: 'status = ?',
      whereArgs: ['active'],
    );
    if (maps.isNotEmpty) {
      return PosId.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertPosId(PosId posId) async {
    final db = await instance.database;
    return await db.insert('pos_id', posId.toMap());
  }

  Future<PosId?> getPosId() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('pos_id');
    if (maps.isNotEmpty) {
      return PosId.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertUser(User user) async {
    final db = await instance.database;
    return await db.insert('user_table', user.toMap());
  }

  Future<int> deleteUser(int id) async {
    try {
      final db = await instance.database;

      // Check if user exists before deletion
      final List<Map<String, dynamic>> user = await db.query(
        'user_table',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (user.isEmpty) {
        print('User with ID $id not found');
        return 0;
      }

      // Check if user is the last admin
      if (user.first['role'] == 'admin') {
        final List<Map<String, dynamic>> adminCount = await db.query(
          'user_table',
          where: 'role = ?',
          whereArgs: ['admin'],
        );

        if (adminCount.length <= 1) {
          print('Cannot delete the last admin user');
          return -1;
        }
      }

      // Proceed with deletion
      final result = await db.delete(
        'user_table',
        where: 'id = ?',
        whereArgs: [id],
      );

      print('User deleted successfully: $result row(s) affected');
      return result;
    } catch (e) {
      print('Error deleting user: $e');
      return -1;
    }
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_table',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('user_table');
    return List.generate(maps.length, (i) => User.fromMap(maps[i]));
  }

  Future<int> updateUser(User user) async {
    final db = await instance.database;
    return await db.update(
      'user_table',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
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
        buyingPrice: 0.0,
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
        buyingPrice: 0.0,
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

  Future<bool> exportDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'pos.db');

      final dbFile = File(path);

      if (await dbFile.exists()) {
        String? selectedDirectory =
            await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory != null) {
          final backupPath = join(selectedDirectory, 'pos_backup.db');
          final backupFile = File(backupPath);
          await dbFile.copy(backupFile.path);
          print('Database exported to ${backupFile.path}');
          return true;
        } else {
          print('No directory selected.');
        }
      } else {
        print('Database file does not exist.');
      }
    } catch (e) {
      print('Error exporting database: $e');
    }
    return false;
  }

  Future<bool> importDatabase() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null && result.files.single.path != null) {
        final backupPath = result.files.single.path!;
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'pos.db');

        final dbFile = File(path);
        final backupFile = File(backupPath);

        if (await backupFile.exists()) {
          // Close the database before replacing it
          await closeDatabase();

          // Delete the existing database file
          if (await dbFile.exists()) {
            await dbFile.delete();
          }

          // Copy the backup file to the database path
          await backupFile.copy(dbFile.path);
          print('Database imported from ${backupFile.path}');

          // Reopen the database
          await reopenDatabase(path);
          return true;
        } else {
          print('Backup file does not exist.');
        }
      } else {
        print('No file selected.');
      }
    } catch (e) {
      print('Error importing database: $e');
    }
    return false;
  }

  Future<void> closeDatabase() async {
    final db = await instance.database;
    await db.close();
    _database = null; // Reset the database instance
  }

  Future<void> reopenDatabase(String path) async {
    _database = await openDatabase(path);
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
