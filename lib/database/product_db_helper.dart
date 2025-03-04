import 'dart:io';
import 'package:digisala_pos/models/delete_sale_item_model.dart';
import 'package:digisala_pos/models/delete_sale_model.dart';
import 'package:digisala_pos/models/expense_model.dart';
import 'package:digisala_pos/models/group_model.dart';
import 'package:digisala_pos/models/pos_id_model.dart';
import 'package:digisala_pos/models/product_model.dart';
import 'package:digisala_pos/models/salesItem_model.dart';
import 'package:digisala_pos/models/sales_model.dart';
import 'package:digisala_pos/models/return_model.dart';
import 'package:digisala_pos/models/supplier_model.dart';
import 'package:digisala_pos/models/user_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
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
        supplierId INTEGER NOT NULL,
        FOREIGN KEY (supplierId) REFERENCES suppliers (id)
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
        stockUpdated INTEGER NOT NULL,
        productId INTEGER NOT NULL,      
        supplierName TEXT NOT NULL, 
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

    await db.execute('''
      CREATE TABLE stock_updates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        quantityAdded REAL NOT NULL,
        updateDate TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE delete_sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL,
        total REAL NOT NULL,
        stockUpdated INTEGER NOT NULL
      )
    ''');

    // Modified table schema: added deleteSaleItemId column
    await db.execute('''
      CREATE TABLE delete_sales_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deleteSaleId INTEGER NOT NULL,
        deleteSaleItemId INTEGER NOT NULL,
        name TEXT NOT NULL,
        quantity REAL NOT NULL,
        buyingPrice REAL NOT NULL,
        price REAL NOT NULL,
        discount REAL NOT NULL,
        total REAL NOT NULL,
        refund INTEGER NOT NULL,
        FOREIGN KEY (deleteSaleId) REFERENCES delete_sales (id)
      )
    ''');
    // In _createDB method of DatabaseHelper
    await db.execute('''
  CREATE TABLE expenses(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    time TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    amount REAL NOT NULL
  )
''');
  }

