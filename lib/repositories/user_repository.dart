import '../database/database_helper.dart';
import '../models/user.dart';

class UserRepository {
  UserRepository._();
  static final instance = UserRepository._();
  final _db = DatabaseHelper.instance;

  Future<List<AppUser>> getAll() async {
    final rows = await _db.getAllUsers();
    return rows.map(AppUser.fromMap).toList();
  }

  Future<int> insert(Map<String, dynamic> userData) async {
    return await _db.insertUser(userData);
  }

  Future<int> update(int id, Map<String, dynamic> userData) async {
    return await _db.updateUser(id, userData);
  }

  Future<int> toggleActive(int id, bool isActive) async {
    return await _db.toggleUserActive(id, isActive);
  }
}
