import 'package:flutter/material.dart' hide Intent;
import 'intent.dart';

class DateRangeParser {
  static DateTimeRange? parse(String input) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (input.contains('hari ini')) {
      return DateTimeRange(start: todayStart, end: todayEnd);
    } else if (input.contains('kemarin')) {
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final yesterdayEnd = todayEnd.subtract(const Duration(days: 1));
      return DateTimeRange(start: yesterdayStart, end: yesterdayEnd);
    } else if (input.contains('minggu ini')) {
      // Monday to Sunday of the current week
      final weekday = now.weekday; // 1 = Monday, 7 = Sunday
      final startOfWeek = todayStart.subtract(Duration(days: weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      return DateTimeRange(start: startOfWeek, end: endOfWeek);
    } else if (input.contains('bulan ini')) {
      final startOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
      final endOfMonth = DateTime(now.year, now.month, lastDayOfMonth, 23, 59, 59);
      return DateTimeRange(start: startOfMonth, end: endOfMonth);
    } else if (input.contains('tahun ini')) {
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);
      return DateTimeRange(start: startOfYear, end: endOfYear);
    }
    
    // Default to today if no period found
    return DateTimeRange(start: todayStart, end: todayEnd);
  }
}

class MatchResult {
  final Intent intent;
  final String? entity;

  MatchResult(this.intent, this.entity);
}

class IntentMatcher {
  static MatchResult match(String input) {
    final normalized = input.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
    
    // Mapping of intents to their keywords
    final intentKeywords = <Intent, List<String>>{
      Intent.salesToday: ['penjualan hari ini', 'omzet hari ini'],
      Intent.salesByPeriod: ['penjualan bulan ini', 'penjualan minggu ini', 'laporan penjualan', 'penjualan kemarin', 'penjualan tahun ini'],
      Intent.expenseToday: ['pengeluaran hari ini'],
      Intent.expenseByPeriod: ['pengeluaran bulan ini', 'pengeluaran minggu ini', 'pengeluaran kemarin', 'pengeluaran tahun ini'],
      Intent.profitToday: ['laba hari ini', 'untung hari ini', 'keuntungan hari ini'],
      Intent.lowStockProducts: ['stok menipis', 'barang hampir habis'],
      Intent.stockCheck: ['stok ', 'cek stok '], // entity extraction needed
      Intent.bestSellingProducts: ['produk terlaris', 'barang terlaris'],
      Intent.slowMovingProducts: ['produk tidak laku', 'barang tidak laku'],
      Intent.transactionSearch: ['cari transaksi ', 'transaksi '], // entity extraction needed
      Intent.customerInfo: ['data pelanggan ', 'riwayat pembelian '], // entity extraction needed
      Intent.topCustomers: ['pelanggan paling sering belanja', 'pelanggan terbaik'],
      Intent.businessStats: ['statistik bisnis', 'rata-rata transaksi', 'pertumbuhan penjualan'],
      Intent.salesTrend: ['tren penjualan', 'grafik penjualan'],
      Intent.generateReport: ['buat laporan', 'rekap penjualan', 'rekap stok', 'rekap pengeluaran'],
      Intent.downloadReport: ['download laporan', 'unduh sebagai'],
      Intent.printReport: ['cetak laporan', 'print laporan'],
      Intent.navigate: ['buka '], // entity extraction needed
      Intent.showMenu: ['menu', 'bantuan', 'bantuan chatbot', 'help', 'pilihan', 'fitur'],
    };

    Intent? bestMatch;
    int maxMatchCount = 0;
    String? matchedEntity;

    for (var entry in intentKeywords.entries) {
      for (var keyword in entry.value) {
        if (normalized.contains(keyword)) {
          // Calculate how many words match (simple heuristic for priority)
          final matchCount = keyword.split(' ').length;
          
          if (matchCount > maxMatchCount) {
            maxMatchCount = matchCount;
            bestMatch = entry.key;
            
            // Extract entity if needed
            if ([Intent.stockCheck, Intent.transactionSearch, Intent.customerInfo, Intent.navigate, Intent.generateReport, Intent.downloadReport].contains(entry.key)) {
               final index = normalized.indexOf(keyword);
               final afterKeyword = normalized.substring(index + keyword.length).trim();
               matchedEntity = afterKeyword.isNotEmpty ? afterKeyword : null;
            } else {
               matchedEntity = null;
            }
          }
        }
      }
    }

    if (bestMatch != null) {
      return MatchResult(bestMatch, matchedEntity);
    }

    return MatchResult(Intent.fallback, null);
  }
}
