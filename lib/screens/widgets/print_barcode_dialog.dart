import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_colors.dart';

class PrintBarcodeDialog extends StatelessWidget {
  final Map<String, dynamic> product;

  const PrintBarcodeDialog({super.key, required this.product});

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final barcodeData = product['barcode']?.toString() ?? '';
    
    // We create a label sized layout, typically 50x30 mm
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  product['name'],
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(), // fallback to code128 as it supports most chars
                  data: barcodeData,
                  width: 40 * PdfPageFormat.mm,
                  height: 15 * PdfPageFormat.mm,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Rp ${product['sell_price']}',
                  style: pw.TextStyle(fontSize: 8),
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
    final barcodeData = product['barcode']?.toString();
    final hasBarcode = barcodeData != null && barcodeData.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Print Barcode Label',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!hasBarcode)
              Expanded(
                child: Center(
                  child: Text(
                    'Product has no barcode. Please edit and generate a barcode first.',
                    style: GoogleFonts.outfit(fontSize: 16, color: AppColors.danger),
                  ),
                ),
              )
            else
              Expanded(
                child: PdfPreview(
                  build: (format) => _generatePdf(format),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  initialPageFormat: PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
