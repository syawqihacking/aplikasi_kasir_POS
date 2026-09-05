import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/login_screen.dart';

import 'database/database_helper.dart';
import 'services/supabase_sync_service.dart';
import 'services/telegram_service.dart';
import 'features/smart_assistant/smart_assistant_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await initializeDateFormatting('en_US', null);
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Run background/maintenance tasks
  await DatabaseHelper.instance.performDailyMaintenance();
  
  // Test Telegram Bot (Hanya untuk testing, nanti bisa dihapus)
  await TelegramService().sendMessage('👋 Halo! Bot Telegram untuk Aplikasi Kasir berhasil terhubung!');
  
  // Run initial Supabase sync (non-blocking)
  SupabaseSyncService().syncUnsyncedData().catchError((e) {
    debugPrint('Initial sync error: $e');
  });

  runApp(const MyApp());
}

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<int> mainLayoutTabNotifier = ValueNotifier(0);
/// Berisi nama produk yang harus difokuskan di halaman Products
/// (diisi oleh notifikasi produk, dikonsumsi oleh ProductsScreen).
final ValueNotifier<String?> productSearchRequest = ValueNotifier(null);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Aplikasi Kasir Desktop',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C2FE2),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C2FE2),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
          builder: (context, child) {
            // Sembunyikan chatbot di mobile (Android/iOS)
            if (Platform.isAndroid || Platform.isIOS) {
              return child!;
            }
            return SmartAssistantOverlay(child: child!);
          },
          home: const LoginScreen(),
        );
      }
    );
  }
}
