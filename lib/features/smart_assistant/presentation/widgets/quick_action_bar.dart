import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';

class QuickActionBar extends StatelessWidget {
  final Function(String) onActionSelected;

  const QuickActionBar({super.key, required this.onActionSelected});

  final List<String> _actions = const [
    "Penjualan Hari Ini",
    "Pengeluaran Hari Ini",
    "Laporan Penjualan",
    "Stok Barang",
    "Produk Terlaris",
    "Laba Hari Ini",
    "Riwayat Transaksi",
    "Data Pelanggan",
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = _actions[index];
          return ActionChip(
            label: Text(action, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primary)),
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            onPressed: () => onActionSelected(action),
          );
        },
      ),
    );
  }
}
