import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../theme/app_colors.dart';
import '../../../database/database_helper.dart';
import '../../../models/shift.dart';

class ShiftReceiptDialog extends StatefulWidget {
  final CashShift shift;
  final List<Map<String, dynamic>> movements;
  final List<Map<String, dynamic>> transactions;

  const ShiftReceiptDialog({
    super.key,
    required this.shift,
    this.movements = const [],
    this.transactions = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required CashShift shift,
    List<Map<String, dynamic>> movements = const [],
    List<Map<String, dynamic>> transactions = const [],
  }) {
    return showDialog(
      context: context,
      builder: (context) => ShiftReceiptDialog(
        shift: shift,
        movements: movements,
        transactions: transactions,
      ),
    );
  }

  @override
  State<ShiftReceiptDialog> createState() => _ShiftReceiptDialogState();
}

class _ShiftReceiptDialogState extends State<ShiftReceiptDialog> {
  String _storeName = 'DashDock Store';
  String _storeAddress = 'Jl. Contoh No. 123';
  String _storePhone = '08123456789';
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadStoreSettings();
  }

  Future<void> _loadStoreSettings() async {
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      if (mounted) {
        setState(() {
          _storeName = settings['store_name'] ?? 'DashDock Store';
          _storeAddress = settings['store_address'] ?? 'Jl. Contoh No. 123';
          _storePhone = settings['store_phone'] ?? '08123456789';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _generateShiftPdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    
    Uint8List? logoBytes;
    try {
      final byteData = await rootBundle.load('assets/logo/Minimalist Red Shopping Cart Logo.png');
      logoBytes = byteData.buffer.asUint8List();
    } catch (_) {}
    
    final openedAt = DateTime.tryParse(widget.shift.openedAt);
    final closedAt = widget.shift.closedAt != null ? DateTime.tryParse(widget.shift.closedAt!) : null;

    final openedStr = openedAt != null ? _dateFormat.format(openedAt) : widget.shift.openedAt;
    final closedStr = closedAt != null ? _dateFormat.format(closedAt) : (widget.shift.isOpen ? 'Sedang Berjalan (Aktif)' : '-');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Store Header
              if (logoBytes != null) ...[
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    width: 120,
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
              pw.Center(
                child: pw.Text(
                  _storeName,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (_storeAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(_storeAddress, style: const pw.TextStyle(fontSize: 8)),
                ),
              if (_storePhone.isNotEmpty)
                pw.Center(
                  child: pw.Text('Telp: $_storePhone', style: const pw.TextStyle(fontSize: 8)),
                ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'LAPORAN PENUTUPAN SHIFT',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Shift Info
              _buildPdfRow('No. Shift', widget.shift.shiftNumber),
              _buildPdfRow('Kasir', widget.shift.cashierName ?? 'Kasir'),
              _buildPdfRow('Status', widget.shift.status),
              _buildPdfRow('Waktu Buka', openedStr),
              _buildPdfRow('Waktu Tutup', closedStr),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Financial Breakdown
              _buildPdfRow('Modal Awal', _currencyFormat.format(widget.shift.openingBalance)),
              _buildPdfRow('Penjualan Kas', _currencyFormat.format(widget.shift.totalCashSales)),
              _buildPdfRow('Penjualan Non-Kas', _currencyFormat.format(widget.shift.totalNonCashSales)),
              _buildPdfRow('Total Penjualan', '${_currencyFormat.format(widget.shift.totalSales)} (${widget.shift.transactionCount} trx)'),
              _buildPdfRow('Total Cash In (+)', _currencyFormat.format(widget.shift.totalCashIn)),
              _buildPdfRow('Total Cash Out (-)', _currencyFormat.format(widget.shift.totalCashOut)),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Reconciliation
              _buildPdfRow('Kas Sistem (Seharusnya)', _currencyFormat.format(widget.shift.closingBalanceSystem > 0 ? widget.shift.closingBalanceSystem : widget.shift.expectedCash), isBold: true),
              _buildPdfRow('Kas Aktual (Fisik Laci)', _currencyFormat.format(widget.shift.closingBalancePhysical), isBold: true),
              _buildPdfRow(
                'Selisih Kas',
                '${widget.shift.difference >= 0 ? '+' : ''}${_currencyFormat.format(widget.shift.difference)} (${widget.shift.difference == 0 ? 'PAS' : (widget.shift.difference > 0 ? 'SURPLUS' : 'DEFISIT')})',
                isBold: true,
              ),

              if (widget.shift.closingNote != null && widget.shift.closingNote!.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text('Catatan Penutupan:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(widget.shift.closingNote!, style: const pw.TextStyle(fontSize: 8)),
              ],

              // Movements summary
              if (widget.movements.isNotEmpty) ...[
                pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                pw.Text('Rincian Mutasi Kas (${widget.movements.length}):', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                ...widget.movements.map((m) {
                  final t = m['type'] == 'IN' ? '[IN]' : '[OUT]';
                  final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('$t ${m['reason'] ?? ''}', style: const pw.TextStyle(fontSize: 7)),
                        ),
                        pw.Text(_currencyFormat.format(amt), style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                  );
                }),
              ],

              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('Dicetak pada: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7)),
              ),
              pw.Center(
                child: pw.Text('*** Terima Kasih ***', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        height: 680,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Slip Ringkasan Shift',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PdfPreview(
                        build: (format) => _generateShiftPdf(format),
                        allowPrinting: true,
                        allowSharing: true,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        initialPageFormat: PdfPageFormat.roll80,
                        pdfFileName: 'Shift_${widget.shift.shiftNumber}.pdf',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
