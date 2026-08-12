import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../services/import_export_service.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await DatabaseHelper.instance.getAllSuppliers();
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSupplierDialog([Map<String, dynamic>? supplier]) {
    final isEdit = supplier != null;
    String name = supplier?['name'] ?? '';
    String phone = supplier?['phone'] ?? '';
    String email = supplier?['email'] ?? '';
    String address = supplier?['address'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Supplier' : 'Add Supplier'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Name'),
                controller: TextEditingController(text: name),
                onChanged: (val) => name = val,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Phone'),
                controller: TextEditingController(text: phone),
                onChanged: (val) => phone = val,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Email'),
                controller: TextEditingController(text: email),
                onChanged: (val) => email = val,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Address'),
                controller: TextEditingController(text: address),
                onChanged: (val) => address = val,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (name.isEmpty) return;
              try {
                if (isEdit) {
                  await DatabaseHelper.instance.updateSupplier(supplier['id'], {
                    'name': name,
                    'phone': phone,
                    'email': email,
                    'address': address,
                  });
                } else {
                  await DatabaseHelper.instance.insertSupplier({
                    'name': name,
                    'phone': phone,
                    'email': email,
                    'address': address,
                  });
                }
                if (!mounted) return;
                Navigator.pop(context);
                _loadSuppliers();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
              }
            },
            child: const Text('Save'),
          )
        ],
      )
    );
  }

  void _deleteSupplier(int id) async {
    try {
      await DatabaseHelper.instance.deleteSupplier(id);
      _loadSuppliers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _handleSupplierImportExport(String action) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    try {
      if (action == 'export') {
        final dir = await getDownloadsDirectory();
        if (dir == null) throw Exception('Downloads directory not found');
        final path = '${dir.path}/Supplier_Export_$timestamp.xlsx';
        await ImportExportService.exportSuppliers(path);
        final userId = AuthService().currentUser?['id'] ?? 1;
        await DatabaseHelper.instance.logActivity('EXPORT', 'suppliers', 'Export data supplier ke Excel', userId: userId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil diekspor ke: $path'), backgroundColor: AppColors.success));
      } else if (action == 'template') {
        final dir = await getDownloadsDirectory();
        if (dir == null) throw Exception('Downloads directory not found');
        final path = '${dir.path}/Template_Supplier.xlsx';
        await ImportExportService.downloadSupplierTemplate(path);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Template tersimpan di: $path'), backgroundColor: AppColors.success));
      } else if (action == 'import') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls'],
        );
        if (result != null && result.files.single.path != null) {
          final importResult = await ImportExportService.importSuppliers(result.files.single.path!);
          final userId = AuthService().currentUser?['id'] ?? 1;
          await DatabaseHelper.instance.logActivity('IMPORT', 'suppliers', 'Import ${importResult.success} supplier dari Excel', userId: userId);
          _loadSuppliers();
          if (mounted) {
            _showImportResultDialog(importResult);
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    }
  }

  void _showImportResultDialog(ImportResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(result.hasErrors ? Icons.warning_amber : Icons.check_circle, color: result.hasErrors ? AppColors.warning : AppColors.success),
            const SizedBox(width: 8),
            const Text('Hasil Import'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Berhasil diimport: ${result.success} data', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (result.hasErrors) ...[
                const SizedBox(height: 12),
                Text('⚠️ ${result.errors.length} error ditemukan:', style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: result.errors.length,
                      itemBuilder: (context, index) {
                        final e = result.errors[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $e', style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Data Supplier', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Row(
                children: [
                  PopupMenuButton<String>(
                    onSelected: _handleSupplierImportExport,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.file_download, size: 18), SizedBox(width: 8), Text('Export Supplier (.xlsx)')])),
                      const PopupMenuItem(value: 'template', child: Row(children: [Icon(Icons.description, size: 18), SizedBox(width: 8), Text('Download Template')])),
                      const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.file_upload, size: 18), SizedBox(width: 8), Text('Import dari Excel')])),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.swap_vert, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('Import / Export', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showSupplierDialog(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Supplier', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: _suppliers.isEmpty 
                  ? Center(child: Text('No suppliers yet.', style: GoogleFonts.outfit(color: AppColors.textLight)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _suppliers.length,
                      itemBuilder: (context, index) {
                        final s = _suppliers[index];
                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.local_shipping, color: AppColors.primary),
                            ),
                            title: Text(
                              s['name'],
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            subtitle: Text(
                              '${s['phone'] ?? '-'}\n${s['email'] ?? '-'}',
                              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 13),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                                  onPressed: () => _showSupplierDialog(s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                  onPressed: () => _deleteSupplier(s['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          )
        ],
      ),
    );
  }
}
