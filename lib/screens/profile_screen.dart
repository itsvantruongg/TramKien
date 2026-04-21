import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/shared_widgets.dart';
import 'curriculum_screen.dart';
import 'feedback_screen.dart';
import 'terms_screen.dart';
import '../services/local_notification_service.dart';

// ════════════════════════════════════════════════════════════
// PROFILE SCREEN
// ════════════════════════════════════════════════════════════

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final s = p.student;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [
        const SliverToBoxAdapter(child: AcademicAppBar(subtitle: 'PROFILE')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Hero
              Text(s?.hoTen ?? 'Sinh viên',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(p.currentMssv ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.primary)),
              const SizedBox(height: 8),
              Row(children: [
                const StatusChip(label: 'ĐANG HỌC'),
                const SizedBox(width: 8),
                if (s?.chuyenNganh.isNotEmpty == true)
                  StatusChip(
                    label: s!.chuyenNganh.toUpperCase(),
                    color: AppTheme.secondary,
                  ),
              ]),
              const SizedBox(height: 28),

              // Settings list
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _NotificationToggle(mssv: p.currentMssv ?? ''),
                  const Divider(
                      height: 1, color: AppTheme.surfaceContainerHigh),
                  _Item(Icons.badge_outlined, 'Thông tin sinh viên', () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StudentInfoScreen()));
                  }),
                  _Item(
                      Icons.account_tree_outlined, 'Chương trình đào tạo chính',
                      () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CurriculumScreen()));
                  }),
                  _Item(Icons.rate_review_outlined, 'Góp ý ứng dụng', () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FeedbackScreen()));
                  }),
                  _Item(Icons.policy_outlined, 'Điều khoản dịch vụ', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const TermsScreen()));
                  }),
                  _Item(
                    Icons.logout,
                    'Đăng xuất',
                    () => _confirmLogout(context, p),
                    iconColor: AppTheme.error,
                    textColor: AppTheme.error,
                  ),
                ]),
              ),

              const SizedBox(height: 20),
              Center(
                  child: Text('Version 1.0.0',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.outlineVariant, letterSpacing: 1.5))),
            ]),
          ),
        ),
      ]),
    );
  }

  void _confirmLogout(BuildContext ctx, AppProvider p) {
    showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('Đăng xuất?',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
              content: const Text('Dữ liệu đã tải về sẽ bị xóa.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Hủy')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    p.logout();
                  },
                  child: const Text('Đăng xuất',
                      style: TextStyle(color: AppTheme.error)),
                ),
              ],
            ));
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor, textColor;
  const _Item(this.icon, this.label, this.onTap,
      {this.iconColor, this.textColor});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? AppTheme.primary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor ?? AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600, color: textColor))),
            Icon(Icons.chevron_right,
                color: textColor ?? AppTheme.outlineVariant, size: 20),
          ]),
        ),
      );
}

class _NotificationToggle extends StatefulWidget {
  final String mssv;
  const _NotificationToggle({required this.mssv});

  @override
  State<_NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<_NotificationToggle> {
  bool _enabled = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(covariant _NotificationToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mssv != widget.mssv) {
      _loadState();
    }
  }

