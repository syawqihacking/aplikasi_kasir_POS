import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/scanner_service.dart';
import 'widgets/sidebar.dart';
import 'dashboard_content.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'transactions_screen.dart';
import 'inventory_screen.dart';
import 'cash_flow_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';
import 'login_screen.dart';
import 'suppliers_screen.dart';
import 'categories_screen.dart';
import 'reports_screen.dart';
import 'backup_restore_screen.dart';
import 'audit_trail_screen.dart';
import 'shift/shift_screen.dart';
import 'bulk_barcode_screen.dart';
import '../utils/responsive_utils.dart';

/// Bottom nav items for phone mode (max 5 items)
const List<_BottomNavItem> _bottomNavItems = [
  _BottomNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', index: 0),
  _BottomNavItem(icon: Icons.point_of_sale_outlined, activeIcon: Icons.point_of_sale, label: 'POS', index: 1),
  _BottomNavItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Products', index: 2),
  _BottomNavItem(icon: Icons.schedule_outlined, activeIcon: Icons.schedule, label: 'Shift', index: 13),
  _BottomNavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Transaksi', index: 4),
];

class _BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}

class ResponsiveLayout extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onMenuTap;

  const ResponsiveLayout({
    super.key,
    required this.selectedIndex,
    required this.onMenuTap,
  });

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  Timer? _idleTimer;
  static const int _idleTimeoutMinutes = 10;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: _idleTimeoutMinutes), _handleIdleTimeout);
  }

  void _handleIdleTimeout() {
    if (mounted) {
      AuthService().logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi telah berakhir karena idle (10 menit). Silakan login kembali.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _onInteraction(PointerEvent event) {
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  Widget _buildActiveScreen() {
    switch (widget.selectedIndex) {
      case 0: return const DashboardContent();
      case 1: return const PosScreen();
      case 2: return const ProductsScreen();
      case 3: return const InventoryScreen();
      case 4: return const TransactionsScreen();
      case 5: return const CashFlowScreen();
      case 6: return const UsersScreen();
      case 7: return const SettingsScreen();
      case 8: return const SuppliersScreen();
      case 9: return const CategoriesScreen();
      case 10: return const ReportsScreen();
      case 11: return const BackupRestoreScreen();
      case 12: return const AuditTrailScreen();
      case 13: return const ShiftScreen();
      case 14: return const BulkBarcodeScreen();
      default: return const Center(child: Text('Coming Soon'));
    }
  }

  Widget _buildScannerBadge() {
    return ValueListenableBuilder<ScanContextMode>(
      valueListenable: ScannerService.instance.modeNotifier,
      builder: (context, mode, _) {
        String modeText;
        Color badgeColor;
        IconData badgeIcon;

        switch (mode) {
          case ScanContextMode.formField:
            modeText = 'Scanner: Input Data';
            badgeColor = AppColors.warning;
            badgeIcon = Icons.edit_note;
            break;
          case ScanContextMode.inventoryLookup:
            modeText = 'Scanner: Inventory Lookup';
            badgeColor = Colors.blue;
            badgeIcon = Icons.inventory_2;
            break;
          case ScanContextMode.sale:
            modeText = 'Scanner: POS Sale';
            badgeColor = AppColors.success;
            badgeIcon = Icons.point_of_sale;
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 16, color: badgeColor),
              const SizedBox(width: 8),
              Text(
                modeText,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = getScreenSize(context);

    return Listener(
      onPointerDown: _onInteraction,
      onPointerMove: _onInteraction,
      onPointerUp: _onInteraction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (screenSize == ScreenSize.phone) {
            return _buildPhoneLayout();
          } else if (screenSize == ScreenSize.tablet) {
            return _buildTabletLayout();
          } else {
            return _buildDesktopLayout();
          }
        },
      ),
    );
  }

  /// Phone layout: BottomNavigationBar + Drawer for extra menus
  Widget _buildPhoneLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/logo/Minimalist Red Shopping Cart Logo.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 10),
            Text(
              'DashDock',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textDark),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildScannerBadge(),
          ),
        ],
      ),
      drawer: SidebarDrawer(
        selectedIndex: widget.selectedIndex,
        onMenuTap: widget.onMenuTap,
      ),
      body: SafeArea(
        child: _buildActiveScreen(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _bottomNavItems.map((item) {
                final isActive = widget.selectedIndex == item.index;
                return GestureDetector(
                  onTap: () => widget.onMenuTap(item.index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive ? AppColors.primary : AppColors.textLight,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? AppColors.primary : AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  /// Tablet layout: Drawer-based navigation (hamburger menu)
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/logo/Minimalist Red Shopping Cart Logo.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 10),
            Text(
              'DashDock',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const Spacer(),
            _buildScannerBadge(),
          ],
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textDark),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
      ),
      drawer: SidebarDrawer(
        selectedIndex: widget.selectedIndex,
        onMenuTap: widget.onMenuTap,
      ),
      body: SafeArea(
        child: _buildActiveScreen(),
      ),
    );
  }

  /// Desktop layout: Fixed sidebar + content
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          Sidebar(
            selectedIndex: widget.selectedIndex,
            onMenuTap: widget.onMenuTap,
          ),
          Expanded(
            child: Stack(
              children: [
                _buildActiveScreen(),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _buildScannerBadge(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}