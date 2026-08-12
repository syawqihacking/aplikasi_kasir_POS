import 'package:flutter/material.dart' hide Intent;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../database/database_helper.dart';
import '../../../services/export_service.dart';
import '../models/assistant_response.dart';
import 'intent.dart';
import 'intent_matcher.dart';
import '../data/assistant_repository.dart';

class CommandHandler {
  final AssistantRepository repository;

  CommandHandler(this.repository);

  Future<AssistantResponse> execute(MatchResult matchResult, DateTimeRange dateRange) async {
    final intent = matchResult.intent;
    final entity = matchResult.entity;

    final startIso = dateRange.start.toIso8601String();
    final endIso = dateRange.end.toIso8601String();
    
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    
    switch (intent) {
      case Intent.salesToday:
      case Intent.salesByPeriod:
        final summary = await repository.getSalesSummary(startIso, endIso);
        final totalSales = (summary['total_sales'] as num?)?.toDouble() ?? 0.0;
        final totalTax = (summary['total_tax'] as num?)?.toDouble() ?? 0.0;
        final count = summary['total_transactions'] ?? 0;
        
        return AssistantResponse(
          summaryText: '📊 Penjualan (${DateFormat('dd MMM yyyy').format(dateRange.start)})\n\n'
                       'Total Transaksi: $count\n'
                       'Total Penjualan: ${currencyFormat.format(totalSales)}\n'
                       'Pajak: ${currencyFormat.format(totalTax)}\n'
                       'Pendapatan Bersih: ${currencyFormat.format(totalSales)}',
          type: ResponseType.text,
        );

      case Intent.profitToday:
        final profit = await repository.getProfit(startIso, endIso);
        return AssistantResponse(
          summaryText: '💰 Laba (${DateFormat('dd MMM yyyy').format(dateRange.start)})\n\n'
                       'Total Keuntungan: ${currencyFormat.format(profit)}',
          type: ResponseType.text,
        );

      case Intent.expenseToday:
      case Intent.expenseByPeriod:
        final expense = await repository.getExpense(startIso, endIso);
        return AssistantResponse(
          summaryText: '💸 Pengeluaran (${DateFormat('dd MMM yyyy').format(dateRange.start)})\n\n'
                       'Total Pengeluaran: ${currencyFormat.format(expense)}',
          type: ResponseType.text,
        );

      case Intent.stockCheck:
        if (entity == null || entity.isEmpty) {
          return AssistantResponse(
            summaryText: 'Sebutkan nama produk yang ingin dicek stoknya. Contoh: "stok indomie"',
            type: ResponseType.text,
          );
        }
        final products = await repository.searchProductsByStock(entity);
        if (products.isEmpty) {
          return AssistantResponse(
            summaryText: 'Produk "$entity" tidak ditemukan. Periksa kembali nama produk atau cek di menu Products.',
            type: ResponseType.text,
          );
        }
        return AssistantResponse(
          summaryText: '📦 Hasil pencarian stok untuk "$entity":',
          type: ResponseType.table,
          payload: {'data': products.map((e) => {'Produk': e['name'], 'Stok': '${e['current_stock']} ${e['unit']}'}).toList()},
        );

      case Intent.lowStockProducts:
        final products = await repository.getLowStockProducts(5); // default threshold
        if (products.isEmpty) {
          return AssistantResponse(
            summaryText: 'Saat ini tidak ada produk dengan stok menipis.',
            type: ResponseType.text,
          );
        }
        return AssistantResponse(
          summaryText: '⚠️ Produk dengan stok menipis:',
          type: ResponseType.table,
          payload: {'data': products.map((e) => {'Produk': e['name'], 'Stok': '${e['current_stock']} ${e['unit']}'}).toList()},
        );

      case Intent.bestSellingProducts:
        final products = await repository.getBestSellingProducts(startIso, endIso);
        if (products.isEmpty) {
          return AssistantResponse(
            summaryText: 'Belum ada data penjualan produk pada periode ini.',
            type: ResponseType.text,
          );
        }
        return AssistantResponse(
          summaryText: '🏆 Produk terlaris:',
          type: ResponseType.table,
          payload: {'data': products.map((e) => {'Produk': e['name'], 'Terjual': e['total_qty'], 'Sisa Stok': e['current_stock']}).toList()},
        );

      case Intent.slowMovingProducts:
        final products = await repository.getSlowMovingProducts(startIso, endIso);
        if (products.isEmpty) {
          return AssistantResponse(
            summaryText: 'Semua produk laku pada periode ini.',
            type: ResponseType.text,
          );
        }
        return AssistantResponse(
          summaryText: '🐌 Produk tidak laku (tidak ada transaksi di periode ini):',
          type: ResponseType.table,
          payload: {'data': products.map((e) => {'Produk': e['name'], 'Stok': e['current_stock']}).toList()},
        );

      case Intent.transactionSearch:
      case Intent.customerInfo:
        if (entity == null || entity.isEmpty) {
          return AssistantResponse(
            summaryText: 'Sebutkan kata kunci pencarian. Contoh: "transaksi INV-123" atau "data pelanggan Budi"',
            type: ResponseType.text,
          );
        }
        final txs = await repository.searchTransactions(entity);
        if (txs.isEmpty) {
          return AssistantResponse(
            summaryText: 'Tidak ditemukan transaksi atau pelanggan dengan kata kunci "$entity".',
            type: ResponseType.text,
          );
        }
        return AssistantResponse(
          summaryText: '🔍 Hasil pencarian transaksi untuk "$entity":',
          type: ResponseType.table,
          payload: {
            'data': txs.map((e) => {
              'Invoice': e['invoice_no'], 
              'Pelanggan': e['customer_name'] ?? '-', 
              'Total': currencyFormat.format((e['grand_total'] as num?)?.toDouble() ?? 0)
            }).toList()
          },
        );

      case Intent.topCustomers:
        final customers = await repository.getTopCustomers(startIso, endIso);
        if (customers.isEmpty) {
          return AssistantResponse(
            summaryText: 'Belum ada data pelanggan pada periode ini.',
            type: ResponseType.text,
          );
        }
        return AssistantResponse(
          summaryText: '🌟 Pelanggan terbaik:',
          type: ResponseType.table,
          payload: {'data': customers.map((e) => {'Nama': e['name'], 'Trx': e['total_transactions'], 'Total Belanja': currencyFormat.format((e['total_spent'] as num).toDouble())}).toList()},
        );

      case Intent.businessStats:
      case Intent.salesTrend:
        return AssistantResponse(
          summaryText: 'Fitur chart/statistik lanjutan bisa dilihat di Dashboard.',
          type: ResponseType.text,
        );

      case Intent.generateReport:
      case Intent.downloadReport:
      case Intent.printReport:
        if (entity == null || entity.isEmpty) {
          return AssistantResponse(
            summaryText: 'Silakan pilih laporan yang ingin Anda unduh:',
            type: ResponseType.actionButtons,
            payload: {
              'actions': [
                {'label': '📊 Laporan Penjualan (PDF)', 'message': 'download laporan penjualan pdf'},
                {'label': '📊 Laporan Penjualan (Excel)', 'message': 'download laporan penjualan excel'},
                {'label': '💰 Laporan Keuntungan (PDF)', 'message': 'download laporan keuntungan pdf'},
                {'label': '💰 Laporan Keuntungan (Excel)', 'message': 'download laporan keuntungan excel'},
                {'label': '📦 Laporan Stok (PDF)', 'message': 'download laporan stok pdf'},
                {'label': '📦 Laporan Stok (Excel)', 'message': 'download laporan stok excel'},
              ]
            }
          );
        }

        final target = entity.toLowerCase();
        final startStr = '${DateFormat('yyyy-MM-dd').format(dateRange.start)} 00:00:00';
        final endStr = '${DateFormat('yyyy-MM-dd').format(dateRange.end)} 23:59:59';
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

        String title = '';
        List<String> headers = [];
        List<List<dynamic>> rows = [];
        bool isExcel = target.contains('excel') || target.contains('xlsx');
        String ext = isExcel ? 'xlsx' : 'pdf';

        if (target.contains('penjualan')) {
          title = 'Laporan_Penjualan';
          headers = ['Tanggal', 'No Invoice', 'Kasir', 'Metode', 'Status', 'Total'];
          final data = await DatabaseHelper.instance.getSalesReport(startStr, endStr);
          rows = data.map((d) => [
            d['created_at'].toString(), d['invoice_no'].toString(), d['cashier'] ?? '-', 
            d['payment_method'] ?? '-', d['status'].toString(), d['total_amount']
          ]).toList();
        } else if (target.contains('keuntungan') || target.contains('laba') || target.contains('profit')) {
          title = 'Laporan_Keuntungan';
          headers = ['Produk', 'Qty Terjual', 'Total HPP', 'Total Penjualan', 'Profit Bersih'];
          final data = await DatabaseHelper.instance.getProfitReport(startStr, endStr);
          rows = data.map((d) => [
            d['product_name'] ?? '-', d['total_qty'], d['total_cost'], d['total_revenue'], d['total_profit']
          ]).toList();
        } else if (target.contains('stok') || target.contains('inventory') || target.contains('barang')) {
          title = 'Laporan_Stok_Nilai';
          headers = ['Produk', 'Stok Saat Ini', 'Total Nilai (Beli)', 'Total Nilai (Jual)'];
          final data = await DatabaseHelper.instance.getCurrentStockValue();
          rows = data.map((d) => [
            d['product_name'] ?? '-', d['current_stock'], d['total_cost_value'], d['total_sell_value']
          ]).toList();
        } else {
          title = 'Laporan_Penjualan';
          headers = ['Tanggal', 'No Invoice', 'Kasir', 'Metode', 'Status', 'Total'];
          final data = await DatabaseHelper.instance.getSalesReport(startStr, endStr);
          rows = data.map((d) => [
            d['created_at'].toString(), d['invoice_no'].toString(), d['cashier'] ?? '-', 
            d['payment_method'] ?? '-', d['status'].toString(), d['total_amount']
          ]).toList();
        }

        final filename = '${title}_$timestamp.$ext';
        final path = '${tempDir.path}/$filename';

        if (isExcel) {
          await ExportService.exportToExcel(filePath: path, sheetName: title, headers: headers, rows: rows);
        } else {
          await ExportService.exportToPdf(filePath: path, title: title.replaceAll('_', ' '), headers: headers, rows: rows);
        }

        return AssistantResponse(
          summaryText: '📄 Laporan Anda telah berhasil dibuat. Klik tombol di bawah ini untuk mengunduh dan menyimpannya:',
          type: ResponseType.fileDownload,
          payload: {
            'fileName': filename,
            'fileUrl': path,
          }
        );

      case Intent.navigate:
        String route = '/';
        String routeName = 'Dashboard';
        
        if (entity != null) {
          final target = entity.toLowerCase();
          if (target.contains('dashboard')) { route = '/dashboard'; routeName = 'Dashboard'; }
          else if (target.contains('pos') || target.contains('kasir') || target.contains('penjualan')) { route = '/pos'; routeName = 'POS / Kasir'; }
          else if (target.contains('produk')) { route = '/products'; routeName = 'Produk'; }
          else if (target.contains('pengaturan')) { route = '/settings'; routeName = 'Pengaturan'; }
          else if (target.contains('laporan')) { route = '/reports'; routeName = 'Laporan'; }
          else if (target.contains('stok') || target.contains('inventory')) { route = '/inventory'; routeName = 'Stok'; }
        }
        
        return AssistantResponse(
          summaryText: 'Siap! Silakan klik tombol di bawah untuk membuka $routeName.',
          type: ResponseType.actionButtons,
          payload: {
            'actions': [
              {'label': 'Buka $routeName', 'route': route}
            ]
          }
        );

      case Intent.showMenu:
        return AssistantResponse(
          summaryText: 'Silakan pilih menu atau fitur yang ingin Anda akses langsung dari daftar di bawah ini:',
          type: ResponseType.actionButtons,
          payload: {
            'actions': [
              {'label': '📊 Penjualan Hari Ini', 'message': 'penjualan hari ini'},
              {'label': '💰 Laba Hari Ini', 'message': 'laba hari ini'},
              {'label': '⚠️ Cek Stok Menipis', 'message': 'stok menipis'},
              {'label': '🏆 Produk Terlaris', 'message': 'produk terlaris'},
              {'label': '💸 Pengeluaran Hari Ini', 'message': 'pengeluaran hari ini'},
              {'label': '📥 Unduh Laporan', 'message': 'download laporan'},
              {'label': '🛒 Buka Kasir (POS)', 'route': '/pos'},
              {'label': '📈 Buka Laporan Bisnis', 'route': '/reports'},
            ]
          }
        );

      case Intent.fallback:
        return AssistantResponse(
          summaryText: 'Maaf, saya tidak mengerti maksud Anda. Silakan pilih salah satu menu di bawah ini atau ketik "menu" untuk melihat opsi lengkap:',
          type: ResponseType.actionButtons,
          payload: {
            'actions': [
              {'label': '📊 Penjualan Hari Ini', 'message': 'penjualan hari ini'},
              {'label': '💰 Laba Hari Ini', 'message': 'laba hari ini'},
              {'label': '⚠️ Cek Stok Menipis', 'message': 'stok menipis'},
              {'label': '📥 Unduh Laporan', 'message': 'download laporan'},
            ]
          }
        );
    }
  }
}
