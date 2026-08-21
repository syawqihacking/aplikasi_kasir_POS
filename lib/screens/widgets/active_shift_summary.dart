import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/shift_service.dart';
import '../../models/shift.dart';

class ActiveShiftSummary extends StatefulWidget {
  const ActiveShiftSummary({super.key});

  @override
  State<ActiveShiftSummary> createState() => _ActiveShiftSummaryState();
}

class _ActiveShiftSummaryState extends State<ActiveShiftSummary> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    ShiftService.instance.refreshActiveShift();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CashShift?>(
      valueListenable: ShiftService.instance.activeShiftNotifier,
      builder: (context, shift, _) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Active Shift',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: Colors.white70),
                    onPressed: () => ShiftService.instance.refreshActiveShift(),
                  )
                ],
              ),
              const SizedBox(height: 16),
              if (shift == null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Tidak ada shift aktif saat ini.',
                      style: GoogleFonts.outfit(color: Colors.white70),
                    ),
                  ),
                )
              else ...[
                _buildRow('No. Shift', shift.shiftNumber),
                const SizedBox(height: 8),
                _buildRow('Kasir', shift.cashierName ?? 'Kasir'),
                const SizedBox(height: 8),
                _buildRow('Waktu Buka', shift.openedAt.substring(0, 16).replaceAll('T', ' ')),
                const Divider(color: Colors.white24, height: 24),
                _buildRow('Modal Awal', _currencyFormat.format(shift.openingBalance)),
                const SizedBox(height: 8),
                _buildRow('Penjualan Kas', _currencyFormat.format(shift.totalCashSales)),
                const SizedBox(height: 8),
                _buildRow('Cash In', _currencyFormat.format(shift.totalCashIn)),
                const SizedBox(height: 8),
                _buildRow('Cash Out', _currencyFormat.format(shift.totalCashOut)),
                const Divider(color: Colors.white24, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kas Seharusnya', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(
                      _currencyFormat.format(shift.expectedCash),
                      style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
