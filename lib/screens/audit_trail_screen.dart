import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss');
  final _shortDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final startStr = '${_shortDateFormat.format(_startDate)} 00:00:00';
      final endStr = '${_shortDateFormat.format(_endDate)} 23:59:59';
      final logs = await DatabaseHelper.instance.getActivityLogs(startDate: startStr, endDate: endStr, limit: 500);
      if (mounted) {
        setState(() {
          _logs = logs;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audit trail: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadLogs();
    }
  }

  Color _getActionColor(String action) {
    action = action.toUpperCase();
    if (action.contains('LOGIN') || action.contains('LOGOUT')) return Colors.blue;
    if (action.contains('DELETE') || action.contains('VOID')) return AppColors.danger;
    if (action.contains('EDIT') || action.contains('UPDATE') || action.contains('CHANGE')) return AppColors.warning;
    if (action.contains('RESTORE')) return AppColors.danger;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Audit Trail / Log Aktivitas', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range),
                label: Text('${_shortDateFormat.format(_startDate)} - ${_shortDateFormat.format(_endDate)}'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : _logs.isEmpty 
                  ? const Center(child: Text('Tidak ada log aktivitas untuk periode ini.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final actionColor = _getActionColor(log['action'] ?? '');
                        
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
                                color: actionColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.history, color: actionColor),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  log['user_name'] ?? 'System',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textDark),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: actionColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: actionColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    log['action'] ?? '-',
                                    style: TextStyle(
                                      color: actionColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  ((log['module'] ?? '-').toString().toUpperCase()),
                                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                log['description'] ?? '-',
                                style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 13),
                              ),
                            ),
                            trailing: Text(
                              _dateFormat.format(DateTime.parse(log['created_at'])),
                              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
