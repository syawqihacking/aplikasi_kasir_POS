import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:customerbandung/services/cart_service.dart';
import 'package:customerbandung/database/database_helper.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Trigger database initialization on the in-memory or default db
    await DatabaseHelper.instance.database;
  });

  tearDown(() {
    CartService.instance.clear();
    CartService.instance.clearHistory();
  });

  group('CartService tests', () {
    test('Initial cart is empty and cannot undo', () {
      expect(CartService.instance.items, isEmpty);
      expect(CartService.instance.canUndo, isFalse);
    });

    test('Add item to cart and undo', () {
      final product = {
        'id': 1,
        'name': 'Produk A',
        'sell_price': 10000.0,
        'current_stock': 10,
        'unit': 'pcs',
      };

      CartService.instance.addToCart(product);
      expect(CartService.instance.items.length, 1);
      expect(CartService.instance.items[0]['qty'], 1);
      expect(CartService.instance.canUndo, isTrue);

      final success = CartService.instance.undo();
      expect(success, isTrue);
      expect(CartService.instance.items, isEmpty);
      expect(CartService.instance.canUndo, isFalse);
    });

    test('Update item quantity and undo', () {
      final product = {
        'id': 1,
        'name': 'Produk A',
        'sell_price': 10000.0,
        'current_stock': 10,
        'unit': 'pcs',
      };

      CartService.instance.addToCart(product);
      CartService.instance.updateQty(0, 2); // Qty should become 3
      expect(CartService.instance.items[0]['qty'], 3);

      final success = CartService.instance.undo();
      expect(success, isTrue);
      expect(CartService.instance.items[0]['qty'], 1); // Reverted back to 1
    });

    test('Clear cart and undo', () {
      final product = {
        'id': 1,
        'name': 'Produk A',
        'sell_price': 10000.0,
        'current_stock': 10,
        'unit': 'pcs',
      };

      CartService.instance.addToCart(product);
      CartService.instance.clear();
      expect(CartService.instance.items, isEmpty);
      expect(CartService.instance.canUndo, isTrue);

      final success = CartService.instance.undo();
      expect(success, isTrue);
      expect(CartService.instance.items.length, 1);
      expect(CartService.instance.items[0]['name'], 'Produk A');
    });
  });
}
