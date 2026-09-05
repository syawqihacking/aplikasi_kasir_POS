import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../services/scanner_service.dart';
import '../utils/responsive_utils.dart';

import 'inventory/stock_out_tab.dart';
import 'inventory/stock_opname_tab.dart';
import 'inventory/stock_history_tab.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPhoneScreen = isPhone(context);
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isPhoneScreen ? 16 : 24.0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manajemen Stok',
                  style: GoogleFonts.outfit(
                    fontSize: responsiveFontSize(context, desktop: 28, tablet: 24, phone: 20),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                const TabBar(
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textLight,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Produk & Restock (Masuk)'),
                    Tab(text: 'Barang Keluar'),
                    Tab(text: 'Stock Opname'),
                    Tab(text: 'Riwayat Stok'),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                InventoryRestockTab(),
                StockOutTab(),
                StockOpnameTab(),
                StockHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryRestockTab extends StatefulWidget {
  const InventoryRestockTab({super.key});

  @override
  State<InventoryRestockTab> createState() => _InventoryRestockTabState();
}

class _InventoryRestockTabState extends State<InventoryRestockTab> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    ScannerService.instance.pushContext(ScanContext(
      id: 'InventoryRestockTab_scanner',
      mode: ScanContextMode.inventoryLookup,
      handler: (scannedBarcode) {
        try {
          final product = _products.firstWhere(
            (p) => p['barcode'] == scannedBarcode,
          );
          _showRestockDialog(product);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Produk dengan barcode '$scannedBarcode' tidak ditemukan di database.",
                ),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        }
      },
    ));
  }

  @override
  void dispose() {
    ScannerService.instance.popContext('InventoryRestockTab_scanner');
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await DatabaseHelper.instance.getAllProducts();
      final suppliers = await DatabaseHelper.instance.getAllSuppliers();
      if (mounted) {
        setState(() {
          _products = products;
          _suppliers = suppliers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRestockDialog(Map<String, dynamic> product) {
    int qty = 0;
    double costPrice = (product['cost_price'] as num).toDouble();
    String invoiceNo = '';
    int? selectedSupplierId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restock: ${product['name']}',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    Text('Current Stock: ${product['current_stock']} ${product['unit']}', style: GoogleFonts.outfit(color: AppColors.textLight)),
                    const SizedBox(height: 24),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity (Qty)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (value) => qty = int.tryParse(value) ?? 0,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Cost Price per unit (Rp)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      controller: TextEditingController(text: costPrice.toStringAsFixed(0)),
                      onChanged: (value) => costPrice = double.tryParse(value) ?? costPrice,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Invoice Number (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (value) => invoiceNo = value,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Supplier (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      initialValue: selectedSupplierId,
                      items: _suppliers.map((s) => DropdownMenuItem<int>(
                        value: s['id'] as int,
                        child: Text(s['name']),
                      )).toList(),
                      onChanged: (val) => selectedSupplierId = val,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (qty > 0) {
                                Navigator.pop(context);
                                await _processRestock(product['id'], qty, costPrice, invoiceNo, selectedSupplierId);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Save', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _processRestock(int productId, int qty, double costPrice, String invoiceNo, int? supplierId) async {
    try {
      await DatabaseHelper.instance.restockProduct(productId, qty, costPrice, invoiceNo, supplierId: supplierId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restock successful!'), backgroundColor: AppColors.success),
        );
        _loadProducts(); // Refresh list to get new stock numbers
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restocking: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: responsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                label: Text('Refresh', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: _products.isEmpty
                  ? Center(child: Text('No products in inventory.', style: GoogleFonts.outfit(color: AppColors.textLight)))
                  : ListView.builder(
                      padding: responsiveCardPadding(context),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final currentStock = product['current_stock'] as int;
                        final minStock = product['min_stock'] as int;
                        final isLowStock = currentStock <= minStock;

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isLowStock ? AppColors.danger.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLowStock ? Icons.warning_amber : Icons.inventory_2, 
                                color: isLowStock ? AppColors.danger : AppColors.success,
                              ),
                            ),
                            title: Text(
                              product['name'],
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            subtitle: Text(
                              'SKU: ${product['sku'] ?? '-'} • Cost: Rp ${(product['cost_price'] as num).toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 13),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  margin: const EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                    color: isLowStock ? AppColors.danger.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$currentStock ${product['unit'] ?? ''}',
                                    style: GoogleFonts.outfit(
                                      color: isLowStock ? AppColors.danger : AppColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _showRestockDialog(product),
                                  icon: const Icon(Icons.add_box, size: 16, color: Colors.white),
                                  label: Text('Restock', style: GoogleFonts.outfit(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
