import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';

class ActiveShiftSummary extends StatefulWidget {
  const ActiveShiftSummary({super.key});

  @override
  State<ActiveShiftSummary> createState() => _ActiveShiftSummaryState();
}

class _ActiveShiftSummaryState extends State<ActiveShiftSummary> {
  Map<String, dynamic>? _shift;

  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shift = await DatabaseHelper.instance.getActiveShiftSummary();
    if (mounted) {
      setState(() {
        _shift = shift;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Shift',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
                onPressed: _loadData,
              )
            ],
          ),
          const SizedBox(height: 16),
          if (_shift == null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No active shift currently open.',
                  style: GoogleFonts.outfit(color: Colors.white70),
                ),
              ),
            )
          else ...[
            _buildRow('Cashier', _shift!['cashier_name']),
            const SizedBox(height: 8),
            _buildRow('Opened At', _shift!['opened_at'].toString().substring(0, 16).replaceAll('T', ' ')),
            const Divider(color: Colors.white24, height: 24),
            _buildRow('Opening Balance', _currencyFormat.format(_shift!['opening_balance'])),
            const SizedBox(height: 8),
            _buildRow('Sales (Cash)', _currencyFormat.format(_shift!['sales_total'])),
            const SizedBox(height: 8),
            _buildRow('Cash In', _currencyFormat.format(_shift!['movements_in'])),
            const SizedBox(height: 8),
            _buildRow('Cash Out', _currencyFormat.format(_shift!['movements_out'])),
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Expected Cash', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(_currencyFormat.format(_shift!['expected_cash']), style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
