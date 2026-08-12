import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');
  final _shortDateFormat = DateFormat('yyyy-MM-dd');

  DateTime? _startDate;
  DateTime? _endDate;

  bool get _hasRange => _startDate != null && _endDate != null;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _hasRange
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadTransactions();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final transactions = await DatabaseHelper.instance.getTransactions(
      startDate: _startDate,
      endDate: _endDate,
    );
    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction History',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadTransactions,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'Refresh',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildPeriodSelector(),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 300,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Search invoice...',
                                  hintStyle: GoogleFonts.outfit(
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _buildFilterButton('Date'),
                          const SizedBox(width: 12),
                          _buildFilterButton('Payment Method'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _transactions.isEmpty
                        ? Center(
                            child: Text(
                              'No transactions yet.',
                              style: GoogleFonts.outfit(
                                color: AppColors.textLight,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final t = _transactions[index];
                              final date = DateTime.parse(t['created_at']);
                              final formattedDate = _dateFormat.format(date);

                              return Card(
                                color: Colors.white,
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    t['invoice_no'] ?? '-',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  subtitle: Text(
                                    formattedDate,
                                    style: GoogleFonts.outfit(
                                      color: AppColors.textLight,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
_currencyFormat.format(t['grand_total']),
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.success,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              t['payment_method'] ?? 'Cash',
                                              style: GoogleFonts.outfit(
                                                fontSize: 10,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildViewItemsButton(t),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final label = _hasRange
        ? '${_shortDateFormat.format(_startDate!)} - ${_shortDateFormat.format(_endDate!)}'
        : 'Periode Hari Ini';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: _selectDateRange,
          icon: const Icon(Icons.date_range, size: 18, color: AppColors.primary),
          label: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_hasRange) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: _clearDateRange,
            tooltip: 'Hapus filter periode',
            icon: const Icon(Icons.close, size: 18, color: AppColors.textLight),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  /// Eye/visibility button placed beside the payment chip. Opens the
  /// per-transaction product detail dialog.
  Widget _buildViewItemsButton(Map<String, dynamic> t) {
    return Tooltip(
      message: 'View items',
      child: Material(
        color: AppColors.primary.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.primary.withOpacity(0.15),
          onTap: () => _showTransactionItems(t),
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Icon(
              Icons.visibility_outlined,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a dialog listing the products sold in a given transaction.
  void _showTransactionItems(Map<String, dynamic> t) {
    final formattedDate = _dateFormat.format(DateTime.parse(t['created_at']));

    Future<List<Map<String, dynamic>>>? itemsFuture;

    showDialog(
      context: context,
      builder: (ctx) {
        itemsFuture ??= DatabaseHelper.instance.getTransactionItems(t['id']);
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 560,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogHeader(t, formattedDate, ctx),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: itemsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return _buildItemsLoadingState();
                        }
                        if (snapshot.hasError) {
                          return _buildItemsErrorState(
                            onRetry: () => setDialogState(() {
                              itemsFuture = DatabaseHelper.instance
                                  .getTransactionItems(t['id']);
                            }),
                          );
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) return _buildItemsEmptyState();
                        return _buildItemsTable(items, _currencyFormat, t);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogHeader(
    Map<String, dynamic> t,
    String formattedDate,
    BuildContext ctx,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transaction Details',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${t['invoice_no'] ?? '-'}  •  $formattedDate',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.close, color: AppColors.textLight),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildItemsLoadingState() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading items...',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsErrorState({required VoidCallback onRetry}) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 32),
            const SizedBox(height: 12),
            Text(
              'Could not load transaction items.',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please try again.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsEmptyState() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.textLight,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'No items found for this transaction.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable(
    List<Map<String, dynamic>> items,
    NumberFormat currencyFormat,
    Map<String, dynamic> t,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _ColumnHeader('Product')),
            const SizedBox(
              width: 100,
              child: _ColumnHeader('Unit Price', align: TextAlign.right),
            ),
            const SizedBox(
              width: 40,
              child: _ColumnHeader('Qty', align: TextAlign.right),
            ),
            const SizedBox(
              width: 120,
              child: _ColumnHeader('Subtotal', align: TextAlign.right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['product_name'] ?? '-'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        currencyFormat.format(item['unit_price']),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${item['qty']}',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        currencyFormat.format(item['subtotal']),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grand Total',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t['payment_method'] ?? 'Cash',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
            Text(
              currencyFormat.format(t['grand_total']),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.outfit(color: AppColors.textDark)),
          const SizedBox(width: 8),
          const Icon(Icons.filter_list, size: 16, color: AppColors.textLight),
        ],
      ),
    );
  }
}

/// Small uppercase column label used in the transaction items table.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader(this.label, {this.align = TextAlign.left});

  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
        letterSpacing: 0.5,
      ),
    );
  }
}
