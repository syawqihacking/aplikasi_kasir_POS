import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
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
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Default Printer', style: TextStyle(fontWeight: FontWeight.bold)),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        hint: Text(_availablePrinters.isEmpty ? 'No printers found' : 'Select printer'),
                                        value: _selectedPrinter,
                                        items: _availablePrinters.map((p) => DropdownMenuItem(
                                          value: p.name,
                                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                                        )).toList(),
                                        onChanged: (val) => setState(() => _selectedPrinter = val),
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
}
