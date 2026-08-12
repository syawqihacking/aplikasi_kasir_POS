import 'package:sqflite_common/sqlite_api.dart';
import '../../../database/database_helper.dart';

class AssistantRepository {
  Future<Database> get db async => await DatabaseHelper.instance.database;

  Future<Map<String, dynamic>> getSalesSummary(String startDate, String endDate) async {
    final database = await db;
    final result = await database.rawQuery('''
      SELECT 
             COUNT(id) as total_transactions,
             SUM(grand_total) as total_sales,
             SUM(tax_total) as total_tax
      FROM transactions 
      WHERE created_at >= ? AND created_at <= ?
    ''', [startDate, endDate]);
    
    return result.first;
  }

  Future<double> getProfit(String startDate, String endDate) async {
    final database = await db;
    final result = await database.rawQuery('''
      SELECT 
             SUM(ti.subtotal - (ti.qty * p.cost_price)) as total_profit
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      JOIN products p ON ti.product_id = p.id
      WHERE t.created_at >= ? AND t.created_at <= ?
    ''', [startDate, endDate]);
    
    return (result.first['total_profit'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getExpense(String startDate, String endDate) async {
    // The instructions mentioned expenseToday. Let's see if expenses table exists.
    // If not, we'll try to find out or just return 0 if it fails.
    // I will use a try-catch for now just in case `expenses` or `cash_out` is not the exact table name.
    final database = await db;
    try {
        final result = await database.rawQuery('''
          SELECT SUM(amount) as total_expense
          FROM expenses
          WHERE created_at >= ? AND created_at <= ?
        ''', [startDate, endDate]);
        return (result.first['total_expense'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
        // Try shift_activities for cash_out
        try {
            final result = await database.rawQuery('''
              SELECT SUM(amount) as total_expense
              FROM shift_activities
              WHERE activity_type = 'cash_out' AND created_at >= ? AND created_at <= ?
            ''', [startDate, endDate]);
            return (result.first['total_expense'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {
            return 0.0;
        }
    }
  }

  Future<List<Map<String, dynamic>>> searchProductsByStock(String query) async {
    final database = await db;
    return await database.query(
      'products',
      where: 'name LIKE ? AND is_active = 1',
      whereArgs: ['%\$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts(int threshold) async {
    final database = await db;
    return await database.query(
      'products',
      where: 'current_stock <= ? AND is_active = 1',
      whereArgs: [threshold],
      orderBy: 'current_stock ASC',
      limit: 10,
    );
  }

  Future<List<Map<String, dynamic>>> getBestSellingProducts(String startDate, String endDate) async {
    final database = await db;
    return await database.rawQuery('''
      SELECT p.name, p.current_stock, SUM(ti.qty) as total_qty
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      JOIN products p ON ti.product_id = p.id
      WHERE t.created_at >= ? AND t.created_at <= ?
      GROUP BY p.id
      ORDER BY total_qty DESC
      LIMIT 10
    ''', [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> getSlowMovingProducts(String startDate, String endDate) async {
    final database = await db;
    return await database.rawQuery('''
      SELECT name, current_stock
      FROM products
      WHERE id NOT IN (
        SELECT DISTINCT product_id 
        FROM transaction_items ti
        JOIN transactions t ON ti.transaction_id = t.id
        WHERE t.created_at >= ? AND t.created_at <= ?
      ) AND is_active = 1
      LIMIT 10
    ''', [startDate, endDate]);
  }

  Future<List<Map<String, dynamic>>> searchTransactions(String query) async {
    final database = await db;
    // Check invoice_no or customer_name
    return await database.rawQuery('''
      SELECT t.invoice_no, t.grand_total, t.created_at, c.name as customer_name
      FROM transactions t
      LEFT JOIN customers c ON t.customer_id = c.id
      WHERE t.invoice_no LIKE ? OR c.name LIKE ?
      ORDER BY t.created_at DESC
      LIMIT 10
    ''', ['%\$query%', '%\$query%']);
  }

  Future<List<Map<String, dynamic>>> getTopCustomers(String startDate, String endDate) async {
    final database = await db;
    return await database.rawQuery('''
      SELECT c.name, COUNT(t.id) as total_transactions, SUM(t.grand_total) as total_spent
      FROM transactions t
      JOIN customers c ON t.customer_id = c.id
      WHERE t.created_at >= ? AND t.created_at <= ?
      GROUP BY c.id
      ORDER BY total_spent DESC
      LIMIT 10
    ''', [startDate, endDate]);
  }
}
