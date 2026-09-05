import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../utils/responsive_utils.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  List<Map<String, dynamic>> _movements = [];
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final movements = await DatabaseHelper.instance.getAllCashMovements();
      if (mounted) {
        setState(() {
          _movements = movements;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalIn {
    return _movements
        .where((m) => m['type'] == 'IN')
        .fold(0.0, (sum, m) => sum + ((m['amount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _totalOut {
    return _movements
        .where((m) => m['type'] == 'OUT')
        .fold(0.0, (sum, m) => sum + ((m['amount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _netCash => _totalIn - _totalOut;

  void _showAddDialog({required String initialType}) {
    String selectedType = initialType;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isIN = selectedType == 'IN';
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isIN ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isIN ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: isIN ? AppColors.success : AppColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isIN ? 'Catat Pemasukan (Cash In)' : 'Catat Pengeluaran (Cash Out)',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jenis Transaksi Kas',
                      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => selectedType = 'IN'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isIN ? AppColors.success : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isIN ? AppColors.success : Colors.grey.shade300),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Pemasukan (+)',
                                style: GoogleFonts.outfit(
                                  color: isIN ? Colors.white : AppColors.textDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => selectedType = 'OUT'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isIN ? AppColors.danger : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: !isIN ? AppColors.danger : Colors.grey.shade300),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Pengeluaran (-)',
                                style: GoogleFonts.outfit(
                                  color: !isIN ? Colors.white : AppColors.textDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nominal (Rp)',
                        hintText: 'Contoh: 50000',
                        prefixIcon: const Icon(Icons.monetization_on_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Masukkan nominal uang';
                        final numVal = double.tryParse(value.trim());
                        if (numVal == null || numVal <= 0) return 'Nominal harus lebih dari 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Keterangan / Alasan',
                        hintText: isIN
                            ? 'Contoh: Tambahan modal kasir dari owner'
                            : 'Contoh: Beli token listrik toko & perlengkapan',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Masukkan keterangan transaksi';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: GoogleFonts.outfit(color: AppColors.textLight)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                  final reason = reasonController.text.trim();
                  final userId = AuthService().currentUser?['id'] ?? 1;

                  await DatabaseHelper.instance.recordCashMovement(
                    selectedType,
                    amount,
                    reason,
                    userId: userId,
                  );
                  await DatabaseHelper.instance.logActivity(
                    'CREATE',
                    'cash_flow',
                    '${selectedType == 'IN' ? 'Pemasukan' : 'Pengeluaran'} Rp $amount: $reason',
                    userId: userId,
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Berhasil mencatat ${selectedType == 'IN' ? 'Pemasukan' : 'Pengeluaran'} kas.',
                        style: GoogleFonts.outfit(),
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isIN ? AppColors.success : AppColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Simpan Catatan', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(int id, String reason, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Catatan Kas?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Apakah Anda yakin ingin menghapus catatan "$reason" sebesar Rp ${amount.toStringAsFixed(0)}?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.outfit(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.deleteCashMovement(id);
              final userId = AuthService().currentUser?['id'] ?? 1;
              await DatabaseHelper.instance.logActivity(
                'DELETE',
                'cash_flow',
                'Hapus catatan kas #$id: $reason',
                userId: userId,
              );
              if (mounted) {
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Catatan kas berhasil dihapus')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text('Hapus', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhoneScreen = isPhone(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isPhoneScreen
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'cash_in',
                  backgroundColor: AppColors.success,
                  onPressed: () => _showAddDialog(initialType: 'IN'),
                  child: const Icon(Icons.add_circle_outline, color: Colors.white),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'cash_out',
                  backgroundColor: AppColors.danger,
                  onPressed: () => _showAddDialog(initialType: 'OUT'),
                  child: const Icon(Icons.remove_circle_outline, color: Colors.white),
                ),
              ],
            )
          : null,
      body: Padding(
        padding: responsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arus Kas (Pemasukan & Pengeluaran)',
                      style: GoogleFonts.outfit(
                        fontSize: responsiveFontSize(context, desktop: 28, tablet: 24, phone: 20),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (!isPhoneScreen) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Kelola catatan uang masuk dan keluar non-transaksi tanpa sistem shift',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
                  if (!isPhoneScreen)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showAddDialog(initialType: 'IN'),
                          icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                          label: Text('Catat Pemasukan', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showAddDialog(initialType: 'OUT'),
                          icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.white),
                          label: Text('Catat Pengeluaran', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
            const SizedBox(height: 24),

            // Stat Cards
            if (isPhoneScreen)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(title: 'Total Pemasukan', amount: _currencyFormat.format(_totalIn), icon: Icons.arrow_downward_rounded, color: AppColors.success, subtitle: 'Uang masuk non-penjualan')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(title: 'Total Pengeluaran', amount: _currencyFormat.format(_totalOut), icon: Icons.arrow_upward_rounded, color: AppColors.danger, subtitle: 'Beban biaya operasional')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(title: 'Saldo Kas Bersih', amount: _currencyFormat.format(_netCash), icon: Icons.account_balance_wallet_outlined, color: AppColors.primary, subtitle: 'Selisih Pemasukan & Pengeluaran'),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _buildStatCard(title: 'Total Pemasukan', amount: _currencyFormat.format(_totalIn), icon: Icons.arrow_downward_rounded, color: AppColors.success, subtitle: 'Uang masuk non-penjualan')),
                  const SizedBox(width: 20),
                  Expanded(child: _buildStatCard(title: 'Total Pengeluaran', amount: _currencyFormat.format(_totalOut), icon: Icons.arrow_upward_rounded, color: AppColors.danger, subtitle: 'Beban biaya operasional')),
                  const SizedBox(width: 20),
                  Expanded(child: _buildStatCard(title: 'Saldo Kas Bersih', amount: _currencyFormat.format(_netCash), icon: Icons.account_balance_wallet_outlined, color: AppColors.primary, subtitle: 'Selisih Pemasukan & Pengeluaran')),
                ],
              ),
            const SizedBox(height: 24),

            // List of movements
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _movements.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum Ada Catatan Pemasukan atau Pengeluaran',
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tekan tombol Catat Pemasukan atau Catat Pengeluaran di kanan atas',
                                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _movements.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _movements[index];
                                final isIN = item['type'] == 'IN';
                                final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                                final dateStr = item['created_at']?.toString() ?? '';
                                String formattedDate = '';
                                try {
                                  final dt = DateTime.parse(dateStr);
                                  formattedDate = _dateFormat.format(dt);
                                } catch (_) {
                                  formattedDate = dateStr;
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isIN
                                              ? AppColors.success.withValues(alpha: 0.1)
                                              : AppColors.danger.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isIN ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                          color: isIN ? AppColors.success : AppColors.danger,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isIN
                                                        ? AppColors.success.withValues(alpha: 0.15)
                                                        : AppColors.danger.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    isIN ? 'PEMASUKAN' : 'PENGELUARAN',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isIN ? AppColors.success : AppColors.danger,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  formattedDate,
                                                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              item['reason'] ?? 'Tanpa keterangan',
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${isIN ? '+' : '-'} ${_currencyFormat.format(amount)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isIN ? AppColors.success : AppColors.danger,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.textLight, size: 20),
                                        tooltip: 'Hapus Catatan',
                                        onPressed: () => _confirmDelete(
                                          (item['id'] as num).toInt(),
                                          item['reason']?.toString() ?? '',
                                          amount,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
