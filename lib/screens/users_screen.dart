import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await UserRepository.instance.getAll();
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  void _showUserDialog([AppUser? user]) {
    final usernameCtrl = TextEditingController(text: user?.username);
    final passwordCtrl = TextEditingController(); // Empty for safety
    final fullNameCtrl = TextEditingController(text: user?.fullName);
    String selectedRole = user?.role ?? 'Kasir';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Add User' : 'Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  enabled: user == null, // Don't change username
                ),
                TextField(
                  controller: passwordCtrl,
                  decoration: InputDecoration(
                    labelText: user == null ? 'Password' : 'New Password (leave blank to keep)',
                  ),
                  obscureText: true,
                ),
                TextField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: ['Admin', 'Kasir'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final username = usernameCtrl.text.trim();
                final password = passwordCtrl.text.trim();
                final fullName = fullNameCtrl.text.trim();

                if (username.isEmpty || fullName.isEmpty || (user == null && password.isEmpty)) {
                  return; // Validation failed
                }

                if (user == null) {
                  await UserRepository.instance.insert({
                    'username': username,
                    'password_hash': password, // Will be hashed in DatabaseHelper
                    'role': selectedRole,
                    'full_name': fullName,
                    'is_active': 1,
                  });
                } else {
                  final updates = {
                    'role': selectedRole,
                    'full_name': fullName,
                  };
                  if (password.isNotEmpty) {
                    updates['password_hash'] = password;
                  }
                  await UserRepository.instance.update(user.id!, updates);
                }
                
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadUsers();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserActive(int id, bool currentStatus) async {
    await UserRepository.instance.toggleActive(id, !currentStatus);
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Users Management',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showUserDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add User'),
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final isActive = user.isActive;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? AppColors.primary : Colors.grey,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text('${user.fullName} (@${user.username})'),
                    subtitle: Text(user.role),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.primary),
                          onPressed: () => _showUserDialog(user),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (val) => _toggleUserActive(user.id!, isActive),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
