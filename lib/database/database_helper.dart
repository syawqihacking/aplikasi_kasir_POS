import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../services/telegram_service.dart';
import '../services/export_service.dart';
import '../services/supabase_sync_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static bool _storageReady = false;

  /// Wajib dipanggil sebelum openDatabase pertama (lihat main()).
  /// Mengarahkan database ke getApplicationSupportDirectory() yang writable
  /// tanpa admin, sehingga tidak lagi resolve ke Directory.current
  /// (folder kerja installasi -> Access denied di Program Files).
  static Future<void> ensureStorageReady() async {
    if (_storageReady) return;
    try {
      if (Platform.isWindows || Platform.isLinux) {
        // Catat lokasi lama SEBELUM setDatabasesPath (default ffi =
        // folder databases relatif Directory.current).
        String? legacyDbPath;
        try {
          final oldDir = await databaseFactory.getDatabasesPath();
          legacyDbPath = join(oldDir, 'pos_desktop.db');
        } catch (_) {}

        final support = await getApplicationSupportDirectory();
        await support.create(recursive: true);
        await databaseFactory.setDatabasesPath(support.path);

        // Migrasi ringan (copy, bukan move): jika db lama ada dan db baru belum ada.
        try {
          final newPath = join(support.path, 'pos_desktop.db');
          if (legacyDbPath != null &&
              legacyDbPath != newPath) {
            final legacyFile = File(legacyDbPath);
            final newFile = File(newPath);
            if (await legacyFile.exists() && !await newFile.exists()) {
              await legacyFile.copy(newPath);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Storage init error: $e');
    }
    _storageReady = true;
  }

  Future<Database> get database async {
    await ensureStorageReady();
    if (_database != null) return _database!;
    _database = await _initDB('pos_desktop.db');
    return _database!;
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }

  Future<void> vacuumDatabase() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  Future<void> performDailyMaintenance() async {
    try {
      await database;
      final settings = await getSettings();
      final lastReportDate = settings['last_report_date'] ?? settings['last_maintenance_date']; 
      final lastBackupDate = settings['last_backup_date'] ?? settings['last_maintenance_date']; 
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final yesterdayStr = now.subtract(const Duration(days: 1)).toIso8601String().split('T')[0];

      final tgService = TelegramService();
      final isTgConfigured = await tgService.isConfigured();

      // 1. Laporan Harian (Setiap hari untuk transaksi kemarin)
      if (lastReportDate != todayStr) {
        await SupabaseSyncService().cleanupDownloadedData();

        if (isTgConfigured) {
          final db = await database;
          final txns = await db.query('transactions', where: 'created_at LIKE ?', whereArgs: ['$yesterdayStr%']);
          
          if (txns.isNotEmpty) {
            final dbPath = await getDatabasePath();
            final reportDir = Directory(join(dirname(dbPath), 'reports'));
            if (!await reportDir.exists()) await reportDir.create(recursive: true);
            final reportPath = join(reportDir.path, 'Daily_Report_$yesterdayStr.pdf');
            
            double totalSales = 0;
            List<List<dynamic>> rows = [];
            for (var txn in txns) {
              totalSales += (txn['grand_total'] as num?)?.toDouble() ?? 0.0;
              rows.add([
                txn['invoice_no'],
                txn['created_at'].toString().substring(11, 16),
                txn['payment_method'],
                txn['grand_total'],
              ]);
            }
            
            await ExportService.exportToPdf(
              filePath: reportPath,
              title: 'Laporan Penjualan $yesterdayStr',
              headers: ['Invoice', 'Waktu', 'Metode', 'Total'],
              rows: rows,
              extraSections: [
                ReportSection(
                  title: 'Ringkasan',
                  headers: ['Deskripsi', 'Jumlah'],
                  rows: [
                    ['Total Transaksi', txns.length],
                    ['Total Pendapatan', totalSales],
                  ],
                )
              ],
            );
            
            await tgService.sendDocument(File(reportPath), caption: '📊 Laporan Penjualan Harian: $yesterdayStr');
          }
        }
        await saveSetting('last_report_date', todayStr);
        await saveSetting('last_maintenance_date', todayStr); // legacy
      }

      // 2. Backup Database Otomatis (Setiap 15 Hari)
      bool needsBackup = false;
      if (lastBackupDate == null || lastBackupDate.toString().isEmpty) {
        needsBackup = true;
      } else {
        try {
          final parsed = DateTime.parse(lastBackupDate.toString());
          if (now.difference(parsed).inDays.abs() >= 15) {
            needsBackup = true;
          }
        } catch(e) {
          needsBackup = true;
        }
      }

      if (needsBackup) {
        await vacuumDatabase();
        final dbPath = await getDatabasePath();
        final file = File(dbPath);
        if (await file.exists()) {
          final backupDir = Directory(join(dirname(dbPath), 'backups'));
          if (!await backupDir.exists()) await backupDir.create(recursive: true);
          final backupFile = join(backupDir.path, 'dashdock_auto_backup_$todayStr.db');
          final savedFile = await file.copy(backupFile);
          
          if (isTgConfigured) {
            await tgService.sendDocument(savedFile, caption: '✅ Backup Database Mingguan: $todayStr');
          }
        }
        await saveSetting('last_backup_date', todayStr);
        await logActivity('MAINTENANCE', 'system', 'Performed weekly database vacuum and backup');
      }
    } catch (e) {
      debugPrint('Maintenance error: $e');
    }
  }

  Future<String> getDatabasePath() async {
    await ensureStorageReady();
    final dbPath = await databaseFactory.getDatabasesPath();
    return join(dbPath, 'pos_desktop.db');
  }

  Future<void> updateSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Database> _initDB(String filePath) async {
    await ensureStorageReady();
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 11,
        onCreate: _createDB,
        onOpen: (db) async {
          // Ensure roles_permissions is seeded even for databases
          // that were created at version 9 without the seeding step.
          final existing = await db.query('roles_permissions');
          if (existing.isEmpty) {
            final modules = ['dashboard', 'pos', 'products', 'inventory', 'transactions', 'shift', 'settings', 'reports', 'users'];
            for (var m in modules) {
              await db.insert('roles_permissions', {
                'role': 'Admin', 'module': m,
                'can_view': 1, 'can_create': 1, 'can_edit': 1, 'can_delete': 1
              });
            }
            for (var m in modules) {
              final isRestricted = ['settings', 'reports', 'users'].contains(m);
              await db.insert('roles_permissions', {
                'role': 'Kasir', 'module': m,
                'can_view': isRestricted ? 0 : 1,
                'can_create': (m == 'pos' || m == 'shift') ? 1 : 0,
                'can_edit': 0, 'can_delete': 0
              });
            }
          }
          // Ensure default settings exist
          final settingsResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM settings');
          final settingsCount = settingsResult.first['cnt'] as int? ?? 0;
          if (settingsCount == 0) {
            final batch = db.batch();
            batch.insert('settings', {'key': 'store_name', 'value': 'DashDock Store'});
            batch.insert('settings', {'key': 'store_address', 'value': 'Jl. Contoh No. 123'});
            batch.insert('settings', {'key': 'store_phone', 'value': '08123456789'});
            batch.insert('settings', {'key': 'tax_percentage', 'value': '11'});
            await batch.commit();
          }
          // Ensure cash_shifts and transactions have modern columns
          try {
            await db.execute('ALTER TABLE cash_shifts ADD COLUMN shift_number TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE cash_shifts ADD COLUMN closing_note TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE transactions ADD COLUMN shift_id INTEGER DEFAULT 0');
          } catch (_) {}
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                invoice_no TEXT,
                subtotal REAL,
                tax_total REAL,
                grand_total REAL,
                payment_method TEXT,
                created_at TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE transaction_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                transaction_id INTEGER,
                product_id INTEGER,
                qty INTEGER,
                unit_price REAL,
                subtotal REAL,
                FOREIGN KEY (transaction_id) REFERENCES transactions (id),
                FOREIGN KEY (product_id) REFERENCES products (id)
              )
            ''');
          }
          if (oldVersion < 3) {
            try {
              await db.execute('ALTER TABLE transactions ADD COLUMN paid_amount REAL DEFAULT 0');
              await db.execute('ALTER TABLE transactions ADD COLUMN change_amount REAL DEFAULT 0');
              await db.execute('ALTER TABLE transactions ADD COLUMN cashier_id INTEGER DEFAULT 0');
            } catch (e) {
              // columns might already exist
            }
          }
          if (oldVersion < 4) {
            await db.execute('''
              CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                role TEXT NOT NULL,
                full_name TEXT NOT NULL,
                is_active INTEGER DEFAULT 1,
                created_at TEXT
              )
            ''');
            
            await db.insert('users', {
              'username': 'admin',
              'password_hash': hashPassword('admin123'),
              'role': 'Admin',
              'full_name': 'Super Admin',
              'is_active': 1,
              'created_at': DateTime.now().toIso8601String(),
            });
            
            await db.insert('users', {
              'username': 'kasir',
              'password_hash': hashPassword('kasir123'),
              'role': 'Kasir',
              'full_name': 'Kasir Utama',
              'is_active': 1,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
          if (oldVersion < 5) {
            await db.execute('''
              CREATE TABLE stock_in (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER,
                supplier_id INTEGER,
                qty INTEGER,
                cost_price REAL,
                invoice_no TEXT,
                created_by INTEGER,
                created_at TEXT,
                FOREIGN KEY (product_id) REFERENCES products (id)
              )
            ''');
          }
          if (oldVersion < 6) {
            await db.execute('''
              CREATE TABLE cash_shifts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cashier_id INTEGER,
                opening_balance REAL DEFAULT 0,
                closing_balance_system REAL DEFAULT 0,
                closing_balance_physical REAL DEFAULT 0,
                difference REAL DEFAULT 0,
                opened_at TEXT,
                closed_at TEXT,
                status TEXT DEFAULT 'OPEN'
              )
            ''');
          }
          if (oldVersion < 7) {
            await db.execute('''
              CREATE TABLE settings (
                key TEXT PRIMARY KEY,
                value TEXT
              )
            ''');
            
            // Default settings
            final batch = db.batch();
            batch.insert('settings', {'key': 'store_name', 'value': 'DashDock Store'});
            batch.insert('settings', {'key': 'store_address', 'value': 'Jl. Contoh No. 123'});
            batch.insert('settings', {'key': 'store_phone', 'value': '08123456789'});
            batch.insert('settings', {'key': 'tax_percentage', 'value': '11'});
            await batch.commit();
          }
          if (oldVersion < 8) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS roles_permissions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                role TEXT NOT NULL,
                module TEXT NOT NULL,
                can_view INTEGER DEFAULT 0,
                can_create INTEGER DEFAULT 0,
                can_edit INTEGER DEFAULT 0,
                can_delete INTEGER DEFAULT 0
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS suppliers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                phone TEXT,
                address TEXT,
                email TEXT,
                created_at TEXT,
                updated_at TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS price_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER,
                old_price REAL,
                new_price REAL,
                changed_by INTEGER,
                changed_at TEXT,
                FOREIGN KEY (product_id) REFERENCES products (id)
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS transaction_payments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                transaction_id INTEGER,
                method TEXT,
                amount REAL,
                FOREIGN KEY (transaction_id) REFERENCES transactions (id)
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS returns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                transaction_id INTEGER,
                reason TEXT,
                refund_amount REAL,
                approved_by INTEGER,
                created_at TEXT,
                FOREIGN KEY (transaction_id) REFERENCES transactions (id)
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS return_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                return_id INTEGER,
                product_id INTEGER,
                qty INTEGER,
                FOREIGN KEY (return_id) REFERENCES returns (id),
                FOREIGN KEY (product_id) REFERENCES products (id)
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS stock_out (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER,
                qty INTEGER,
                reason TEXT,
                notes TEXT,
                created_by INTEGER,
                created_at TEXT,
                FOREIGN KEY (product_id) REFERENCES products (id)
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS stock_opname (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                opname_date TEXT,
                product_id INTEGER,
                system_qty INTEGER,
                physical_qty INTEGER,
                difference INTEGER,
                adjusted INTEGER DEFAULT 0,
                created_by INTEGER,
                FOREIGN KEY (product_id) REFERENCES products (id)
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS stock_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER,
                change_type TEXT,
                qty_change INTEGER,
                reference_id INTEGER,
                changed_by INTEGER,
                changed_at TEXT,
                notes TEXT,
                FOREIGN KEY (product_id) REFERENCES products (id)
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS cash_movements (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                shift_id INTEGER,
                type TEXT,
                amount REAL,
                reason TEXT,
                created_by INTEGER,
                created_at TEXT,
                FOREIGN KEY (shift_id) REFERENCES cash_shifts (id)
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS activity_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                action TEXT,
                module TEXT,
                description TEXT,
                device_info TEXT,
                created_at TEXT
              )
            ''');
            // Seed default role permissions
            final modules = ['dashboard', 'pos', 'products', 'inventory', 'transactions', 'shift', 'settings', 'reports', 'users'];
            for (var m in modules) {
              await db.insert('roles_permissions', {
                'role': 'Admin', 'module': m,
                'can_view': 1, 'can_create': 1, 'can_edit': 1, 'can_delete': 1
              });
            }
            for (var m in modules) {
              final isRestricted = ['settings', 'reports', 'users'].contains(m);
              await db.insert('roles_permissions', {
                'role': 'Kasir', 'module': m,
                'can_view': isRestricted ? 0 : 1,
                'can_create': (m == 'pos' || m == 'shift') ? 1 : 0,
                'can_edit': 0, 'can_delete': 0
              });
            }
          }
          if (oldVersion < 9) {
            // Update existing users plain-text passwords to hashed passwords
            final users = await db.query('users');
            for (var user in users) {
              final password = user['password_hash'] as String;
              if (!password.contains(RegExp(r'^[a-f0-9]{64}$'))) { // if not already sha256
                await db.update(
                  'users', 
                  {'password_hash': hashPassword(password)}, 
                  where: 'id = ?', 
                  whereArgs: [user['id']]
                );
              }
            }
          }
          if (oldVersion < 10) {
            try {
              await db.execute('ALTER TABLE transactions ADD COLUMN synced INTEGER DEFAULT 0');
              await db.execute('ALTER TABLE cash_movements ADD COLUMN synced INTEGER DEFAULT 0');
            } catch (e) {
              // columns might already exist
            }
          }
          if (oldVersion < 11) {
            try {
              await db.execute('ALTER TABLE users ADD COLUMN synced INTEGER DEFAULT 0');
            } catch (e) {
              // columns might already exist
            }
          }
        }
      ),
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        full_name TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.insert('users', {
      'username': 'admin',
      'password_hash': hashPassword('admin123'),
      'role': 'Admin',
      'full_name': 'Super Admin',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('users', {
      'username': 'kasir',
      'password_hash': hashPassword('kasir123'),
      'role': 'Kasir',
      'full_name': 'Kasir Utama',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT,
        sku TEXT,
        name TEXT NOT NULL,
        category_id INTEGER,
        unit TEXT,
        cost_price REAL DEFAULT 0,
        sell_price REAL DEFAULT 0,
        min_stock INTEGER DEFAULT 0,
        current_stock INTEGER DEFAULT 0,
        rack_location TEXT,
        photo_path TEXT,
        is_active INTEGER DEFAULT 1,
        created_by INTEGER,
        created_at TEXT,
        updated_by INTEGER,
        updated_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_in (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        supplier_id INTEGER,
        qty INTEGER,
        cost_price REAL,
        invoice_no TEXT,
        created_by INTEGER,
        created_at TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE cash_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_number TEXT,
        cashier_id INTEGER,
        opening_balance REAL DEFAULT 0,
        closing_balance_system REAL DEFAULT 0,
        closing_balance_physical REAL DEFAULT 0,
        difference REAL DEFAULT 0,
        closing_note TEXT,
        opened_at TEXT,
        closed_at TEXT,
        status TEXT DEFAULT 'OPEN'
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE roles_permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        module TEXT NOT NULL,
        can_view INTEGER DEFAULT 0,
        can_create INTEGER DEFAULT 0,
        can_edit INTEGER DEFAULT 0,
        can_delete INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        email TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE price_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        old_price REAL,
        new_price REAL,
        changed_by INTEGER,
        changed_at TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT,
        subtotal REAL,
        tax_total REAL,
        grand_total REAL,
        paid_amount REAL,
        change_amount REAL,
        payment_method TEXT,
        cashier_id INTEGER,
        shift_id INTEGER DEFAULT 0,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER,
        product_id INTEGER,
        qty INTEGER,
        unit_price REAL,
        subtotal REAL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER,
        method TEXT,
        amount REAL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER,
        reason TEXT,
        refund_amount REAL,
        approved_by INTEGER,
        created_at TEXT,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER,
        product_id INTEGER,
        qty INTEGER,
        FOREIGN KEY (return_id) REFERENCES returns (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_out (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        qty INTEGER,
        reason TEXT,
        notes TEXT,
        created_by INTEGER,
        created_at TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_opname (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opname_date TEXT,
        product_id INTEGER,
        system_qty INTEGER,
        physical_qty INTEGER,
        difference INTEGER,
        adjusted INTEGER DEFAULT 0,
        created_by INTEGER,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        change_type TEXT,
        qty_change INTEGER,
        reference_id INTEGER,
        changed_by INTEGER,
        changed_at TEXT,
        notes TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE cash_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER,
        type TEXT,
        amount REAL,
        reason TEXT,
        created_by INTEGER,
        created_at TEXT,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (shift_id) REFERENCES cash_shifts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT,
        module TEXT,
        description TEXT,
        device_info TEXT,
        created_at TEXT
      )
    ''');

    await _insertDummyData(db);
  }

  Future _insertDummyData(Database db) async {
    // Seed default role permissions
    final modules = ['dashboard', 'pos', 'products', 'inventory', 'transactions', 'shift', 'settings', 'reports', 'users'];
    for (var m in modules) {
      await db.insert('roles_permissions', {
        'role': 'Admin', 'module': m,
        'can_view': 1, 'can_create': 1, 'can_edit': 1, 'can_delete': 1
      });
    }
    for (var m in modules) {
      final isRestricted = ['settings', 'reports', 'users'].contains(m);
      await db.insert('roles_permissions', {
        'role': 'Kasir', 'module': m,
        'can_view': isRestricted ? 0 : 1,
        'can_create': (m == 'pos' || m == 'shift') ? 1 : 0,
        'can_edit': 0, 'can_delete': 0
      });
    }

    // Default settings
    final batch = db.batch();
    batch.insert('settings', {'key': 'store_name', 'value': 'DashDock Store'});
    batch.insert('settings', {'key': 'store_address', 'value': 'Jl. Contoh No. 123'});
    batch.insert('settings', {'key': 'store_phone', 'value': '08123456789'});
    batch.insert('settings', {'key': 'tax_percentage', 'value': '11'});
    await batch.commit();

    await db.insert('categories', {'name': 'Food', 'description': 'Semua makanan'});
    await db.insert('categories', {'name': 'Beverages', 'description': 'Semua minuman'});
    await db.insert('categories', {'name': 'Electronics', 'description': 'Alat elektronik'});

    await db.insert('products', {
      'barcode': '1234567890123',
      'sku': 'SKU-001',
      'name': 'Indomie Goreng',
      'category_id': 1,
      'unit': 'Pcs',
      'cost_price': 2500,
      'sell_price': 3500,
      'current_stock': 120,
      'created_at': DateTime.now().toIso8601String()
    });

    await db.insert('products', {
      'barcode': '0987654321098',
      'sku': 'SKU-002',
      'name': 'Aqua Botol 600ml',
      'category_id': 2,
      'unit': 'Btl',
      'cost_price': 2000,
      'sell_price': 3000,
      'current_stock': 85,
      'created_at': DateTime.now().toIso8601String()
    });
  }
  
  // --- Products ---
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name 
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.is_active = 1
      ORDER BY p.name ASC
      LIMIT 500
    ''');
  }

  /// Check if barcode is already used by another product.
  /// Returns the product using this barcode, or null if available.
  /// [excludeProductId] allows ignoring a specific product (for edit mode).
  Future<Map<String, dynamic>?> findProductByBarcode(String barcode, {int? excludeProductId}) async {
    if (barcode.isEmpty) return null;
    final db = await instance.database;
    String query = 'SELECT * FROM products WHERE barcode = ? AND is_active = 1';
    List<dynamic> args = [barcode];
    if (excludeProductId != null) {
      query += ' AND id != ?';
      args.add(excludeProductId);
    }
    final results = await db.rawQuery(query, args);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await instance.database;
    product['created_at'] = DateTime.now().toIso8601String();
    
    int productId = 0;
    await db.transaction((txn) async {
      productId = await txn.insert('products', product);
      
      int qty = product['current_stock'] ?? 0;
      if (qty > 0) {
        await txn.insert('stock_in', {
          'product_id': productId,
          'supplier_id': null,
          'qty': qty,
          'cost_price': product['cost_price'] ?? 0.0,
          'invoice_no': 'Initial Stock',
          'created_by': 1, // Default user
          'created_at': product['created_at'],
        });
        await txn.insert('stock_history', {
          'product_id': productId,
          'change_type': 'IN',
          'qty_change': qty,
          'reference_id': null,
          'changed_by': 1,
          'changed_at': product['created_at'],
          'notes': 'Initial Stock',
        });
      }
    });
    return productId;
  }

  Future<void> restockProduct(int productId, int qty, double costPrice, String invoiceNo, {int? supplierId}) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('stock_in', {
        'product_id': productId,
        'supplier_id': supplierId,
        'qty': qty,
        'cost_price': costPrice,
        'invoice_no': invoiceNo,
        'created_by': 1, // Default user
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate('''
        UPDATE products 
        SET current_stock = current_stock + ? 
        WHERE id = ?
      ''', [qty, productId]);
      await txn.insert('stock_history', {
        'product_id': productId,
        'change_type': 'IN',
        'qty_change': qty,
        'reference_id': null,
        'changed_by': 1,
        'changed_at': DateTime.now().toIso8601String(),
        'notes': 'Invoice: $invoiceNo',
      });
    });
  }

  // --- Auth ---
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await instance.database;
    final hashedPwd = hashPassword(password);
    final results = await db.query(
      'users',
      where: 'username = ? AND password_hash = ? AND is_active = 1',
      whereArgs: [username, hashedPwd],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // --- Shift Management ---
  Future<String> generateNextShiftNumber() async {
    final db = await instance.database;
    final now = DateTime.now();
    final datePrefix = 'SHF-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM cash_shifts WHERE shift_number LIKE '$datePrefix%'"
    );
    final count = (result.first['count'] as int? ?? 0) + 1;
    return '$datePrefix-${count.toString().padLeft(3, '0')}';
  }

  Future<Map<String, dynamic>?> getActiveShift() async {
    final db = await instance.database;
    final results = await db.rawQuery('''
      SELECT cs.*, u.full_name as cashier_name, u.username as cashier_username
      FROM cash_shifts cs
      LEFT JOIN users u ON cs.cashier_id = u.id
      WHERE cs.status = 'OPEN'
      ORDER BY cs.opened_at DESC
      LIMIT 1
    ''');
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<Map<String, dynamic>> openShift({
    required int cashierId,
    required double openingBalance,
  }) async {
    final db = await instance.database;
    final existing = await getActiveShift();
    if (existing != null) {
      throw Exception('Masih ada shift yang aktif (${existing['shift_number'] ?? '#${existing['id']}'}). Tutup shift terlebih dahulu.');
    }
    final shiftNumber = await generateNextShiftNumber();
    final nowStr = DateTime.now().toIso8601String();
    
    final id = await db.insert('cash_shifts', {
      'shift_number': shiftNumber,
      'cashier_id': cashierId,
      'opening_balance': openingBalance,
      'closing_balance_system': 0.0,
      'closing_balance_physical': 0.0,
      'difference': 0.0,
      'opened_at': nowStr,
      'status': 'OPEN',
    });

    await logActivity('OPEN_SHIFT', 'shift', 'Buka shift $shiftNumber dengan modal awal Rp ${openingBalance.toStringAsFixed(0)}', userId: cashierId);

    return {
      'id': id,
      'shift_number': shiftNumber,
      'cashier_id': cashierId,
      'opening_balance': openingBalance,
      'opened_at': nowStr,
      'status': 'OPEN',
    };
  }

  Future<Map<String, dynamic>?> getActiveShiftSummary({int? shiftId}) async {
    final db = await instance.database;
    Map<String, dynamic>? shift;
    
    if (shiftId != null) {
      final res = await db.rawQuery('''
        SELECT cs.*, u.full_name as cashier_name, u.username as cashier_username
        FROM cash_shifts cs
        LEFT JOIN users u ON cs.cashier_id = u.id
        WHERE cs.id = ?
      ''', [shiftId]);
      if (res.isNotEmpty) shift = res.first;
    } else {
      shift = await getActiveShift();
    }

    if (shift == null) return null;
    final int sid = shift['id'] as int;
    final String openedAt = shift['opened_at'] as String;
    final String? closedAt = shift['closed_at'] as String?;

    // 1. Get transactions metrics
    final txQuery = closedAt != null
        ? "SELECT * FROM transactions WHERE (shift_id = ? OR (shift_id = 0 AND created_at >= ? AND created_at <= ?))"
        : "SELECT * FROM transactions WHERE (shift_id = ? OR (shift_id = 0 AND created_at >= ?))";
    final txArgs = closedAt != null ? [sid, openedAt, closedAt] : [sid, openedAt];
    final txList = await db.rawQuery(txQuery, txArgs);

    double totalCashSales = 0.0;
    double totalNonCashSales = 0.0;
    double totalSales = 0.0;
    int transactionCount = txList.length;

    for (var tx in txList) {
      final grandTotal = (tx['grand_total'] as num?)?.toDouble() ?? 0.0;
      final paidAmount = (tx['paid_amount'] as num?)?.toDouble() ?? grandTotal;
      final changeAmount = (tx['change_amount'] as num?)?.toDouble() ?? 0.0;
      final method = (tx['payment_method'] as String?) ?? 'Cash';

      totalSales += grandTotal;

      if (method.toLowerCase() == 'cash') {
        final netCash = (paidAmount - changeAmount).clamp(0.0, double.infinity);
        totalCashSales += netCash > 0 ? netCash : grandTotal;
      } else if (method.toLowerCase().startsWith('split')) {
        final match = RegExp(r'cash:\s*([0-9\.]+)', caseSensitive: false).firstMatch(method);
        if (match != null) {
          final splitCash = double.tryParse(match.group(1)!) ?? 0.0;
          totalCashSales += splitCash;
          totalNonCashSales += (grandTotal - splitCash).clamp(0.0, double.infinity);
        } else {
          totalCashSales += (grandTotal / 2);
          totalNonCashSales += (grandTotal / 2);
        }
      } else {
        totalNonCashSales += grandTotal;
      }
    }

    // 2. Get Cash Movements
    final inResult = await db.rawQuery("SELECT SUM(amount) as total FROM cash_movements WHERE shift_id = ? AND type = 'IN'", [sid]);
    final outResult = await db.rawQuery("SELECT SUM(amount) as total FROM cash_movements WHERE shift_id = ? AND type = 'OUT'", [sid]);
    final movementsIn = (inResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final movementsOut = (outResult.first['total'] as num?)?.toDouble() ?? 0.0;

    final double openingBalance = (shift['opening_balance'] as num?)?.toDouble() ?? 0.0;
    final expectedCash = openingBalance + totalCashSales + movementsIn - movementsOut;

    return {
      ...shift,
      'cashier_name': shift['cashier_name'] ?? shift['cashier_username'] ?? 'Kasir',
      'total_cash_sales': totalCashSales,
      'total_non_cash_sales': totalNonCashSales,
      'total_sales': totalSales,
      'sales_total': totalSales,
      'transaction_count': transactionCount,
      'movements_in': movementsIn,
      'movements_out': movementsOut,
      'total_cash_in': movementsIn,
      'total_cash_out': movementsOut,
      'expected_cash': expectedCash,
    };
  }

  Future<void> closeShift({
    required int shiftId,
    required double physicalBalance,
    String? note,
    int? closedBy,
  }) async {
    final db = await instance.database;
    final summary = await getActiveShiftSummary(shiftId: shiftId);
    if (summary == null) throw Exception('Shift #$shiftId tidak ditemukan');

    final double expectedCash = (summary['expected_cash'] as num?)?.toDouble() ?? 0.0;
    final double difference = physicalBalance - expectedCash;
    final nowStr = DateTime.now().toIso8601String();
    final cashierId = closedBy ?? (summary['cashier_id'] as int? ?? 1);

    await db.update('cash_shifts', {
      'closing_balance_system': expectedCash,
      'closing_balance_physical': physicalBalance,
      'difference': difference,
      'closing_note': note,
      'closed_at': nowStr,
      'status': 'CLOSED',
    }, where: 'id = ?', whereArgs: [shiftId]);

    final shiftNumber = summary['shift_number'] ?? '#$shiftId';
    await logActivity('CLOSE_SHIFT', 'shift', 'Tutup shift $shiftNumber. Kas Sistem: $expectedCash, Kas Fisik: $physicalBalance, Selisih: $difference', userId: cashierId);
  }

  Future<List<Map<String, dynamic>>> getShiftHistory({
    String? startDate,
    String? endDate,
    int? cashierId,
    String? status,
    String? searchQuery,
    int limit = 100,
  }) async {
    final db = await instance.database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null && startDate.isNotEmpty) {
      whereClause += ' AND cs.opened_at >= ?';
      whereArgs.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      whereClause += ' AND cs.opened_at <= ?';
      whereArgs.add(endDate);
    }
    if (cashierId != null && cashierId > 0) {
      whereClause += ' AND cs.cashier_id = ?';
      whereArgs.add(cashierId);
    }
    if (status != null && status.isNotEmpty && status != 'ALL') {
      whereClause += ' AND cs.status = ?';
      whereArgs.add(status);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause += ' AND (cs.shift_number LIKE ? OR u.full_name LIKE ? OR u.username LIKE ?)';
      final q = '%${searchQuery.trim()}%';
      whereArgs.addAll([q, q, q]);
    }

    final query = '''
      SELECT cs.*, COALESCE(u.full_name, u.username, 'Kasir') as cashier_name
      FROM cash_shifts cs
      LEFT JOIN users u ON cs.cashier_id = u.id
      WHERE $whereClause
      ORDER BY cs.opened_at DESC
      LIMIT $limit
    ''';

    final shifts = await db.rawQuery(query, whereArgs);
    List<Map<String, dynamic>> results = [];
    for (var s in shifts) {
      final summary = await getActiveShiftSummary(shiftId: s['id'] as int);
      results.add(summary ?? Map<String, dynamic>.from(s));
    }
    return results;
  }

  Future<Map<String, dynamic>?> getShiftDetails(int shiftId) async {
    final summary = await getActiveShiftSummary(shiftId: shiftId);
    if (summary == null) return null;
    final movements = await getShiftMovements(shiftId);
    final transactions = await getShiftTransactions(shiftId, openedAt: summary['opened_at'], closedAt: summary['closed_at']);
    return {
      ...summary,
      'movements': movements,
      'transactions': transactions,
    };
  }

  Future<List<Map<String, dynamic>>> getShiftMovements(int shiftId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT cm.*, COALESCE(u.full_name, u.username, 'User') as created_by_name
      FROM cash_movements cm
      LEFT JOIN users u ON cm.created_by = u.id
      WHERE cm.shift_id = ?
      ORDER BY cm.created_at DESC
    ''', [shiftId]);
  }

  Future<List<Map<String, dynamic>>> getShiftTransactions(int shiftId, {String? openedAt, String? closedAt}) async {
    final db = await instance.database;
    if (openedAt != null) {
      if (closedAt != null) {
        return await db.rawQuery('''
          SELECT t.*, COALESCE(u.full_name, u.username, 'Kasir') as cashier_name
          FROM transactions t
          LEFT JOIN users u ON t.cashier_id = u.id
          WHERE t.shift_id = ? OR (t.shift_id = 0 AND t.created_at >= ? AND t.created_at <= ?)
          ORDER BY t.created_at DESC
        ''', [shiftId, openedAt, closedAt]);
      } else {
        return await db.rawQuery('''
          SELECT t.*, COALESCE(u.full_name, u.username, 'Kasir') as cashier_name
          FROM transactions t
          LEFT JOIN users u ON t.cashier_id = u.id
          WHERE t.shift_id = ? OR (t.shift_id = 0 AND t.created_at >= ?)
          ORDER BY t.created_at DESC
        ''', [shiftId, openedAt]);
      }
    }
    return await db.rawQuery('''
      SELECT t.*, COALESCE(u.full_name, u.username, 'Kasir') as cashier_name
      FROM transactions t
      LEFT JOIN users u ON t.cashier_id = u.id
      WHERE t.shift_id = ?
      ORDER BY t.created_at DESC
    ''', [shiftId]);
  }

  // --- Settings ---
  Future<Map<String, String>> getSettings() async {
    final db = await instance.database;
    final results = await db.query('settings');
    Map<String, String> settings = {};
    for (var row in results) {
      settings[row['key'] as String] = row['value'] as String;
    }
    return settings;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> searchProducts(String keyword) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name 
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.is_active = 1 AND (p.name LIKE ? OR p.barcode = ? OR p.sku LIKE ?)
      ORDER BY p.name ASC
    ''', ['%$keyword%', keyword, '%$keyword%']);
  }

  // --- Transactions ---
  Future<String> saveTransaction({
    required double subtotal,
    required double tax,
    required double grandTotal,
    required double paidAmount,
    required double changeAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> cartItems,
  }) async {
    final db = await instance.database;
    final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    
    // Start a transaction block to ensure atomic operations
    await db.transaction((txn) async {
      // 1. Insert Transaction Header
      final transactionId = await txn.insert('transactions', {
        'invoice_no': invoiceNo,
        'subtotal': subtotal,
        'tax_total': tax,
        'grand_total': grandTotal,
        'paid_amount': paidAmount,
        'change_amount': changeAmount,
        'payment_method': paymentMethod,
        'cashier_id': 1, // Default user
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Insert Items and Reduce Stock
      for (var item in cartItems) {
        final int productId = item['id'];
        final int qty = item['qty'];
        final double price = (item['sell_price'] as num).toDouble();
        
        await txn.insert('transaction_items', {
          'transaction_id': transactionId,
          'product_id': productId,
          'qty': qty,
          'unit_price': price,
          'subtotal': price * qty,
        });

        // Deduct stock
        await txn.rawUpdate('''
          UPDATE products 
          SET current_stock = current_stock - ? 
          WHERE id = ?
        ''', [qty, productId]);
      }
    });

    // Trigger sync in background
    SupabaseSyncService().syncUnsyncedData().catchError((e) => debugPrint('Sync error: $e'));
    return invoiceNo;
  }

  Future<List<Map<String, dynamic>>> getTransactions({DateTime? startDate, DateTime? endDate}) async {
    final db = await instance.database;
    String whereClause = '';
    List<Object?> args = [];
    if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().substring(0, 10);
      final endStr = endDate.toIso8601String().substring(0, 10);
      whereClause = ' WHERE created_at >= ? AND created_at <= ?';
      args = ['${startStr}T00:00:00', '${endStr}T23:59:59'];
    }
    return await db.rawQuery('''
      SELECT * FROM transactions 
      $whereClause
      ORDER BY created_at DESC 
      LIMIT 100
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getTransactionItems(int transactionId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT ti.*, p.name as product_name
      FROM transaction_items ti
      LEFT JOIN products p ON ti.product_id = p.id
      WHERE ti.transaction_id = ?
    ''', [transactionId]);
  }

  Future<bool> verifyAdminPin(String pin) async {
    final db = await instance.database;
    final hashedPin = hashPassword(pin);
    final adminList = await db.query(
      'users',
      where: 'role = ? AND password_hash = ? AND is_active = 1',
      whereArgs: ['Admin', hashedPin],
    );
    return adminList.isNotEmpty;
  }

  Future<void> voidTransaction(int transactionId, String pin) async {
    final db = await instance.database;
    
    // Verify Admin PIN
    if (!(await verifyAdminPin(pin))) {
      throw Exception('Invalid Admin PIN / Password');
    }
    
    // Fetch transaction to get amount
    final txList = await db.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
    if (txList.isEmpty) throw Exception('Transaction not found');
    final grandTotal = (txList.first['grand_total'] as num).toDouble();
    
    // Fetch items
    final items = await getTransactionItems(transactionId);
    
    // Use createReturn logic
    await createReturn(
      transactionId, 
      'VOID - Admin Approval', 
      grandTotal, 
      items.map((e) => {'product_id': e['product_id'], 'qty': e['qty']}).toList()
    );
  }

  // --- Suppliers ---
  Future<List<Map<String, dynamic>>> getAllSuppliers() async {
    final db = await instance.database;
    return await db.query('suppliers', orderBy: 'name ASC');
  }

  Future<int> insertSupplier(Map<String, dynamic> supplier) async {
    final db = await instance.database;
    supplier['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('suppliers', supplier);
  }

  Future<int> updateSupplier(int id, Map<String, dynamic> supplier) async {
    final db = await instance.database;
    supplier['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('suppliers', supplier, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSupplier(int id) async {
    final db = await instance.database;
    return await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  // --- Stock Out ---
  Future<void> stockOut(int productId, int qty, String reason, String notes) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('stock_out', {
        'product_id': productId,
        'qty': qty,
        'reason': reason,
        'notes': notes,
        'created_by': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate('''
        UPDATE products SET current_stock = current_stock - ? WHERE id = ?
      ''', [qty, productId]);
      await txn.insert('stock_history', {
        'product_id': productId,
        'change_type': 'OUT',
        'qty_change': -qty,
        'reference_id': null,
        'changed_by': 1,
        'changed_at': DateTime.now().toIso8601String(),
        'notes': '$reason: $notes',
      });
    });
  }

  // --- Stock History ---
  Future<List<Map<String, dynamic>>> getStockHistory({int? productId}) async {
    final db = await instance.database;
    String query = '''
      SELECT sh.*, p.name as product_name
      FROM stock_history sh
      LEFT JOIN products p ON sh.product_id = p.id
    ''';
    List<dynamic> args = [];
    if (productId != null) {
      query += ' WHERE sh.product_id = ?';
      args.add(productId);
    }
    query += ' ORDER BY sh.changed_at DESC LIMIT 200';
    return await db.rawQuery(query, args);
  }

  // --- Price History ---
  Future<void> updateProductPrice(int productId, double newPrice, {int changedBy = 1}) async {
    final db = await instance.database;
    // Get old price
    final product = await db.query('products', where: 'id = ?', whereArgs: [productId]);
    if (product.isEmpty) return;
    final oldPrice = (product.first['sell_price'] as num).toDouble();
    if (oldPrice == newPrice) return;

    await db.transaction((txn) async {
      await txn.insert('price_history', {
        'product_id': productId,
        'old_price': oldPrice,
        'new_price': newPrice,
        'changed_by': changedBy,
        'changed_at': DateTime.now().toIso8601String(),
      });
      await txn.update('products', {'sell_price': newPrice, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [productId]);
    });
  }



  // --- Returns ---
  Future<void> createReturn(int transactionId, String reason, double refundAmount, List<Map<String, dynamic>> items) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final returnId = await txn.insert('returns', {
        'transaction_id': transactionId,
        'reason': reason,
        'refund_amount': refundAmount,
        'approved_by': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (var item in items) {
        await txn.insert('return_items', {
          'return_id': returnId,
          'product_id': item['product_id'],
          'qty': item['qty'],
        });
        // Restore stock
        await txn.rawUpdate('UPDATE products SET current_stock = current_stock + ? WHERE id = ?', [item['qty'], item['product_id']]);
      }
    });
  }

  // --- Cash Movements ---
  Future<int> addCashMovement(int shiftId, String type, double amount, String reason, {int userId = 1}) async {
    final db = await instance.database;
    final id = await db.insert('cash_movements', {
      'shift_id': shiftId,
      'type': type,
      'amount': amount,
      'reason': reason,
      'created_by': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
    final typeLabel = type.toUpperCase() == 'IN' ? 'Cash In (Pemasukan)' : 'Cash Out (Pengeluaran)';
    await logActivity('CASH_MOVEMENT', 'shift', '$typeLabel Rp ${amount.toStringAsFixed(0)} - $reason', userId: userId);
    // Trigger sync in background
    SupabaseSyncService().syncUnsyncedData().catchError((e) => debugPrint('Sync error: $e'));
    return id;
  }

  Future<List<Map<String, dynamic>>> getCashMovements(int shiftId) async {
    final db = await instance.database;
    return await db.query('cash_movements', where: 'shift_id = ?', whereArgs: [shiftId], orderBy: 'created_at DESC');
  }

  Future<void> recordCashMovement(String type, double amount, String reason, {int userId = 1}) async {
    final db = await instance.database;
    await db.insert('cash_movements', {
      'shift_id': 0, // Without shift
      'type': type, // 'IN' for Pemasukan, 'OUT' for Pengeluaran
      'amount': amount,
      'reason': reason,
      'created_by': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
    // Trigger sync in background
    SupabaseSyncService().syncUnsyncedData().catchError((e) => debugPrint('Sync error: $e'));
  }

  Future<List<Map<String, dynamic>>> getAllCashMovements({String? startDate, String? endDate}) async {
    final db = await instance.database;
    String query = 'SELECT * FROM cash_movements WHERE 1=1';
    List<dynamic> args = [];
    if (startDate != null) {
      query += ' AND created_at >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      query += ' AND created_at <= ?';
      args.add(endDate);
    }
    query += ' ORDER BY created_at DESC';
    return await db.rawQuery(query, args);
  }

  Future<void> deleteCashMovement(int id) async {
    final db = await instance.database;
    await db.delete('cash_movements', where: 'id = ?', whereArgs: [id]);
  }

  // --- Activity Logs ---
  Future<void> logActivity(String action, String module, String description, {int userId = 1}) async {
    final db = await instance.database;
    await db.insert('activity_logs', {
      'user_id': userId,
      'action': action,
      'module': module,
      'description': description,
      'device_info': Platform.operatingSystem,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({String? startDate, String? endDate, int limit = 100}) async {
    final db = await instance.database;
    String whereClause = '';
    List<dynamic> args = [];
    if (startDate != null && endDate != null) {
      whereClause = 'WHERE al.created_at >= ? AND al.created_at <= ?';
      args.addAll([startDate, endDate]);
    }
    args.add(limit);
    
    return await db.rawQuery('''
      SELECT al.*, u.full_name as user_name
      FROM activity_logs al
      LEFT JOIN users u ON al.user_id = u.id
      $whereClause
      ORDER BY al.created_at DESC
      LIMIT ?
    ''', args);
  }

  // --- Roles & Permissions ---
  Future<List<Map<String, dynamic>>> getPermissions(String role) async {
    final db = await instance.database;
    return await db.query('roles_permissions', where: 'role = ?', whereArgs: [role]);
  }

  Future<bool> hasPermission(String role, String module, String action) async {
    final db = await instance.database;
    final results = await db.query('roles_permissions', where: 'role = ? AND module = ?', whereArgs: [role, module]);
    if (results.isEmpty) return false;
    final perm = results.first;
    switch (action) {
      case 'view': return perm['can_view'] == 1;
      case 'create': return perm['can_create'] == 1;
      case 'edit': return perm['can_edit'] == 1;
      case 'delete': return perm['can_delete'] == 1;
      default: return false;
    }
  }

  // --- Users CRUD ---
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await instance.database;
    return await db.query('users', orderBy: 'username ASC');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    user['password_hash'] = hashPassword(user['password_hash']);
    user['created_at'] = DateTime.now().toIso8601String();
    final id = await db.insert('users', user);
    SupabaseSyncService().syncUnsyncedData().catchError((e) => debugPrint('Sync error: $e'));
    return id;
  }

  Future<int> updateUser(int id, Map<String, dynamic> user) async {
    final db = await instance.database;
    if (user.containsKey('password_hash')) {
      user['password_hash'] = hashPassword(user['password_hash']);
    }
    user['synced'] = 0;
    final result = await db.update('users', user, where: 'id = ?', whereArgs: [id]);
    SupabaseSyncService().syncUnsyncedData().catchError((e) => debugPrint('Sync error: $e'));
    return result;
  }

  Future<int> toggleUserActive(int id, bool isActive) async {
    final db = await instance.database;
    final result = await db.update('users', {'is_active': isActive ? 1 : 0, 'synced': 0}, where: 'id = ?', whereArgs: [id]);
    SupabaseSyncService().syncUnsyncedData().catchError((e) => debugPrint('Sync error: $e'));
    return result;
  }

  // --- Product Update ---
  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await instance.database;
    
    // Check old price
    final oldProductQuery = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (oldProductQuery.isNotEmpty && product.containsKey('sell_price')) {
      final oldPrice = (oldProductQuery.first['sell_price'] as num?)?.toDouble() ?? 0.0;
      final newPrice = (product['sell_price'] as num?)?.toDouble() ?? 0.0;
      if (oldPrice != newPrice) {
        await logPriceChange(productId: id, oldPrice: oldPrice, newPrice: newPrice);
      }
    }

    product['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('products', product, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> softDeleteProduct(int id) async {
    final db = await instance.database;
    return await db.update('products', {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> reactivateProduct(int id) async {
    final db = await instance.database;
    return await db.update('products', {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  /// Menghapus produk permanen. Riwayat transaksi/stok/harga tetap dipertahankan
  /// dengan mengosongkan product_id pada tabel yang mereferensikan produk.
  Future<void> deleteProduct(int id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Tabel yang mereferensikan products.id (tanpa ON DELETE CASCADE)
      const refTables = ['transaction_items', 'stock_in', 'stock_out', 'stock_history', 'price_history', 'return_items', 'stock_opname'];
      for (final table in refTables) {
        await txn.rawUpdate('UPDATE $table SET product_id = NULL WHERE product_id = ?', [id]);
      }
      await txn.delete('products', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> logPriceChange({required int productId, required double oldPrice, required double newPrice, int changedBy = 1}) async {
    final db = await instance.database;
    await db.insert('price_history', {
      'product_id': productId,
      'old_price': oldPrice,
      'new_price': newPrice,
      'changed_by': changedBy,
      'changed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPriceHistory(int productId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT ph.*, u.full_name as changed_by_name
      FROM price_history ph
      LEFT JOIN users u ON ph.changed_by = u.id
      WHERE ph.product_id = ?
      ORDER BY ph.changed_at DESC
    ''', [productId]);
  }

  Future<List<Map<String, dynamic>>> getAllProductsIncludingInactive() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name 
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.is_active DESC, p.name ASC
    ''');
  }

  // --- Categories CRUD ---
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await instance.database;
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<int> insertCategory(Map<String, dynamic> cat) async {
    final db = await instance.database;
    return await db.insert('categories', cat);
  }

  Future<int> updateCategory(int id, Map<String, dynamic> cat) async {
    final db = await instance.database;
    return await db.update('categories', cat, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- Stock Opname ---
  Future<void> saveStockOpname(List<Map<String, dynamic>> items) async {
    final db = await instance.database;
    final opnameDate = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (var item in items) {
        await txn.insert('stock_opname', {
          'opname_date': opnameDate,
          'product_id': item['product_id'],
          'system_qty': item['system_qty'],
          'physical_qty': item['physical_qty'],
          'difference': item['physical_qty'] - item['system_qty'],
          'adjusted': 0,
          'created_by': 1,
        });
      }
    });
  }

  Future<void> applyStockOpnameAdjustment(int opnameId) async {
    final db = await instance.database;
    final opname = await db.query('stock_opname', where: 'id = ?', whereArgs: [opnameId]);
    if (opname.isEmpty) return;
    final item = opname.first;
    final difference = (item['difference'] as int);
    if (difference == 0) return;

    await db.transaction((txn) async {
      await txn.rawUpdate('UPDATE products SET current_stock = ? WHERE id = ?', [item['physical_qty'], item['product_id']]);
      await txn.update('stock_opname', {'adjusted': 1}, where: 'id = ?', whereArgs: [opnameId]);
      await txn.insert('stock_history', {
        'product_id': item['product_id'],
        'change_type': 'OPNAME',
        'qty_change': difference,
        'reference_id': opnameId,
        'changed_by': 1,
        'changed_at': DateTime.now().toIso8601String(),
        'notes': 'Stock opname adjustment',
      });
    });
  }

  // --- Dashboard Stats & Widgets ---
  Future<Map<String, dynamic>> getDashboardStats({DateTime? startDate, DateTime? endDate}) async {
    final db = await instance.database;
    
    final salesResult = await db.rawQuery('SELECT SUM(grand_total) as total FROM transactions');
    final totalSales = salesResult.first['total'] ?? 0.0;
    
    final ordersResult = await db.rawQuery('SELECT COUNT(id) as count FROM transactions');
    final totalOrders = ordersResult.first['count'] ?? 0;
    
    final productsResult = await db.rawQuery('SELECT SUM(qty) as count FROM transaction_items');
    final totalSoldProducts = productsResult.first['count'] ?? 0;

    final totalProductsResult = await db.rawQuery('SELECT COUNT(id) as count FROM products WHERE is_active = 1');
    final totalProducts = totalProductsResult.first['count'] ?? 0;

    final totalCategoriesResult = await db.rawQuery('SELECT COUNT(id) as count FROM categories');
    final totalCategories = totalCategoriesResult.first['count'] ?? 0;

    final totalSuppliersResult = await db.rawQuery('SELECT COUNT(id) as count FROM suppliers');
    final totalSuppliers = totalSuppliersResult.first['count'] ?? 0;

    final lowStockResult = await db.rawQuery('SELECT COUNT(id) as count FROM products WHERE is_active = 1 AND current_stock <= min_stock');
    final lowStockCount = lowStockResult.first['count'] ?? 0;

    final noBarcodeResult = await db.rawQuery("SELECT COUNT(id) as count FROM products WHERE is_active = 1 AND (barcode IS NULL OR barcode = '')");
    final noBarcodeCount = noBarcodeResult.first['count'] ?? 0;

    final todayStart = DateTime.now().toIso8601String().substring(0, 10);
    String todayWhereClause = 'created_at >= ?';
    List<String> todayWhereArgs = ['${todayStart}T00:00:00'];
    if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().substring(0, 10);
      final endStr = endDate.toIso8601String().substring(0, 10);
      todayWhereClause = 'created_at >= ? AND created_at <= ?';
      todayWhereArgs = ['${startStr}T00:00:00', '${endStr}T23:59:59'];
    }
    final todaySalesResult = await db.rawQuery("SELECT SUM(grand_total) as total, COUNT(id) as count FROM transactions WHERE $todayWhereClause", todayWhereArgs);
    final todaySales = todaySalesResult.first['total'] ?? 0.0;
    final todayOrders = todaySalesResult.first['count'] ?? 0;

    final todayProfitResult = await db.rawQuery('''
      SELECT 
             SUM(ti.subtotal) as total_revenue,
             SUM(ti.subtotal - (ti.qty * COALESCE(p.cost_price, 0))) as total_profit
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      LEFT JOIN products p ON ti.product_id = p.id
      WHERE t.$todayWhereClause
    ''', todayWhereArgs);
    
    final todayGross = todayProfitResult.first['total_revenue'] ?? todaySales;
    final todayNet = todayProfitResult.first['total_profit'] ?? 0.0;

    final todayExpenseResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM cash_movements WHERE type = 'OUT' AND $todayWhereClause",
      todayWhereArgs,
    );
    final todayExpense = todayExpenseResult.first['total'] ?? 0.0;

    return {
      'totalSales': totalSales,
      'totalOrders': totalOrders,
      'totalSoldProducts': totalSoldProducts,
      'totalProducts': totalProducts,
      'totalCategories': totalCategories,
      'totalSuppliers': totalSuppliers,
      'lowStockCount': lowStockCount,
      'noBarcodeCount': noBarcodeCount,
      'todaySales': todaySales,
      'todayOrders': todayOrders,
      'todayGross': todayGross,
      'todayNet': todayNet,
      'todayExpense': todayExpense,
    };
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT * FROM products
      WHERE current_stock <= min_stock AND min_stock > 0
      ORDER BY current_stock ASC
      LIMIT 50
    ''');
  }

  // --- Reporting Queries ---

  Future<List<Map<String, dynamic>>> getSalesReport(String startDate, String endDate) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT t.id as transaction_id, t.invoice_no, t.created_at, t.grand_total as total_amount, t.payment_method, 
             u.username as cashier, 
             CASE WHEN r.id IS NOT NULL THEN 'returned' ELSE 'completed' END as status
      FROM transactions t
      LEFT JOIN users u ON t.cashier_id = u.id
      LEFT JOIN returns r ON t.id = r.transaction_id
      WHERE t.created_at >= ? AND t.created_at <= ?
      ORDER BY t.created_at DESC
      LIMIT 500
    ''', [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getTopSellingItems(String startDate, String endDate) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT COALESCE(p.name, 'Produk dihapus') as product_name, SUM(ti.qty) as total_qty, 
             SUM(ti.subtotal) as total_revenue
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      LEFT JOIN products p ON ti.product_id = p.id
      WHERE t.created_at >= ? AND t.created_at <= ?
      GROUP BY p.id
      ORDER BY total_qty DESC
      LIMIT 500
    ''', [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getDailySales({int? days, DateTime? startDate, DateTime? endDate}) async {
    final db = await instance.database;
    final effectiveDays = days ?? 7;

    // Build date buckets and where clauses.
    List<String> dateStrs = [];
    String salesWhereClause;
    String stockInWhereClause;
    List<String> queryArgs;

    if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().substring(0, 10);
      final endStr = endDate.toIso8601String().substring(0, 10);
      salesWhereClause = 'created_at >= ? AND created_at <= ?';
      stockInWhereClause = 'si.created_at >= ? AND si.created_at <= ?';
      queryArgs = ['${startStr}T00:00:00', '${endStr}T23:59:59'];

      final startDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endDay = DateTime(endDate.year, endDate.month, endDate.day);
      for (var d = startDay; !d.isAfter(endDay); d = DateTime(d.year, d.month, d.day + 1)) {
        dateStrs.add(d.toIso8601String().substring(0, 10));
      }
    } else {
      final startDateStr = DateTime.now().subtract(Duration(days: effectiveDays - 1)).toIso8601String().substring(0, 10);
      salesWhereClause = 'created_at >= ?';
      stockInWhereClause = 'si.created_at >= ?';
      queryArgs = ['${startDateStr}T00:00:00'];

      for (int i = 0; i < effectiveDays; i++) {
        final d = DateTime.now().subtract(Duration(days: effectiveDays - 1 - i));
        dateStrs.add(d.toIso8601String().substring(0, 10));
      }
    }

    // SQLite string functions to group by date
    final salesData = await db.rawQuery('''
      SELECT substr(created_at, 1, 10) as date, SUM(grand_total) as total_sales
      FROM transactions
      WHERE $salesWhereClause
      GROUP BY substr(created_at, 1, 10)
    ''', queryArgs);

    final stockInData = await db.rawQuery('''
      SELECT substr(si.created_at, 1, 10) as date, 
             SUM(si.qty * CASE 
               WHEN si.cost_price > 0 THEN si.cost_price 
               WHEN p.cost_price > 0 THEN p.cost_price 
               ELSE p.sell_price 
             END) as total_stock_in
      FROM stock_in si
      LEFT JOIN products p ON si.product_id = p.id
      WHERE $stockInWhereClause
      GROUP BY substr(si.created_at, 1, 10)
    ''', queryArgs);


    // Combine data by date
    Map<String, Map<String, dynamic>> combined = {};
    
    for (final dateStr in dateStrs) {
      combined[dateStr] = {'date': dateStr, 'total_sales': 0.0, 'total_stock_in': 0.0};
    }

    for (var row in salesData) {
      final date = row['date'] as String;
      if (combined.containsKey(date)) {
        combined[date]!['total_sales'] = row['total_sales'] ?? 0.0;
      }
    }

    for (var row in stockInData) {
      final date = row['date'] as String;
      if (combined.containsKey(date)) {
        combined[date]!['total_stock_in'] = row['total_stock_in'] ?? 0.0;
      }
    }

    final result = combined.values.toList();
    result.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return result;
  }

  Future<List<Map<String, dynamic>>> getProfitReport(String startDate, String endDate) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT COALESCE(p.name, 'Produk dihapus') as product_name, 
             SUM(ti.qty) as total_qty,
             SUM(ti.qty * COALESCE(p.cost_price, 0)) as total_cost,
             SUM(ti.subtotal) as total_revenue,
             SUM(ti.subtotal - (ti.qty * COALESCE(p.cost_price, 0))) as total_profit
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      LEFT JOIN products p ON ti.product_id = p.id
      WHERE t.created_at >= ? AND t.created_at <= ?
      GROUP BY p.id
      ORDER BY total_profit DESC
      LIMIT 500
    ''', [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getInventoryFlow(String startDate, String endDate) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT sh.changed_at as created_at, COALESCE(p.name, 'Produk dihapus') as product_name, sh.qty_change as change_qty,
             sh.change_type as type, sh.notes as reason, sh.reference_id
      FROM stock_history sh
      LEFT JOIN products p ON sh.product_id = p.id
      WHERE sh.changed_at >= ? AND sh.changed_at <= ?
      ORDER BY sh.changed_at DESC
      LIMIT 500
    ''', [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getShiftReport(String startDate, String endDate) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT cs.opened_at, cs.closed_at, u.username as cashier,
             cs.opening_balance, cs.closing_balance_system, cs.closing_balance_physical,
             cs.difference, cs.status
      FROM cash_shifts cs
      LEFT JOIN users u ON cs.cashier_id = u.id
      WHERE cs.opened_at >= ? AND (cs.opened_at <= ? OR cs.closed_at <= ?)
      ORDER BY cs.opened_at DESC
      LIMIT 500
    ''', [startDate, endDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getCurrentStockValue() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.name as product_name, p.current_stock, p.cost_price, p.sell_price,
             (p.current_stock * p.cost_price) as total_cost_value,
             (p.current_stock * p.sell_price) as total_sell_value
      FROM products p
      WHERE p.current_stock > 0
      ORDER BY p.name ASC
      LIMIT 500
    ''');
  }

  Future<List<Map<String, dynamic>>> getProductsWithoutBarcode() async {
    final db = await instance.database;
    return await db.query('products', where: "is_active = 1 AND (barcode IS NULL OR barcode = '')", limit: 10);
  }

  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 10, DateTime? startDate, DateTime? endDate}) async {
    final db = await instance.database;
    if (startDate != null && endDate != null) {
      final startStr = startDate.toIso8601String().substring(0, 10);
      final endStr = endDate.toIso8601String().substring(0, 10);
      return await db.query(
        'transactions',
        where: 'created_at >= ? AND created_at <= ?',
        whereArgs: ['${startStr}T00:00:00', '${endStr}T23:59:59'],
        orderBy: 'created_at DESC',
        limit: limit,
      );
    }
    return await db.query('transactions', orderBy: 'created_at DESC', limit: limit);
  }

  // --- Sync Methods ---
  Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
    final db = await instance.database;
    // Get transactions and their items for sync
    final txns = await db.query('transactions', where: 'synced = 0');
    List<Map<String, dynamic>> result = [];
    for (var txn in txns) {
      final items = await db.query('transaction_items', where: 'transaction_id = ?', whereArgs: [txn['id']]);
      Map<String, dynamic> txnMap = Map<String, dynamic>.from(txn);
      txnMap['items'] = items;
      result.add(txnMap);
    }
    return result;
  }

  Future<void> markTransactionsAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    await db.update('transactions', {'synced': 1}, where: 'id IN (${ids.map((_) => '?').join(',')})', whereArgs: ids);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedCashMovements() async {
    final db = await instance.database;
    return await db.query('cash_movements', where: 'synced = 0');
  }

  Future<void> markCashMovementsAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    await db.update('cash_movements', {'synced': 1}, where: 'id IN (${ids.map((_) => '?').join(',')})', whereArgs: ids);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedUsers() async {
    final db = await instance.database;
    return await db.query('users', where: 'synced = 0');
  }

  Future<void> markUsersAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    await db.update('users', {'synced': 1}, where: 'id IN (${ids.map((_) => '?').join(',')})', whereArgs: ids);
  }
}

