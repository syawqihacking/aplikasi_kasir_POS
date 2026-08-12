import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';
import '../../services/auth_service.dart';
import '../../services/scanner_service.dart';

class StockOpnameTab extends StatefulWidget {
  const StockOpnameTab({super.key});

  @override
  State<StockOpnameTab> createState() => _StockOpnameTabState();
}

class _StockOpnameTabState extends State<StockOpnameTab> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  
  // map of product_id -> physical stock entered
  final Map<int, int> _physicalStocks = {};
  final Map<int, TextEditingController> _controllers = {};
  String _notes = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
    ScannerService.instance.pushContext(ScanContext(
      id: 'StockOpnameTab_scanner',
      mode: ScanContextMode.inventoryLookup,
      handler: (scannedBarcode) {
        try {
          final product = _products.firstWhere(
            (p) => p['barcode'] == scannedBarcode,
          );
          _showPhysicalStockDialog(product);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Produk dengan barcode '$scannedBarcode' tidak ditemukan di database."),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
    ));
  }

  void _showPhysicalStockDialog(Map<String, dynamic> product) {
    final pId = product['id'] as int;
    final String initialVal = _controllers[pId]?.text ?? '';
    final dialogController = TextEditingController(text: initialVal);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Input Qty Fisik - ${product['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stok Sistem: ${product['current_stock']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: dialogController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Fisik',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                dialogController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final input = dialogController.text.trim();
                _controllers[pId]?.text = input;
                setState(() {
                  if (input.isEmpty) {
                    _physicalStocks.remove(pId);
                  } else {
                    _physicalStocks[pId] = int.tryParse(input) ?? 0;
                  }
                });
                dialogController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    ScannerService.instance.popContext('StockOpnameTab_scanner');
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await DatabaseHelper.instance.getAllProducts();
      if (mounted) {
        setState(() {
          _products = products;
          for (var c in _controllers.values) {
            c.dispose();
          }
          _controllers.clear();
          for (var p in _products) {
            final pId = p['id'] as int;
            _controllers[pId] = TextEditingController();
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOpname() async {
    if (_notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catatan wajib diisi!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (_physicalStocks.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada stok fisik yang diinput.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    List<Map<String, dynamic>> opnameItems = [];
    for (var p in _products) {
      final pId = p['id'] as int;
      if (_physicalStocks.containsKey(pId)) {
        opnameItems.add({
          'product_id': pId,
          'system_qty': p['current_stock'],
          'physical_qty': _physicalStocks[pId],
          'difference': _physicalStocks[pId]! - (p['current_stock'] as int),
          'notes': _notes,
        });
      }
    }

    try {
      await DatabaseHelper.instance.saveStockOpname(opnameItems);
      final userId = AuthService().currentUser?['id'] ?? 1;
      await DatabaseHelper.instance.logActivity('CREATE', 'inventory', 'Melakukan Stock Opname. Catatan: $_notes', userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock Opname berhasil disimpan (Belum di-apply). Cek Riwayat Opname.'), backgroundColor: AppColors.success),
      );
      setState(() {
        _physicalStocks.clear();
        _notes = '';
        for (var c in _controllers.values) {
          c.clear();
        }
      });
      _loadProducts();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Stock Opname (Penyesuaian Fisik)', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              ElevatedButton.icon(
                onPressed: _saveOpname,
                icon: const Icon(Icons.save, color: Colors.white),
                label: Text('Simpan Draft Opname', style: GoogleFonts.outfit(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Catatan / Periode Opname (Wajib)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => _notes = val,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final p = _products[index];
              final pId = p['id'] as int;
              final sysQty = p['current_stock'] as int;
              final physQty = _physicalStocks[pId];
              final diff = physQty != null ? physQty - sysQty : 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('SKU: ${p['sku'] ?? '-'}', style: GoogleFonts.outfit(color: AppColors.textLight)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Sistem', style: GoogleFonts.outfit(color: AppColors.textLight)),
                            Text('$sysQty', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _controllers[pId],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Fisik',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val.isEmpty) {
                                _physicalStocks.remove(pId);
                              } else {
                                _physicalStocks[pId] = int.tryParse(val) ?? 0;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Selisih', style: GoogleFonts.outfit(color: AppColors.textLight)),
                            Text(
                              physQty == null ? '-' : (diff > 0 ? '+$diff' : '$diff'),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold, 
                                fontSize: 18,
                                color: physQty == null ? AppColors.textDark : (diff == 0 ? AppColors.success : AppColors.danger)
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
