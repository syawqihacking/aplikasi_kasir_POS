import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'backup_service.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'warning', 'danger', 'info'
  final IconData icon;
  final int? productId; // null for non-product notifications
  final bool isSeen;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    this.productId,
    this.isSeen = false,
  });
}

class NotificationService {
  static const String _seenSettingKey = 'notifications_seen';

  static Future<List<AppNotification>> getNotifications() async {
    List<AppNotification> notifications = [];
    final db = DatabaseHelper.instance;

    // Seen-state: notification ids the user has already viewed.
    final settings = await db.getSettings();
    final Set<String> seenIds = _readSeenIds(settings[_seenSettingKey]);

    // 1. Stok Habis & Stok Menipis — per produk
    final products = await db.getAllProducts(); // Active products only

    for (var p in products) {
      final int productId = (p['id'] as num).toInt();
      final String name = _productName(p, productId);
      final int current = (p['current_stock'] as num?)?.toInt() ?? 0;
      final int min = (p['min_stock'] as num?)?.toInt() ?? 0;

      if (current <= 0) {
        notifications.add(_build(
          id: 'out_stock_$productId',
          productId: productId,
          title: name,
          message: 'Stok habis (0). Klik untuk detail.',
          type: 'danger',
          icon: Icons.error_outline,
          seenIds: seenIds,
        ));
      } else if (current <= min) {
        notifications.add(_build(
          id: 'low_stock_$productId',
          productId: productId,
          title: name,
          message: 'Stok tersisa $current (minimum $min). Klik untuk detail.',
          type: 'warning',
          icon: Icons.warning_amber_rounded,
          seenIds: seenIds,
        ));
      }
    }

    // 2. Produk Tanpa Barcode — per produk
    for (var p in products) {
      final int productId = (p['id'] as num).toInt();
      final String name = _productName(p, productId);
      final barcode = p['barcode']?.toString() ?? '';
      if (barcode.isEmpty) {
        notifications.add(_build(
          id: 'no_barcode_$productId',
          productId: productId,
          title: name,
          message: 'Barcode belum diisi. Klik untuk detail.',
          type: 'info',
          icon: Icons.qr_code_scanner,
          seenIds: seenIds,
        ));
      }
    }

    // 3. Shift Belum Ditutup — agregat (non-produk)
    final shifts = await db.getShiftReport(
      DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
      DateTime.now().toIso8601String(),
    );

    int openShifts = 0;
    for (var s in shifts) {
      if (s['status'] == 'OPEN') {
        openShifts++;
      }
    }

    if (openShifts > 0) {
      notifications.add(_build(
        id: 'shift_open',
        title: 'Shift Terbuka',
        message: 'Ada $openShifts shift kasir yang belum ditutup (Close Shift).',
        type: 'warning',
        icon: Icons.access_time,
        seenIds: seenIds,
      ));
    }

    // 4. Backup Belum Dilakukan — agregat (non-produk)
    final needsBackup = await BackupService.shouldWarnBackup();
    if (needsBackup) {
      notifications.add(_build(
        id: 'backup_warning',
        title: 'Peringatan Backup',
        message: 'Anda belum melakukan backup database dalam 7 hari terakhir. Sangat disarankan untuk mem-backup data.',
        type: 'danger',
        icon: Icons.backup_outlined,
        seenIds: seenIds,
      ));
    }

    // Prune: buang id seen yang tidak lagi punya notifikasi aktif (mis.
    // produk sudah di-restock) supaya badge muncul lagi jika masalah kembali.
    final currentIds = notifications.map((n) => n.id).toSet();
    final pruned = seenIds.where(currentIds.contains).toList();
    if (pruned.length != seenIds.length) {
      await db.saveSetting(_seenSettingKey, jsonEncode(pruned));
    }

    return notifications;
  }

  /// Simpan union seen list lama + [ids] ke settings (JSON).
  static Future<void> markAllSeen(List<String> ids) async {
    final db = DatabaseHelper.instance;
    final settings = await db.getSettings();
    final seen = _readSeenIds(settings[_seenSettingKey]);
    seen.addAll(ids);
    await db.saveSetting(_seenSettingKey, jsonEncode(seen.toList()));
  }

  static AppNotification _build({
    required String id,
    required String title,
    required String message,
    required String type,
    required IconData icon,
    required Set<String> seenIds,
    int? productId,
  }) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      icon: icon,
      productId: productId,
      isSeen: seenIds.contains(id),
    );
  }

  static String _productName(Map<String, dynamic> p, int productId) {
    final raw = p['name']?.toString().trim() ?? '';
    return raw.isNotEmpty ? raw : 'Produk #$productId';
  }

  static Set<String> _readSeenIds(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } catch (_) {
      // Corrupt value — treat as empty.
    }
    return {};
  }
}