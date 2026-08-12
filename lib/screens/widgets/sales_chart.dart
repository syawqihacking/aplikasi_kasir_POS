import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';

class SalesChart extends StatefulWidget {
  const SalesChart({super.key, this.startDate, this.endDate});

  final DateTime? startDate;
  final DateTime? endDate;

  @override
  State<SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<SalesChart> {
  List<Map<String, dynamic>> _dailySales = [];
  bool _isLoading = true;

  final _dateFormat = DateFormat('dd/MM');
  final _compactCurrencyFormat =
      NumberFormat.compactCurrency(symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant SalesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }
    final bool hasRange = widget.startDate != null && widget.endDate != null;
    final data = hasRange
        ? await DatabaseHelper.instance.getDailySales(
            startDate: widget.startDate,
            endDate: widget.endDate,
          )
        : await DatabaseHelper.instance.getDailySales(days: 7);
    if (mounted) {
      setState(() {
        _dailySales = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(24),
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
                  widget.startDate != null && widget.endDate != null
                      ? 'Grafik Penjualan & Stok Masuk (Periode)'
                      : 'Grafik Penjualan & Stok Masuk (7 Hari)',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Row(
                  children: [
                    _buildLegendItem('Penjualan', AppColors.primary),
                    const SizedBox(width: 16),
                    _buildLegendItem('Stok Masuk', AppColors.warning),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _loadData,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.refresh, size: 20, color: AppColors.textLight),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _dailySales.isEmpty
                      ? Center(
                          child: Text(
                            'Belum ada data penjualan',
                            style: GoogleFonts.outfit(color: AppColors.textLight),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 500000,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.withOpacity(0.2),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < _dailySales.length) {
                                      final dateStr = _dailySales[value.toInt()]['date'] as String;
                                      // Parse date and show day/month like "12/07"
                                      final date = DateTime.tryParse(dateStr);
                                      final title = date != null ? _dateFormat.format(date) : '';
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        space: 8,
                                        child: Text(
                                          title,
                                          style: GoogleFonts.outfit(
                                            color: AppColors.textLight,
                                            fontSize: 10,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 500000,
                                  reservedSize: 42,
                                  getTitlesWidget: (value, meta) {
                                  return Text(
                                    _compactCurrencyFormat.format(value),
                                      style: GoogleFonts.outfit(
                                        color: AppColors.textLight,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(_dailySales.length, (index) {
                                  final sales = (_dailySales[index]['total_sales'] as num?)?.toDouble() ?? 0.0;
                                  return FlSpot(index.toDouble(), sales);
                                }),
                                isCurved: true,
                                color: AppColors.primary,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppColors.primary.withOpacity(0.1),
                                ),
                              ),
                              LineChartBarData(
                                spots: List.generate(_dailySales.length, (index) {
                                  final stockIn = (_dailySales[index]['total_stock_in'] as num?)?.toDouble() ?? 0.0;
                                  return FlSpot(index.toDouble(), stockIn);
                                }),
                                isCurved: true,
                                color: AppColors.warning,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppColors.warning.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }
}
