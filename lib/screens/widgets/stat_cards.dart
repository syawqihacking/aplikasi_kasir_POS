import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';
import 'package:intl/intl.dart';

class StatCardsGrid extends StatefulWidget {
  const StatCardsGrid({super.key, this.startDate, this.endDate});

  final DateTime? startDate;
  final DateTime? endDate;

  @override
  State<StatCardsGrid> createState() => _StatCardsGridState();
}

class _StatCardsGridState extends State<StatCardsGrid> {
  double _todayGross = 0.0;
  double _todayNet = 0.0;
  double _todayExpense = 0.0;
  int _todayOrders = 0;
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _totalCategories = 0;
  int _totalSuppliers = 0;
  int _noBarcodeCount = 0;

  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant StatCardsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseHelper.instance.getDashboardStats(
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
    if (mounted) {
      setState(() {
        _todayGross = stats['todayGross'] ?? 0.0;
        _todayNet = stats['todayNet'] ?? 0.0;
        _todayExpense = stats['todayExpense'] ?? 0.0;
        _todayOrders = stats['todayOrders'] ?? 0;
        _totalProducts = stats['totalProducts'] ?? 0;
        _lowStockCount = stats['lowStockCount'] ?? 0;
        _totalCategories = stats['totalCategories'] ?? 0;
        _totalSuppliers = stats['totalSuppliers'] ?? 0;
        _noBarcodeCount = stats['noBarcodeCount'] ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPeriod = widget.startDate != null && widget.endDate != null;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Pendapatan Kotor',
                value: _currencyFormat.format(_todayGross),
                icon: Icons.receipt_long,
                isPrimary: true,
                subtitle: isPeriod ? 'Total penjualan periode' : 'Total penjualan hari ini',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard(
                title: 'Pendapatan Bersih',
                value: _currencyFormat.format(_todayNet),
                icon: Icons.attach_money,
                subtitle: isPeriod ? 'Profit periode' : 'Profit hari ini',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard(
                title: 'Transaksi',
                value: '$_todayOrders',
                icon: Icons.shopping_basket_outlined,
                subtitle: isPeriod ? 'Jumlah order periode' : 'Jumlah order hari ini',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Produk',
                value: '$_totalProducts',
                icon: Icons.inventory_2_outlined,
                subtitle: '$_totalCategories Kategori | $_totalSuppliers Supplier',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard(
                title: 'Perlu Tindakan',
                value: '${_lowStockCount + _noBarcodeCount}',
                icon: Icons.warning_amber_rounded,
                isDanger: (_lowStockCount + _noBarcodeCount) > 0,
                subtitle: '$_lowStockCount stok menipis | $_noBarcodeCount tanpa barcode',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard(
                title: 'Pengeluaran',
                value: _currencyFormat.format(_todayExpense),
                icon: Icons.arrow_upward_rounded,
                subtitle: isPeriod ? 'Total pengeluaran periode' : 'Total pengeluaran hari ini',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required String subtitle,
    bool isPrimary = false,
    bool isDanger = false,
  }) {
    Color bgColor = Colors.white;
    Color textColor = AppColors.textDark;
    Color subtitleColor = AppColors.textLight;
    Color iconBgColor = AppColors.background;
    Color iconColor = AppColors.textDark;

    if (isPrimary) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
      subtitleColor = Colors.white70;
      iconBgColor = Colors.white;
      iconColor = AppColors.primary;
    } else if (isDanger) {
      bgColor = AppColors.danger.withValues(alpha: 0.1);
      iconBgColor = AppColors.danger.withValues(alpha: 0.2);
      iconColor = AppColors.danger;
      textColor = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}
