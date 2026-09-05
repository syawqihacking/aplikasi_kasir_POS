import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../services/shift_service.dart';
import '../../../models/shift.dart';
import '../dialogs/cash_movement_dialog.dart';
import '../dialogs/close_shift_dialog.dart';

class ActiveShiftView extends StatefulWidget {
  final CashShift shift;
  final VoidCallback onRefresh;

  const ActiveShiftView({
    super.key,
    required this.shift,
    required this.onRefresh,
  });

  @override
  State<ActiveShiftView> createState() => _ActiveShiftViewState();
}

class _ActiveShiftViewState extends State<ActiveShiftView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;

  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingActivity = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _calculateDuration();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateDuration());
    _loadActivity();
  }

  @override
  void didUpdateWidget(covariant ActiveShiftView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shift.id != widget.shift.id) {
      _loadActivity();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _calculateDuration() {
    try {
      final opened = DateTime.parse(widget.shift.openedAt);
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(opened);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadActivity() async {
    setState(() => _isLoadingActivity = true);
    try {
      final details = await ShiftService.instance.getShiftDetails(widget.shift.id ?? 1);
      if (details != null && mounted) {
        setState(() {
          _movements = (details['movements'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _transactions = (details['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingActivity = false);
    }
  }

  String _formatElapsed(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final openedAt = DateTime.tryParse(widget.shift.openedAt);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C2FE2), Color(0xFF4A1BB8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C2FE2).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.timer_outlined, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.circle, color: Colors.white, size: 8),
                                const SizedBox(width: 6),
                                Text(
                                  'SHIFT AKTIF',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.shift.shiftNumber,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kasir: ${widget.shift.cashierName ?? 'Kasir'}',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Waktu Mulai: ${openedAt != null ? _dateFormat.format(openedAt) : widget.shift.openedAt}',
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                // Elapsed Timer Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'DURASI BERJALAN',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatElapsed(_elapsed),
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons Bar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await CashMovementDialog.show(
                      context,
                      shift: widget.shift,
                      initialType: 'IN',
                    );
                    if (res == true) {
                      widget.onRefresh();
                      _loadActivity();
                    }
                  },
                  icon: const Icon(Icons.south_west_rounded, color: Colors.white, size: 20),
                  label: Text('Cash In (Masuk)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await CashMovementDialog.show(
                      context,
                      shift: widget.shift,
                      initialType: 'OUT',
                    );
                    if (res == true) {
                      widget.onRefresh();
                      _loadActivity();
                    }
                  },
                  icon: const Icon(Icons.north_east_rounded, color: Colors.white, size: 20),
                  label: Text('Cash Out (Keluar)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final res = await CloseShiftDialog.show(context, shift: widget.shift);
                    if (res == true) {
                      widget.onRefresh();
                    }
                  },
                  icon: const Icon(Icons.lock_clock_outlined, color: Colors.white, size: 20),
                  label: Text('Tutup Shift', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: () {
                  widget.onRefresh();
                  _loadActivity();
                },
                tooltip: 'Segarkan Data',
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Financial KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return GridView.count(
                crossAxisCount: isWide ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: isWide ? 2.2 : 1.7,
                children: [
                  _buildMetricCard(
                    title: 'Modal Awal Kasir',
                    value: _currencyFormat.format(widget.shift.openingBalance),
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF3B82F6),
                    subtitle: 'Saldo kas saat mulai shift',
                  ),
                  _buildMetricCard(
                    title: 'Penjualan Kas (Tunai)',
                    value: _currencyFormat.format(widget.shift.totalCashSales),
                    icon: Icons.point_of_sale_outlined,
                    color: AppColors.success,
                    subtitle: '${widget.shift.transactionCount} Transaksi total',
                  ),
                  _buildMetricCard(
                    title: 'Penjualan Non-Tunai',
                    value: _currencyFormat.format(widget.shift.totalNonCashSales),
                    icon: Icons.qr_code_2_rounded,
                    color: const Color(0xFF8B5CF6),
                    subtitle: 'QRIS / Transfer / EDC',
                  ),
                  _buildMetricCard(
                    title: 'Total Cash In (+)',
                    value: _currencyFormat.format(widget.shift.totalCashIn),
                    icon: Icons.south_west_rounded,
                    color: AppColors.success,
                    subtitle: '${_movements.where((m) => m['type'] == 'IN').length} Kali pemasukan',
                  ),
                  _buildMetricCard(
                    title: 'Total Cash Out (-)',
                    value: _currencyFormat.format(widget.shift.totalCashOut),
                    icon: Icons.north_east_rounded,
                    color: const Color(0xFFE53935),
                    subtitle: '${_movements.where((m) => m['type'] == 'OUT').length} Kali pengeluaran',
                  ),
                  _buildMetricCard(
                    title: 'Kas Seharusnya di Laci',
                    value: _currencyFormat.format(widget.shift.expectedCash),
                    icon: Icons.payments_rounded,
                    color: AppColors.primary,
                    subtitle: 'Modal + Penjualan Tunai + In - Out',
                    isHighlight: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Activity Lists Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textLight,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: 'Riwayat Mutasi Kas (${_movements.length})'),
                      Tab(text: 'Transaksi Penjualan (${_transactions.length})'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  height: 300,
                  child: _isLoadingActivity
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildMovementsList(),
                            _buildTransactionsList(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isHighlight ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlight ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: isHighlight ? 1.5 : 1,
        ),
        boxShadow: isHighlight
            ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isHighlight ? color : AppColors.textLight,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? color : AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsList() {
    if (_movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Belum ada mutasi uang kas di shift ini',
              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Gunakan tombol Cash In atau Cash Out di atas untuk mencatat mutasi',
              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _movements.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final m = _movements[index];
        final isIN = m['type'] == 'IN';
        final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
        final created = DateTime.tryParse(m['created_at']?.toString() ?? '');

        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isIN ? AppColors.success.withValues(alpha: 0.12) : const Color(0xFFE53935).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIN ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isIN ? AppColors.success : const Color(0xFFE53935),
              size: 18,
            ),
          ),
          title: Text(
            m['reason'] ?? (isIN ? 'Cash In' : 'Cash Out'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            '${created != null ? _dateFormat.format(created) : '-'} • Oleh: ${m['created_by_name'] ?? 'User'}',
            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight),
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

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Belum ada transaksi penjualan di shift ini',
              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final grandTotal = (tx['grand_total'] as num?)?.toDouble() ?? 0.0;
        final created = DateTime.tryParse(tx['created_at']?.toString() ?? '');

        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_outlined, color: AppColors.primary, size: 18),
          ),
          title: Text(
            tx['invoice_no'] ?? 'Invoice',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            '${created != null ? _dateFormat.format(created) : '-'} • ${tx['payment_method'] ?? 'Cash'}',
            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight),
          ),
          trailing: Text(
            _currencyFormat.format(grandTotal),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
          ),
        );
      },
    );
  }
}
