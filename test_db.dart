// ignore_for_file: avoid_print
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  final dbPath = '/home/albert/Desktop/customerbandung/.dart_tool/sqflite_common_ffi/databases/pos_desktop.db';
  final db = await databaseFactory.openDatabase(dbPath);
  
  final res = await db.rawQuery('SELECT * FROM stock_in');
  print('STOCK IN: $res');
  
  final stockInData = await db.rawQuery('''
      SELECT substr(created_at, 1, 10) as date, SUM(qty * cost_price) as total_stock_in
      FROM stock_in
      GROUP BY substr(created_at, 1, 10)
    ''');
  print('STOCK IN GROUPED: $stockInData');
  
  await db.close();
}
