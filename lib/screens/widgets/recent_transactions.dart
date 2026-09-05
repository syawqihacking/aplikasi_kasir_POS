import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive_utils.dart';

class RecentTransactions extends StatefulWidget {
  const RecentTransactions({super.key, this.startDate, this.endDate});

  final DateTime? startDate;
  final DateTime? endDate;

  @override
  State<RecentTransactions> createState() => _RecentTransactionsState();
}

class _RecentTransactionsState extends State<RecentTransactions> {
  List<Map<String, dynamic>> _transactions = [];

  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant RecentTransactions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final data = await DatabaseHelper.instance.getRecentTransactions(
      limit: 10,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
    if (mounted) {
      setState(() {
        _transactions = data;
      });
    }
  }

  void _showTransactionDetails(Map<String, dynamic> tx, NumberFormat currencyFormat) async {
    final items = await DatabaseHelper.instance.getTransactionItems(tx['id']);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transaction ${tx['invoice_no']}'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${tx['created_at'].toString().substring(0, 19).replaceAll('T', ' ')}'),
              Text('Total: ${currencyFormat.format(tx['grand_total'])}'),
              const Divider(),
              ...items.map((e) => Text('${e['qty']}x ${e['product_name']} - ${currencyFormat.format(e['subtotal'])}')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () {
              Navigator.pop(ctx);
              _showPartialReturnDialog(tx, items, currencyFormat);
            },
            child: const Text('Partial Return', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => _confirmVoid(tx, ctx),
            child: const Text('Void', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _confirmVoid(Map<String, dynamic> tx, BuildContext parentCtx) {
    String pin = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Transaction'),
        content: TextField(
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Admin PIN'),
          onChanged: (val) => pin = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              try {
                await DatabaseHelper.instance.voidTransaction(tx['id'], pin);
                final userId = AuthService().currentUser?['id'] ?? 1;
                await DatabaseHelper.instance.logActivity('VOID', 'transactions', 'Void transaksi #${tx['invoice_no']}', userId: userId);
                if (!mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction Voided'), backgroundColor: AppColors.success));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
              }
            },
            child: const Text('Confirm Void', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _showPartialReturnDialog(Map<String, dynamic> tx, List<Map<String, dynamic>> items, NumberFormat currencyFormat) {
    final Map<int, int> returnQtys = {};
    String reason = 'Customer request';
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            double totalRefund = 0;
            for (var item in items) {
              final returnQty = returnQtys[item['id']] ?? 0;
              if (returnQty > 0) {
                totalRefund += returnQty * (item['price'] - item['discount']);
              }
            }

            return AlertDialog(
              title: Text('Partial Return - Invoice ${tx['invoice_no']}'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Reason for return'),
                      onChanged: (val) => reason = val,
                      controller: TextEditingController(text: reason),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select quantities to return:'),
                    const SizedBox(height: 8),
                    ...items.map((item) {
                      final maxQty = item['qty'] as int;
                      final currentReturn = returnQtys[item['id']] ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${item['product_name']} (Max: $maxQty)')),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: currentReturn > 0
                                    ? () => setDialogState(() => returnQtys[item['id']] = currentReturn - 1)
                                    : null,
                              ),
                              Text('$currentReturn', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: currentReturn < maxQty
                                    ? () => setDialogState(() => returnQtys[item['id']] = currentReturn + 1)
                                    : null,
                              ),
                            ],
                          )
                        ],
                      );
                    }),
                    const Divider(),
                    Text('Total Refund: ${currencyFormat.format(totalRefund)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                  onPressed: () => _confirmPartialReturn(tx, returnQtys, items, reason, totalRefund, ctx),
                  child: const Text('Process Return', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      }
    );
  }

  void _confirmPartialReturn(Map<String, dynamic> tx, Map<int, int> returnQtys, List<Map<String, dynamic>> items, String reason, double totalRefund, BuildContext parentCtx) {
    if (totalRefund <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one item to return'), backgroundColor: AppColors.warning));
      return;
    }

    String pin = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Authorization'),
        content: TextField(
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Admin PIN'),
          onChanged: (val) => pin = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () async {
              final isValid = await DatabaseHelper.instance.verifyAdminPin(pin);
              if (!isValid) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Admin PIN'), backgroundColor: AppColors.danger));
                return;
              }
              
              List<Map<String, dynamic>> finalReturnItems = [];
              for (var item in items) {
                final returnQty = returnQtys[item['id']] ?? 0;
                if (returnQty > 0) {
                  finalReturnItems.add({
                    'product_id': item['product_id'],
                    'qty': returnQty,
                  });
                }
              }

              try {
                await DatabaseHelper.instance.createReturn(tx['id'], reason, totalRefund, finalReturnItems);
                final userId = AuthService().currentUser?['id'] ?? 1;
                await DatabaseHelper.instance.logActivity('RETURN', 'transactions', 'Retur produk untuk transaksi #${tx['invoice_no']}, Alasan: $reason', userId: userId);
                if (!mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partial Return Processed'), backgroundColor: AppColors.success));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
              }
            },
            child: const Text('Authorize & Return', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhoneScreen = isPhone(context);
    return Container(
      padding: responsiveCardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: GoogleFonts.outfit(
                  fontSize: isPhoneScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadData,
              )
            ],
          ),
          const SizedBox(height: 16),
          if (_transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No transactions yet.')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                return ListTile(
                  onTap: () => _showTransactionDetails(tx, _currencyFormat),
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    tx['invoice_no'],
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    tx['created_at'].toString().substring(0, 16).replaceAll('T', ' '),
                    style: GoogleFonts.outfit(fontSize: 12),
                  ),
                  trailing: Text(
                    _currencyFormat.format(tx['grand_total']),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
