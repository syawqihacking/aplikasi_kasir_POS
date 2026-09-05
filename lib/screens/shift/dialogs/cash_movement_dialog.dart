import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/shift_service.dart';
import '../../../models/shift.dart';

class CashMovementDialog extends StatefulWidget {
  final CashShift shift;
  final String initialType; // 'IN' or 'OUT'

  const CashMovementDialog({
    super.key,
    required this.shift,
    this.initialType = 'IN',
  });

  static Future<bool?> show(BuildContext context, {required CashShift shift, String initialType = 'IN'}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CashMovementDialog(
        shift: shift,
        initialType: initialType,
      ),
    );
  }

  @override
  State<CashMovementDialog> createState() => _CashMovementDialogState();
}

class _CashMovementDialogState extends State<CashMovementDialog> {
  late String _type;
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final List<String> _cashInReasons = [
    'Tambahan Modal / Kas Awal',
    'Tukar Uang Pecahan',
    'Penambahan Saldo Kasir',
    'Uang Titipan',
    'Lainnya',
  ];

  final List<String> _cashOutReasons = [
    'Pengeluaran Operasional Toko',
    'Beli Kertas Thermal / Struk',
    'Beli Galon / Minuman / ATK',
    'Setor Uang ke Owner / Brankas',
    'Pengembalian / Refund Khusus',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _reasonController.text = _type == 'IN' ? _cashInReasons.first : _cashOutReasons.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String newType) {
    setState(() {
      _type = newType;
      _reasonController.text = _type == 'IN' ? _cashInReasons.first : _cashOutReasons.first;
    });
  }

  void _setAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal harus lebih dari 0'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alasan mutasi kas harus diisi'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = AuthService().currentUser?['id'] as int? ?? widget.shift.cashierId;
      await ShiftService.instance.addCashMovement(
        shiftId: widget.shift.id ?? 1,
        type: _type,
        amount: amount,
        reason: reason,
        userId: userId,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_type == 'IN' ? 'Cash In' : 'Cash Out'} berhasil dicatat: ${_currencyFormat.format(amount)}',
            ),
            backgroundColor: _type == 'IN' ? AppColors.success : AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencatat mutasi kas: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIN = _type == 'IN';
    final primaryColor = isIN ? AppColors.success : const Color(0xFFE53935);
    final reasons = isIN ? _cashInReasons : _cashOutReasons;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
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
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isIN ? Icons.south_west_rounded : Icons.north_east_rounded,
                      color: primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIN ? 'Cash In (Pemasukan Kas)' : 'Cash Out (Pengeluaran Kas)',
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
                    onPressed: () {
                      if (ModalRoute.of(context)?.isCurrent == true) {
                        Navigator.pop(context, false);
                      }
                    },
                    icon: const Icon(Icons.close, color: AppColors.textLight),
                  )
                ],
              ),
              const SizedBox(height: 20),

              // Type Switcher Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onTypeChanged('IN'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isIN ? AppColors.success : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isIN
                                ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 6)]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '📥 Cash In (Pemasukan)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isIN ? Colors.white : AppColors.textLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onTypeChanged('OUT'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isIN ? const Color(0xFFE53935) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isIN
                                ? [BoxShadow(color: const Color(0xFFE53935).withValues(alpha: 0.3), blurRadius: 6)]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '📤 Cash Out (Pengeluaran)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !isIN ? Colors.white : AppColors.textLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Amount Input
              Text(
                'Nominal (Rp)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.payments_outlined, color: primaryColor),
                  prefixText: 'Rp ',
                  prefixStyle: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                  hintText: '0',
                  filled: true,
                  fillColor: primaryColor.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Masukkan nominal';
                  final numVal = double.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (numVal == null || numVal <= 0) return 'Nominal harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Quick Nominal Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [20000.0, 50000.0, 100000.0, 200000.0, 500000.0].map((amt) {
                  return ActionChip(
                    label: Text(
                      _currencyFormat.format(amt),
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onPressed: () => _setAmount(amt),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Reason / Keterangan Dropdown & Quick Chips
              Text(
                'Alasan / Kategori',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: reasons.map((r) {
                  final isSelected = _reasonController.text.trim() == r;
                  return ChoiceChip(
                    label: Text(r, style: GoogleFonts.outfit(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: primaryColor.withValues(alpha: 0.18),
                    labelStyle: GoogleFonts.outfit(
                      color: isSelected ? primaryColor : AppColors.textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _reasonController.text = r);
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Keterangan Detail',
                  hintText: 'Misal: Beli pulsa listrik / Uang kembalian',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit_note_outlined),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Keterangan harus diisi' : null,
              ),
              const SizedBox(height: 26),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () {
                        if (ModalRoute.of(context)?.isCurrent == true) {
                          Navigator.pop(context, false);
                        }
                      },
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
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(isIN ? Icons.save_alt : Icons.check, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Menyimpan...' : (isIN ? 'Simpan Cash In' : 'Simpan Cash Out'),
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
    );
  }
}
