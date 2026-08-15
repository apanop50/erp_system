/// Database Helper
///
/// Singleton class that manages the SQLite database for the ERP system.
/// Handles database creation, migration, and provides access to the database.
/// Uses sqflite_common_ffi for desktop platform support.
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../constants/app_constants.dart';

/// Singleton database helper for managing SQLite operations.
///
/// Provides:
/// - Database initialization
/// - Table creation
/// - Database migrations
/// - CRUD operation access
class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  /// Private constructor for singleton pattern
  DatabaseHelper._internal();

  /// Returns the database instance, initializing if necessary.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initializes the database at the given [path].
  ///
  /// Called during app startup from main.dart.
  Future<void> initDatabase(String path) async {
    _database = await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Internal database initialization
  Future<Database> _initDatabase() async {
    // This should not be called directly; use initDatabase instead
    throw StateError(
      'Database not initialized. Call initDatabase() first.',
    );
  }

  /// Called when the database is created for the first time.
  ///
  /// Creates all tables for the ERP system.
  Future<void> _onCreate(Database db, int version) async {
    // ==================== USERS TABLE ====================
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        phone TEXT,
        photo TEXT,
        address TEXT,
        role TEXT NOT NULL DEFAULT 'admin',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ==================== CATEGORIES TABLE ====================
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        name_ar TEXT,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ==================== SUPPLIERS TABLE ====================
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        company_name TEXT,
        phone TEXT,
        whatsapp TEXT,
        address TEXT,
        city TEXT,
        email TEXT,
        tax_number TEXT,
        balance REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ==================== PRODUCTS TABLE ====================
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        image TEXT,
        name TEXT NOT NULL,
        name_ar TEXT,
        name_en TEXT,
        barcode TEXT,
        internal_code TEXT,
        category_id TEXT,
        supplier_id TEXT,
        cost_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        hotel_price REAL NOT NULL DEFAULT 0,
        wholesale_price REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'piece',
        current_stock REAL NOT NULL DEFAULT 0,
        minimum_stock REAL NOT NULL DEFAULT 0,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    // ==================== CUSTOMERS TABLE ====================
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        company_name TEXT,
        phone TEXT,
        whatsapp TEXT,
        address TEXT,
        city TEXT,
        email TEXT,
        tax_number TEXT,
        customer_type TEXT NOT NULL DEFAULT 'normal',
        account_balance REAL NOT NULL DEFAULT 0,
        credit_limit REAL NOT NULL DEFAULT 0,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ==================== HOTELS TABLE ====================
    await db.execute('''
      CREATE TABLE hotels (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // ==================== HOTEL SPECIAL PRICES TABLE ====================
    await db.execute('''
      CREATE TABLE hotel_special_prices (
        id TEXT PRIMARY KEY,
        hotel_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        special_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (hotel_id) REFERENCES hotels(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // ==================== PRINTED BAGS ORDERS TABLE ====================
    await db.execute('''
      CREATE TABLE printed_bags_orders (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        customer_logo TEXT,
        printing_design TEXT,
        printing_colors TEXT,
        printing_size TEXT,
        printing_quantity INTEGER NOT NULL DEFAULT 0,
        printing_notes TEXT,
        status TEXT NOT NULL DEFAULT 'new',
        unit_price REAL NOT NULL DEFAULT 0,
        total_price REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // ==================== SALES INVOICES TABLE ====================
    await db.execute('''
      CREATE TABLE sales_invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_id TEXT NOT NULL,
        sales_rep_id TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        tax_percentage REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        remaining_balance REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'unpaid',
        notes TEXT,
        invoice_date TEXT NOT NULL,
        due_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // ==================== SALES INVOICE ITEMS TABLE ====================
    await db.execute('''
      CREATE TABLE sales_invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES sales_invoices(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // ==================== PURCHASES INVOICES TABLE ====================
    await db.execute('''
      CREATE TABLE purchases_invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT UNIQUE NOT NULL,
        supplier_id TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        grand_total REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        remaining_balance REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'unpaid',
        notes TEXT,
        invoice_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    // ==================== PURCHASE INVOICE ITEMS TABLE ====================
    await db.execute('''
      CREATE TABLE purchase_invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES purchases_invoices(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // ==================== EXPENSES TABLE ====================
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        description TEXT,
        amount REAL NOT NULL DEFAULT 0,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ==================== SALES REPRESENTATIVES TABLE ====================
    await db.execute('''
      CREATE TABLE sales_representatives (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        photo TEXT,
        address TEXT,
        commission_rate REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ==================== PAYMENTS TABLE ====================
    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        invoice_id TEXT,
        customer_id TEXT,
        amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        payment_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES sales_invoices(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // ==================== SETTINGS TABLE ====================
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // ==================== CREATE INDEXES ====================
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_category ON products(category_id)');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_customers_type ON customers(customer_type)');
    await db.execute('CREATE INDEX idx_invoices_customer ON sales_invoices(customer_id)');
    await db.execute('CREATE INDEX idx_invoices_date ON sales_invoices(invoice_date)');
    await db.execute('CREATE INDEX idx_invoices_status ON sales_invoices(status)');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(expense_date)');
    await db.execute('CREATE INDEX idx_payments_customer ON payments(customer_id)');
  }

  /// Called when the database needs to be upgraded.
  ///
  /// Handles migrations between versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations will be handled here
    // For now, no migrations needed as we're on version 1
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ==================== GENERIC CRUD HELPERS ====================

  /// Inserts a row into the specified [table].
  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    return db.insert(table, row);
  }

  /// Queries rows from the specified [table].
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Updates rows in the specified [table].
  Future<int> update(
    String table,
    Map<String, dynamic> row, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return db.update(table, row, where: where, whereArgs: whereArgs);
  }

  /// Deletes rows from the specified [table].
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Executes a raw SQL query.
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, arguments);
  }

  /// Executes a raw SQL insert/update/delete.
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return db.rawInsert(sql, arguments);
  }

  /// Executes a raw SQL update/delete.
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return db.rawUpdate(sql, arguments);
  }

  /// Executes a raw SQL delete.
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return db.rawDelete(sql, arguments);
  }

  /// Executes a transaction.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }
}