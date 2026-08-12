import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportSection {
  final String title;
  final List<String> headers;
  final List<List<dynamic>> rows;

  ReportSection({required this.title, required this.headers, required this.rows});
}

class ExportService {
  static Future<void> exportToExcel({
    required String filePath,
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    List<ReportSection> extraSections = const [],
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // Headers
    sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // Rows
    for (var row in rows) {
      sheet.appendRow(row.map((e) {
        if (e is num) return DoubleCellValue(e.toDouble());
        return TextCellValue(e.toString());
      }).toList());
    }

    // Extra sections (additional sheets)
    for (var sec in extraSections) {
      final s = excel[sec.title];
      s.appendRow(sec.headers.map((e) => TextCellValue(e)).toList());
      for (var row in sec.rows) {
        s.appendRow(row.map((e) {
          if (e is num) return DoubleCellValue(e.toDouble());
          return TextCellValue(e.toString());
        }).toList());
      }
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }
  }

  static Future<void> exportToPdf({
    required String filePath,
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
    List<ReportSection> extraSections = const [],
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows.map((r) => r.map((e) => e.toString()).toList()).toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
              cellHeight: 30,
              cellAlignments: {
                for (var i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
              },
            ),
            for (var sec in extraSections) ...[
              pw.SizedBox(height: 20),
              pw.Header(level: 1, child: pw.Text(sec.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: sec.headers,
                data: sec.rows.map((r) => r.map((e) => e.toString()).toList()).toList(),
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellHeight: 25,
              ),
            ],
          ];
        },
      ),
    );

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
  }
}
