import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';

class StockHistoryTab extends StatefulWidget {
  const StockHistoryTab({super.key});

  @override
  State<StockHistoryTab> createState() => _StockHistoryTabState();
}

class _StockHistoryTabState extends State<StockHistoryTab> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await DatabaseHelper.instance.getStockHistory();
      if (mounted) {
        setState(() {
          _history = history;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Riwayat Pergerakan Stok', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: _history.isEmpty
                ? Center(child: Text('Belum ada riwayat stok.', style: GoogleFonts.outfit(color: AppColors.textLight)))
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final h = _history[index];
                      final isOut = h['change_type'] == 'OUT';
                      
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
                              color: isOut ? AppColors.danger.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isOut ? Icons.arrow_downward : Icons.arrow_upward, 
                              color: isOut ? AppColors.danger : AppColors.success,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                h['product_name'] ?? 'Unknown',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOut ? AppColors.danger.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  h['change_type'] ?? '',
                                  style: TextStyle(
                                    color: isOut ? AppColors.danger : AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Alasan: ${h['notes'] ?? '-'}',
                              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 13),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isOut ? '-' : '+'}${(h['qty_change'] as num).abs()}',
                                style: GoogleFonts.outfit(
                                  color: isOut ? AppColors.danger : AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dateFormat.format(DateTime.parse(h['changed_at'])),
                                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                              ),
                            ],
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
