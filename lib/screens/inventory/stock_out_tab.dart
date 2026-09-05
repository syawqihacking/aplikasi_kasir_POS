import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';
import '../../services/scanner_service.dart';
import '../../utils/responsive_utils.dart';

class StockOutTab extends StatefulWidget {
  const StockOutTab({super.key});

  @override
  State<StockOutTab> createState() => _StockOutTabState();
}

class _StockOutTabState extends State<StockOutTab> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  
  int? _selectedProductId;
  int _qty = 0;
  String _reason = 'damaged';
  String _notes = '';

  final List<Map<String, String>> _reasons = [
    {'value': 'damaged', 'label': 'Barang Rusak'},
    {'value': 'lost', 'label': 'Barang Hilang'},
    {'value': 'internal_use', 'label': 'Pemakaian Internal'},
    {'value': 'supplier_return', 'label': 'Retur ke Supplier'},
    {'value': 'adjustment', 'label': 'Koreksi Stok'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    ScannerService.instance.pushContext(ScanContext(
      id: 'StockOutTab_scanner',
      mode: ScanContextMode.inventoryLookup,
      handler: (scannedBarcode) {
        try {
          final product = _products.firstWhere(
            (p) => p['barcode'] == scannedBarcode,
          );
          setState(() {
            _selectedProductId = product['id'];
          });
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Produk dengan barcode '$scannedBarcode' tidak ditemukan di database.",
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
    ));
  }

  @override
  void dispose() {
    ScannerService.instance.popContext('StockOutTab_scanner');
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await DatabaseHelper.instance.getAllProducts();
      if (mounted) {
        setState(() {
          _products = products;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitStockOut() async {
    if (_selectedProductId == null || _qty <= 0 || _notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk, masukkan qty > 0, dan wajib isi catatan.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    
    // Check if enough stock
    final product = _products.firstWhere((p) => p['id'] == _selectedProductId);
    if ((product['current_stock'] as int) < _qty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok tidak mencukupi!'), backgroundColor: AppColors.warning),
      );
      return;
    }

    try {
      await DatabaseHelper.instance.stockOut(_selectedProductId!, _qty, _reason, _notes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang keluar berhasil dicatat.'), backgroundColor: AppColors.success),
      );
      setState(() {
        _selectedProductId = null;
        _qty = 0;
        _notes = '';
      });
      _loadProducts(); // Refresh stocks
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final isPhoneScreen = isPhone(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isPhoneScreen ? 16 : 24),
      child: Container(
        width: isPhoneScreen ? double.infinity : 600,
        padding: responsiveCardPadding(context),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Form Barang Keluar', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 24),
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Pilih Produk',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              initialValue: _selectedProductId,
              items: _products.map((p) => DropdownMenuItem<int>(
                value: p['id'] as int,
                child: Text('${p['name']} (Stok: ${p['current_stock']})'),
              )).toList(),
              onChanged: (val) => setState(() => _selectedProductId = val),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity (Qty)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => _qty = int.tryParse(value) ?? 0,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Alasan Keluar',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              initialValue: _reason,
              items: _reasons.map((r) => DropdownMenuItem<String>(
                value: r['value'],
                child: Text(r['label']!),
              )).toList(),
              onChanged: (val) => setState(() => _reason = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan (Wajib)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => _notes = value,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitStockOut,
                icon: const Icon(Icons.save, color: Colors.white),
                label: Text('Simpan', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
