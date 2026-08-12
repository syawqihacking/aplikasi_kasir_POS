import 'dart:io';
import 'package:excel/excel.dart';
import '../database/database_helper.dart';

class ImportExportService {
  // ──────────────── PRODUCT EXPORT ────────────────
  static Future<String> exportProducts(String filePath) async {
    final products = await DatabaseHelper.instance.getAllProductsIncludingInactive();
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    excel.setDefaultSheet('Products');

    sheet.appendRow([
      TextCellValue('Barcode'),
      TextCellValue('SKU'),
      TextCellValue('Nama Produk'),
      TextCellValue('Kategori'),
      TextCellValue('Satuan'),
      TextCellValue('Harga Beli (Cost)'),
      TextCellValue('Harga Jual (Sell)'),
      TextCellValue('Stok Minimum'),
      TextCellValue('Stok Saat Ini'),
      TextCellValue('Lokasi Rak'),
      TextCellValue('Status'),
    ]);

    for (var p in products) {
      sheet.appendRow([
        TextCellValue(p['barcode']?.toString() ?? ''),
        TextCellValue(p['sku']?.toString() ?? ''),
        TextCellValue(p['name']?.toString() ?? ''),
        TextCellValue(p['category_name']?.toString() ?? ''),
        TextCellValue(p['unit']?.toString() ?? ''),
        DoubleCellValue((p['cost_price'] as num?)?.toDouble() ?? 0),
        DoubleCellValue((p['sell_price'] as num?)?.toDouble() ?? 0),
        DoubleCellValue((p['min_stock'] as num?)?.toDouble() ?? 0),
        DoubleCellValue((p['current_stock'] as num?)?.toDouble() ?? 0),
        TextCellValue(p['rack_location']?.toString() ?? ''),
        TextCellValue(p['is_active'] == 1 ? 'Active' : 'Inactive'),
      ]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
    return filePath;
  }

  // ──────────────── PRODUCT TEMPLATE ────────────────
  static Future<String> downloadProductTemplate(String filePath) async {
    final excel = Excel.createExcel();
    final sheet = excel['Template_Produk'];
    excel.setDefaultSheet('Template_Produk');

    sheet.appendRow([
      TextCellValue('barcode'),
      TextCellValue('sku'),
      TextCellValue('name'),
      TextCellValue('category'),
      TextCellValue('unit'),
      TextCellValue('cost_price'),
      TextCellValue('sell_price'),
      TextCellValue('min_stock'),
      TextCellValue('current_stock'),
      TextCellValue('rack_location'),
    ]);

    // Example row
    sheet.appendRow([
      TextCellValue('8991234567890'),
      TextCellValue('SKU-001'),
      TextCellValue('Produk Contoh'),
      TextCellValue('Makanan'),
      TextCellValue('pcs'),
      DoubleCellValue(5000),
      DoubleCellValue(8000),
      DoubleCellValue(10),
      DoubleCellValue(50),
      TextCellValue('Rak A1'),
    ]);

    final bytes = excel.save();
    if (bytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
    return filePath;
  }

  // ──────────────── PRODUCT IMPORT ────────────────
  static Future<ImportResult> importProducts(String filePath) async {
    final bytes = File(filePath).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;

    if (sheet.rows.isEmpty) {
      return ImportResult(success: 0, errors: ['File kosong atau tidak valid.']);
    }

    // Detect header row
    final headerRow = sheet.rows.first;
    final headers = headerRow.map((c) => c?.value?.toString().toLowerCase().trim() ?? '').toList();

    // Validate minimum headers
    final nameIdx = headers.indexOf('name');
    if (nameIdx == -1) {
      // Try alternative
      final altIdx = headers.indexOf('nama produk');
      if (altIdx == -1) {
        return ImportResult(success: 0, errors: ['Kolom "name" tidak ditemukan di header. Gunakan template yang disediakan.']);
      }
    }

    // Map headers to column indices
    int col(String key) {
      final idx = headers.indexOf(key);
      if (idx != -1) return idx;
      // Try alternatives
      final alternatives = <String, List<String>>{
        'name': ['nama produk', 'nama', 'product_name'],
        'barcode': ['barcode', 'kode_barcode'],
        'sku': ['sku', 'kode_sku'],
        'category': ['category', 'kategori', 'category_name'],
        'unit': ['unit', 'satuan'],
        'cost_price': ['cost_price', 'harga beli', 'harga_beli', 'harga beli (cost)'],
        'sell_price': ['sell_price', 'harga jual', 'harga_jual', 'harga jual (sell)'],
        'min_stock': ['min_stock', 'stok minimum', 'stok_minimum'],
        'current_stock': ['current_stock', 'stok saat ini', 'stok_saat_ini', 'stok'],
        'rack_location': ['rack_location', 'lokasi rak', 'lokasi_rak'],
      };
      for (var alt in (alternatives[key] ?? [])) {
        final i = headers.indexOf(alt);
        if (i != -1) return i;
      }
      return -1;
    }

    String cellStr(List<Data?> row, int idx) {
      if (idx < 0 || idx >= row.length) return '';
      final v = row[idx]?.value;
      if (v is TextCellValue) return v.value.toString().trim();
      if (v is IntCellValue) return v.value.toString();
      if (v is DoubleCellValue) return v.value.toString();
      return '';
    }

    double cellDouble(List<Data?> row, int idx) {
      if (idx < 0 || idx >= row.length) return 0;
      final v = row[idx]?.value;
      if (v is IntCellValue) return v.value.toDouble();
      if (v is DoubleCellValue) return v.value;
      if (v is TextCellValue) return double.tryParse(v.value.toString()) ?? 0;
      return 0;
    }

    int cellInt(List<Data?> row, int idx) {
      if (idx < 0 || idx >= row.length) return 0;
      final v = row[idx]?.value;
      if (v is IntCellValue) return v.value;
      if (v is DoubleCellValue) return v.value.toInt();
      if (v is TextCellValue) return int.tryParse(v.value.toString()) ?? 0;
      return 0;
    }

    // Get all categories for category matching
    final categories = await DatabaseHelper.instance.getAllCategories();
    Map<String, int> catMap = {};
    for (var c in categories) {
      catMap[c['name'].toString().toLowerCase()] = c['id'] as int;
    }

    final nameColIdx = col('name');
    List<String> errors = [];
    int successCount = 0;

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowNum = i + 1;

      final name = cellStr(row, nameColIdx);
      if (name.isEmpty) {
        errors.add('Baris $rowNum: Nama produk kosong, dilewati.');
        continue;
      }

      final categoryName = cellStr(row, col('category'));
      int? categoryId;
      if (categoryName.isNotEmpty) {
        categoryId = catMap[categoryName.toLowerCase()];
        if (categoryId == null) {
          // Auto-create category
          final newId = await DatabaseHelper.instance.insertCategory({'name': categoryName});
          catMap[categoryName.toLowerCase()] = newId;
          categoryId = newId;
        }
      }

      try {
        await DatabaseHelper.instance.insertProduct({
          'barcode': cellStr(row, col('barcode')),
          'sku': cellStr(row, col('sku')),
          'name': name,
          'category_id': categoryId,
          'unit': cellStr(row, col('unit')),
          'cost_price': cellDouble(row, col('cost_price')),
          'sell_price': cellDouble(row, col('sell_price')),
          'min_stock': cellInt(row, col('min_stock')),
          'current_stock': cellInt(row, col('current_stock')),
          'rack_location': cellStr(row, col('rack_location')),
          'is_active': 1,
        });
        successCount++;
      } catch (e) {
        errors.add('Baris $rowNum ($name): $e');
      }
    }

    return ImportResult(success: successCount, errors: errors);
  }

  // ──────────────── SUPPLIER EXPORT ────────────────
  static Future<String> exportSuppliers(String filePath) async {
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    final excel = Excel.createExcel();
    final sheet = excel['Suppliers'];
    excel.setDefaultSheet('Suppliers');

    sheet.appendRow([
      TextCellValue('Nama'),
      TextCellValue('Telepon'),
      TextCellValue('Email'),
      TextCellValue('Alamat'),
    ]);

    for (var s in suppliers) {
      sheet.appendRow([
        TextCellValue(s['name']?.toString() ?? ''),
        TextCellValue(s['phone']?.toString() ?? ''),
        TextCellValue(s['email']?.toString() ?? ''),
        TextCellValue(s['address']?.toString() ?? ''),
      ]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
    return filePath;
  }

  // ──────────────── SUPPLIER TEMPLATE ────────────────
  static Future<String> downloadSupplierTemplate(String filePath) async {
    final excel = Excel.createExcel();
    final sheet = excel['Template_Supplier'];
    excel.setDefaultSheet('Template_Supplier');

    sheet.appendRow([
      TextCellValue('name'),
      TextCellValue('phone'),
      TextCellValue('email'),
      TextCellValue('address'),
    ]);

    sheet.appendRow([
      TextCellValue('PT Contoh Supplier'),
      TextCellValue('08123456789'),
      TextCellValue('supplier@email.com'),
      TextCellValue('Jl. Contoh No. 1'),
    ]);

    final bytes = excel.save();
    if (bytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
    return filePath;
  }

  // ──────────────── SUPPLIER IMPORT ────────────────
  static Future<ImportResult> importSuppliers(String filePath) async {
    final bytes = File(filePath).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;

    if (sheet.rows.isEmpty) {
      return ImportResult(success: 0, errors: ['File kosong atau tidak valid.']);
    }

    final headerRow = sheet.rows.first;
    final headers = headerRow.map((c) => c?.value?.toString().toLowerCase().trim() ?? '').toList();

    int col(String key) {
      final idx = headers.indexOf(key);
      if (idx != -1) return idx;
      final alternatives = <String, List<String>>{
        'name': ['nama', 'supplier_name', 'nama supplier'],
        'phone': ['telepon', 'phone', 'no_telp', 'no telp'],
        'email': ['email', 'e-mail'],
        'address': ['alamat', 'address'],
      };
      for (var alt in (alternatives[key] ?? [])) {
        final i = headers.indexOf(alt);
        if (i != -1) return i;
      }
      return -1;
    }

    String cellStr(List<Data?> row, int idx) {
      if (idx < 0 || idx >= row.length) return '';
      final v = row[idx]?.value;
      if (v is TextCellValue) return v.value.toString().trim();
      if (v is IntCellValue) return v.value.toString();
      if (v is DoubleCellValue) return v.value.toString();
      return '';
    }

    final nameColIdx = col('name');
    if (nameColIdx == -1) {
      return ImportResult(success: 0, errors: ['Kolom "name" tidak ditemukan. Gunakan template yang disediakan.']);
    }

    List<String> errors = [];
    int successCount = 0;

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowNum = i + 1;

      final name = cellStr(row, nameColIdx);
      if (name.isEmpty) {
        errors.add('Baris $rowNum: Nama supplier kosong, dilewati.');
        continue;
      }

      try {
        await DatabaseHelper.instance.insertSupplier({
          'name': name,
          'phone': cellStr(row, col('phone')),
          'email': cellStr(row, col('email')),
          'address': cellStr(row, col('address')),
        });
        successCount++;
      } catch (e) {
        errors.add('Baris $rowNum ($name): $e');
      }
    }

    return ImportResult(success: successCount, errors: errors);
  }
}

class ImportResult {
  final int success;
  final List<String> errors;

  ImportResult({required this.success, required this.errors});

  bool get hasErrors => errors.isNotEmpty;
}
