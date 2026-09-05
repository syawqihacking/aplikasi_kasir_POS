import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../database/database_helper.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import '../../main.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/shift_service.dart';
import '../../models/shift.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onMenuTap;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final userRole = (auth.role ?? '').toLowerCase();
    final isKasir = userRole == 'kasir' || userRole == 'cashier' || userRole == 'kasir utama' || userRole == 'cashier utama';
    return Container(
      width: 250,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Image.asset(
                  'assets/logo/Minimalist Red Shopping Cart Logo.png',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'DashDock',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Logged in as: ${auth.currentUser?['username'] ?? 'User'}\nRole: ${auth.role ?? 'Unknown'}',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMenuSection('MENU'),
                  if (!isKasir && auth.hasPermission('dashboard', 'view')) _buildMenuItem(Icons.dashboard_outlined, 'Dashboard', 0),
                  if (auth.hasPermission('pos', 'view')) _buildMenuItem(Icons.point_of_sale_outlined, 'POS / Kasir', 1),
                  _buildMenuItem(
                    Icons.schedule_outlined,
                    'Shift Kasir',
                    13,
                    trailing: ValueListenableBuilder<CashShift?>(
                      valueListenable: ShiftService.instance.activeShiftNotifier,
                      builder: (context, shift, _) {
                        if (shift == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'AKTIF',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (!isKasir && auth.hasPermission('products', 'view')) _buildMenuItem(Icons.shopping_cart_outlined, 'Products', 2),
                  if (!isKasir && auth.hasPermission('products', 'view')) _buildMenuItem(Icons.bar_chart_outlined, 'Bulk Barcode', 14),
                  if (!isKasir && auth.hasPermission('inventory', 'view')) _buildMenuItem(Icons.inventory_outlined, 'Inventory (Restock)', 3),
                  if (!isKasir) ...[
                    _buildMenuSection('FINANCIAL'),
                    if (auth.hasPermission('transactions', 'view')) _buildMenuItem(Icons.account_balance_wallet_outlined, 'Transactions', 4),
                    if (auth.hasPermission('transactions', 'view')) _buildMenuItem(Icons.swap_horiz_outlined, 'Arus Kas (In / Out)', 5),
                    if (auth.hasPermission('reports', 'view')) _buildMenuItem(Icons.bar_chart_outlined, 'Laporan Bisnis', 10),
                    const SizedBox(height: 24),
                    _buildMenuSection('MASTER DATA'),
                    if (auth.hasPermission('products', 'view')) _buildMenuItem(Icons.business_outlined, 'Suppliers', 8),
                    if (auth.hasPermission('products', 'view')) _buildMenuItem(Icons.category_outlined, 'Categories', 9),
                    const SizedBox(height: 24),
                    _buildMenuSection('TOOLS'),
                    if (auth.hasPermission('users', 'view')) _buildMenuItem(Icons.people_outline, 'Users', 6),
                    if (auth.hasPermission('settings', 'view')) _buildMenuItem(Icons.settings_outlined, 'Settings', 7),
                    if (auth.hasPermission('settings', 'view')) _buildMenuItem(Icons.backup_outlined, 'Backup & Restore', 11),
                    if (auth.hasPermission('reports', 'view')) _buildMenuItem(Icons.history_outlined, 'Audit Trail', 12),
                  ],
                ],
              ),
            ),
          ),
          _buildThemeToggle(context),
          _buildLogoutCard(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index, {Widget? trailing}) {
    final isActive = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: isActive ? Colors.white : AppColors.textLight,
            size: 22,
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? Colors.white : AppColors.textDark,
            ),
          ),
          trailing: trailing,
          onTap: () => onMenuTap(index),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (context, currentMode, _) {
          final isDark = currentMode == ThemeMode.dark;
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => appThemeMode.value = ThemeMode.light,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !isDark ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.light_mode, size: 16, color: !isDark ? AppColors.primary : AppColors.textLight),
                          const SizedBox(width: 4),
                          Text('Light', style: GoogleFonts.outfit(fontSize: 12, fontWeight: !isDark ? FontWeight.bold : FontWeight.normal, color: !isDark ? AppColors.primary : AppColors.textLight)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => appThemeMode.value = ThemeMode.dark,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3A3A3A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)] : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dark_mode, size: 16, color: isDark ? Colors.white : AppColors.textLight),
                          const SizedBox(width: 4),
                          Text('Dark', style: GoogleFonts.outfit(fontSize: 12, fontWeight: isDark ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white : AppColors.textLight)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GestureDetector(
        onTap: () async {
          final userId = AuthService().currentUser?['id'] ?? 1;
          await DatabaseHelper.instance.logActivity('LOGOUT', 'auth', 'User logged out', userId: userId);
          AuthService().logout();
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.logout, color: AppColors.danger, size: 20),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
