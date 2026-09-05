import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../services/shift_service.dart';
import '../../../models/shift.dart';
import 'shift_receipt_dialog.dart';

class ShiftDetailDialog extends StatefulWidget {
  final int shiftId;

  const ShiftDetailDialog({
    super.key,
    required this.shiftId,
  });

  static Future<void> show(BuildContext context, {required int shiftId}) {
    return showDialog(
      context: context,
      builder: (context) => ShiftDetailDialog(shiftId: shiftId),
    );
  }

  @override
  State<ShiftDetailDialog> createState() => _ShiftDetailDialogState();
}

class _ShiftDetailDialogState extends State<ShiftDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CashShift? _shift;
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadShiftDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShiftDetails() async {
    setState(() => _isLoading = true);
    try {
      final details = await ShiftService.instance.getShiftDetails(widget.shiftId);
      if (details != null && mounted) {
        setState(() {
          _shift = CashShift.fromMap(details);
          _movements = (details['movements'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _transactions = (details['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat detail shift: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(String startStr, String? endStr) {
    try {
      final start = DateTime.parse(startStr);
      final end = endStr != null ? DateTime.parse(endStr) : DateTime.now();
      final diff = end.difference(start);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      if (hours > 0) {
        return '$hours jam $minutes menit';
      } else {
        return '$minutes menit';
      }
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 780,
        height: 680,
        padding: const EdgeInsets.all(28),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _shift == null
                ? Center(
                    child: Text(
                      'Shift #${widget.shiftId} tidak ditemukan.',
                      style: GoogleFonts.outfit(color: AppColors.textLight),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.schedule, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Detail Shift ${_shift!.shiftNumber}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _shift!.isOpen
                                            ? AppColors.success.withValues(alpha: 0.12)
                                            : AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _shift!.isOpen ? 'AKTIF / BERJALAN' : 'SELESAI (CLOSED)',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _shift!.isOpen ? AppColors.success : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kasir: ${_shift!.cashierName ?? 'Kasir'} • Durasi: ${_formatDuration(_shift!.openedAt, _shift!.closedAt)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              ShiftReceiptDialog.show(
                                context,
                                shift: _shift!,
                                movements: _movements,
                                transactions: _transactions,
                              );
                            },
                            icon: const Icon(Icons.print_outlined, size: 18, color: Colors.white),
                            label: Text('Cetak Slip', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              if (ModalRoute.of(context)?.isCurrent == true) {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.close, color: AppColors.textLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Metric Summary Row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            _buildTopMetric('Modal Awal', _currencyFormat.format(_shift!.openingBalance)),
                            _buildDivider(),
                            _buildTopMetric('Penjualan Kas', _currencyFormat.format(_shift!.totalCashSales), color: AppColors.success),
                            _buildDivider(),
                            _buildTopMetric('Cash In / Out', '+${_currencyFormat.format(_shift!.totalCashIn)} / -${_currencyFormat.format(_shift!.totalCashOut)}'),
                            _buildDivider(),
                            _buildTopMetric(
                              _shift!.isClosed ? 'Kas Fisik (Aktual)' : 'Kas Seharusnya',
                              _currencyFormat.format(_shift!.isClosed ? _shift!.closingBalancePhysical : _shift!.expectedCash),
                              color: AppColors.primary,
                              isHighlight: true,
                            ),
                            if (_shift!.isClosed) ...[
                              _buildDivider(),
                              _buildTopMetric(
                                'Selisih',
                                '${_shift!.difference >= 0 ? '+' : ''}${_currencyFormat.format(_shift!.difference)}',
                                color: _shift!.difference == 0
                                    ? AppColors.success
                                    : (_shift!.difference > 0 ? Colors.blue.shade700 : AppColors.danger),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tabs
                      TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textLight,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(text: 'Ringkasan Finansial'),
                          Tab(text: 'Mutasi Kas (${_movements.length})'),
                          Tab(text: 'Transaksi Penjualan (${_transactions.length})'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tab View
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildFinancialSummaryTab(),
                            _buildMovementsTab(),
                            _buildTransactionsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTopMetric(String label, String value, {Color? color, bool isHighlight = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 32,
      width: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildFinancialSummaryTab() {
    final openedAt = DateTime.tryParse(_shift!.openedAt);
    final closedAt = _shift!.closedAt != null ? DateTime.tryParse(_shift!.closedAt!) : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildInfoRow('Waktu Mulai', openedAt != null ? _dateFormat.format(openedAt) : _shift!.openedAt),
                const Divider(height: 16),
                _buildInfoRow('Waktu Selesai', closedAt != null ? _dateFormat.format(closedAt) : 'Shift Masih Aktif'),
                const Divider(height: 16),
                _buildInfoRow('Modal / Kas Awal', _currencyFormat.format(_shift!.openingBalance)),
                const Divider(height: 16),
                _buildInfoRow('Penjualan Tunai (Cash)', _currencyFormat.format(_shift!.totalCashSales)),
                const Divider(height: 16),
                _buildInfoRow('Penjualan Non-Tunai (QRIS / Transfer)', _currencyFormat.format(_shift!.totalNonCashSales)),
                const Divider(height: 16),
                _buildInfoRow('Total Transaksi Penjualan', '${_currencyFormat.format(_shift!.totalSales)} (${_shift!.transactionCount} Transaksi)'),
                const Divider(height: 16),
                _buildInfoRow('Total Cash In (Pemasukan)', '+${_currencyFormat.format(_shift!.totalCashIn)}', valueColor: AppColors.success),
                const Divider(height: 16),
                _buildInfoRow('Total Cash Out (Pengeluaran)', '-${_currencyFormat.format(_shift!.totalCashOut)}', valueColor: AppColors.danger),
                const Divider(height: 20, thickness: 1.5),
                _buildInfoRow(
                  'Kas Sistem (Seharusnya)',
                  _currencyFormat.format(_shift!.closingBalanceSystem > 0 ? _shift!.closingBalanceSystem : _shift!.expectedCash),
                  isBold: true,
                  valueColor: AppColors.primary,
                ),
                if (_shift!.isClosed) ...[
                  const Divider(height: 16),
                  _buildInfoRow('Kas Aktual (Fisik di Laci)', _currencyFormat.format(_shift!.closingBalancePhysical), isBold: true),
                  const Divider(height: 16),
                  _buildInfoRow(
                    'Selisih Kas',
                    '${_shift!.difference >= 0 ? '+' : ''}${_currencyFormat.format(_shift!.difference)} (${_shift!.difference == 0 ? 'PAS' : (_shift!.difference > 0 ? 'SURPLUS' : 'DEFISIT')})',
                    isBold: true,
                    valueColor: _shift!.difference == 0
                        ? AppColors.success
                        : (_shift!.difference > 0 ? Colors.blue.shade700 : AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
          if (_shift!.closingNote != null && _shift!.closingNote!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.comment_outlined, size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Text(
                        'Catatan Penutupan Kasir:',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _shift!.closingNote!,
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMovementsTab() {
    if (_movements.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada mutasi kas (Cash In / Out) selama shift ini.',
          style: GoogleFonts.outfit(color: AppColors.textLight),
        ),
      );
    }

    return ListView.separated(
      itemCount: _movements.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final m = _movements[index];
        final isIN = m['type'] == 'IN';
        final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
        final created = DateTime.tryParse(m['created_at']?.toString() ?? '');

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isIN ? AppColors.success.withValues(alpha: 0.12) : const Color(0xFFE53935).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIN ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isIN ? AppColors.success : const Color(0xFFE53935),
              size: 20,
            ),
          ),
          title: Text(
            m['reason'] ?? (isIN ? 'Cash In' : 'Cash Out'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${created != null ? _dateFormat.format(created) : '-'} • Oleh: ${m['created_by_name'] ?? 'User'}',
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
          ),
          trailing: Text(
            '${isIN ? '+' : '-'}${_currencyFormat.format(amt)}',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isIN ? AppColors.success : const Color(0xFFE53935),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          'Belum ada transaksi penjualan selama shift ini.',
          style: GoogleFonts.outfit(color: AppColors.textLight),
        ),
      );
    }

    return ListView.separated(
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final grandTotal = (tx['grand_total'] as num?)?.toDouble() ?? 0.0;
        final created = DateTime.tryParse(tx['created_at']?.toString() ?? '');

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_outlined, color: AppColors.primary, size: 20),
          ),
          title: Text(
            tx['invoice_no'] ?? 'Invoice',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${created != null ? _dateFormat.format(created) : '-'} • Metode: ${tx['payment_method'] ?? 'Cash'}',
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
          ),
          trailing: Text(
            _currencyFormat.format(grandTotal),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: isBold ? AppColors.textDark : AppColors.textLight,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
