import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';

class SupabaseSyncService {
  static final SupabaseSyncService _instance = SupabaseSyncService._internal();
  factory SupabaseSyncService() => _instance;
  SupabaseSyncService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final supabaseUrl = 'https://txxcfqnfusjybwkrbsyq.supabase.co';
    final supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4eGNmcW5mdXNqeWJ3a3Jic3lxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2MDY0NjUsImV4cCI6MjEwMjE4MjQ2NX0.dGIcgZP_fnDGEP454wdsnClknBLp_U1iGklx91dRK5s';

    if (supabaseUrl != null && supabaseUrl.isNotEmpty && supabaseAnonKey != null && supabaseAnonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
        );
        _isInitialized = true;
      } catch (e) {
        print('Error initializing Supabase: $e');
      }
    }
  }

  Future<void> syncUnsyncedData() async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return; // Still not initialized
    }

    final supabase = Supabase.instance.client;
    final dbHelper = DatabaseHelper.instance;

    try {
      // Sync Transactions
      final unsyncedTxns = await dbHelper.getUnsyncedTransactions();
      if (unsyncedTxns.isNotEmpty) {
        List<int> syncedTxnIds = [];
        for (var txn in unsyncedTxns) {
          try {
            // Upsert transaction to Supabase table 'transactions_sync'
            await supabase.from('transactions_sync').upsert({
              'local_id': txn['id'],
              'invoice_no': txn['invoice_no'],
              'subtotal': txn['subtotal'],
              'tax_total': txn['tax_total'],
              'grand_total': txn['grand_total'],
              'payment_method': txn['payment_method'],
              'cashier_id': txn['cashier_id'],
              'created_at': txn['created_at'],
              'items': txn['items'], // Store items as JSONB in Supabase
            });
            syncedTxnIds.add(txn['id']);
          } catch (e) {
            print('Error syncing transaction ${txn["id"]}: $e');
          }
        }
        if (syncedTxnIds.isNotEmpty) {
          await dbHelper.markTransactionsAsSynced(syncedTxnIds);
        }
      }

      // Sync Cash Movements
      final unsyncedMovements = await dbHelper.getUnsyncedCashMovements();
      if (unsyncedMovements.isNotEmpty) {
        List<int> syncedMovementIds = [];
        for (var movement in unsyncedMovements) {
          try {
            await supabase.from('cash_movements_sync').upsert({
              'local_id': movement['id'],
              'shift_id': movement['shift_id'],
              'type': movement['type'],
              'amount': movement['amount'],
              'reason': movement['reason'],
              'created_by': movement['created_by'],
              'created_at': movement['created_at'],
            });
            syncedMovementIds.add(movement['id']);
          } catch (e) {
            print('Error syncing cash movement ${movement["id"]}: $e');
          }
        }
        if (syncedMovementIds.isNotEmpty) {
          await dbHelper.markCashMovementsAsSynced(syncedMovementIds);
        }
      }

      // Sync Users
      final unsyncedUsers = await dbHelper.getUnsyncedUsers();
      if (unsyncedUsers.isNotEmpty) {
        List<int> syncedUserIds = [];
        for (var user in unsyncedUsers) {
          try {
            await supabase.from('users_sync').upsert({
              'local_id': user['id'],
              'username': user['username'],
              'password_hash': user['password_hash'],
              'role': user['role'],
              'full_name': user['full_name'],
              'is_active': user['is_active'],
              'created_at': user['created_at'],
            });
            syncedUserIds.add(user['id']);
          } catch (e) {
            print('Error syncing user ${user["id"]}: $e');
          }
        }
        if (syncedUserIds.isNotEmpty) {
          await dbHelper.markUsersAsSynced(syncedUserIds);
        }
      }
    } catch (e) {
      print('Global sync error: $e');
    }
  }

  Future<void> cleanupDownloadedData() async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }
    
    final supabase = Supabase.instance.client;
    try {
      // Menghapus data yang sudah di-download oleh aplikasi mobile
      // Asumsi: aplikasi mobile telah meng-update kolom 'is_downloaded' menjadi true (boolean)
      await supabase.from('transactions_sync').delete().eq('is_downloaded', true);
      await supabase.from('cash_movements_sync').delete().eq('is_downloaded', true);
      await supabase.from('users_sync').delete().eq('is_downloaded', true);
      print('Supabase cleanup successful');
    } catch (e) {
      print('Error cleaning up Supabase data: $e');
    }
  }
}
