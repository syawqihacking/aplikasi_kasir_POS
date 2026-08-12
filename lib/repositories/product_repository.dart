import '../database/database_helper.dart';
import '../models/product.dart';

class ProductRepository {
  // Singleton for simplicity (no DI framework yet)
  ProductRepository._();
  static final instance = ProductRepository._();

  final _db = DatabaseHelper.instance;

  /// Get all products including inactive, mapped to Product model.
  Future<List<Product>> getAllProductsIncludingInactive() async {
    final rows = await _db.getAllProductsIncludingInactive();
    return rows.map(Product.fromMap).toList();
  }

  /// Get all active products (for POS catalog etc — but don't wire POS yet).
  Future<List<Product>> getAllActiveProducts() async {
    final rows = await _db.getAllProducts();
    return rows.map(Product.fromMap).toList();
  }

  /// Find product by barcode, returns Product or null.
  Future<Product?> findByBarcode(String barcode, {int? excludeProductId}) async {
    final row = await _db.findProductByBarcode(barcode, excludeProductId: excludeProductId);
    return row != null ? Product.fromMap(row) : null;
  }

  /// Insert product from map, returns new product ID.
  Future<int> insert(Map<String, dynamic> productData) async {
    return await _db.insertProduct(productData);
  }

  /// Update product by ID.
  Future<int> update(int id, Map<String, dynamic> productData) async {
    return await _db.updateProduct(id, productData);
  }

  /// Soft delete (deactivate).
  Future<int> softDelete(int id) async {
    return await _db.softDeleteProduct(id);
  }

  /// Reactivate.
  Future<int> reactivate(int id) async {
    return await _db.reactivateProduct(id);
  }

  /// Permanent delete.
  Future<void> delete(int id) async {
    return await _db.deleteProduct(id);
  }

  /// Get price history for a product (raw maps — no PriceHistory model yet).
  Future<List<Map<String, dynamic>>> getPriceHistory(int productId) async {
    return await _db.getPriceHistory(productId);
  }

  /// Log a price change.
  Future<void> logPriceChange({
    required int productId,
    required double oldPrice,
    required double newPrice,
    int changedBy = 1,
  }) async {
    return await _db.logPriceChange(
      productId: productId,
      oldPrice: oldPrice,
      newPrice: newPrice,
      changedBy: changedBy,
    );
  }
}
