import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import '../database/database_helper.dart';
import 'package:path_provider/path_provider.dart';

class BackupService {
  static const int MAX_BACKUPS = 5;
  
  static Future<String> _getBackupDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(join(dir.path, 'DashDock_Backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  static Future<String> backupDatabase({String? customPath}) async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) {
        throw Exception("Database file not found.");
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'pos_desktop_backup_$timestamp.db';
      
      String destinationPath;
      if (customPath != null) {
        destinationPath = join(customPath, backupFileName);
      } else {
        final backupDir = await _getBackupDirectory();
        destinationPath = join(backupDir, backupFileName);
      }

      await DatabaseHelper.instance.close();
      await dbFile.copy(destinationPath);
      
      // Save last backup date
      await DatabaseHelper.instance.database; // Re-open
      await DatabaseHelper.instance.updateSetting('last_backup_date', DateTime.now().toIso8601String());

      if (customPath == null) {
        await _cleanOldBackups();
      }

      return destinationPath;
    } catch (e) {
      // Ensure DB re-opens if failed
      await DatabaseHelper.instance.database;
      throw Exception('Failed to backup: $e');
    }
  }

  static Future<void> restoreDatabase(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception("Backup file not found at $backupFilePath");
      }

      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      
      await DatabaseHelper.instance.close();
      await backupFile.copy(dbPath);
      
      // Re-open to verify
      await DatabaseHelper.instance.database;
    } catch (e) {
      await DatabaseHelper.instance.database;
      throw Exception('Failed to restore: $e');
    }
  }

  static Future<void> _cleanOldBackups() async {
    final backupDir = Directory(await _getBackupDirectory());
    final files = backupDir.listSync().whereType<File>().toList();
    
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    
    if (files.length > MAX_BACKUPS) {
      for (int i = MAX_BACKUPS; i < files.length; i++) {
        await files[i].delete();
      }
    }
  }

  static Future<String?> getLastBackupDate() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: ['last_backup_date']);
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return null;
  }

  static Future<bool> shouldWarnBackup() async {
    final lastBackup = await getLastBackupDate();
    if (lastBackup == null) return true;
    
    final date = DateTime.parse(lastBackup);
    final diff = DateTime.now().difference(date).inDays;
    return diff >= 7; // Warn if > 7 days
  }
}
