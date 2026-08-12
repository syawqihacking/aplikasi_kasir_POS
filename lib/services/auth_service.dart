import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Map<String, dynamic>? _currentUser;
  List<Map<String, dynamic>> _permissions = [];

  Map<String, dynamic>? get currentUser => _currentUser;
  String? get role => _currentUser?['role'];

  Future<void> setLoggedInUser(Map<String, dynamic> user) async {
    _currentUser = user;
    final roleName = user['role'] as String;
    
    // Load permissions for this role
    _permissions = await DatabaseHelper.instance.getPermissions(roleName);
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _permissions = [];
    notifyListeners();
  }

  bool hasPermission(String module, String action) {
    if (_currentUser == null) return false;
    
    try {
      final perm = _permissions.firstWhere((p) => p['module'] == module);
      switch (action) {
        case 'view':
          return perm['can_view'] == 1;
        case 'create':
          return perm['can_create'] == 1;
        case 'edit':
          return perm['can_edit'] == 1;
        case 'delete':
          return perm['can_delete'] == 1;
        default:
          return false;
      }
    } catch (e) {
      return false; // Module not found in permissions
    }
  }
}