// In DatabaseHelper class
  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('expenses');
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<List<Expense>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    final db = await instance.database;
    final String startIso = start.toIso8601String();
    final String endIso = end.add(Duration(days: 1)).toIso8601String();

    return await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startIso, endIso],
    ).then(
        (maps) => List.generate(maps.length, (i) => Expense.fromMap(maps[i])));
  }

  Future<List<Expense>> getExpensesByDate(DateTime date) async {
    final db = await instance.database;
    final String formattedDate = date.toIso8601String().split('T').first;

    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date LIKE ?',
      whereArgs: ['$formattedDate%'],
    );

    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<List<Expense>> searchExpenses(String query) async {
    final db = await instance.database;
    return await db.rawQuery('''
    SELECT * FROM expenses 
    WHERE category LIKE ? 
       OR description LIKE ? 
       OR id LIKE ?
  ''', [
      '%$query%',
      '%$query%',
      '%$query%'
    ]).then(
        (maps) => List.generate(maps.length, (i) => Expense.fromMap(maps[i])));
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
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

  Future<int> insertDeleteSale(DeleteSale deleteSale) async {
    final db = await instance.database;
    return await db.insert('delete_sales', deleteSale.toMap());
  }

  Future<int> insertDeleteSaleItem(DeleteSaleItem deleteSaleItem) async {
    final db = await instance.database;
    return await db.insert('delete_sales_items', deleteSaleItem.toMap());
  }

  Future<List<DeleteSale>> getAllDeleteSales() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('delete_sales');
    return List.generate(maps.length, (i) => DeleteSale.fromMap(maps[i]));
  }

  Future<List<DeleteSaleItem>> getDeleteSaleItems(int deleteSaleId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'delete_sales_items',
      where: 'deleteSaleId = ?',
      whereArgs: [deleteSaleId],
    );
    return List.generate(maps.length, (i) => DeleteSaleItem.fromMap(maps[i]));
  }

  Future<void> deleteSaleAndItems(int saleId, bool updateStock) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Get the sale and items before deleting
      final sale = (await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      ))
          .first;

      final items = await txn.query(
        'sales_items',
        where: 'salesId = ?',
        whereArgs: [saleId],
      );

      // Insert into delete_sales
      final deleteSaleId = await txn.insert('delete_sales', {
        ...sale,
        'stockUpdated': updateStock ? 1 : 0,
      });

      // Insert items into delete_sales_items with modified keys
      for (var item in items) {
        final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
        // Remove the 'salesId' key since it is not in the new schema
        itemMap.remove('salesId');
        // Add the new key using the original sales item id
        itemMap['deleteSaleItemId'] = item['id'];
        // Set the foreign key for delete sales record
        itemMap['deleteSaleId'] = deleteSaleId;
        await txn.insert('delete_sales_items', itemMap);

        // Update product quantity if needed
        if (updateStock) {
          final product = await txn.query(
            'products',
            where: 'name = ?',
            whereArgs: [item['name']],
          );

          if (product.isNotEmpty) {
            await txn.update(
              'products',
              {
                'quantity': (product.first['quantity'] as num? ?? 0) +
                    (item['quantity'] as num),
                'updatedDate': DateTime.now().toIso8601String(),
              },
              where: 'name = ?',
              whereArgs: [item['name']],
            );
          }
        }
      }

      // Delete from original tables
      await txn.delete(
        'sales_items',
        where: 'salesId = ?',
        whereArgs: [saleId],
      );
      await txn.delete(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  // Add to your DatabaseHelper class
  Future<List<Return>> getAllReturns({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final db = await instance.database;
    String where = '1=1';
    List<Object?> whereArgs = [];

    if (startDate != null && endDate != null) {
      where += ' AND returnDate BETWEEN ? AND ?';
      whereArgs.addAll([
        startDate.toIso8601String(),
        endDate.add(const Duration(days: 1)).toIso8601String(),
      ]);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += '''
      AND (products.name LIKE ? 
        OR suppliers.name LIKE ? 
        OR CAST(products.id AS TEXT) LIKE ?)
    ''';
      String searchPattern = '%$searchQuery%';
      whereArgs.addAll([searchPattern, searchPattern, searchPattern]);
    }

    // In DatabaseHelper.getAllReturns
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
  SELECT 
    returns.*,
    products.id as productId,
    suppliers.name as supplierName
  FROM returns
  INNER JOIN products ON returns.name = products.name
  INNER JOIN suppliers ON products.supplierId = suppliers.id
  WHERE $where
  ORDER BY returnDate DESC
''', whereArgs);

    return List.generate(maps.length, (i) => Return.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('groups');
  }

  Future<List<Sales>> searchSalesByDateRange(
      DateTime startDate, DateTime endDate) async {
    final start =
        DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );

    return List.generate(maps.length, (i) {
      return Sales.fromMap(maps[i]);
    });
  }

  Future<int> insertStockUpdate(int productId, double quantityAdded) async {
    final db = await instance.database;
    return await db.insert('stock_updates', {
      'productId': productId,
      'quantityAdded': quantityAdded,
      'updateDate': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Return>> getRefundsForSalesItem(int salesItemId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'returns',
      where: 'salesItemId = ?',
      whereArgs: [salesItemId],
    );
    return List.generate(maps.length, (i) => Return.fromMap(maps[i]));
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
    final String startIso =
        DateFormat("yyyy-MM-dd").format(start) + "T00:00:00";
    final String endIso = DateFormat("yyyy-MM-dd").format(end) + "T23:59:59";

    return await db.query(
      'stock_updates',
      where: 'updateDate BETWEEN ? AND ?',
      whereArgs: [startIso, endIso],
      orderBy: 'updateDate DESC',
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
    return null;
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
      final List<Map<String, dynamic>> user = await db.query(
        'user_table',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (user.isEmpty) {
        print('User with ID $id not found');
        return 0;
      }

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
    final String formattedDate = date.toIso8601String().split('T').first;
    print('Querying sales for date: $formattedDate');

    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'date LIKE ?',
      whereArgs: ['$formattedDate%'],
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
    ''', ['$today%']);

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
    ''', ['$today%']);

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

  Future<bool> _requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<bool> exportDatabase() async {
    if (!(await _requestStoragePermission())) {
      print('Storage permission not granted.');
      return false;
    }
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'pos.db');

      final dbFile = File(path);

      if (await dbFile.exists()) {
        String? selectedDirectory =
            await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory != null) {
          String formattedDate =
              DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
          final backupPath =
              join(selectedDirectory, 'pos_backup_$formattedDate.db');

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
    if (!(await _requestStoragePermission())) {
      print('Storage permission not granted.');
      return false;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final backupPath = result.files.single.path!;
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'pos.db');

        final dbFile = File(path);
        final backupFile = File(backupPath);

        if (await backupFile.exists()) {
          await closeDatabase();

          if (await dbFile.exists()) {
            await dbFile.delete();
          }

          await backupFile.copy(dbFile.path);
          print('Database imported from ${backupFile.path}');

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
    _database = null;
  }

  Future<void> reopenDatabase(String path) async {
    _database = await openDatabase(path);
  }

  Future<List<SalesItem>> getAllSalesItems() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('sales_items');
    return List.generate(maps.length, (i) => SalesItem.fromMap(maps[i]));
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
