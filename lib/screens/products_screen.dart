import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../repositories/product_repository.dart';
import '../repositories/category_repository.dart';
import '../services/auth_service.dart';
import '../services/import_export_service.dart';
import 'widgets/add_product_dialog.dart';
import 'widgets/print_barcode_dialog.dart';
import '../main.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Active', 'Inactive'
  int? _categoryFilter; // null = all

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    productSearchRequest.addListener(_onProductSearchRequest);
    _loadData();
  }

  @override
  void dispose() {
    productSearchRequest.removeListener(_onProductSearchRequest);
    _searchController.dispose();
    super.dispose();
  }

  /// Merespons permintaan fokus produk dari notifikasi. Mengonsumsi request
  /// (reset ke null) supaya tidak ter-apply ulang pada rebuild berikutnya.
  void _onProductSearchRequest() {
    final request = productSearchRequest.value;
    if (request == null || request.isEmpty) return;
    productSearchRequest.value = null; // consume
    if (!mounted) return;
    setState(() {
      _searchQuery = request;
      _searchController.text = request;
    });
    _applyFilters();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final products = await ProductRepository.instance.getAllProductsIncludingInactive();
    final categories = await CategoryRepository.instance.getAll();
    setState(() {
      _allProducts = products;
      _categories = categories;
      _isLoading = false;
    });
    _applyFilters();
    // Terapkan request fokus produk yang tiba sebelum data selesai dimuat.
    final pending = productSearchRequest.value;
    if (pending != null && pending.isNotEmpty) {
      productSearchRequest.value = null; // consume
      if (mounted) {
        setState(() {
          _searchQuery = pending;
          _searchController.text = pending;
        });
        _applyFilters();
      }
    }
  }

  void _applyFilters() {
    List<Product> result = List.from(_allProducts);

    // Status filter
    if (_statusFilter == 'Active') {
      result = result.where((p) => p.isActive).toList();
    } else if (_statusFilter == 'Inactive') {
      result = result.where((p) => !p.isActive).toList();
    }

    // Category filter
    if (_categoryFilter != null) {
      result = result.where((p) => p.categoryId == _categoryFilter).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(q) ||
            (p.barcode?.toLowerCase().contains(q) ?? false) ||
            (p.sku?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    setState(() => _filteredProducts = result);
  }

  void _showAddProductDialog([Product? product]) {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        existingProduct: product?.toMap(),
        onProductAdded: _loadData,
      ),
    );
  }

  void _confirmSoftDelete(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Produk'),
        content: Text('Yakin ingin menonaktifkan "${product.name}"?\nProduk tidak akan muncul di halaman POS.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await ProductRepository.instance.softDelete(product.id!);
              final userId = AuthService().currentUser?['id'] ?? 1;
              await DatabaseHelper.instance.logActivity('DELETE', 'products', 'Nonaktifkan produk: ${product.name}', userId: userId);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${product.name}" berhasil dinonaktifkan.'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Nonaktifkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Yakin ingin menghapus "${product.name}" secara permanen?\nRiwayat transaksi/stok akan tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ProductRepository.instance.delete(product.id!);
                final userId = AuthService().currentUser?['id'] ?? 1;
                await DatabaseHelper.instance.logActivity('DELETE', 'products', 'Hapus produk: ${product.name}', userId: userId);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Produk berhasil dihapus.'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmReactivate(Product product) async {
    await ProductRepository.instance.reactivate(product.id!);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${product.name}" berhasil diaktifkan kembali.'), backgroundColor: AppColors.success),
      );
    }
  }

  void _showPriceHistory(Product product) async {
    final history = await ProductRepository.instance.getPriceHistory(product.id!);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Price History — ${product.name}'),
        content: SizedBox(
          width: 500,
          child: history.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text('No price changes recorded yet.'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (_, i) {
                    final h = history[i];
                    return ListTile(
                      leading: const Icon(Icons.history, color: AppColors.primary),
                      title: Text(
                        '${_currencyFormat.format(h['old_price'])} → ${_currencyFormat.format(h['new_price'])}',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${h['changed_at'].toString().substring(0, 16).replaceAll('T', ' ')} by ${h['changed_by_name'] ?? 'Admin'}',
                        style: GoogleFonts.outfit(fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _handleProductImportExport(String action) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    try {
      if (action == 'export') {
        final dir = await getDownloadsDirectory();
        if (dir == null) throw Exception('Downloads directory not found');
        final path = '${dir.path}/Produk_Export_$timestamp.xlsx';
        await ImportExportService.exportProducts(path);
        final userId = AuthService().currentUser?['id'] ?? 1;
        await DatabaseHelper.instance.logActivity('EXPORT', 'products', 'Export data produk ke Excel', userId: userId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil diekspor ke: $path'), backgroundColor: AppColors.success));
      } else if (action == 'template') {
        final dir = await getDownloadsDirectory();
        if (dir == null) throw Exception('Downloads directory not found');
        final path = '${dir.path}/Template_Produk.xlsx';
        await ImportExportService.downloadProductTemplate(path);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Template tersimpan di: $path'), backgroundColor: AppColors.success));
      } else if (action == 'import') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls'],
        );
        if (result != null && result.files.single.path != null) {
          final importResult = await ImportExportService.importProducts(result.files.single.path!);
          final userId = AuthService().currentUser?['id'] ?? 1;
          await DatabaseHelper.instance.logActivity('IMPORT', 'products', 'Import ${importResult.success} produk dari Excel', userId: userId);
          _loadData();
          if (mounted) {
            _showImportResultDialog(importResult);
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    }
  }

  void _showImportResultDialog(ImportResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(result.hasErrors ? Icons.warning_amber : Icons.check_circle, color: result.hasErrors ? AppColors.warning : AppColors.success),
            const SizedBox(width: 8),
            const Text('Hasil Import'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ Berhasil diimport: ${result.success} data', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (result.hasErrors) ...[
                const SizedBox(height: 12),
                Text('⚠️ ${result.errors.length} error ditemukan:', style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: result.errors.length,
                      itemBuilder: (context, index) {
                        final e = result.errors[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $e', style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
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
                'Products Management',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Row(
                children: [
                  PopupMenuButton<String>(
                    onSelected: _handleProductImportExport,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.file_download, size: 18), SizedBox(width: 8), Text('Export Produk (.xlsx)')])),
                      const PopupMenuItem(value: 'template', child: Row(children: [Icon(Icons.description, size: 18), SizedBox(width: 8), Text('Download Template')])),
                      const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.file_upload, size: 18), SizedBox(width: 8), Text('Import dari Excel')])),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.swap_vert, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('Import / Export', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddProductDialog(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      'Add New Product',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Filters Row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Search
              SizedBox(
                width: 300,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.textLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search by name, SKU, barcode...',
                            hintStyle: GoogleFonts.outfit(color: AppColors.textLight),
                          ),
                          onChanged: (value) {
                            _searchQuery = value;
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Category Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _categoryFilter,
                    hint: Text('All Categories', style: GoogleFonts.outfit()),
                    items: [
                      DropdownMenuItem<int?>(value: null, child: Text('All Categories', style: GoogleFonts.outfit())),
                      ..._categories.map((c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.name, style: GoogleFonts.outfit()),
                          )),
                    ],
                    onChanged: (val) {
                      _categoryFilter = val;
                      _applyFilters();
                    },
                  ),
                ),
              ),
              // Status Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    items: ['All', 'Active', 'Inactive']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.outfit())))
                        .toList(),
                    onChanged: (val) {
                      _statusFilter = val!;
                      _applyFilters();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Results count
          Text(
            '${_filteredProducts.length} products found',
            style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 13),
          ),
          const SizedBox(height: 8),
          // Table
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(0), // Removed padding to let table span fully
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                        ? Center(
                            child: Text('No products found.', style: GoogleFonts.outfit(color: AppColors.textLight)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final p = _filteredProducts[index];
                              final isActive = p.isActive;
                              final isLowStock = p.isLowStock;
                              
                              return Card(
                                color: Colors.white,
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.inventory_2, color: isActive ? AppColors.primary : AppColors.danger),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${p.sku ?? '-'} • ${p.categoryName ?? 'Uncategorized'}',
                                              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Jual: ${_currencyFormat.format(p.sellPrice)}',
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.success),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Beli: ${_currencyFormat.format(p.costPrice)}',
                                              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Stok: ${p.currentStock} ${p.unit ?? ''}',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textDark),
                                                ),
                                                if (isLowStock) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.warning_amber, size: 16, color: AppColors.danger),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isActive ? 'Active' : 'Inactive',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  color: isActive ? AppColors.success : AppColors.danger,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.history, color: AppColors.textLight, size: 20),
                                            tooltip: 'Riwayat Harga',
                                            onPressed: () => _showPriceHistory(p),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.print_outlined, color: Colors.blueGrey, size: 20),
                                            tooltip: 'Print Label',
                                            onPressed: () {
                                              // Always open dialog — it auto-generates barcode if missing
                                              showDialog(
                                                context: context,
                                                builder: (context) => PrintBarcodeDialog(product: p.toMap()),
                                              ).then((_) => _loadData()); // Refresh list to show new barcode
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                            tooltip: 'Edit',
                                            onPressed: () => _showAddProductDialog(p),
                                          ),
                                          if (isActive)
                                            IconButton(
                                              icon: const Icon(Icons.block, color: AppColors.danger, size: 20),
                                              tooltip: 'Nonaktifkan',
                                              onPressed: () => _confirmSoftDelete(p),
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                                              tooltip: 'Aktifkan Kembali',
                                              onPressed: () => _confirmReactivate(p),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                            tooltip: 'Hapus',
                                            onPressed: () => _confirmDeleteProduct(p),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
              ),
            ),
        ],
      ),
    );
  }
}
