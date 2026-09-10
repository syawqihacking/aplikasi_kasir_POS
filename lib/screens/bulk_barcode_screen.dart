import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_colors.dart';

class BulkBarcodeScreen extends StatefulWidget {
  const BulkBarcodeScreen({super.key});

  @override
  State<BulkBarcodeScreen> createState() => _BulkBarcodeScreenState();
}

class _BulkBarcodeScreenState extends State<BulkBarcodeScreen> {
  final _barcodeController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _prefixController = TextEditingController(text: '200');
  bool _autoGenerate = true;
  final List<_Entry> _history = [];

  String _generateBarcode() {
    final prefix = _prefixController.text.trim();
    final r = Random();
    final body = prefix + List.generate(max(0, 12 - prefix.length), (_) => r.nextInt(10)).join();
    if (body.length < 12) return body;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final d = int.parse(body[i]);
      sum += (i % 2 == 0) ? d : d * 3;
    }
    return body + ((10 - (sum % 10)) % 10).toString();
  }

  void _add() {
    final qty = int.tryParse(_quantityController.text.trim()) ?? 1;
    final bc = _autoGenerate ? _generateBarcode() : _barcodeController.text.trim();
    if (bc.isEmpty) return;
    setState(() => _history.insert(0, _Entry(bc, qty)));
    _barcodeController.clear();
    _quantityController.text = '1';
  }

  void _remove(int i) => setState(() => _history.removeAt(i));
  void _clearAll() => setState(() => _history.clear());

  void _print() {
    final total = _history.fold<int>(0, (s, e) => s + e.qty);
    showDialog(context: context, builder: (_) => _PreviewDialog(entries: _history, total: total));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          // Input card
          SizedBox(
            width: 400,
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Input Barcode', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Switch(value: _autoGenerate, onChanged: (v) => setState(() => _autoGenerate = v), activeThumbColor: AppColors.primary),
                        Text('Auto-generate', style: GoogleFonts.outfit(fontSize: 14)),
                      ],
                    ),
                    if (_autoGenerate) ...[
                      const SizedBox(height: 12),
                      Text('Prefix', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(controller: _prefixController, decoration: _dec('200'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                    ],
                    if (!_autoGenerate) ...[
                      const SizedBox(height: 12),
                      Text('Nomor Barcode', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(controller: _barcodeController, decoration: _dec('Masukkan barcode')),
                    ],
                    const SizedBox(height: 12),
                    Text('Jumlah Label', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(controller: _quantityController, decoration: _dec('1'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 44,
                      child: ElevatedButton(
                        onPressed: _add,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: Text('Tambah', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Queue card
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Daftar Cetak', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_history.isNotEmpty)
                          Row(children: [
                            TextButton(onPressed: _clearAll, child: const Text('Hapus Semua', style: TextStyle(color: AppColors.danger))),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _print,
                              icon: const Icon(Icons.print, color: Colors.white, size: 18),
                              label: Text('Cetak (${_history.fold<int>(0, (s, e) => s + e.qty)})', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _history.isEmpty
                          ? Center(child: Text('Belum ada barcode', style: GoogleFonts.outfit(color: AppColors.textLight)))
                          : ListView.builder(
                              itemCount: _history.length,
                              itemBuilder: (ctx, i) {
                                final e = _history[i];
                                return ListTile(
                                  leading: Icon(Icons.qr_code, color: AppColors.primary),
                                  title: Text(e.bc, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                  subtitle: Text('×${e.qty} label', style: GoogleFonts.outfit(fontSize: 12)),
                                  trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _remove(i)),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, hintStyle: GoogleFonts.outfit(color: AppColors.textLight),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );
}

class _Entry {
  final String bc;
  final int qty;
  _Entry(this.bc, this.qty);
}

class _PreviewDialog extends StatelessWidget {
  final List<_Entry> entries;
  final int total;
  const _PreviewDialog({required this.entries, required this.total});

  Future<Uint8List> _pdf(PdfPageFormat fmt) async {
    final doc = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final all = <_Entry>[];
    for (final e in entries) {
      for (int i = 0; i < e.qty; i++) all.add(e);
    }
    for (final e in all) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
        build: (_) => pw.Center(child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: e.bc, width: 40 * PdfPageFormat.mm, height: 15 * PdfPageFormat.mm),
            pw.SizedBox(height: 2),
            pw.Text(e.bc, style: const pw.TextStyle(fontSize: 7)),
          ],
        )),
      ));
    }
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 700, height: 550,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Preview & Cetak', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Text('$total label • 50×30mm • Code128', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 8),
          Expanded(
            child: PdfPreview(
              build: (f) => _pdf(f),
              canChangeOrientation: false, canChangePageFormat: false,
              initialPageFormat: PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm),
            ),
          ),
        ]),
      ),
    );
  }
}
