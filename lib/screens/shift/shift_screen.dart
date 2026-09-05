import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';
import '../../services/shift_service.dart';
import '../../models/shift.dart';
import '../../utils/responsive_utils.dart';
import 'widgets/open_shift_card.dart';
import 'widgets/active_shift_view.dart';
import 'dialogs/shift_detail_dialog.dart';
import 'dialogs/shift_receipt_dialog.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<CashShift> _historyShifts = [];
  List<Map<String, dynamic>> _cashiers = [];
  bool _isLoadingHistory = false;

  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedCashierId;
  String _selectedStatus = 'ALL';

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');
  final _shortDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    ShiftService.instance.refreshActiveShift();
    _loadCashiers();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCashiers() async {
    try {
      final users = await DatabaseHelper.instance.getAllUsers();
      if (mounted) {
        setState(() {
          _cashiers = users;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final startStr = _startDate != null ? '${_shortDateFormat.format(_startDate!)}T00:00:00' : null;
      final endStr = _endDate != null ? '${_shortDateFormat.format(_endDate!)}T23:59:59' : null;
      final query = _searchController.text.trim();

      final list = await ShiftService.instance.getShiftHistory(
        startDate: startStr,
        endDate: endStr,
        cashierId: _selectedCashierId,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        searchQuery: query.isNotEmpty ? query : null,
      );

      if (mounted) {
        setState(() {
          _historyShifts = list;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat riwayat shift: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadHistory();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadHistory();
  }

  String _formatDuration(String startStr, String? endStr) {
    try {
      final start = DateTime.parse(startStr);
      final end = endStr != null ? DateTime.parse(endStr) : DateTime.now();
      final diff = end.difference(start);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      if (hours > 0) {
        return '$hours jam $minutes mnt';
      } else {
        return '$minutes mnt';
      }
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: responsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            _buildScreenHeader(),
            const SizedBox(height: 20),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ValueListenableBuilder<CashShift?>(
                valueListenable: ShiftService.instance.activeShiftNotifier,
                builder: (context, activeShift, _) {
                  return TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textLight,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                    unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(activeShift != null ? 'Shift Aktif' : 'Buka Shift'),
                            if (activeShift != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('Riwayat Shift (${_historyShifts.length})'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveOrOpenShiftTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenHeader() {
    final isPhoneScreen = isPhone(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manajemen Shift',
              style: GoogleFonts.outfit(
                fontSize: responsiveFontSize(context, desktop: 28, tablet: 24, phone: 20),
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            if (!isPhoneScreen)
              Text(
                'Kelola sesi kasir, pantau kas real-time, dan audit riwayat shift toko',
                style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
              ),
          ],
        ),
        ValueListenableBuilder<CashShift?>(
          valueListenable: ShiftService.instance.activeShiftNotifier,
          builder: (context, activeShift, _) {
            if (activeShift != null) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: AppColors.success, size: 10),
                    const SizedBox(width: 8),
                    Text(
                      'Shift Aktif: ${activeShift.shiftNumber} (${activeShift.cashierName ?? 'Kasir'})',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Tidak Ada Shift Berjalan',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActiveOrOpenShiftTab() {
    return ValueListenableBuilder<bool>(
      valueListenable: ShiftService.instance.isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ValueListenableBuilder<CashShift?>(
          valueListenable: ShiftService.instance.activeShiftNotifier,
          builder: (context, activeShift, _) {
            if (activeShift == null) {
              return Center(
                key: const ValueKey('open_shift_container'),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: OpenShiftCard(
                      key: const ValueKey('open_shift_card'),
                      onShiftOpened: () {
                        ShiftService.instance.refreshActiveShift();
                        _loadHistory();
                      },
                    ),
                  ),
                ),
              );
            }

            return ActiveShiftView(
              key: ValueKey('active_shift_${activeShift.id}'),
              shift: activeShift,
              onRefresh: () {
                ShiftService.instance.refreshActiveShift();
                _loadHistory();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    final isPhoneScreen = isPhone(context);
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: EdgeInsets.all(isPhoneScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isPhoneScreen
              ? _buildPhoneFilters()
              : _buildDesktopFilters(),
        ),
        const SizedBox(height: 16),

        // History Table / List
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _historyShifts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada riwayat shift yang sesuai dengan filter',
                              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : isPhoneScreen
                        ? _buildShiftCardList()
                        : _buildShiftDataTable(),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cari no. shift atau nama kasir...',
            prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppColors.background,
          ),
          onChanged: (_) => _loadHistory(),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                label: Text(
                  _startDate != null && _endDate != null
                      ? '${_shortDateFormat.format(_startDate!)} - ${_shortDateFormat.format(_endDate!)}'
                      : 'Semua Tanggal',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textDark),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_startDate != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _clearDateFilter,
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Reset Tanggal',
                ),
              ],
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedCashierId,
                    hint: Text('Kasir', style: GoogleFonts.outfit(fontSize: 12)),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Semua', style: TextStyle(fontSize: 12))),
                      ..._cashiers.map((c) => DropdownMenuItem<int?>(
                            value: c['id'] as int,
                            child: Text(c['full_name'] ?? c['username'] ?? 'User #${c['id']}', style: const TextStyle(fontSize: 12)),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedCashierId = val);
                      _loadHistory();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Semua', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'OPEN', child: Text('Aktif', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'CLOSED', child: Text('Selesai', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatus = val);
                        _loadHistory();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Muat Ulang Riwayat',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        // Search field
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari no. shift atau nama kasir...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AppColors.background,
            ),
            onChanged: (_) => _loadHistory(),
          ),
        ),
        const SizedBox(width: 12),

        // Date Range Filter Button
        OutlinedButton.icon(
          onPressed: _selectDateRange,
          icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
          label: Text(
            _startDate != null && _endDate != null
                ? '${_shortDateFormat.format(_startDate!)} - ${_shortDateFormat.format(_endDate!)}'
                : 'Semua Tanggal',
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textDark),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_startDate != null) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: _clearDateFilter,
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Reset Tanggal',
          ),
        ],
        const SizedBox(width: 12),

        // Cashier Filter
        DropdownButton<int?>(
          value: _selectedCashierId,
          hint: Text('Semua Kasir', style: GoogleFonts.outfit(fontSize: 13)),
          underline: const SizedBox(),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Semua Kasir')),
            ..._cashiers.map((c) => DropdownMenuItem<int?>(
                  value: c['id'] as int,
                  child: Text(c['full_name'] ?? c['username'] ?? 'User #${c['id']}'),
                )),
          ],
          onChanged: (val) {
            setState(() => _selectedCashierId = val);
            _loadHistory();
          },
        ),
        const SizedBox(width: 12),

        // Status Filter
        DropdownButton<String>(
          value: _selectedStatus,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('Semua Status')),
            DropdownMenuItem(value: 'OPEN', child: Text('Sedang Aktif')),
            DropdownMenuItem(value: 'CLOSED', child: Text('Selesai / Ditutup')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedStatus = val);
              _loadHistory();
            }
          },
        ),
        const SizedBox(width: 8),

        // Refresh Button
        IconButton(
          onPressed: _loadHistory,
          icon: const Icon(Icons.refresh, color: AppColors.primary),
          tooltip: 'Muat Ulang Riwayat',
        ),
      ],
    );
  }

  Widget _buildShiftCardList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _historyShifts.length,
      itemBuilder: (context, index) {
        final s = _historyShifts[index];
        final isClosed = s.isClosed;
        final diff = s.difference;
        final openedAt = DateTime.tryParse(s.openedAt);
        final closedAt = s.closedAt != null ? DateTime.tryParse(s.closedAt!) : null;

        Color diffColor = AppColors.success;
        String diffText = 'Pas (0)';
        if (diff > 0) {
          diffColor = Colors.blue.shade700;
          diffText = '+${_currencyFormat.format(diff)}';
        } else if (diff < 0) {
          diffColor = AppColors.danger;
          diffText = '-${_currencyFormat.format(diff.abs())}';
        }

        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (ModalRoute.of(context)?.isCurrent == true) {
                ShiftDetailDialog.show(context, shiftId: s.id ?? 1);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.shiftNumber,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.isOpen ? AppColors.success.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.isOpen ? 'AKTIF' : 'SELESAI',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: s.isOpen ? AppColors.success : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(s.cashierName ?? 'Kasir', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          openedAt != null ? _dateFormat.format(openedAt) : s.openedAt,
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                        ),
                      ),
                    ],
                  ),
                  if (isClosed && closedAt != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Tutup: ${_dateFormat.format(closedAt)} (${_formatDuration(s.openedAt, s.closedAt)})',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Modal Awal', style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textLight)),
                          Text(_currencyFormat.format(s.openingBalance), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('Kas Sistem', style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textLight)),
                          Text(_currencyFormat.format(s.closingBalanceSystem > 0 ? s.closingBalanceSystem : s.expectedCash), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (isClosed)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Selisih', style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textLight)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: diffColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                diffText,
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: diffColor),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          if (ModalRoute.of(context)?.isCurrent == true) {
                            ShiftDetailDialog.show(context, shiftId: s.id ?? 1);
                          }
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primary),
                        label: Text('Detail', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final ctx = context;
                          final details = await ShiftService.instance.getShiftDetails(s.id ?? 1);
                          if (!ctx.mounted) return;
                          if (details != null) {
                            final shiftObj = CashShift.fromMap(details);
                            final movements = (details['movements'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                            final transactions = (details['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                            ShiftReceiptDialog.show(
                              ctx,
                              shift: shiftObj,
                              movements: movements,
                              transactions: transactions,
                            );
                          }
                        },
                        icon: const Icon(Icons.print_outlined, size: 16, color: AppColors.textLight),
                        label: Text('Cetak', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShiftDataTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1200, // Min width for all columns
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              dataRowMinHeight: 64,
              dataRowMaxHeight: 64,
              horizontalMargin: 20,
              columnSpacing: 24,
              headingTextStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppColors.textLight,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
              columns: const [
                DataColumn(label: Text('NO. SHIFT')),
                DataColumn(label: Text('KASIR')),
                DataColumn(label: Text('WAKTU BUKA')),
                DataColumn(label: Text('WAKTU TUTUP / DURASI')),
                DataColumn(label: Text('MODAL AWAL')),
                DataColumn(label: Text('KAS SISTEM')),
                DataColumn(label: Text('KAS FISIK')),
                DataColumn(label: Text('SELISIH')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('AKSI')),
              ],
              rows: _historyShifts.map((s) {
                final isClosed = s.isClosed;
                final diff = s.difference;
                final openedAt = DateTime.tryParse(s.openedAt);
                final closedAt = s.closedAt != null ? DateTime.tryParse(s.closedAt!) : null;

                Color diffColor = AppColors.success;
                String diffText = 'Pas (0)';
                if (diff > 0) {
                  diffColor = Colors.blue.shade700;
                  diffText = '+${_currencyFormat.format(diff)}';
                } else if (diff < 0) {
                  diffColor = AppColors.danger;
                  diffText = '-${_currencyFormat.format(diff.abs())}';
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        s.shiftNumber,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      onTap: () {
                        if (ModalRoute.of(context)?.isCurrent == true) {
                          ShiftDetailDialog.show(context, shiftId: s.id ?? 1);
                        }
                      },
                    ),
                    DataCell(
                      Text(s.cashierName ?? 'Kasir', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                    DataCell(
                      Text(openedAt != null ? _dateFormat.format(openedAt) : s.openedAt, style: GoogleFonts.outfit(fontSize: 12)),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            closedAt != null ? _dateFormat.format(closedAt) : 'Sedang Berjalan',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: closedAt != null ? AppColors.textDark : AppColors.success,
                              fontWeight: closedAt != null ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDuration(s.openedAt, s.closedAt),
                            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(_currencyFormat.format(s.openingBalance), style: GoogleFonts.outfit(fontSize: 13))),
                    DataCell(Text(_currencyFormat.format(s.closingBalanceSystem > 0 ? s.closingBalanceSystem : s.expectedCash), style: GoogleFonts.outfit(fontSize: 13))),
                    DataCell(Text(isClosed ? _currencyFormat.format(s.closingBalancePhysical) : '-', style: GoogleFonts.outfit(fontSize: 13))),
                    DataCell(
                      isClosed
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: diffColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                diffText,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: diffColor,
                                ),
                              ),
                            )
                          : const Text('-'),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.isOpen ? AppColors.success.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.isOpen ? 'AKTIF' : 'SELESAI',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: s.isOpen ? AppColors.success : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                            tooltip: 'Lihat Detail Shift',
                            onPressed: () {
                              if (ModalRoute.of(context)?.isCurrent == true) {
                                ShiftDetailDialog.show(context, shiftId: s.id ?? 1);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.print_outlined, size: 18, color: AppColors.textLight),
                            tooltip: 'Cetak Slip Shift',
                            onPressed: () async {
                              final ctx = context;
                              final details = await ShiftService.instance.getShiftDetails(s.id ?? 1);
                              if (!ctx.mounted) return;
                              if (details != null) {
                                final shiftObj = CashShift.fromMap(details);
                                final movements = (details['movements'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                                final transactions = (details['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                                ShiftReceiptDialog.show(
                                  ctx,
                                  shift: shiftObj,
                                  movements: movements,
                                  transactions: transactions,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
