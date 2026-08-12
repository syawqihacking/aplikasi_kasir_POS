import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../services/backup_service.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  String? _lastBackupDate;
  bool _isWarning = false;
  bool _isLoading = false;

  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final date = await BackupService.getLastBackupDate();
    final warn = await BackupService.shouldWarnBackup();
    
    setState(() {
      _lastBackupDate = date;
      _isWarning = warn;
    });
  }

  Future<void> _performBackup() async {
    setState(() => _isLoading = true);
    try {
      final path = await BackupService.backupDatabase();
      await _loadStatus();
      final userId = AuthService().currentUser?['id'] ?? 1;
      await DatabaseHelper.instance.logActivity('BACKUP', 'settings', 'Melakukan backup database ke $path', userId: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup berhasil dibuat di: $path'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup gagal: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performExportCustom() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      return; // User canceled
    }

    setState(() => _isLoading = true);
    try {
      final path = await BackupService.backupDatabase(customPath: selectedDirectory);
      await _loadStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil diekspor ke: $path'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export gagal: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performRestore() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null) {
      final file = result.files.single.path!;
      if (!file.endsWith('.db')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mohon pilih file berformat .db'), backgroundColor: AppColors.danger),
          );
        }
        return;
      }

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Konfirmasi Restore'),
          content: const Text('PERINGATAN: Mengembalikan database akan menimpa seluruh data yang ada saat ini. Anda disarankan melakukan backup data saat ini terlebih dahulu.\n\nLanjutkan restore?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), 
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Ya, Restore', style: TextStyle(color: Colors.white))
            ),
          ],
        )
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        try {
          await BackupService.restoreDatabase(file);
          final userId = AuthService().currentUser?['id'] ?? 1;
          await DatabaseHelper.instance.logActivity('RESTORE', 'settings', 'Melakukan restore database dari $file', userId: userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Restore berhasil. Data telah dipulihkan.'), backgroundColor: AppColors.success),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Restore gagal: $e'), backgroundColor: AppColors.danger),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backup & Restore', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 24),
          
          if (_isWarning) 
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), border: Border.all(color: AppColors.warning), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Peringatan: Anda belum melakukan backup dalam 7 hari terakhir. Sangat disarankan untuk segera melakukan backup data.',
                      style: GoogleFonts.outfit(color: AppColors.warning, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backup Card
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text('Backup Database', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Amankan data transaksi dan produk Anda dengan membuat salinan database (Max 5 file otomatis disimpan dalam sistem).', style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 16),
                        Text(
                          _lastBackupDate == null 
                            ? 'Belum pernah di-backup' 
                            : 'Backup Terakhir: ${_dateFormat.format(DateTime.parse(_lastBackupDate!))}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _isWarning ? AppColors.danger : AppColors.success),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _performBackup,
                              icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save, color: Colors.white),
                              label: const Text('Backup Cepat', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _performExportCustom,
                              icon: const Icon(Icons.folder_open),
                              label: const Text('Export ke Folder'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              
              // Restore Card
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cloud_download_outlined, size: 48, color: AppColors.danger),
                        const SizedBox(height: 16),
                        Text('Restore Database', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Pulihkan sistem Anda dari file backup (.db). Proses ini akan menimpa seluruh data yang ada saat ini secara permanen.', style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _performRestore,
                          icon: const Icon(Icons.restore, color: Colors.white),
                          label: const Text('Pilih File & Restore', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
