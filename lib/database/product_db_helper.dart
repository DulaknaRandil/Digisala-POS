import 'package:paylink_pos/models/group_model.dart';
import 'package:paylink_pos/models/product_model.dart';
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
}
