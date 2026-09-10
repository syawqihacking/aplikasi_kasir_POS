import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';

class ActionNeededList extends StatefulWidget {
  const ActionNeededList({super.key});

  @override
  State<ActionNeededList> createState() => _ActionNeededListState();
}

class _ActionNeededListState extends State<ActionNeededList> {
  List<Map<String, dynamic>> _lowStock = [];
  List<Map<String, dynamic>> _noBarcode = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final lowStock = await DatabaseHelper.instance.getLowStockProducts();
    final noBarcode = await DatabaseHelper.instance.getProductsWithoutBarcode();
    if (mounted) {
      setState(() {
        _lowStock = lowStock;
        _noBarcode = noBarcode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                'Action Needed',
                style: GoogleFonts.outfit(
                  fontSize: 16,
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
          if (_lowStock.isEmpty && _noBarcode.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('All good! No pending actions.')),
            )
          else ...[
            if (_lowStock.isNotEmpty) ...[
              Text(
                'Low Stock Products',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.danger),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _lowStock.length,
                itemBuilder: (context, index) {
                  final p = _lowStock[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                    title: Text(p['name'], style: GoogleFonts.outfit(fontSize: 14), overflow: TextOverflow.ellipsis),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text('Stock: ${p['current_stock']} / Min: ${p['min_stock']}', style: GoogleFonts.outfit(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            if (_noBarcode.isNotEmpty) ...[
              Text(
                'Products Without Barcode',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.warning),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _noBarcode.length,
                itemBuilder: (context, index) {
                  final p = _noBarcode[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.qr_code_scanner, color: AppColors.warning),
                    title: Text(p['name'], style: GoogleFonts.outfit(fontSize: 14)),
                  );
                },
              ),
            ]
          ]
        ],
      ),
    );
  }
}
