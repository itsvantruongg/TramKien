import 'package:flutter/material.dart';
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
  List<AppNotif> _notifs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await NotificationService.getAll();
    await NotificationService.markAllRead();
    if (mounted)
      setState(() {
        _notifs = list;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [
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
                  TextButton(
                    onPressed: () async {
                      await NotificationService.clearAll();
                      if (mounted) setState(() => _notifs.clear());
                    },
                    child: const Text('Xóa tất cả',
                        style: TextStyle(color: AppTheme.error, fontSize: 12)),
                  ),
                ]),
              )),
        )),
        if (_loading)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else if (_notifs.isEmpty)
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
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotifCard(
                  notif: _notifs[i],
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNavigate?.call(_notifs[i].targetTab);
                  },
                ),
              ),
              childCount: _notifs.length,
            )),
          ),
      ]),
    );
  }
}

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
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(notif.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(notif.body,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.onSurfaceVariant),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_ago(notif.ts),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppTheme.outline)),
              ])),
          Icon(Icons.chevron_right, color: AppTheme.outlineVariant, size: 18),
        ]),
      );
}
