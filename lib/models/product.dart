/// Typed model for the SQLite `products` table, plus JOIN field [categoryName].
class Product {
  final int? id;
  final String? barcode;
  final String? sku;
  final String name;
  final int? categoryId;
  final String? unit;
  final double costPrice;
  final double sellPrice;
  final int minStock;
  final int currentStock;
  final String? rackLocation;
  final String? photoPath;
  final int isActiveFlag;
  final int? createdBy;
  final String? createdAt;
  final int? updatedBy;
  final String? updatedAt;
  /// From LEFT JOIN categories — not a DB column on products.
  final String? categoryName;

  const Product({
    this.id,
    this.barcode,
    this.sku,
    required this.name,
    this.categoryId,
    this.unit,
    this.costPrice = 0.0,
    this.sellPrice = 0.0,
    this.minStock = 0,
    this.currentStock = 0,
    this.rackLocation,
    this.photoPath,
    this.isActiveFlag = 1,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.categoryName,
  });

  bool get isActive => isActiveFlag == 1;
  bool get isLowStock => currentStock <= minStock;

  static int? _asInt(dynamic v) =>
      v == null ? null : (v is int ? v : (v as num).toInt());

  static int _asIntOr(dynamic v, int fallback) =>
      v == null ? fallback : (v is int ? v : (v as num).toInt());

  static double _asDouble(dynamic v) =>
      v == null ? 0.0 : (v as num).toDouble();

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: _asInt(map['id']),
      barcode: map['barcode'] as String?,
      sku: map['sku'] as String?,
      name: map['name'] as String? ?? '',
      categoryId: _asInt(map['category_id']),
      unit: map['unit'] as String?,
      costPrice: _asDouble(map['cost_price']),
      sellPrice: _asDouble(map['sell_price']),
      minStock: _asIntOr(map['min_stock'], 0),
      currentStock: _asIntOr(map['current_stock'], 0),
      rackLocation: map['rack_location'] as String?,
      photoPath: map['photo_path'] as String?,
      isActiveFlag: _asIntOr(map['is_active'], 1),
      createdBy: _asInt(map['created_by']),
      createdAt: map['created_at'] as String?,
      updatedBy: _asInt(map['updated_by']),
      updatedAt: map['updated_at'] as String?,
      categoryName: map['category_name'] as String?,
    );
  }

  /// Keys match DB column names (snake_case). Includes [category_name] when set
  /// so dialogs that still expect maps keep working via [toMap].
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'sku': sku,
      'name': name,
      'category_id': categoryId,
      'unit': unit,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'min_stock': minStock,
      'current_stock': currentStock,
      'rack_location': rackLocation,
      'photo_path': photoPath,
      'is_active': isActiveFlag,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_by': updatedBy,
      'updated_at': updatedAt,
      if (categoryName != null) 'category_name': categoryName,
    };
  }
}
