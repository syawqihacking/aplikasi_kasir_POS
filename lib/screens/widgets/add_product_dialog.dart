import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/category.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/category_repository.dart';
import '../../services/auth_service.dart';
import '../../services/scanner_service.dart';

class AddProductDialog extends StatefulWidget {
  final VoidCallback onProductAdded;
  final Map<String, dynamic>? existingProduct; // null = add, non-null = edit
  final String? initialBarcode;

  const AddProductDialog({
    super.key,
    required this.onProductAdded,
    this.existingProduct,
    this.initialBarcode,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _unitController = TextEditingController();
  final _rackLocationController = TextEditingController();
  final _photoPathController = TextEditingController();

  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _isSaving = false;
  bool _priceWarning = false;

  bool get _isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    // Register as formField scan context so scans go to barcode field
    ScannerService.instance.pushContext(ScanContext(
      id: 'add_product_dialog',
      mode: ScanContextMode.formField,
      handler: (barcode) {
        if (mounted) {
          setState(() => _barcodeController.text = barcode);
        }
      },
    ));
    
    if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
    }
    
    if (_isEditing) {
      final p = widget.existingProduct!;
      _nameController.text = p['name'] ?? '';
      _skuController.text = p['sku'] ?? '';
      _barcodeController.text = p['barcode'] ?? '';
      _costPriceController.text = (p['cost_price'] ?? 0).toString();
      _sellPriceController.text = (p['sell_price'] ?? 0).toString();
      _stockController.text = (p['current_stock'] ?? 0).toString();
      _minStockController.text = (p['min_stock'] ?? 0).toString();
      _unitController.text = p['unit'] ?? '';
      _rackLocationController.text = p['rack_location'] ?? '';
      _photoPathController.text = p['photo_path'] ?? '';
      _selectedCategoryId = p['category_id'];
    }

    _costPriceController.addListener(_checkPriceWarning);
    _sellPriceController.addListener(_checkPriceWarning);
  }

