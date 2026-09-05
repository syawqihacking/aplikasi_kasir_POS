import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'responsive_layout.dart';
import 'login_screen.dart';

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
    return Listener(
      onPointerDown: _onInteraction,
      onPointerMove: _onInteraction,
      onPointerUp: _onInteraction,
      child: ResponsiveLayout(
        selectedIndex: _selectedIndex,
        onMenuTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          mainLayoutTabNotifier.value = index;
        },
      ),
    );
  }
}