import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../services/notification_service.dart';
import '../../main.dart';

class Header extends StatefulWidget {
  final String? title;
  const Header({super.key, this.title});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  final _dateFormat = DateFormat('EEEE, d MMMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final notifs = await NotificationService.getNotifications();
      if (mounted) {
        setState(() => _notifications = notifs);
      }
    } catch (_) {
      // Ignore
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showNotificationDialog() async {
    // Tandai semua notifikasi saat ini sebagai sudah dibaca, lalu muat ulang
    // supaya badge merah langsung hilang setelah dialog ditutup.
    final ids = _notifications.map((n) => n.id).toList();
    if (ids.isNotEmpty) {
      await NotificationService.markAllSeen(ids);
      await _loadNotifications();
    }
    if (!mounted) return;

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
                          bgColor = AppColors.danger.withOpacity(0.1);
                        } else if (notif.type == 'warning') {
                          iconColor = AppColors.warning;
                          bgColor = AppColors.warning.withOpacity(0.1);
                        } else {
                          iconColor = AppColors.primary;
                          bgColor = AppColors.primary.withOpacity(0.1);
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
                          // Notifikasi produk bisa diklik → buka halaman produk.
                          trailing: notif.productId != null
                              ? const Icon(Icons.chevron_right, color: AppColors.textLight)
                              : null,
                          onTap: notif.productId != null
                              ? () {
                                  Navigator.pop(ctx);
                                  productSearchRequest.value = notif.title;
                                  mainLayoutTabNotifier.value = 2;
                                }
                              : null,
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
    final todayStr = _dateFormat.format(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ?? 'Sales Report',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              todayStr,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        const Spacer(),
        _buildIconButton(Icons.search, onTap: () {
          // Search functionality if needed
        }),
        const SizedBox(width: 16),
        _buildIconButton(
          Icons.notifications_none,
          hasBadge: _notifications.any((n) => !n.isSeen),
          badgeCount: _notifications.where((n) => !n.isSeen).length,
          onTap: _showNotificationDialog,
        ),
        const SizedBox(width: 24),
        Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=47'), // Placeholder image
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ferra Alexandra',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Admin store',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, {bool hasBadge = false, int badgeCount = 0, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.textDark, size: 24),
          ),
          if (hasBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
