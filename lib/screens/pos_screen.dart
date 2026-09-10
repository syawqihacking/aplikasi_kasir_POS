import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../services/scanner_service.dart';
import '../services/cart_service.dart';
import '../services/shift_service.dart';
import '../models/shift.dart';
import '../main.dart';
import 'shift/widgets/open_shift_card.dart';
import 'shift/dialogs/cash_movement_dialog.dart';
import 'shift/dialogs/close_shift_dialog.dart';
import 'widgets/add_product_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<Map<String, dynamic>> _catalogProducts = [];
  final CartService _cart = CartService.instance;
  final FocusNode _searchFocusNode = FocusNode();

  double _taxPercentage = 0.10; // Default 10%
  bool _allowMinusStock = false;
  String _selectedPaymentMethod = 'Cash';
  double _discountTotal = 0.0;
  String _storeName = 'Store Name';
  String _storeAddress = 'Alamat Toko';
  String _storePhone = '-';
  String _storeNib = '-';
  
  bool _isLoadingShift = true;
  bool _isShiftOpened = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _loadSettings();

    // Register POS as the active scan context
    ScannerService.instance.pushContext(ScanContext(
      id: 'pos_screen',
      mode: ScanContextMode.sale,
      handler: _handleBarcodeScanned,
    ));

    // Listen for cart changes to trigger re-render
    _cart.notifier.addListener(_onCartChanged);
    ShiftService.instance.activeShiftNotifier.addListener(_onActiveShiftChanged);
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  void _onActiveShiftChanged() {
    if (mounted) {
      setState(() {
        _isShiftOpened = ShiftService.instance.hasActiveShift;
      });
    }
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getSettings();
    final activeShift = await ShiftService.instance.refreshActiveShift();
    
    // Load draft
    if (_cart.items.isEmpty) {
      await _cart.loadDraft();
    }
    
    if (mounted) {
      setState(() {
        _isShiftOpened = activeShift != null;
        _isLoadingShift = false;
        
        if (settings.containsKey('tax_percentage')) {
          final taxStr = settings['tax_percentage'];
          if (taxStr != null) {
            _taxPercentage = (double.tryParse(taxStr) ?? 11.0) / 100.0;
          }
        }
        if (settings.containsKey('allow_minus_stock')) {
          _allowMinusStock = settings['allow_minus_stock'] == '1' || settings['allow_minus_stock'] == 'true';
        }
        if (settings.containsKey('store_name')) {
          _storeName = settings['store_name']!;
        }
        if (settings.containsKey('store_address')) {
          _storeAddress = settings['store_address']!;
        }
        if (settings.containsKey('store_phone')) {
          _storePhone = settings['store_phone']!;
        }
        if (settings.containsKey('store_nib')) {
          _storeNib = settings['store_nib']!;
        }
      });
    }
  }

  @override
  void dispose() {
    ScannerService.instance.popContext('pos_screen');
    _cart.notifier.removeListener(_onCartChanged);
    ShiftService.instance.activeShiftNotifier.removeListener(_onActiveShiftChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _catalogProducts = products;
    });
  }

  Future<void> _searchCatalog(String query) async {
    final products = await DatabaseHelper.instance.searchProducts(query);
    setState(() {
      _catalogProducts = products;
    });
  }

  void _addToCartWithCheck(Map<String, dynamic> product) {
    if (!_allowMinusStock) {
      int currentQty = _cart.getQty(product['id']);
      if (currentQty + 1 > (product['current_stock'] ?? 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stok tidak mencukupi (Tersedia: ${product['current_stock']})'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }
    }
    _cart.addToCart(product);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product['name']} added to cart!'),
          backgroundColor: AppColors.success,
          duration: const Duration(milliseconds: 1000),
        ),
      );
    }
  }

  void _handleBarcodeScanned(String barcode) async {
    // 1. Search DB for exact barcode match
    final products = await DatabaseHelper.instance.searchProducts(barcode);
    if (products.isNotEmpty) {
      // 2. Add the first match to cart
      final product = products.first;
      _addToCartWithCheck(product);
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Barcode Tidak Dikenal'),
          content: Text('Produk dengan barcode $barcode tidak ditemukan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (context) => AddProductDialog(
                    initialBarcode: barcode,
                    onProductAdded: _loadCatalog,
                  ),
                );
              },
              child: const Text('Daftarkan Barcode'),
            )
          ],
        ),
      );
    }
  }

  // --- Calculations ---
  double get _subtotal => _cart.subtotal();
  double get _tax => (_subtotal - _discountTotal) * _taxPercentage;
  double get _grandTotal => (_subtotal - _discountTotal) + _tax;

  @override
  Widget build(BuildContext context) {
    if (_isLoadingShift) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isShiftOpened) {
      return Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock_outlined, size: 54, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                'Shift Kasir Belum Dibuka',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Buka shift kasir terlebih dahulu untuk mulai melayani transaksi penjualan dan mencatat uang kas secara akurat.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (ModalRoute.of(context)?.isCurrent != true) return;
                    final res = await OpenShiftCard.show(context);
                    if (res == true) {
                      await ShiftService.instance.refreshActiveShift();
                      if (mounted) setState(() => _isShiftOpened = true);
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  label: Text(
                    'Buka Shift Sekarang',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    mainLayoutTabNotifier.value = 13; // Navigate to Shift tab
                  },
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text(
                    'Ke Halaman Manajemen Shift',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f1) {
            if (_cart.items.isNotEmpty) _showPaymentDialog();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.f2) {
            _searchFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.f3) {
            _cart.clear();
            setState(() {
              _discountTotal = 0;
            });
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.f4 ||
              (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyZ)) {
            if (_cart.undo()) {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tindakan terakhir dibatalkan (Undo)'),
                  backgroundColor: AppColors.success,
                  duration: Duration(milliseconds: 1000),
                ),
              );
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Left side: Product Catalog
          Expanded(
            flex: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<CashShift?>(
                  valueListenable: ShiftService.instance.activeShiftNotifier,
                  builder: (context, activeShift, _) {
                    if (activeShift != null) {
                      return _buildShiftBar(activeShift);
                    }
                    return const SizedBox.shrink();
                  },
                ),
                _buildSearchBar(),
                const SizedBox(height: 16),
                Text('Fast Items / Terlaris', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textLight)),
                const SizedBox(height: 8),
                _buildFastButtons(),
                const SizedBox(height: 16),
                _buildCategories(),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _catalogProducts.length,
                    itemBuilder: (context, index) {
                      return _buildProductCard(_catalogProducts[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right side: Shopping Cart
          Expanded(
            flex: 7,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildCartHeader(),
                  Expanded(
                    child: _cart.items.isEmpty
                      ? Center(
                          child: Text(
                            'Cart is empty.\nScan or add products.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(color: AppColors.textLight),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _cart.items.length,
                          itemBuilder: (context, index) {
                            return _buildCartItem(index, _cart.items[index]);
                          },
                        ),
                  ),
                  _buildCartSummary(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textLight),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              focusNode: _searchFocusNode,
              onChanged: (val) => _searchCatalog(val),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search product manually (Scanner works anywhere)...',
                hintStyle: GoogleFonts.outfit(color: AppColors.textLight),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
          )
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final categories = ['All', 'Food', 'Beverages', 'Electronics', 'Clothing'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == 0;
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: isSelected ? null : Border.all(color: Colors.grey.shade200),
            ),
            alignment: Alignment.center,
            child: Text(
              categories[index],
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFastButtons() {
    // For demo purposes, let's take the first 4 products as "Fast Items"
    final fastItems = _catalogProducts.take(4).toList();
    if (fastItems.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: fastItems.length,
        itemBuilder: (context, index) {
          final p = fastItems[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _addToCartWithCheck(p),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'].toString().length > 12 ? '${p['name'].toString().substring(0, 10)}..' : p['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Rp ${p['price'] ?? p['sell_price']}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () => _addToCartWithCheck(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? '-',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product['category_name'] ?? 'No Category',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rp ${product['sell_price'].toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCartHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Order',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${_cart.items.length} items',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_cart.heldTransactions.isNotEmpty) ...[
                InkWell(
                  onTap: () {
                    if (ModalRoute.of(context)?.isCurrent == true) {
                      _showHeldTransactionsDialog();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.list_alt, color: AppColors.primary, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (_cart.items.isNotEmpty) ...[
                InkWell(
                  onTap: _showHoldTransactionDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pause_circle_outline, color: AppColors.primary, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (_cart.canUndo) ...[
                InkWell(
                  onTap: () {
                    if (_cart.undo()) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tindakan terakhir dibatalkan (Undo)'),
                          backgroundColor: AppColors.success,
                          duration: Duration(milliseconds: 1000),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.undo, color: Colors.orange, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: () {
                  _cart.clear();
                  setState(() {
                    _discountTotal = 0;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_sweep, color: AppColors.danger, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateCartQtyWithCheck(int index, int delta) {
    if (delta > 0 && !_allowMinusStock) {
      final product = _cart.items[index];
      if (product['qty'] + delta > (product['current_stock'] ?? 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stok tidak mencukupi (Tersedia: ${product['current_stock']})'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }
    _cart.updateQty(index, delta);
  }

  Widget _buildCartItem(int index, Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? '-',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Rp ${item['sell_price'].toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildQtyButton(Icons.remove, () => _updateCartQtyWithCheck(index, -1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('${item['qty']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
              _buildQtyButton(Icons.add, () => _updateCartQtyWithCheck(index, 1)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.textDark),
      ),
    );
  }

  Widget _buildCartSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', 'Rp ${_subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showDiscountDialog,
            child: _buildSummaryRow('Discount', '- Rp ${_discountTotal.toStringAsFixed(0)}', isDiscount: true, showEditIcon: true),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow('Tax (${(_taxPercentage * 100).toStringAsFixed(0)}%)', 'Rp ${_tax.toStringAsFixed(0)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'Rp ${_grandTotal.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildPaymentMethod('Cash', Icons.money)),
              const SizedBox(width: 8),
              Expanded(child: _buildPaymentMethod('QRIS', Icons.qr_code)),
              const SizedBox(width: 8),
              Expanded(child: _buildPaymentMethod('Transfer', Icons.account_balance)),
              const SizedBox(width: 8),
              Expanded(child: _buildPaymentMethod('Split', Icons.call_split)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _cart.items.isEmpty ? null : _showPaymentDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              child: Text(
                'Pay Now (F1)',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showHoldTransactionDialog() {
    String holdName = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hold Transaction'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Customer Name / Reference'),
          onChanged: (val) => holdName = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (holdName.isEmpty) holdName = 'Customer ${_cart.heldTransactions.length + 1}';
              _cart.holdTransaction(holdName, _discountTotal);
              setState(() {
                _discountTotal = 0;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Hold'),
          )
        ],
      )
    );
  }

  void _showHeldTransactionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Held Transactions'),
        content: SizedBox(
          width: 400,
          child: _cart.heldTransactions.isEmpty 
              ? const Text('No held transactions.') 
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _cart.heldTransactions.length,
                  itemBuilder: (context, index) {
                    final t = _cart.heldTransactions[index];
                    return ListTile(
                      title: Text(t['name']),
                      subtitle: Text('${t['items'].length} items - ${t['time'].toString().split('.')[0]}'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          final resumed = _cart.resumeTransaction(t['id']);
                          if (resumed != null) {
                            setState(() {
                              _discountTotal = resumed['discountTotal'];
                            });
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text('Resume'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      )
    );
  }

  void _showDiscountDialog() {
    double tempDiscount = _discountTotal;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Discount'),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Discount Nominal (Rp)'),
            onChanged: (val) {
              tempDiscount = double.tryParse(val) ?? 0.0;
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _discountTotal = tempDiscount;
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            )
          ],
        );
      },
    );
  }

  void _showPaymentDialog() {
    double paidAmount = _selectedPaymentMethod == 'Cash' ? 0.0 : _grandTotal;
    String splitMethod1 = 'Cash';
    String splitMethod2 = 'Transfer';
    double splitAmount1 = 0.0;
    double splitAmount2 = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (_selectedPaymentMethod == 'Split') {
              paidAmount = splitAmount1 + splitAmount2;
            }
            final changeAmount = paidAmount - _grandTotal;
            final isSufficient = paidAmount >= _grandTotal;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Payment',
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Bill:', style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 16)),
                        Text('Rp ${_grandTotal.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedPaymentMethod == 'Split') ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: splitMethod1,
                              isExpanded: true,
                              items: ['Cash', 'Transfer', 'QRIS'].map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => splitMethod1 = val);
                              },
                              decoration: InputDecoration(labelText: 'Method 1', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Amount 1 (Rp)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              onChanged: (val) {
                                setDialogState(() {
                                  splitAmount1 = double.tryParse(val) ?? 0.0;
                                  paidAmount = splitAmount1 + splitAmount2;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: splitMethod2,
                              isExpanded: true,
                              items: ['Cash', 'Transfer', 'QRIS'].map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => splitMethod2 = val);
                              },
                              decoration: InputDecoration(labelText: 'Method 2', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Amount 2 (Rp)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              onChanged: (val) {
                                setDialogState(() {
                                  splitAmount2 = double.tryParse(val) ?? 0.0;
                                  paidAmount = splitAmount1 + splitAmount2;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else if (_selectedPaymentMethod == 'Cash')
                      TextField(
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount Paid (Rp)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.money),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            paidAmount = double.tryParse(value) ?? 0.0;
                          });
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Awaiting $_selectedPaymentMethod payment...',
                          style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Change:', style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 16)),
                        Text(
                          changeAmount > 0 ? 'Rp ${changeAmount.toStringAsFixed(0)}' : 'Rp 0',
                          style: GoogleFonts.outfit(
                            color: changeAmount >= 0 ? AppColors.success : AppColors.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
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
                            onPressed: isSufficient ? () async {
                              Navigator.pop(context); // Close dialog
                              String finalMethod = _selectedPaymentMethod == 'Split' 
                                ? 'Split ($splitMethod1: ${splitAmount1.toStringAsFixed(0)}, $splitMethod2: ${splitAmount2.toStringAsFixed(0)})'
                                : _selectedPaymentMethod;
                              await _processTransaction(paidAmount, changeAmount, finalMethod);
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Confirm', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildShiftBar(CashShift shift) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: AppColors.success, size: 8),
                const SizedBox(width: 6),
                Text(
                  shift.shiftNumber,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Kasir: ${shift.cashierName ?? 'Kasir'}',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(width: 16),
          Container(height: 16, width: 1, color: Colors.grey.shade300),
          const SizedBox(width: 16),
          Text(
            'Kas di Laci: ',
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
          ),
          Text(
            currencyFormat.format(shift.expectedCash),
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          // Quick actions
          TextButton.icon(
            onPressed: () async {
              final res = await CashMovementDialog.show(context, shift: shift, initialType: 'IN');
              if (res == true) ShiftService.instance.refreshActiveShift();
            },
            icon: const Icon(Icons.south_west_rounded, size: 15, color: AppColors.success),
            label: Text('Cash In', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.success.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () async {
              final res = await CashMovementDialog.show(context, shift: shift, initialType: 'OUT');
              if (res == true) ShiftService.instance.refreshActiveShift();
            },
            icon: const Icon(Icons.north_east_rounded, size: 15, color: Color(0xFFE53935)),
            label: Text('Cash Out', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFE53935))),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () async {
              final res = await CloseShiftDialog.show(context, shift: shift);
              if (res == true) {
                ShiftService.instance.refreshActiveShift();
              }
            },
            icon: const Icon(Icons.lock_clock_outlined, size: 15, color: AppColors.textDark),
            label: Text('Tutup Shift', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _processTransaction(double paidAmount, double changeAmount, String finalMethod) async {
    try {
      final invoiceNo = await DatabaseHelper.instance.saveTransaction(
        subtotal: _subtotal,
        tax: _tax,
        grandTotal: _grandTotal,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
        paymentMethod: finalMethod,
        cartItems: _cart.items,
      );

      // Refresh active shift summary to reflect latest sales immediately
      ShiftService.instance.refreshActiveShift();

      if (mounted) {
        final activeShift = ShiftService.instance.activeShiftNotifier.value;
        final cashierName = activeShift?.cashierName ?? 'Admin';
        
        _showReceiptDialog(
          invoiceNo: invoiceNo,
          cashierName: cashierName,
          subtotal: _subtotal,
          discount: _discountTotal,
          tax: _tax,
          grandTotal: _grandTotal,
          paidAmount: paidAmount,
          changeAmount: changeAmount,
          paymentMethod: finalMethod,
          items: List.from(_cart.items),
        );
        _cart.clear();
        _cart.clearHistory();
        setState(() {
          _discountTotal = 0;
          _selectedPaymentMethod = 'Cash';
        });
        _loadCatalog(); // Refresh catalog to update stock numbers
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<Uint8List> _generateReceiptPdf(
    PdfPageFormat format, {
    required String invoiceNo,
    required String cashierName,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    required double paidAmount,
    required double changeAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateTime.now().toString().split('.')[0];

    Uint8List? logoBytes;
    try {
      final byteData = await rootBundle.load('assets/logo/Minimalist Red Shopping Cart Logo.png');
      logoBytes = byteData.buffer.asUint8List();
    } catch (_) {}

    // Use built-in Courier font (monospaced, receipt-like appearance)
    final receiptFont = pw.Font.courier();

    // Use a very large height so content is never cut off on roll paper.
    // Reduced margins for maximum printable area on 58mm paper.
    final receiptFormat = PdfPageFormat(
      58 * PdfPageFormat.mm,
      300 * PdfPageFormat.mm,
      marginLeft: 2 * PdfPageFormat.mm,
      marginRight: 2 * PdfPageFormat.mm,
      marginTop: 2 * PdfPageFormat.mm,
      marginBottom: 2 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: receiptFormat,
        theme: pw.ThemeData.withFont(base: receiptFont, bold: receiptFont),
        build: (pw.Context context) {
          int totalQty = items.fold(0, (sum, item) => sum + (item['qty'] as int));
          final dateOnly = dateStr.split(' ')[0];
          final timeOnly = dateStr.split(' ')[1];
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoBytes != null) ...[
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    width: 120,
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
              pw.Center(child: pw.Text(_storeName, style: pw.TextStyle(font: receiptFont, fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text(_storeAddress, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: receiptFont, fontSize: 10))),
              pw.Center(child: pw.Text(_storePhone, style: pw.TextStyle(font: receiptFont, fontSize: 10))),
              pw.Center(child: pw.Text(_storeNib, style: pw.TextStyle(font: receiptFont, fontSize: 10))),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(dateOnly, style: pw.TextStyle(font: receiptFont, fontSize: 10)),
                      pw.Text(timeOnly, style: pw.TextStyle(font: receiptFont, fontSize: 10)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("kasir", style: pw.TextStyle(font: receiptFont, fontSize: 10)),
                      pw.Text(cashierName, style: pw.TextStyle(font: receiptFont, fontSize: 10)),
                    ]
                  )
                ]
              ),
              pw.SizedBox(height: 4),
              pw.Text(invoiceNo, style: pw.TextStyle(font: receiptFont, fontSize: 10)),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              ...items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('$idx. ${item['name']}', style: pw.TextStyle(font: receiptFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('  ${item['qty']} x Rp${_formatNumber(item['sell_price'])}', style: pw.TextStyle(font: receiptFont, fontSize: 10)),
                          pw.Text('Rp${_formatNumber(item['qty'] * item['sell_price'])}', style: pw.TextStyle(font: receiptFont, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              pw.Text('Total QTY : $totalQty', style: pw.TextStyle(font: receiptFont, fontSize: 10)),
              pw.SizedBox(height: 4),
              _buildReceiptRow('Sub Total', 'Rp${_formatNumber(subtotal)}', receiptFont),
              if (discount > 0) _buildReceiptRow('Discount', '-Rp${_formatNumber(discount)}', receiptFont),
              _buildReceiptRow('Tax', 'Rp${_formatNumber(tax)}', receiptFont),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total', style: pw.TextStyle(font: receiptFont, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text('Rp${_formatNumber(grandTotal)}', style: pw.TextStyle(font: receiptFont, fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.SizedBox(height: 2),
              _buildReceiptRow('Bayar ($paymentMethod)', 'Rp${_formatNumber(paidAmount)}', receiptFont),
              _buildReceiptRow('Kembali', 'Rp${_formatNumber(changeAmount)}', receiptFont),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text('Terimakasih Telah Berbelanja', style: pw.TextStyle(font: receiptFont, fontSize: 10))),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Link Kritik dan Saran:', style: pw.TextStyle(font: receiptFont, fontSize: 9))),
              pw.Center(child: pw.Text('kasir.com/e-receipt/S-00D39U', style: pw.TextStyle(font: receiptFont, fontSize: 9))),
              pw.SizedBox(height: 4),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }


  pw.Widget _buildReceiptRow(String label, String value, [pw.Font? font]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10), maxLines: 1),
          ),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }


  String _formatNumber(dynamic number) {
    final n = (number is int) ? number.toDouble() : (number as double);
    final str = n.toStringAsFixed(0);
    final result = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (str[i] == '-') { result.write(str[i]); break; }
      if (count > 0 && count % 3 == 0) result.write('.');
      result.write(str[i]);
      count++;
    }
    return result.toString().split('').reversed.join('');
  }

  /// Build ESC/POS raw bytes for thermal receipt printer.
  Uint8List _buildEscPosReceipt({
    required List<int> logoBytes,
    required String invoiceNo,
    required String cashierName,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    required double paidAmount,
    required double changeAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) {
    final bytes = <int>[];
    


    final dateStr = DateTime.now().toString().split('.')[0];
    const lf = 0x0A;
    const int colW = 32;

    // Initialize printer (reset all settings)
    bytes.addAll([0x1B, 0x40]);

    // Insert logo if available
    if (logoBytes.isNotEmpty) {
      bytes.addAll(logoBytes);
      bytes.addAll([0x0A]); // line feed after logo
    }

    // Format Data
    final dateOnly = dateStr.split(' ')[0];
    final timeOnly = dateStr.split(' ')[1];

    // ---- Header: Store Name (center + bold) ----
    if (_storeName.trim().isNotEmpty) {
      bytes.addAll([0x1B, 0x61, 0x01]); // center
      bytes.addAll([0x1B, 0x45, 0x01]); // bold ON
      bytes.addAll(_encode(_storeName));
      bytes.add(lf);
      bytes.addAll([0x1B, 0x45, 0x00]); // bold OFF
    }

    // ---- Address (center) ----
    bytes.addAll([0x1B, 0x61, 0x01]); // center
    final addrLines = _storeAddress.split('\n');
    for (var line in addrLines) {
      if (line.trim().isNotEmpty) {
        bytes.addAll(_encode(line));
        bytes.add(lf);
      }
    }
    bytes.addAll(_encode(_storePhone));
    bytes.add(lf);
    bytes.addAll(_encode(_storeNib));
    bytes.add(lf);

    // ---- Left align for body ----
    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll(_encode('--------------------------------'));
    bytes.add(lf);

    // Info: Date/Time (left), Cashier (right)
    bytes.addAll(_encode(_pad(dateOnly, "kasir", colW)));
    bytes.add(lf);
    bytes.addAll(_encode(_pad(timeOnly, cashierName, colW)));
    bytes.add(lf);
    bytes.add(lf);
    bytes.addAll(_encode(invoiceNo));
    bytes.add(lf);

    bytes.addAll(_encode('--------------------------------'));
    bytes.add(lf);

    // ---- Items ----
    int totalQty = 0;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final name = '${item['name']}';
      final qty = item['qty'] as int;
      final price = item['sell_price'];
      final total = qty * price;
      totalQty += qty;

      // Item name (bold)
      bytes.addAll([0x1B, 0x45, 0x01]);
      bytes.addAll(_encode('${i + 1}. $name'));
      bytes.add(lf);
      bytes.addAll([0x1B, 0x45, 0x00]);

      // Qty x price ... subtotal (right-aligned using tab or padding)
      final leftPart = '  $qty x ${_fmtK(price)}';
      final rightPart = _fmtK(total);
      bytes.addAll(_encode(_pad(leftPart, rightPart, colW)));
      bytes.add(lf);
    }

    bytes.addAll(_encode('--------------------------------'));
    bytes.add(lf);
    
    // Total QTY
    bytes.addAll(_encode('Total QTY : $totalQty'));
    bytes.add(lf);
    bytes.add(lf);

    // ---- Summary ----
    bytes.addAll(_encode(_pad('Sub Total', _fmtK(subtotal), colW)));
    bytes.add(lf);
    if (discount > 0) {
      bytes.addAll(_encode(_pad('Diskon', '-${_fmtK(discount)}', colW)));
      bytes.add(lf);
    }
    bytes.addAll(_encode(_pad('Tax', _fmtK(tax), colW)));
    bytes.add(lf);

    // ---- TOTAL (bold) ----
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll(_encode(_pad('Total', _fmtK(grandTotal), colW)));
    bytes.add(lf);
    bytes.addAll([0x1B, 0x45, 0x00]);

    // Payment info
    bytes.addAll(_encode(_pad('Bayar ($paymentMethod)', _fmtK(paidAmount), colW)));
    bytes.add(lf);
    bytes.addAll(_encode(_pad('Kembali', _fmtK(changeAmount), colW)));
    bytes.add(lf);
    bytes.add(lf);

    // ---- Footer ----
    bytes.addAll([0x1B, 0x61, 0x01]); // center
    bytes.addAll(_encode('Terimakasih Telah Berbelanja'));
    bytes.add(lf);
    bytes.add(lf);
    bytes.addAll(_encode('Link Kritik dan Saran:'));
    bytes.add(lf);
    bytes.addAll(_encode('kasir.com/e-receipt/S-00D39U'));
    bytes.add(lf);
    bytes.add(lf);
    bytes.add(lf);

    // Partial cut
    bytes.addAll([0x1D, 0x56, 0x01]);

    return Uint8List.fromList(bytes);
  }

  List<int> _encode(String text) => text.codeUnits.map((c) => c > 127 ? 0x3F : c).toList();

  String _pad(String left, String right, int w) {
    final gap = w - left.length - right.length;
    if (gap > 0) {
      return '$left${' ' * gap}$right';
    } else if (gap == 0) {
      return '$left$right';
    } else {
      final maxLeft = w - right.length - 1;
      if (maxLeft > 0 && left.length > maxLeft) {
        return '${left.substring(0, maxLeft)} $right';
      }
      return '$left $right'.substring(0, w); // Force strict width
    }
  }

  /// Compact Rp formatter for receipt (e.g. "Rp7.000")
  String _fmtK(dynamic n) => 'Rp${_formatNumber(n)}';


  /// Send raw bytes to Windows printer via winspool.drv API (PowerShell).
  Future<bool> _sendRawToWindowsPrinter(String printerName, Uint8List data) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp('receipt_');
      final tempFile = File('${tempDir.path}\\receipt.bin');
      await tempFile.writeAsBytes(data);
      final escapedPath = tempFile.path.replaceAll('\\', '\\\\');

      final result = await Process.run('powershell', [
        '-NoProfile', '-Command',
        '''
Add-Type -TypeDefinition @"
using System; using System.IO; using System.Runtime.InteropServices;
public class RawPrint {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
  public class DOCINFOA { [MarshalAs(UnmanagedType.LPStr)] public string pDocName; [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile; [MarshalAs(UnmanagedType.LPStr)] public string pDataType; }
  [DllImport("winspool.drv", EntryPoint="OpenPrinterA", SetLastError=true, CharSet=CharSet.Ansi)]
  public static extern bool OpenPrinter(string p, out IntPtr hP, IntPtr pd);
  [DllImport("winspool.drv", EntryPoint="ClosePrinter", SetLastError=true)]
  public static extern bool ClosePrinter(IntPtr hP);
  [DllImport("winspool.drv", EntryPoint="StartDocPrinterA", SetLastError=true, CharSet=CharSet.Ansi)]
  public static extern bool StartDocPrinter(IntPtr hP, int l, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
  [DllImport("winspool.drv", EntryPoint="EndDocPrinter", SetLastError=true)]
  public static extern bool EndDocPrinter(IntPtr hP);
  [DllImport("winspool.drv", EntryPoint="StartPagePrinter", SetLastError=true)]
  public static extern bool StartPagePrinter(IntPtr hP);
  [DllImport("winspool.drv", EntryPoint="EndPagePrinter", SetLastError=true)]
  public static extern bool EndPagePrinter(IntPtr hP);
  [DllImport("winspool.drv", EntryPoint="WritePrinter", SetLastError=true)]
  public static extern bool WritePrinter(IntPtr hP, IntPtr pB, int dwC, out int dwW);
  public static bool Send(string name, byte[] b) {
    IntPtr hP; var di = new DOCINFOA(); di.pDocName = "Receipt"; di.pDataType = "RAW";
    if (!OpenPrinter(name, out hP, IntPtr.Zero)) return false;
    StartDocPrinter(hP, 1, di); StartPagePrinter(hP);
    IntPtr p = Marshal.AllocCoTaskMem(b.Length); Marshal.Copy(b, 0, p, b.Length);
    int w; WritePrinter(hP, p, b.Length, out w); Marshal.FreeCoTaskMem(p);
    EndPagePrinter(hP); EndDocPrinter(hP); ClosePrinter(hP); return true;
  }
}
"@
\$bytes = [System.IO.File]::ReadAllBytes("$escapedPath")
[RawPrint]::Send("$printerName", \$bytes)
'''
      ]);

      try { await tempDir.delete(recursive: true); } catch (_) {}
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Raw printing error: \$e');
      return false;
    }
  }

  Future<void> _printReceipt({
    required String invoiceNo,
    required String cashierName,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    required double paidAmount,
    required double changeAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      final defaultPrinterName = settings['default_printer'];

      // Try ESC/POS raw printing for thermal printers on Windows
      if (defaultPrinterName != null && defaultPrinterName.isNotEmpty && Platform.isWindows) {
        // Load logo for ESC/POS
        List<int> escLogo = [];
        try {
          final bd = await rootBundle.load('assets/logo/Minimalist Red Shopping Cart Logo.png');
          final image = img.decodeImage(bd.buffer.asUint8List());
          if (image != null) {
            final resized = img.copyResize(image, width: 350);
            final wBytes = (resized.width + 7) ~/ 8;
            
            int minY = resized.height;
            int maxY = -1;
            for (int y = 0; y < resized.height; y++) {
              bool hasBlack = false;
              for (int x = 0; x < resized.width; x++) {
                final p = resized.getPixel(x, y);
                if (p.a > 127 && (p.r * 0.299 + p.g * 0.587 + p.b * 0.114) < 128) {
                  hasBlack = true;
                  break;
                }
              }
              if (hasBlack) {
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
              }
            }
            
            if (maxY >= minY) {
              final h = maxY - minY + 1;
              escLogo.addAll([0x1B, 0x61, 0x01]); // Center
              escLogo.addAll([0x1D, 0x76, 0x30, 0x00, wBytes % 256, wBytes ~/ 256, h % 256, h ~/ 256]);
              for (int y = minY; y <= maxY; y++) {
                for (int xb = 0; xb < wBytes; xb++) {
                  int b = 0;
                  for (int bit = 0; bit < 8; bit++) {
                    int x = xb * 8 + bit;
                    if (x < resized.width) {
                      final p = resized.getPixel(x, y);
                      if (p.a > 127) {
                        if ((p.r * 0.299 + p.g * 0.587 + p.b * 0.114) < 128) {
                          b |= (1 << (7 - bit));
                        }
                      }
                    }
                  }
                  escLogo.add(b);
                }
              }
            }
          }
        } catch (_) {}

        final escBytes = _buildEscPosReceipt(
          logoBytes: escLogo,
          invoiceNo: invoiceNo,
          cashierName: cashierName,
          subtotal: subtotal, discount: discount, tax: tax,
          grandTotal: grandTotal, paidAmount: paidAmount,
          changeAmount: changeAmount, paymentMethod: paymentMethod,
          items: items,
        );
        final success = await _sendRawToWindowsPrinter(defaultPrinterName, escBytes);
        if (success) return;
        debugPrint('Raw ESC/POS failed, falling back to PDF...');
      }

      // Fallback: PDF printing
      final pdfBytes = await _generateReceiptPdf(
        PdfPageFormat.roll57,
        invoiceNo: invoiceNo,
        cashierName: cashierName,
        subtotal: subtotal, discount: discount, tax: tax,
        grandTotal: grandTotal, paidAmount: paidAmount,
        changeAmount: changeAmount, paymentMethod: paymentMethod,
        items: items,
      );

      if (defaultPrinterName != null && defaultPrinterName.isNotEmpty) {
        final printers = await Printing.listPrinters();
        final targetPrinter = printers.firstWhere(
          (p) => p.name == defaultPrinterName,
          orElse: () => printers.first,
        );
        await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (format) async => pdfBytes,
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Receipt_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      debugPrint('Printing failed: $e');
    }
  }

  void _showReceiptDialog({
    required String invoiceNo,
    required String cashierName,
    required double subtotal,
    required double discount,
    required double tax,
    required double grandTotal,
    required double paidAmount,
    required double changeAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text('Receipt - $_storeName', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text('Date: ${DateTime.now().toString().split('.')[0]}', style: GoogleFonts.outfit(fontSize: 12))),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${item['qty']}x ${item['name']}', style: GoogleFonts.outfit(fontSize: 14))),
                      Text('Rp ${(item['qty'] * item['sell_price']).toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 14)),
                    ],
                  ),
                )),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Subtotal:', style: GoogleFonts.outfit()), Text('Rp ${subtotal.toStringAsFixed(0)}', style: GoogleFonts.outfit())]),
                if (discount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discount:', style: GoogleFonts.outfit()), Text('-Rp ${discount.toStringAsFixed(0)}', style: GoogleFonts.outfit())]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Tax:', style: GoogleFonts.outfit()), Text('Rp ${tax.toStringAsFixed(0)}', style: GoogleFonts.outfit())]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider()),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)), Text('Rp ${grandTotal.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16))]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider()),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('Paid ($paymentMethod):', style: GoogleFonts.outfit())),
                    const SizedBox(width: 8),
                    Text('Rp ${paidAmount.toStringAsFixed(0)}', style: GoogleFonts.outfit()),
                  ],
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Change:', style: GoogleFonts.outfit()), Text('Rp ${changeAmount.toStringAsFixed(0)}', style: GoogleFonts.outfit())]),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _printReceipt(
                invoiceNo: invoiceNo,
                cashierName: cashierName,
                subtotal: subtotal,
                discount: discount,
                tax: tax,
                grandTotal: grandTotal,
                paidAmount: paidAmount,
                changeAmount: changeAmount,
                paymentMethod: paymentMethod,
                items: items,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Print & Close', style: GoogleFonts.outfit(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false, bool showEditIcon = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(color: AppColors.textLight),
            ),
            if (showEditIcon) ...[
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 14, color: AppColors.textLight),
            ]
          ],
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: isDiscount ? AppColors.danger : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod(String label, IconData icon) {
    bool isSelected = _selectedPaymentMethod == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textLight, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: isSelected ? AppColors.primary : AppColors.textLight,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
