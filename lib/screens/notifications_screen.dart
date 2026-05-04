import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  final void Function(int)? onNavigate;
  const NotificationsScreen({super.key, this.onNavigate});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Đánh dấu tất cả đã đọc và reload danh sách từ provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.markAllRead();
      if (mounted) {
        await context.read<AppProvider>().refreshNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe reactive từ AppProvider – UI tự rebuild khi có thay đổi
    final notifs = context.watch<AppProvider>().notifications;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [
        // ── Header ──────────────────────────────────────────────
        SliverToBoxAdapter(
            child: Container(
          color: AppTheme.surface.withOpacity(0.7),
          child: SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Thông báo',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w800)),
                        Text('CẬP NHẬT MỚI NHẤT',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppTheme.outline,
                                    letterSpacing: 1.5)),
                      ])),
                  Opacity(
                    opacity: notifs.isNotEmpty ? 1.0 : 0.4,
                    child: IgnorePointer(
                      ignoring: notifs.isEmpty,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.read<AppProvider>().clearAllNotifs(),
                        icon: const Icon(Icons.delete_sweep_outlined,
                            size: 18, color: AppTheme.error),
                        label: const Text('Xóa tất cả',
                            style:
                                TextStyle(color: AppTheme.error, fontSize: 13)),
                      ),
                    ),
                  ),
                ]),
              )),
        )),

        // ── Empty state ─────────────────────────────────────────
        if (notifs.isEmpty)
          const SliverFillRemaining(
              child: Center(
                  child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none,
                  size: 56, color: AppTheme.outlineVariant),
              SizedBox(height: 12),
              Text('Chưa có thông báo nào',
                  style: TextStyle(color: AppTheme.onSurfaceVariant)),
            ],
          )))
        // ── Notification list ────────────────────────────────────
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final notif = notifs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  // ── Swipe-to-dismiss ──────────────────────────
                  child: Dismissible(
                    key: ValueKey(notif.id),
                    direction: DismissDirection.endToStart,
                    // Nền đỏ khi vuốt
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: AppTheme.error, size: 24),
                    ),
                    onDismissed: (_) =>
                        context.read<AppProvider>().removeNotif(notif.id),
                    child: _NotifCard(
                      notif: notif,
                      onTap: () {
                        context.read<AppProvider>().markNotifAsRead(notif.id);
                        Navigator.pop(context);
                        widget.onNavigate?.call(notif.targetTab);
                      },
                    ),
                  ),
                );
              },
              childCount: notifs.length,
            )),
          ),
      ]),
    );
  }
}

// ── _NotifCard ────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotif notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  IconData get _icon => switch (notif.targetTab) {
        1 => Icons.calendar_today_outlined,
        2 => Icons.school_outlined,
        3 => Icons.payment_outlined,
        _ => Icons.notifications_outlined,
      };

  Color get _color => switch (notif.targetTab) {
        1 => AppTheme.secondary,
        2 => AppTheme.primary,
        3 => AppTheme.tertiary,
        _ => AppTheme.primary,
      };

  String _ago(DateTime ts) {
    final d = DateTime.now().difference(ts);
    if (d.inMinutes < 1) return 'Vừa xong';
    if (d.inHours < 1) return '${d.inMinutes} phút trước';
    if (d.inDays < 1) return '${d.inHours} giờ trước';
    return '${d.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) => SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _color, size: 20),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                    child: Text(notif.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            // Đậm nếu chưa đọc
                            color: notif.isRead
                                ? AppTheme.onSurfaceVariant
                                : null)),
                  ),
                  // Chấm đỏ nếu chưa đọc
                  if (!notif.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(notif.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_ago(notif.ts),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppTheme.outline)),
              ])),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppTheme.outlineVariant, size: 18),
        ]),
      );
}
