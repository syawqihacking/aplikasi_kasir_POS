import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';

class TodayFinancialSummary extends StatefulWidget {
  const TodayFinancialSummary({super.key, this.startDate, this.endDate});

  final DateTime? startDate;
  final DateTime? endDate;

  @override
  State<TodayFinancialSummary> createState() => _TodayFinancialSummaryState();
}

class _TodayFinancialSummaryState extends State<TodayFinancialSummary> {
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant TodayFinancialSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;

      // Build the period filter: a selected range filters by created_at
      // between the start (00:00:00) and end (23:59:59) of the range;
      // otherwise fall back to today's transactions.
      final bool hasRange = widget.startDate != null && widget.endDate != null;
      final List<String> conditions = [];
      final List<Object?> args = [];
      if (hasRange) {
        final startStr = widget.startDate!.toIso8601String().substring(0, 10);
        final endStr = widget.endDate!.toIso8601String().substring(0, 10);
        conditions.add('created_at >= ?');
        conditions.add('created_at <= ?');
        args.add('${startStr}T00:00:00');
        args.add('${endStr}T23:59:59');
      } else {
        final todayStart = DateTime.now().toIso8601String().substring(0, 10);
        conditions.add('created_at >= ?');
        args.add('${todayStart}T00:00:00');
      }
      final String where = conditions.join(' AND ');

      // Period's total sales and transaction count
      final salesRes = await db.rawQuery(
        "SELECT SUM(grand_total) as total, COUNT(id) as count FROM transactions WHERE $where",
        args,
      );
      final double todaySales = (salesRes.first['total'] as num?)?.toDouble() ?? 0.0;
      final int todayOrders = (salesRes.first['count'] as num?)?.toInt() ?? 0;

      // Period's profit/net income
      final profitRes = await db.rawQuery('''
        SELECT 
               SUM(ti.subtotal - (ti.qty * p.cost_price)) as total_profit
        FROM transaction_items ti
        JOIN transactions t ON ti.transaction_id = t.id
        JOIN products p ON ti.product_id = p.id
        WHERE t.$where
      ''', args);
      final double todayNet = (profitRes.first['total_profit'] as num?)?.toDouble() ?? 0.0;

      // Period's total sold products
      final productsRes = await db.rawQuery('''
        SELECT SUM(ti.qty) as count 
        FROM transaction_items ti
        JOIN transactions t ON ti.transaction_id = t.id
        WHERE t.$where
      ''', args);
      final int todaySoldQty = (productsRes.first['count'] as num?)?.toInt() ?? 0;

      // Period's top payment method
      final payRes = await db.rawQuery('''
        SELECT payment_method, COUNT(id) as count 
        FROM transactions 
        WHERE $where
        GROUP BY payment_method 
        ORDER BY count DESC 
        LIMIT 1
      ''', args);
      final String topPayment = payRes.isNotEmpty ? (payRes.first['payment_method']?.toString() ?? '-') : '-';

      // Payment breakdown for the period
      final breakdownRes = await db.rawQuery('''
        SELECT payment_method, grand_total 
        FROM transactions 
        WHERE $where
      ''', args);

      final Map<String, double> paymentBreakdown = {
        'Cash': 0.0,
        'QRIS': 0.0,
        'Transfer': 0.0,
        'Debit': 0.0,
      };

      for (var row in breakdownRes) {
        final String rawMethod = row['payment_method']?.toString() ?? 'Cash';
        final double total = (row['grand_total'] as num?)?.toDouble() ?? 0.0;
        
        if (rawMethod.startsWith('Split')) {
          // Parse split format: "Split (Cash: 50000, Transfer: 50000)"
          final match = RegExp(r'Split \((.+): (\d+), (.+): (\d+)\)').firstMatch(rawMethod);
          if (match != null) {
            final m1 = match.group(1)!;
            final a1 = double.tryParse(match.group(2)!) ?? 0.0;
            final m2 = match.group(3)!;
            final a2 = double.tryParse(match.group(4)!) ?? 0.0;
            
            final key1 = _normalizeMethod(m1);
            final key2 = _normalizeMethod(m2);
            paymentBreakdown[key1] = (paymentBreakdown[key1] ?? 0.0) + a1;
            paymentBreakdown[key2] = (paymentBreakdown[key2] ?? 0.0) + a2;
          } else {
            // Fallback: split evenly to Cash
            paymentBreakdown['Cash'] = (paymentBreakdown['Cash'] ?? 0.0) + total;
          }
        } else {
          final key = _normalizeMethod(rawMethod);
          paymentBreakdown[key] = (paymentBreakdown[key] ?? 0.0) + total;
        }
      }

      final double avgTransaction = todayOrders > 0 ? todaySales / todayOrders : 0.0;

      if (mounted) {
        setState(() {
          _summary = {
            'sales': todaySales,
            'orders': todayOrders,
            'net': todayNet,
            'soldQty': todaySoldQty,
            'payment': topPayment,
            'average': avgTransaction,
            'breakdown': paymentBreakdown,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.startDate != null && widget.endDate != null
                          ? 'Ringkasan Keuangan Periode'
                          : 'Ringkasan Keuangan Hari Ini',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.startDate != null && widget.endDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_dateFormat.format(widget.startDate!)} - ${_dateFormat.format(widget.endDate!)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
                onPressed: _loadData,
              )
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else if (_summary == null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Gagal memuat data keuangan.',
                  style: GoogleFonts.outfit(color: Colors.white70),
                ),
              ),
            )
          else ...[
            _buildRow('Total Transaksi', '${_summary!['orders']} Order'),
            const SizedBox(height: 8),
            _buildRow('Rata-rata per Transaksi', _currencyFormat.format(_summary!['average'])),
            const SizedBox(height: 8),
            _buildRow('Item Terjual', '${_summary!['soldQty']} Pcs'),
            const Divider(color: Colors.white24, height: 20),
            
            Text(
              'Rincian per Pembayaran', 
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_summary!['breakdown'] as Map<String, double>).entries.map((entry) {
                IconData icon;
                Color badgeColor;
                switch (entry.key.toLowerCase()) {
                  case 'cash':
                    icon = Icons.money;
                    badgeColor = Colors.green.shade400;
                    break;
                  case 'qris':
                    icon = Icons.qr_code;
                    badgeColor = Colors.blue.shade400;
                    break;
                  case 'transfer':
                    icon = Icons.account_balance;
                    badgeColor = Colors.orange.shade400;
                    break;
                  case 'debit':
                    icon = Icons.credit_card;
                    badgeColor = Colors.purple.shade400;
                    break;
                  default:
                    icon = Icons.payment;
                    badgeColor = Colors.grey.shade400;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: badgeColor),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.key}: ',
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        _currencyFormat.format(entry.value),
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            
            const Divider(color: Colors.white24, height: 24),
            _buildRow('Pembayaran Terpopuler', _summary!['payment']),
            const SizedBox(height: 8),
            _buildRow('Pendapatan Bersih (Profit)', _currencyFormat.format(_summary!['net'])),
            const Divider(color: Colors.white24, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('Pendapatan Kotor', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text(
                  _currencyFormat.format(_summary!['sales']), 
                  style: GoogleFonts.outfit(
                    color: AppColors.primary, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 18
                  )
                ),
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
        Flexible(
          child: Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  String _normalizeMethod(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'cash') return 'Cash';
    if (lower == 'qris') return 'QRIS';
    if (lower == 'transfer') return 'Transfer';
    if (lower == 'debit' || lower == 'card') return 'Debit';
    return raw.trim();
  }
}
