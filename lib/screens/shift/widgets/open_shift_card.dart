import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../database/database_helper.dart';
import '../../../services/auth_service.dart';
import '../../../services/shift_service.dart';

class OpenShiftCard extends StatefulWidget {
  final VoidCallback? onShiftOpened;
  final bool isDialog;

  const OpenShiftCard({
    super.key,
    this.onShiftOpened,
    this.isDialog = false,
  });

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: OpenShiftCard(
            isDialog: true,
            onShiftOpened: () => Navigator.pop(context, true),
          ),
        ),
      ),
    );
  }

  @override
  State<OpenShiftCard> createState() => _OpenShiftCardState();
}

class _OpenShiftCardState extends State<OpenShiftCard> {
  final _openingBalanceController = TextEditingController(text: '100000');
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _users = [];
  int? _selectedCashierId;
  String _previewShiftNumber = 'SHF-...';
  bool _isLoading = true;
  bool _isSubmitting = false;

  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('EEEE, dd MMMM yyyy • HH:mm:ss', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final users = await DatabaseHelper.instance.getAllUsers();
      final previewNumber = await DatabaseHelper.instance.generateNextShiftNumber();
      final currentUserId = AuthService().currentUser?['id'] as int?;

      if (mounted) {
        setState(() {
          _users = users.where((u) => u['is_active'] == 1).toList();
          _previewShiftNumber = previewNumber;
          if (_users.isNotEmpty) {
            final match = _users.where((u) => u['id'] == currentUserId);
            _selectedCashierId = match.isNotEmpty ? match.first['id'] as int : _users.first['id'] as int;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setAmount(double amount) {
    _openingBalanceController.text = amount.toStringAsFixed(0);
  }

  Future<void> _startShift() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCashierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kasir terlebih dahulu'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final balance = double.tryParse(_openingBalanceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

    setState(() => _isSubmitting = true);
    try {
      final shift = await ShiftService.instance.openShift(
        cashierId: _selectedCashierId!,
        openingBalance: balance,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shift ${shift.shiftNumber} berhasil dibuka dengan modal ${_currencyFormat.format(balance)}!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onShiftOpened?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka shift: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(widget.isDialog ? 0 : 32),
      decoration: widget.isDialog
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card Title & Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buka Shift Baru',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Mulai sesi operasional kasir dan catat modal kas awal',
                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
                if (widget.isDialog)
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: AppColors.textLight),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Live Time & Shift Number Info Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Waktu Mulai Otomatis',
                            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy • HH:mm:ss').format(_currentTime),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _previewShiftNumber,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pilih Kasir Dropdown
            Text(
              'Pilih Kasir Bertugas',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedCashierId,
              items: _users.map((u) {
                final id = u['id'] as int;
                final name = u['full_name'] ?? u['username'] ?? 'User #$id';
                final role = u['role'] ?? 'Kasir';
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text('$name ($role)', style: GoogleFonts.outfit(fontSize: 14)),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCashierId = val),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (val) => val == null ? 'Pilih kasir' : null,
            ),
            const SizedBox(height: 20),

            // Input Modal / Kas Awal
            Text(
              'Modal / Kas Awal (Rp)',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _openingBalanceController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                prefixText: 'Rp ',
                prefixStyle: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                hintText: '0',
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Masukkan modal awal (bisa 0)';
                return null;
              },
            ),
            const SizedBox(height: 10),

            // Quick Denomination Chips
            Text(
              'Pilihan Cepat Modal Awal:',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                0.0,
                50000.0,
                100000.0,
                200000.0,
                500000.0,
                1000000.0,
              ].map((amt) {
                final label = amt == 0 ? 'Rp 0 (Tanpa Modal)' : _currencyFormat.format(amt);
                return ActionChip(
                  label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onPressed: () => _setAmount(amt),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _startShift,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                label: Text(
                  _isSubmitting ? 'Membuka Shift...' : 'Mulai / Buka Shift Sekarang',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
