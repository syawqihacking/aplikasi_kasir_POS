import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/shift_service.dart';
import '../../../models/shift.dart';
import 'shift_receipt_dialog.dart';

class CloseShiftDialog extends StatefulWidget {
  final CashShift shift;

  const CloseShiftDialog({
    super.key,
    required this.shift,
  });

  static Future<bool?> show(BuildContext context, {required CashShift shift}) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CloseShiftDialog(shift: shift),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      final closedShift = CashShift.fromMap(result);
      final movements = (result['movements'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final transactions = (result['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      await ShiftReceiptDialog.show(
        context,
        shift: closedShift,
        movements: movements,
        transactions: transactions,
      );
      return true;
    }
    return result != null;
  }

  @override
  State<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<CloseShiftDialog> {
  final _physicalCashController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  double _actualCash = 0.0;
  bool _isClosing = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  double get _systemCash => widget.shift.expectedCash;
  double get _difference => _actualCash - _systemCash;

  @override
  void initState() {
    super.initState();
    // Default actual cash to system cash
    _actualCash = _systemCash;
    _physicalCashController.text = _systemCash.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _physicalCashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitCloseShift() async {
    if (!_formKey.currentState!.validate()) return;

    final diff = _difference;
    if (diff != 0) {
      final isDeficit = diff < 0;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                diff < 0 ? Icons.warning_amber_rounded : Icons.info_outline,
                color: diff < 0 ? AppColors.danger : Colors.blue,
              ),
              const SizedBox(width: 10),
              Text(
                isDeficit ? 'Konfirmasi Defisit Kas' : 'Konfirmasi Surplus Kas',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Terdapat selisih kas sebesar ${isDeficit ? '-' : '+'}${_currencyFormat.format(diff.abs())}.\n\nApakah Anda yakin ingin menutup shift ini dengan catatan yang telah dimasukkan?',
            style: GoogleFonts.outfit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Periksa Kembali', style: GoogleFonts.outfit()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDeficit ? AppColors.danger : AppColors.primary,
              ),
              child: Text(
                'Tetap Tutup Shift',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isClosing = true);
    try {
      final userId = AuthService().currentUser?['id'] as int? ?? widget.shift.cashierId;
      await ShiftService.instance.closeShift(
        shiftId: widget.shift.id ?? 1,
        physicalBalance: _actualCash,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        closedBy: userId,
      );

      final details = await ShiftService.instance.getShiftDetails(widget.shift.id ?? 1);

      if (mounted) {
        Navigator.pop(context, details ?? <String, dynamic>{});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shift ${widget.shift.shiftNumber} berhasil ditutup!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menutup shift: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diff = _difference;
    Color diffColor;
    String diffLabel;
    IconData diffIcon;

    if (diff == 0) {
      diffColor = AppColors.success;
      diffLabel = 'Pas / Sesuai (Rp 0)';
      diffIcon = Icons.check_circle_outline_rounded;
    } else if (diff > 0) {
      diffColor = Colors.blue.shade700;
      diffLabel = 'Surplus / Lebih (+${_currencyFormat.format(diff)})';
      diffIcon = Icons.arrow_upward_rounded;
    } else {
      diffColor = AppColors.danger;
      diffLabel = 'Defisit / Kurang (-${_currencyFormat.format(diff.abs())})';
      diffIcon = Icons.error_outline_rounded;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.lock_clock_outlined,
                        color: Color(0xFFE53935),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tutup Shift Kasir',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            'Shift ${widget.shift.shiftNumber} • ${widget.shift.cashierName ?? 'Kasir'}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close, color: AppColors.textLight),
                    )
                  ],
                ),
                const SizedBox(height: 20),

                // Financial Breakdown Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildRow('Modal Awal Kasir', _currencyFormat.format(widget.shift.openingBalance)),
                      const SizedBox(height: 6),
                      _buildRow('Penjualan Tunai (Cash)', _currencyFormat.format(widget.shift.totalCashSales), color: AppColors.success),
                      const SizedBox(height: 6),
                      _buildRow('Penjualan Non-Tunai (QRIS/Transfer)', _currencyFormat.format(widget.shift.totalNonCashSales)),
                      const SizedBox(height: 6),
                      _buildRow('Total Cash In (Pemasukan Kas)', '+${_currencyFormat.format(widget.shift.totalCashIn)}', color: AppColors.success),
                      const SizedBox(height: 6),
                      _buildRow('Total Cash Out (Pengeluaran Kas)', '-${_currencyFormat.format(widget.shift.totalCashOut)}', color: AppColors.danger),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kas yang Seharusnya di Laci',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                '(Modal + Penjualan Tunai + In - Out)',
                                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight),
                              ),
                            ],
                          ),
                          Text(
                            _currencyFormat.format(_systemCash),
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Actual Physical Cash Input
                Text(
                  'Kas Aktual Fisik (Dihitung dari laci uang)',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _physicalCashController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.point_of_sale, color: AppColors.primary),
                    prefixText: 'Rp ',
                    prefixStyle: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    hintText: '0',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    final numVal = double.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
                    setState(() => _actualCash = numVal);
                  },
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Masukkan jumlah uang fisik di laci';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Difference Calculation Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: diffColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: diffColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(diffIcon, color: diffColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Selisih Kas: $diffLabel',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: diffColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Closing Note
                Text(
                  'Catatan Penutupan ${diff != 0 ? '(Wajib diisi jika ada selisih)' : '(Opsional)'}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: diff != 0
                        ? 'Jelaskan alasan selisih kas (misal: uang kembalian lebih/kurang)'
                        : 'Catatan tambahan penutupan kasir...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (diff != 0 && (val == null || val.trim().isEmpty)) {
                      return 'Harap masukkan catatan penjelasan mengenai selisih kas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isClosing ? null : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Batal', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isClosing ? null : _submitCloseShift,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _isClosing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: Text(
                          _isClosing ? 'Memproses...' : 'Tutup Shift Sekarang',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
