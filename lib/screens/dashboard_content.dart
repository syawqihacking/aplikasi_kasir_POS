import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import 'widgets/header.dart';
import 'widgets/stat_cards.dart';
import 'widgets/recent_transactions.dart';
import 'widgets/action_needed_list.dart';
import 'widgets/sales_chart.dart';
import '../utils/responsive_utils.dart';

import 'widgets/today_financial_summary.dart';

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  DateTime? _startDate;
  DateTime? _endDate;

  final _shortDateFormat = DateFormat('yyyy-MM-dd');

  bool get _hasRange => _startDate != null && _endDate != null;

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
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhoneScreen = isPhone(context);
    final gap = responsiveGap(context);

    return Padding(
      padding: responsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Header(),
          SizedBox(height: isPhoneScreen ? 12 : 16),
          Align(
            alignment: Alignment.centerRight,
            child: _buildPeriodSelector(),
          ),
          SizedBox(height: isPhoneScreen ? 12 : 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (isPhoneScreen)
                    // Phone: single column, vertical stack
                    Column(
                      children: [
                        RepaintBoundary(
                          child: StatCardsGrid(startDate: _startDate, endDate: _endDate),
                        ),
                        SizedBox(height: gap),
                        RepaintBoundary(
                          child: TodayFinancialSummary(startDate: _startDate, endDate: _endDate),
                        ),
                        SizedBox(height: gap),
                        RepaintBoundary(
                          child: SalesChart(startDate: _startDate, endDate: _endDate),
                        ),
                        SizedBox(height: gap),
                        RepaintBoundary(
                          child: RecentTransactions(startDate: _startDate, endDate: _endDate),
                        ),
                        SizedBox(height: gap),
                        const RepaintBoundary(
                          child: ActionNeededList(),
                        ),
                      ],
                    )
                  else
                    // Tablet/Desktop: multi-column layout
                    Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: RepaintBoundary(
                                child: StatCardsGrid(startDate: _startDate, endDate: _endDate),
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              flex: 2,
                              child: RepaintBoundary(
                                child: TodayFinancialSummary(startDate: _startDate, endDate: _endDate),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: gap),
                        Row(
                          children: [
                            Expanded(
                              child: RepaintBoundary(
                                child: SalesChart(startDate: _startDate, endDate: _endDate),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: gap),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: RepaintBoundary(
                                child: RecentTransactions(startDate: _startDate, endDate: _endDate),
                              ),
                            ),
                            SizedBox(width: gap),
                            const Expanded(
                              flex: 2,
                              child: RepaintBoundary(
                                child: ActionNeededList(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}