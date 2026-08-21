import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
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
import '../services/auth_service.dart';
import '../services/scanner_service.dart';
import '../main.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  Timer? _idleTimer;
  static const int _idleTimeoutMinutes = 10;

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    final userRole = (auth.role ?? '').toLowerCase();
    final isKasir = userRole == 'kasir' || userRole == 'cashier' || userRole == 'kasir utama' || userRole == 'cashier utama';
    if (isKasir && mainLayoutTabNotifier.value == 0) {
      _selectedIndex = 1;
      mainLayoutTabNotifier.value = 1;
    } else {
      _selectedIndex = mainLayoutTabNotifier.value;
    }
    _resetIdleTimer();
    mainLayoutTabNotifier.addListener(_onTabNotifierChanged);
  }

  void _onTabNotifierChanged() {
    if (mounted) {
      setState(() {
        _selectedIndex = mainLayoutTabNotifier.value;
      });
    }
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
    mainLayoutTabNotifier.removeListener(_onTabNotifierChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget activeScreen;
    switch (_selectedIndex) {
      case 0:
        activeScreen = const DashboardContent();
        break;
      case 1:
        activeScreen = const PosScreen();
        break;
      case 2:
        activeScreen = const ProductsScreen();
        break;
      case 3:
        activeScreen = const InventoryScreen();
        break;
      case 4:
        activeScreen = const TransactionsScreen();
        break;
      case 5:
        activeScreen = const CashFlowScreen();
        break;
      case 6:
        activeScreen = const UsersScreen();
        break;
      case 7:
        activeScreen = const SettingsScreen();
        break;
      case 8:
        activeScreen = const SuppliersScreen();
        break;
      case 9:
        activeScreen = const CategoriesScreen();
        break;
      case 10:
        activeScreen = const ReportsScreen();
        break;
      case 11:
        activeScreen = const BackupRestoreScreen();
        break;
      case 12:
        activeScreen = const AuditTrailScreen();
        break;
      case 13:
        activeScreen = const ShiftScreen();
        break;
      default:
        activeScreen = const Center(child: Text('Coming Soon'));
    }

    return Listener(
      onPointerDown: _onInteraction,
      onPointerMove: _onInteraction,
      onPointerUp: _onInteraction,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            Sidebar(
              selectedIndex: _selectedIndex,
              onMenuTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
                // Sinkronkan notifier agar navigasi dari notifikasi
                // (mis. pindah ke halaman Produk) tetap berfungsi.
                mainLayoutTabNotifier.value = index;
              },
            ),
            Expanded(
              child: Stack(
                children: [
                  activeScreen,
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: ValueListenableBuilder<ScanContextMode>(
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
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                            border: Border.all(color: badgeColor.withOpacity(0.5)),
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
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

