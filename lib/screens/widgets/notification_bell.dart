import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/notification_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifs = await NotificationService.getNotifications();
      if (mounted) {
        setState(() => _notifications = notifs);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showNotificationDialog() {
    _loadNotifications(); // Refresh on open
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Notifikasi Sistem', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: _isLoading
              ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
              : _notifications.isEmpty
                  ? SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'Tidak ada notifikasi baru.\nSemua sistem berjalan baik.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: AppColors.textLight),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        Color iconColor;
                        Color bgColor;
                        if (notif.type == 'danger') {
                          iconColor = AppColors.danger;
                          bgColor = AppColors.danger.withValues(alpha: 0.1);
                        } else if (notif.type == 'warning') {
                          iconColor = AppColors.warning;
                          bgColor = AppColors.warning.withValues(alpha: 0.1);
                        } else {
                          iconColor = AppColors.primary;
                          bgColor = AppColors.primary.withValues(alpha: 0.1);
                        }

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: bgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(notif.icon, color: iconColor, size: 24),
                          ),
                          title: Text(notif.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(notif.message, style: GoogleFonts.outfit(fontSize: 12)),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showNotificationDialog,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: AppColors.textDark, size: 28),
          if (_notifications.isNotEmpty)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _notifications.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
