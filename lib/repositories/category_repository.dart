import '../database/database_helper.dart';
import '../models/category.dart';

class CategoryRepository {
  CategoryRepository._();
  static final instance = CategoryRepository._();
  final _db = DatabaseHelper.instance;

  Future<List<Category>> getAll() async {
    final rows = await _db.getAllCategories();
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insert(Map<String, dynamic> data) async {
    return await _db.insertCategory(data);
  }

  Future<int> update(int id, Map<String, dynamic> data) async {
    return await _db.updateCategory(id, data);
  }

  Future<int> delete(int id) async {
    return await _db.deleteCategory(id);
  }
}