  Future<void> _loadState() async {
    final enabled =
        await LocalNotificationService.isNotificationEnabled(widget.mssv);
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _toggle(bool val) async {
    if (!mounted) return;

    // Disable switch trong lúc đang xử lý
    setState(() => _processing = true);

    try {
      if (val) {
        await LocalNotificationService.requestPermissions();
      }
      await LocalNotificationService.setNotificationEnabled(widget.mssv, val);

      // Chỉ cập nhật UI sau khi hệ thống đã xử lý xong
      if (!mounted) return;
      setState(() {
        _enabled = val;
        _processing = false;
      });

      if (val) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã bật thông báo! Đang gửi thông báo thử nghiệm...'),
          duration: Duration(seconds: 2),
        ));
        await LocalNotificationService.showTestNotification();
        if (!mounted) return;
        context.read<AppProvider>().syncSchedule(forceRefresh: false).then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Đã lên lịch xong các thông báo.'),
              duration: Duration(seconds: 2),
            ));
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã tắt thông báo lịch học.'),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      // Nếu lỗi → revert lại trạng thái cũ
      if (!mounted) return;
      setState(() {
        _enabled = !val;
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.notifications_active_outlined,
              size: 20, color: AppTheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thông báo lịch',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
              Text('Nhắc nhở lịch học và thi vào 20:00 ngày hôm trước',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppTheme.outlineVariant)),
            ],
          ),
        ),
        Switch(
          value: _enabled,
          onChanged: (widget.mssv.isNotEmpty && !_processing) ? _toggle : null,
          activeColor: AppTheme.primary,
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// STUDENT INFO SUB-SCREEN
// ════════════════════════════════════════════════════════════

class StudentInfoScreen extends StatelessWidget {
  const StudentInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final s = p.student;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [
        // Custom appbar with back
        SliverToBoxAdapter(
            child: Container(
          color: AppTheme.surface.withOpacity(0.7),
          child: SafeArea(
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
                    Text('Thông tin sinh viên',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800)),
                    Text('STUDENT PROFILE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.outline, letterSpacing: 1.5)),
                  ])),
              IconButton(
                icon: const Icon(Icons.sync_outlined, color: AppTheme.primary),
                onPressed: () => p.syncAll(forceRefresh: true),
              ),
            ]),
          )),
        )),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Identity card
              SurfaceCard(
                  child: Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(s?.hoTen ?? '—',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(p.currentMssv ?? '—',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const StatusChip(label: 'ĐANG HỌC'),
                        const SizedBox(width: 6),
                        if (s?.gioiTinh.isNotEmpty == true)
                          StatusChip(
                            label: s!.gioiTinh.toUpperCase(),
                            color: AppTheme.secondary,
                          ),
                      ]),
                    ])),
              ])),
              const SizedBox(height: 20),

              // Academic grid
              _SectionTitle('Thông tin học tập'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _GridCard('Chuyên ngành', s?.chuyenNganh ?? '—',
                      Icons.school_outlined),
                  _GridCard('Hệ đào tạo', s?.heDaoTao ?? '—',
                      Icons.category_outlined),
                  _GridCard('Niên khóa', s?.nienKhoa ?? '—',
                      Icons.calendar_month_outlined),
                  _GridCard(
                      'Khóa học', s?.khoaHoc ?? '—', Icons.bookmark_outlined),
                ],
              ),
              const SizedBox(height: 20),

              // Personal info
              _SectionTitle('Thông tin cá nhân'),
              const SizedBox(height: 12),
              SurfaceCard(
                  child: Column(children: [
                _Row(Icons.cake_outlined, 'Ngày sinh', s?.ngaySinh ?? '—'),
                _Div(),
                _Row(Icons.phone_outlined, 'Điện thoại', s?.dienThoai ?? '—'),
                _Div(),
                _Row(Icons.email_outlined, 'Email', s?.email ?? '—'),
                _Div(),
                _Row(Icons.home_outlined, 'Quê quán', s?.queQuan ?? '—'),
                _Div(),
                _Row(Icons.location_on_outlined, 'Địa chỉ báo tin',
                    s?.diaChiBaoTin ?? '—'),
                _Div(),
                _Row(Icons.badge_outlined, 'CMND/CCCD', s?.cmnd ?? '—'),
              ])),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(title,
            style: Theme.of(ctx)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _GridCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _GridCard(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext ctx) => SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const Spacer(),
          Text(label,
              style: Theme.of(ctx)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.outline, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(ctx)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext ctx) => Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(ctx)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.outline, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value,
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ])),
      ]);
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext _) =>
      const Divider(height: 20, color: AppTheme.surfaceContainerHigh);
}
