import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../services/scanner_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  final _taxPercentageController = TextEditingController();
  final _scannerDelayController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  
  bool _allowNegativeStock = false;
  String? _storeLogoPath;
  String? _selectedPrinter;
  List<Printer> _availablePrinters = [];
  Map<String, bool> _printerStatusMap = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      _storeNameController.text = settings['store_name'] ?? '';
      _storeAddressController.text = settings['store_address'] ?? '';
      _storePhoneController.text = settings['store_phone'] ?? '';
      _taxPercentageController.text = settings['tax_percentage'] ?? '0';
      _scannerDelayController.text = settings['scanner_delay'] ?? '50';
      _maxDiscountController.text = settings['max_discount_no_approval'] ?? '10';
      _allowNegativeStock = (settings['allow_negative_stock'] ?? '0') == '1';
      _storeLogoPath = settings['store_logo'];
      _selectedPrinter = settings['default_printer'];
      
      if (!Platform.isAndroid && !Platform.isIOS) {
        _availablePrinters = await Printing.listPrinters();
        await _checkPrinterStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await DatabaseHelper.instance.saveSetting('store_name', _storeNameController.text);
      await DatabaseHelper.instance.saveSetting('store_address', _storeAddressController.text);
      await DatabaseHelper.instance.saveSetting('store_phone', _storePhoneController.text);
      await DatabaseHelper.instance.saveSetting('tax_percentage', _taxPercentageController.text);
      await DatabaseHelper.instance.saveSetting('scanner_delay', _scannerDelayController.text);
      ScannerService.instance.setKeystrokeThreshold(int.tryParse(_scannerDelayController.text) ?? 50);
      await DatabaseHelper.instance.saveSetting('max_discount_no_approval', _maxDiscountController.text);
      await DatabaseHelper.instance.saveSetting('allow_negative_stock', _allowNegativeStock ? '1' : '0');
      if (_storeLogoPath != null) {
        await DatabaseHelper.instance.saveSetting('store_logo', _storeLogoPath!);
      }
      if (_selectedPrinter != null) {
        await DatabaseHelper.instance.saveSetting('default_printer', _selectedPrinter!);
      }
      
      final userId = AuthService().currentUser?['id'] ?? 1;
      await DatabaseHelper.instance.logActivity('EDIT', 'settings', 'Mengubah pengaturan sistem', userId: userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  Future<void> _refreshPrinters() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        final printers = await Printing.listPrinters();
        _availablePrinters = printers;
        await _checkPrinterStatus();
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ditemukan ${printers.length} printer'),
              backgroundColor: printers.isNotEmpty ? AppColors.success : AppColors.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memindai printer: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _testPrint() async {
    if (_selectedPrinter == null) return;
    try {
      final printers = await Printing.listPrinters();
      final targetPrinter = printers.firstWhere(
        (p) => p.name == _selectedPrinter,
        orElse: () => printers.first,
      );

      final pdf = pw.Document();
      
      Uint8List? logoBytes;
      try {
        final byteData = await rootBundle.load('assets/logo/Minimalist Red Shopping Cart Logo.png');
        logoBytes = byteData.buffer.asUint8List();
      } catch (_) {}
      final receiptFormat = PdfPageFormat(
        58 * PdfPageFormat.mm,
        120,
        marginLeft: 4 * PdfPageFormat.mm,
        marginRight: 4 * PdfPageFormat.mm,
        marginTop: 4 * PdfPageFormat.mm,
        marginBottom: 4 * PdfPageFormat.mm,
      );
      pdf.addPage(
        pw.Page(
          pageFormat: receiptFormat,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoBytes != null) ...[
                  pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(logoBytes),
                      width: 120,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],
                pw.Text('=== TEST PRINT ===', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('DashDock POS', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 2),
                pw.Text('Printer: ${targetPrinter.name}', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(DateTime.now().toString().split('.')[0], style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 4),
                pw.Text('Printer berfungsi!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.directPrintPdf(
        printer: targetPrinter,
        onLayout: (format) async => pdfBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print berhasil dikirim!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test print gagal: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _pickLogo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null) {
      final sourceFile = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final assetsDir = Directory(p.join(appDir.path, 'DashDock_Assets'));
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }
      final extension = p.extension(sourceFile.path);
      final destPath = p.join(assetsDir.path, 'store_logo$extension');
      await sourceFile.copy(destPath);
      setState(() {
        _storeLogoPath = destPath;
      });
    }
  }

  Future<void> _backupDatabase() async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final backupPath = p.join(selectedDirectory, 'dashdock_backup_$timestamp.db');
        await dbFile.copy(backupPath);
        
        final userId = AuthService().currentUser?['id'] ?? 1;
        await DatabaseHelper.instance.logActivity('BACKUP', 'settings', 'Backup database ke $backupPath', userId: userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup sukses: $backupPath'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup gagal: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Settings',
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: const Icon(Icons.save, color: Colors.white, size: 20),
                label: Text('Save Settings', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Store Profile', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _pickLogo,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _storeLogoPath != null && File(_storeLogoPath!).existsSync()
                                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_storeLogoPath!), fit: BoxFit.cover))
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Add Logo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: [
                              _buildTextField('Store Name', _storeNameController, Icons.store),
                              const SizedBox(height: 16),
                              _buildTextField('Phone Number', _storePhoneController, Icons.phone),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Store Address', _storeAddressController, Icons.location_on),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Financial & Taxes', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              _buildTextField('Tax Percentage (%)', _taxPercentageController, Icons.percent, isNumber: true),
                              const SizedBox(height: 8),
                              Text('* Setting tax to 0 will disable tax calculation at checkout.', style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 12)),
                              const SizedBox(height: 16),
                              _buildTextField('Max Discount Without Approval (%)', _maxDiscountController, Icons.discount, isNumber: true),
                              const SizedBox(height: 8),
                              Text('* Limit for cashiers. Requires Admin PIN if exceeded.', style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('System Operations', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              _buildTextField('Scanner Input Delay (ms)', _scannerDelayController, Icons.qr_code_scanner, isNumber: true),
                              const SizedBox(height: 8),
                              Text('* Determines threshold for keystrokes to be considered barcode scan (default 50).', style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 12)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Allow Negative Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text('Allow checkout even if stock is 0 or negative', style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _allowNegativeStock,
                                      onChanged: (val) => setState(() => _allowNegativeStock = val),
                                      activeThumbColor: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.print_outlined, size: 20, color: AppColors.primary),
                                            const SizedBox(width: 8),
                                            Text('Default Printer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            if (_selectedPrinter != null)
                                              TextButton.icon(
                                                onPressed: _testPrint,
                                                icon: const Icon(Icons.receipt_long, size: 16),
                                                label: Text('Test Print', style: GoogleFonts.outfit(fontSize: 12)),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: AppColors.primary,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                ),
                                              ),
                                            IconButton(
                                              onPressed: _refreshPrinters,
                                              icon: const Icon(Icons.refresh, size: 20),
                                              tooltip: 'Refresh Printers',
                                              color: AppColors.textLight,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (_availablePrinters.isEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 24),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.print_disabled, size: 40, color: Colors.grey.shade400),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Tidak ada printer ditemukan',
                                              style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Pastikan printer terhubung, lalu tekan tombol Refresh',
                                              style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      ...List.generate(_availablePrinters.length, (index) {
                                        final printer = _availablePrinters[index];
                                        final isSelected = _selectedPrinter == printer.name;
                                        final isVirtual = _isVirtualPrinter(printer.name);
                                        final isConnected = _printerStatusMap[printer.name] ?? false;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () {
                                              setState(() => _selectedPrinter = printer.name);
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppColors.primary.withValues(alpha: 0.08)
                                                    : isVirtual
                                                        ? Colors.grey.shade50
                                                        : Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : Colors.grey.shade200,
                                                  width: isSelected ? 1.5 : 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: isSelected
                                                        ? Center(
                                                            child: Container(
                                                              width: 10,
                                                              height: 10,
                                                              decoration: const BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                color: AppColors.primary,
                                                              ),
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(
                                                    isVirtual ? Icons.description_outlined : Icons.print,
                                                    size: 20,
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : isVirtual
                                                            ? Colors.grey.shade400
                                                            : AppColors.textDark,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          printer.name,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 13,
                                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                            color: isVirtual ? Colors.grey.shade500 : AppColors.textDark,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          isVirtual ? 'Printer Virtual (Software)' : 'Printer Fisik',
                                                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade500),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (isVirtual)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.shade50,
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(color: Colors.blue.shade200),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.cloud_outlined, size: 12, color: Colors.blue.shade400),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Virtual',
                                                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade400),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: isConnected
                                                            ? AppColors.success.withValues(alpha: 0.12)
                                                            : Colors.orange.shade50,
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(
                                                          color: isConnected
                                                              ? AppColors.success.withValues(alpha: 0.4)
                                                              : Colors.orange.shade300,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 7,
                                                            height: 7,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: isConnected ? AppColors.success : Colors.orange.shade400,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 5),
                                                          Text(
                                                            isConnected ? 'Terhubung' : 'Terpasang',
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: isConnected ? AppColors.success : Colors.orange.shade600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (isSelected) ...[
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    if (_selectedPrinter != null && _availablePrinters.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Printer terpilih: $_selectedPrinter',
                                                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '🟢 Terhubung = printer fisik online & siap cetak\n'
                                              '🟠 Terpasang = driver ada, printer belum terdeteksi online\n'
                                              '🔵 Virtual = printer software (PDF, OneNote, dll)',
                                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.amber.shade800, height: 1.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text('System & Backup', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _backupDatabase,
                                icon: const Icon(Icons.save_alt, color: Colors.white),
                                label: const Text('Backup Database (Export .db)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  bool _isVirtualPrinter(String name) {
    final lower = name.toLowerCase();
    const virtualKeywords = [
      'onenote', 'pdf', 'xps', 'fax', 'microsoft print',
      'send to', 'snagit', 'cute', 'foxit', 'adobe',
      'bullzip', 'dopdf', 'pdfcreator', 'nitro', 'primo',
    ];
    return virtualKeywords.any((kw) => lower.contains(kw));
  }

  Future<void> _checkPrinterStatus() async {
    final statusMap = <String, bool>{};
    
    if (Platform.isWindows) {
      try {
        // Use PowerShell to check real printer status via WMI
        final result = await Process.run('powershell', [
          '-NoProfile', '-Command',
          'Get-Printer | Select-Object Name, PrinterStatus | ConvertTo-Json'
        ]);
        
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
          final output = result.stdout.toString().trim();
          final dynamic decoded = const JsonDecoder().convert(output);
          final List<dynamic> printerList = decoded is List ? decoded : [decoded];
          
          for (var p in printerList) {
            final name = p['Name'] as String? ?? '';
            // PrinterStatus: 0 = Normal, 1 = Paused, 2 = Error, 3 = Pending Deletion, etc.
            final status = p['PrinterStatus'] as int? ?? -1;
            if (_isVirtualPrinter(name)) {
              statusMap[name] = true; // Virtual printers are always "available"
            } else {
              // Status 0 (Normal) means the printer is online and ready
              statusMap[name] = status == 0;
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking printer status: $e');
      }
    }
    
    // For any printer not found in WMI result, default to false
    for (var printer in _availablePrinters) {
      statusMap.putIfAbsent(printer.name, () => false);
    }
    
    _printerStatusMap = statusMap;
  }
}
