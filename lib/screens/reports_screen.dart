import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../services/export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final _shortDateFormat = DateFormat('yyyy-MM-dd');

  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _topItemsData = [];
  List<Map<String, dynamic>> _profitData = [];
  List<Map<String, dynamic>> _inventoryData = [];
  List<Map<String, dynamic>> _stockValueData = [];
  List<Map<String, dynamic>> _shiftData = [];
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final startStr = '${_shortDateFormat.format(_startDate)} 00:00:00';
    final endStr = '${_shortDateFormat.format(_endDate)} 23:59:59';
    
    try {
      if (_tabController.index == 0) {
        _salesData = await DatabaseHelper.instance.getSalesReport(startStr, endStr);
      } else if (_tabController.index == 1) {
        _profitData = await DatabaseHelper.instance.getProfitReport(startStr, endStr);
      } else if (_tabController.index == 2) {
        _topItemsData = await DatabaseHelper.instance.getTopSellingItems(startStr, endStr);
      } else if (_tabController.index == 3) {
        _inventoryData = await DatabaseHelper.instance.getInventoryFlow(startStr, endStr);
      } else if (_tabController.index == 4) {
        _stockValueData = await DatabaseHelper.instance.getCurrentStockValue();
      } else if (_tabController.index == 5) {
        _shiftData = await DatabaseHelper.instance.getShiftReport(startStr, endStr);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading report: $e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  Future<void> _exportReport(String type) async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir == null) throw Exception("Downloads directory not found");

      String title = '';
      List<String> headers = [];
      List<List<dynamic>> rows = [];
      List<ReportSection> extraSections = const [];

      if (_tabController.index == 0) {
        title = 'Laporan_Penjualan';
        headers = ['Tanggal', 'No Invoice', 'Kasir', 'Metode', 'Status', 'Total'];
        rows = _salesData.map((d) => [
          d['created_at'].toString(), d['invoice_no'].toString(), d['cashier'] ?? '-', 
          d['payment_method'] ?? '-', d['status'].toString(), d['total_amount']
        ]).toList();
        final detailRows = <List<dynamic>>[];
        for (final d in _salesData) {
          final items = await DatabaseHelper.instance.getTransactionItems(d['transaction_id']);
          final tanggal = d['created_at'].toString().substring(0, 19);
          for (final item in items) {
            detailRows.add([
              d['invoice_no'].toString(), tanggal, item['product_name'] ?? '-',
              item['qty'], item['unit_price'], item['subtotal']
            ]);
          }
        }
        extraSections = [
          ReportSection(
            title: 'Detail Produk per Invoice',
            headers: ['No Invoice', 'Tanggal', 'Produk', 'Qty', 'Harga Satuan', 'Subtotal'],
            rows: detailRows,
          ),
        ];
      } else if (_tabController.index == 1) {
        title = 'Laporan_Keuntungan';
        headers = ['Produk', 'Qty Terjual', 'Total HPP', 'Total Penjualan', 'Profit Bersih'];
        rows = _profitData.map((d) => [
          d['product_name'] ?? '-', d['total_qty'], d['total_cost'], d['total_revenue'], d['total_profit']
        ]).toList();
      } else if (_tabController.index == 2) {
        title = 'Barang_Terlaris';
        headers = ['Produk', 'Qty Terjual', 'Total Revenue'];
        rows = _topItemsData.map((d) => [
          d['product_name'] ?? '-', d['total_qty'], d['total_revenue']
        ]).toList();
      } else if (_tabController.index == 3) {
        title = 'Arus_Stok';
        headers = ['Waktu', 'Produk', 'Tipe', 'Perubahan (Qty)', 'Alasan'];
        rows = _inventoryData.map((d) => [
          d['created_at'].toString(), d['product_name'] ?? '-', d['type'] ?? '-', 
          d['change_qty'], d['reason'] ?? '-'
        ]).toList();
      } else if (_tabController.index == 4) {
        title = 'Nilai_Stok';
        headers = ['Produk', 'Stok Saat Ini', 'Total Nilai (Beli)', 'Total Nilai (Jual)'];
        rows = _stockValueData.map((d) => [
          d['product_name'] ?? '-', d['current_stock'], d['total_cost_value'], d['total_sell_value']
        ]).toList();
      } else if (_tabController.index == 5) {
        title = 'Laporan_Shift';
        headers = ['Kasir', 'Waktu Buka', 'Waktu Tutup', 'Saldo Awal', 'Saldo Sistem', 'Saldo Fisik', 'Selisih', 'Status'];
        rows = _shiftData.map((d) => [
          d['cashier'] ?? '-', d['opened_at'].toString(), d['closed_at']?.toString() ?? '-',
          d['opening_balance'], d['closing_balance_system'], d['closing_balance_physical'],
          d['difference'], d['status']
        ]).toList();
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = '${title}_$timestamp.${type == 'excel' ? 'xlsx' : 'pdf'}';
      final path = '${dir.path}/$filename';

      if (type == 'excel') {
        await ExportService.exportToExcel(filePath: path, sheetName: title, headers: headers, rows: rows, extraSections: extraSections);
      } else {
        await ExportService.exportToPdf(filePath: path, title: title.replaceAll('_', ' '), headers: headers, rows: rows, extraSections: extraSections);
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil diekspor ke: $path'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Laporan Bisnis', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text('${_shortDateFormat.format(_startDate)} - ${_shortDateFormat.format(_endDate)}'),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    onSelected: _exportReport,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'excel', child: Text('Export Excel (.xlsx)')),
                      const PopupMenuItem(value: 'pdf', child: Text('Export PDF (.pdf)')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.file_download, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.primary,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Penjualan'),
                Tab(text: 'Keuntungan (Profit)'),
                Tab(text: 'Barang Terlaris'),
                Tab(text: 'Arus Stok'),
                Tab(text: 'Nilai Stok Saat Ini'),
                Tab(text: 'Laporan Kasir/Shift'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator()) 
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSalesTab(),
                        _buildProfitTab(),
                        _buildTopItemsTab(),
                        _buildInventoryTab(),
                        _buildStockValueTab(),
                        _buildShiftTab(),
                      ],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    double totalRevenue = 0;
    for (var r in _salesData) {
      if (r['status'] != 'void') {
        totalRevenue += (r['total_amount'] as num).toDouble();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Total Revenue: ${_currencyFormat.format(totalRevenue)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background.withOpacity(0.5)),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              horizontalMargin: 24,
              columnSpacing: 40,
              dividerThickness: 1,
              headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textLight, fontSize: 14),
              dataTextStyle: GoogleFonts.outfit(color: AppColors.textDark, fontSize: 14),
              columns: const [
                DataColumn(label: Text('')),
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('No Invoice')),
                DataColumn(label: Text('Kasir')),
                DataColumn(label: Text('Metode')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Total', textAlign: TextAlign.right)),
              ],
              rows: _salesData.map((d) {
                final isVoid = d['status'] == 'void';
                return DataRow(cells: [
                  DataCell(_buildViewItemsButton(d)),
                  DataCell(Text(d['created_at'].toString().substring(0, 19))),
                  DataCell(Text(d['invoice_no'].toString(), style: TextStyle(decoration: isVoid ? TextDecoration.lineThrough : null))),
                  DataCell(Text(d['cashier'] ?? 'Unknown')),
                  DataCell(Text(d['payment_method'] ?? '-')),
                  DataCell(Text(d['status'].toString().toUpperCase(), style: TextStyle(color: isVoid ? AppColors.danger : AppColors.success))),
                  DataCell(Text(_currencyFormat.format(d['total_amount']), style: TextStyle(decoration: isVoid ? TextDecoration.lineThrough : null))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Eye/visibility button placed beside the invoice. Opens the per-transaction
  /// product detail dialog.
  Widget _buildViewItemsButton(Map<String, dynamic> t) {
    return Tooltip(
      message: 'View items',
      child: Material(
        color: AppColors.primary.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.primary.withOpacity(0.15),
          onTap: () => _showTransactionItems(t),
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Icon(
              Icons.visibility_outlined,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a dialog listing the products sold in a given transaction.
  void _showTransactionItems(Map<String, dynamic> t) {
    final formattedDate = _dateFormat.format(DateTime.parse(t['created_at']));

    Future<List<Map<String, dynamic>>>? itemsFuture;

    showDialog(
      context: context,
      builder: (ctx) {
        itemsFuture ??= DatabaseHelper.instance.getTransactionItems(t['transaction_id']);
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 560,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogHeader(t, formattedDate, ctx),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: itemsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return _buildItemsLoadingState();
                        }
                        if (snapshot.hasError) {
                          return _buildItemsErrorState(
                            onRetry: () => setDialogState(() {
                              itemsFuture = DatabaseHelper.instance
                                  .getTransactionItems(t['transaction_id']);
                            }),
                          );
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) return _buildItemsEmptyState();
                        return _buildItemsTable(items, _currencyFormat, t);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogHeader(
    Map<String, dynamic> t,
    String formattedDate,
    BuildContext ctx,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transaction Details',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${t['invoice_no'] ?? '-'}  •  $formattedDate',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.close, color: AppColors.textLight),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildItemsLoadingState() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading items...',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsErrorState({required VoidCallback onRetry}) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
            const SizedBox(height: 12),
            Text(
              'Could not load transaction items.',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please try again.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsEmptyState() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.textLight,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'No items found for this transaction.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable(
    List<Map<String, dynamic>> items,
    NumberFormat currencyFormat,
    Map<String, dynamic> t,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _ColumnHeader('Product')),
            const SizedBox(
              width: 100,
              child: _ColumnHeader('Unit Price', align: TextAlign.right),
            ),
            const SizedBox(
              width: 40,
              child: _ColumnHeader('Qty', align: TextAlign.right),
            ),
            const SizedBox(
              width: 120,
              child: _ColumnHeader('Subtotal', align: TextAlign.right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['product_name'] ?? '-'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        currencyFormat.format(item['unit_price']),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${item['qty']}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        currencyFormat.format(item['subtotal']),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grand Total',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t['payment_method'] ?? 'Cash',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
            Text(
              currencyFormat.format(t['total_amount']),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfitTab() {
    double totalProfit = 0;
    for (var r in _profitData) {
      totalProfit += (r['total_profit'] as num).toDouble();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Total Profit: ${_currencyFormat.format(totalProfit)}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success)),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background.withOpacity(0.5)),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              horizontalMargin: 24,
              columnSpacing: 40,
              dividerThickness: 1,
              headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textLight, fontSize: 14),
              dataTextStyle: GoogleFonts.outfit(color: AppColors.textDark, fontSize: 14),
              columns: const [
                DataColumn(label: Text('Produk')),
                DataColumn(label: Text('Qty Terjual')),
                DataColumn(label: Text('Total HPP (Cost)')),
                DataColumn(label: Text('Total Penjualan')),
                DataColumn(label: Text('Profit Bersih')),
              ],
              rows: _profitData.map((d) {
                return DataRow(cells: [
                  DataCell(Text(d['product_name'] ?? '-')),
                  DataCell(Text(d['total_qty'].toString())),
                  DataCell(Text(_currencyFormat.format(d['total_cost'] ?? 0))),
                  DataCell(Text(_currencyFormat.format(d['total_revenue'] ?? 0))),
                  DataCell(Text(_currencyFormat.format(d['total_profit'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopItemsTab() {
    return SingleChildScrollView(
      child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background.withOpacity(0.5)),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              horizontalMargin: 24,
              columnSpacing: 40,
              dividerThickness: 1,
              headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textLight, fontSize: 14),
              dataTextStyle: GoogleFonts.outfit(color: AppColors.textDark, fontSize: 14),
        columns: const [
          DataColumn(label: Text('Rank')),
          DataColumn(label: Text('Produk')),
          DataColumn(label: Text('Qty Terjual')),
          DataColumn(label: Text('Total Revenue')),
        ],
        rows: _topItemsData.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          return DataRow(cells: [
            DataCell(Text('${i + 1}')),
            DataCell(Text(d['product_name'] ?? '-')),
            DataCell(Text(d['total_qty'].toString())),
            DataCell(Text(_currencyFormat.format(d['total_revenue'] ?? 0))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildInventoryTab() {
    return SingleChildScrollView(
      child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background.withOpacity(0.5)),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              horizontalMargin: 24,
              columnSpacing: 40,
              dividerThickness: 1,
              headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textLight, fontSize: 14),
              dataTextStyle: GoogleFonts.outfit(color: AppColors.textDark, fontSize: 14),
        columns: const [
          DataColumn(label: Text('Waktu')),
          DataColumn(label: Text('Produk')),
          DataColumn(label: Text('Tipe')),
          DataColumn(label: Text('Perubahan (Qty)')),
          DataColumn(label: Text('Alasan')),
        ],
        rows: _inventoryData.map((d) {
          final isOut = d['type'] == 'OUT' || d['type'] == 'SALE' || d['type'] == 'OPNAME_MINUS';
          return DataRow(cells: [
            DataCell(Text(d['created_at'].toString().substring(0, 19))),
            DataCell(Text(d['product_name'] ?? '-')),
            DataCell(Text(d['type'] ?? '-')),
            DataCell(Text(
              '${isOut ? '-' : '+'}${d['change_qty'].abs()}', 
              style: TextStyle(color: isOut ? AppColors.danger : AppColors.success, fontWeight: FontWeight.bold)
            )),
            DataCell(Text(d['reason'] ?? '-')),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildStockValueTab() {
    double totalCostValue = 0;
    double totalSellValue = 0;
    for (var r in _stockValueData) {
      totalCostValue += (r['total_cost_value'] as num).toDouble();
      totalSellValue += (r['total_sell_value'] as num).toDouble();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Nilai Aset (Harga Beli/Modal)', style: TextStyle(color: Colors.blue)),
                      const SizedBox(height: 8),
                      Text(_currencyFormat.format(totalCostValue), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Potensi Pendapatan (Harga Jual)', style: TextStyle(color: Colors.green)),
                      const SizedBox(height: 8),
                      Text(_currencyFormat.format(totalSellValue), style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background.withOpacity(0.5)),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              horizontalMargin: 24,
              columnSpacing: 40,
              dividerThickness: 1,
              headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textLight, fontSize: 14),
              dataTextStyle: GoogleFonts.outfit(color: AppColors.textDark, fontSize: 14),
              columns: const [
                DataColumn(label: Text('Produk')),
                DataColumn(label: Text('Stok Saat Ini')),
                DataColumn(label: Text('Total Nilai (Beli)')),
                DataColumn(label: Text('Total Nilai (Jual)')),
              ],
              rows: _stockValueData.map((d) {
                return DataRow(cells: [
                  DataCell(Text(d['product_name'] ?? '-')),
                  DataCell(Text(d['current_stock'].toString())),
                  DataCell(Text(_currencyFormat.format(d['total_cost_value'] ?? 0))),
                  DataCell(Text(_currencyFormat.format(d['total_sell_value'] ?? 0))),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftTab() {
    return SingleChildScrollView(
      child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background.withOpacity(0.5)),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              horizontalMargin: 24,
              columnSpacing: 40,
              dividerThickness: 1,
              headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.textLight, fontSize: 14),
              dataTextStyle: GoogleFonts.outfit(color: AppColors.textDark, fontSize: 14),
        columns: const [
          DataColumn(label: Text('Kasir')),
          DataColumn(label: Text('Waktu Buka')),
          DataColumn(label: Text('Waktu Tutup')),
          DataColumn(label: Text('Saldo Awal')),
          DataColumn(label: Text('Saldo Sistem')),
          DataColumn(label: Text('Saldo Fisik')),
          DataColumn(label: Text('Selisih')),
          DataColumn(label: Text('Status')),
        ],
        rows: _shiftData.map((d) {
          final isClosed = d['status'] == 'CLOSED';
          final diff = (d['difference'] as num?)?.toDouble() ?? 0.0;
          final opening = (d['opening_balance'] as num?)?.toDouble() ?? 0.0;
          final closingSys = (d['closing_balance_system'] as num?)?.toDouble() ?? 0.0;
          final closingPhys = (d['closing_balance_physical'] as num?)?.toDouble() ?? 0.0;
          return DataRow(cells: [
            DataCell(Text(d['cashier'] ?? 'Unknown')),
            DataCell(Text(d['opened_at'] != null ? d['opened_at'].toString().substring(0, 19).replaceAll('T', ' ') : '-')),
            DataCell(Text(d['closed_at'] != null ? d['closed_at'].toString().substring(0, 19).replaceAll('T', ' ') : '-')),
            DataCell(Text(_currencyFormat.format(opening))),
            DataCell(Text(_currencyFormat.format(closingSys))),
            DataCell(Text(_currencyFormat.format(closingPhys))),
            DataCell(Text(_currencyFormat.format(diff), style: TextStyle(color: diff < 0 ? AppColors.danger : (diff > 0 ? AppColors.success : Colors.black), fontWeight: FontWeight.bold))),
            DataCell(Text(d['status'] ?? 'OPEN', style: TextStyle(color: isClosed ? AppColors.primary : AppColors.success, fontWeight: FontWeight.bold))),
          ]);
        }).toList(),
      ),
    );
  }
}

/// Small uppercase column label used in the transaction items table.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader(this.label, {this.align = TextAlign.left});

  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
        letterSpacing: 0.5,
      ),
    );
  }
}