  void _generateBarcode() {
    // Generate an EAN-13 like internal barcode (Custom prefix e.g., 200 + timestamp)
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(2, 11);
    final prefix = "200";
    final withoutChecksum = prefix + timestamp;
    
    // Calculate EAN-13 Checksum
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(withoutChecksum[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checksum = (10 - (sum % 10)) % 10;
    
    setState(() {
      _barcodeController.text = withoutChecksum + checksum.toString();
    });
  }

  void _checkPriceWarning() {
    final cost = double.tryParse(_costPriceController.text) ?? 0;
    final sell = double.tryParse(_sellPriceController.text) ?? 0;
    setState(() {
      _priceWarning = sell > 0 && cost > 0 && sell < cost;
    });
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryRepository.instance.getAll();
    if (mounted) {
      setState(() => _categories = cats);
    }
  }

  Future<void> _pickPhoto() async {
    // For desktop: simple file path input dialog
    final pathController = TextEditingController(text: _photoPathController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Image Path'),
        content: TextField(
          controller: pathController,
          decoration: const InputDecoration(
            hintText: '/path/to/image.jpg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pathController.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _photoPathController.text = result);
    }
  }

  @override
  void dispose() {
    ScannerService.instance.popContext('add_product_dialog');
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _unitController.dispose();
    _rackLocationController.dispose();
    _photoPathController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // --- Barcode uniqueness check ---
      final barcode = _barcodeController.text.trim();
      if (barcode.isNotEmpty) {
        final existingProduct = await ProductRepository.instance.findByBarcode(
          barcode,
          excludeProductId: _isEditing ? widget.existingProduct!['id'] : null,
        );
        if (existingProduct != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Barcode "$barcode" sudah dipakai oleh produk "${existingProduct.name}". '
                  'Satu barcode hanya bisa untuk 1 produk.',
                ),
                backgroundColor: AppColors.danger,
                duration: const Duration(seconds: 4),
              ),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      final productData = {
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(),
        'barcode': barcode,
        'cost_price': double.tryParse(_costPriceController.text) ?? 0.0,
        'sell_price': double.tryParse(_sellPriceController.text) ?? 0.0,
        'current_stock': int.tryParse(_stockController.text) ?? 0,
        'min_stock': int.tryParse(_minStockController.text) ?? 0,
        'unit': _unitController.text.trim(),
        'rack_location': _rackLocationController.text.trim(),
        'photo_path': _photoPathController.text.trim(),
        'category_id': _selectedCategoryId,
        'is_active': 1,
      };

      if (_isEditing) {
        final oldProduct = widget.existingProduct!;
        final oldPrice = (oldProduct['sell_price'] ?? 0).toDouble();
        final newPrice = productData['sell_price'] as double;

        // Don't overwrite current_stock on edit (stock managed via restock)
        productData.remove('current_stock');

        await ProductRepository.instance.update(oldProduct['id'], productData);
        final userId = AuthService().currentUser?['id'] ?? 1;
        await DatabaseHelper.instance.logActivity('EDIT', 'products', 'Update produk: ${productData['name']}', userId: userId);

        // Log price change if sell_price changed
        if (oldPrice != newPrice) {
          await ProductRepository.instance.logPriceChange(
            productId: oldProduct['id'],
            oldPrice: oldPrice,
            newPrice: newPrice,
            changedBy: userId,
          );
          await DatabaseHelper.instance.logActivity('CHANGE', 'products', 'Ubah harga ${productData['name']}: $oldPrice -> $newPrice', userId: userId);
        }
      } else {
        await ProductRepository.instance.insert(productData);
        final userId = AuthService().currentUser?['id'] ?? 1;
        await DatabaseHelper.instance.logActivity('CREATE', 'products', 'Tambah produk baru: ${productData['name']}', userId: userId);
      }

      widget.onProductAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save product: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 650,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Product' : 'Add New Product',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Scrollable form content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      _buildTextField('Product Name *', _nameController, isRequired: true),
                      const SizedBox(height: 16),

                      // SKU & Barcode
                      Row(
                        children: [
                          Expanded(child: _buildTextField('SKU', _skuController)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(child: _buildTextField('Barcode', _barcodeController)),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: IconButton(
                                    icon: const Icon(Icons.auto_awesome),
                                    color: AppColors.primary,
                                    tooltip: 'Auto Generate Barcode',
                                    onPressed: _generateBarcode,
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Category & Unit
                      Row(
                        children: [
                          Expanded(child: _buildCategoryDropdown()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Unit (e.g. pcs, kg)', _unitController)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cost Price & Sell Price
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Cost Price (Rp)', _costPriceController, isNumber: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTextField('Sell Price (Rp) *', _sellPriceController, isNumber: true, isRequired: true)),
                        ],
                      ),
                      if (_priceWarning) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Warning: Sell price is lower than cost price! You may incur a loss.',
                                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Stock & Min Stock (only show for new product)
                      if (!_isEditing) ...[
                        Row(
                          children: [
                            Expanded(child: _buildTextField('Initial Stock *', _stockController, isNumber: true, isRequired: true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('Min Stock Alert', _minStockController, isNumber: true)),
                          ],
                        ),
                      ] else ...[
                        _buildTextField('Min Stock Alert', _minStockController, isNumber: true),
                      ],
                      const SizedBox(height: 16),

                      // Rack Location
                      _buildTextField('Rack Location (optional)', _rackLocationController),
                      const SizedBox(height: 16),

                      // Photo
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField('Photo Path', _photoPathController),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _pickPhoto,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.background,
                              foregroundColor: AppColors.textDark,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Icon(Icons.folder_open),
                          ),
                        ],
                      ),

                      // Photo Preview
                      if (_photoPathController.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: File(_photoPathController.text).existsSync()
                              ? Image.file(
                                  File(_photoPathController.text),
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
                                )
                              : _buildPhotoPlaceholder(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEditing ? 'Update Product' : 'Save Product',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _selectedCategoryId,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          hint: const Text('Select Category'),
          items: _categories
              .map((c) => DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(c.name),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedCategoryId = value),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false, bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
