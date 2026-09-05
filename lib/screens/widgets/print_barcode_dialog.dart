import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';
import '../../repositories/product_repository.dart';
import '../../services/auth_service.dart';

class PrintBarcodeDialog extends StatefulWidget {
  final Map<String, dynamic> product;

  const PrintBarcodeDialog({super.key, required this.product});

  @override
  State<PrintBarcodeDialog> createState() => _PrintBarcodeDialogState();
}

class _PrintBarcodeDialogState extends State<PrintBarcodeDialog> {
  late String _barcodeData;
  late String _productName;
  late dynamic _sellPrice;
  bool _isGenerating = false;
  bool _hasGenerated = false;

  @override
  void initState() {
    super.initState();
    _barcodeData = widget.product['barcode']?.toString() ?? '';
    _productName = widget.product['name'] ?? '';
    _sellPrice = widget.product['sell_price'] ?? 0;

    // Auto-generate barcode if product doesn't have one
    if (_barcodeData.isEmpty) {
      _autoGenerateBarcode();
    }
  }

  String _generateEan13Barcode() {
    // Generate EAN-13 like internal barcode with prefix 200
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(2, 11);
    final prefix = "200";
    final withoutChecksum = prefix + timestamp;

    // Calculate EAN-13 Checksum
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(withoutChecksum[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checksum = (10 - (sum % 10)) % 10;

    return withoutChecksum + checksum.toString();
  }

  Future<void> _autoGenerateBarcode() async {
    setState(() => _isGenerating = true);

    try {
      // Generate a unique barcode
      String barcode = _generateEan13Barcode();

      // Ensure uniqueness
      int attempts = 0;
      while (attempts < 10) {
        final existing = await ProductRepository.instance.findByBarcode(
          barcode,
          excludeProductId: widget.product['id'],
        );
        if (existing == null) break;
        barcode = _generateEan13Barcode();
        attempts++;
      }

      // Save barcode to database
      final productId = widget.product['id'];
      if (productId != null) {
        await ProductRepository.instance.update(productId, {'barcode': barcode});
        final userId = AuthService().currentUser?['id'] ?? 1;
        await DatabaseHelper.instance.logActivity(
          'EDIT',
          'products',
          'Auto-generate barcode untuk: $_productName',
          userId: userId,
        );
      }

      setState(() {
        _barcodeData = barcode;
        _hasGenerated = true;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal generate barcode: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    // We create a label sized layout, typically 50x30 mm
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          50 * PdfPageFormat.mm,
          30 * PdfPageFormat.mm,
          marginAll: 2 * PdfPageFormat.mm,
        ),
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  _productName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: _barcodeData,
                  width: 40 * PdfPageFormat.mm,
                  height: 15 * PdfPageFormat.mm,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Rp $_sellPrice',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final hasBarcode = _barcodeData.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Print Barcode Label',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Product info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _productName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  if (hasBarcode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Barcode: $_barcodeData',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content area
            Expanded(
              child: _isGenerating
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Generating barcode...'),
                        ],
                      ),
                    )
                  : !hasBarcode
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: AppColors.danger,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Gagal generate barcode',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Silakan coba lagi atau generate manual dari halaman produk.',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: AppColors.textLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _autoGenerateBarcode,
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: Text(
                                  'Coba Lagi',
                                  style: GoogleFonts.outfit(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            if (_hasGenerated)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.success.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Barcode berhasil di-generate dan disimpan: $_barcodeData',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: PdfPreview(
                                build: (format) => _generatePdf(format),
                                canChangeOrientation: false,
                                canChangePageFormat: false,
                                initialPageFormat: PdfPageFormat(
                                  50 * PdfPageFormat.mm,
                                  30 * PdfPageFormat.mm,
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
