import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Global cart state that persists across page navigation.
/// The POS screen reads from and writes to this service.
class CartService {
  static final CartService instance = CartService._();
  CartService._();

  final List<Map<String, dynamic>> _items = [];
  final List<List<Map<String, dynamic>>> _history = [];
  final _notifier = ValueNotifier<int>(0); // Fires whenever cart changes

  List<Map<String, dynamic>> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + (item['qty'] as int));
  ValueNotifier<int> get notifier => _notifier;

  bool get canUndo => _history.isNotEmpty;

  void _saveToHistory() {
    final copy = _items.map((item) => Map<String, dynamic>.from(item)).toList();
    _history.add(copy);
    if (_history.length > 10) {
      _history.removeAt(0);
    }
  }

  bool undo() {
    if (_history.isEmpty) return false;
    final previousState = _history.removeLast();
    _items.clear();
    _items.addAll(previousState);
    _notifier.value++;
    _saveDraft();
    return true;
  }

  void clearHistory() {
    _history.clear();
  }

  Future<void> loadDraft() async {
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      final draftStr = settings['draft_cart'];
      if (draftStr != null && draftStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(draftStr);
        _items.clear();
        for (var item in decoded) {
          _items.add(Map<String, dynamic>.from(item));
        }
        _notifier.value++;
      }
    } catch (e) {
      debugPrint('Failed to load cart draft: $e');
    }
  }

  void _saveDraft() {
    try {
      final draftStr = jsonEncode(_items);
      DatabaseHelper.instance.saveSetting('draft_cart', draftStr);
    } catch (e) {
      debugPrint('Failed to save cart draft: $e');
    }
  }

  final List<Map<String, dynamic>> _heldTransactions = [];
  List<Map<String, dynamic>> get heldTransactions => _heldTransactions;

  void holdTransaction(String name, double discountTotal) {
    if (_items.isEmpty) return;
    _heldTransactions.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'time': DateTime.now(),
      'items': List<Map<String, dynamic>>.from(_items),
      'discountTotal': discountTotal,
    });
    clear();
    _saveDraft();
  }

  Map<String, dynamic>? resumeTransaction(String id) {
    final index = _heldTransactions.indexWhere((t) => t['id'] == id);
    if (index >= 0) {
      final t = _heldTransactions.removeAt(index);
      clear();
      _items.addAll(t['items']);
      _notifier.value++;
      _saveDraft();
      return t;
    }
    return null;
  }

  int getQty(int productId) {
    final index = _items.indexWhere((item) => item['id'] == productId);
    if (index >= 0) return _items[index]['qty'];
    return 0;
  }

  void addToCart(Map<String, dynamic> product) {
    _saveToHistory();
    final existingIndex = _items.indexWhere((item) => item['id'] == product['id']);
    if (existingIndex >= 0) {
      _items[existingIndex] = Map<String, dynamic>.from(_items[existingIndex]);
      _items[existingIndex]['qty'] += 1;
    } else {
      _items.add({...product, 'qty': 1});
    }
    _notifier.value++;
    _saveDraft();
  }

  void updateQty(int index, int delta) {
    _saveToHistory();
    final newQty = _items[index]['qty'] + delta;
    if (newQty > 0) {
      _items[index] = Map<String, dynamic>.from(_items[index]);
      _items[index]['qty'] = newQty;
    } else {
      _items.removeAt(index);
    }
    _notifier.value++;
    _saveDraft();
  }

  void removeAt(int index) {
    _saveToHistory();
    _items.removeAt(index);
    _notifier.value++;
    _saveDraft();
  }

  void clear() {
    if (_items.isNotEmpty) {
      _saveToHistory();
    }
    _items.clear();
    _notifier.value++;
    _saveDraft();
  }

  double subtotal() {
    return _items.fold(0.0, (sum, item) => sum + (item['sell_price'] * item['qty']));
  }
}
