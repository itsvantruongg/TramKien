import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () => p.syncAll(forceRefresh: true),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: AcademicAppBar(
              subtitle: 'DASHBOARD',
              actions: [
                // Bell icon với badge số thông báo chưa đọc
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: AppTheme.primary),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                NotificationsScreen(onNavigate: onNavigate),
                          ),
                        );
                        // Trigger rebuild để cập nhật badge
                        (context as Element).markNeedsBuild();
                      },
                    ),
                    if (p.unreadNotifCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              p.unreadNotifCount > 9
                                  ? '9+'
                                  : '${p.unreadNotifCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: p.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_outlined,
                          color: AppTheme.primary),
                  onPressed: () => p.syncAll(forceRefresh: true),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // Welcome
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xin chào,',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.onSurfaceVariant)),
                        Text(
                          p.student?.hoTen ?? 'Sinh viên',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Text('HK${p.currentHocKy} · ${p.namHocLabel}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.outline)),
                      ]),
                ),
                const SizedBox(height: 24),

                // GPA + Credits bento row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // GPA gradient — tap → Grades
                      Expanded(
                          flex: 2,
                          child: PressScale(
                            onTap: () => onNavigate?.call(2),
                            child: GradientCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ĐIỂM HIỆN TẠI',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          letterSpacing: 1.5,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w700,
                                        )),
                                    const SizedBox(height: 8),
                                    Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                              (p.diemSummary?.tbcTichLuyHe4 ??
                                                      0.0)
                                                  .toStringAsFixed(2),
                                              style: GoogleFonts.manrope(
                                                fontSize: 52,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                height: 1,
                                              )),
                                          const Padding(
                                            padding: EdgeInsets.only(
                                                bottom: 8, left: 4),
                                            child: Text('/ 4.0',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.white70)),
                                          ),
                                        ]),
                                    const SizedBox(height: 16),
                                    const Text('Tiến độ học tập',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white70)),
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(
                                      value: (p.totalCredits /
                                              p.curriculumTotalCredits)
                                          .clamp(0.0, 1.0),
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation(
                                          Colors.white),
                                      minHeight: 6,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${p.totalCredits} / ${p.curriculumTotalCredits} tín chỉ',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ]),
                            ),
                          )),
                      const SizedBox(width: 12),

                      // Credits circular — tap → Grades
                      Expanded(
                          child: PressScale(
                        onTap: () => onNavigate?.call(2),
                        child: SurfaceCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('TÍN CHỈ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                            color: AppTheme.onSurfaceVariant)),
                                const SizedBox(height: 12),
                                CircularProgressWidget(
                                  value: (p.totalCredits /
                                          p.curriculumTotalCredits)
                                      .clamp(0.0, 1.0),
                                  center: '${p.totalCredits}',
                                  subtitle: 'của ${p.curriculumTotalCredits}',
                                  size: 88,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                    'Còn ${(p.curriculumTotalCredits - p.totalCredits).clamp(0, p.curriculumTotalCredits)} TC',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: AppTheme.onSurfaceVariant),
                                    textAlign: TextAlign.center),
                              ]),
                        ),
                      )),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Lịch hôm nay
                SectionHeader(
                  title: 'Lịch học hôm nay',
                  action: 'Xem tất cả',
                  onAction: () => onNavigate?.call(1),
                ),
                const SizedBox(height: 12),
                ..._buildTodaySchedule(context, p),
                const SizedBox(height: 20),

                // Lịch thi sắp tới
                SectionHeader(
                  title: 'Lịch thi sắp tới',
                  action: 'Xem tất cả',
                  onAction: () => onNavigate?.call(1),
                ),
                const SizedBox(height: 12),
                ..._buildUpcomingExams(context, p),
                const SizedBox(height: 20),

                // Học phí summary
                SectionHeader(
                  title: 'Học phí',
                  action: 'Chi tiết',
                  onAction: () => onNavigate?.call(3),
                ),
                const SizedBox(height: 12),
                PressScale(
                  onTap: () => onNavigate?.call(3),
                  child: GradientCard(
                      child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TỔNG ĐÃ NỘP',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                    )),
                                const SizedBox(height: 4),
                                Text(_fmt(p.tongHocPhiAllDaDong),
                                    style: GoogleFonts.manrope(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    )),
                              ]),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${(p.progressHocPhiAll * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: p.progressHocPhiAll,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _FinStat('Phải nộp', _fmt(p.tongHocPhiAllPhaiDong),
                              Colors.white),
                          _FinStat('Còn lại', _fmt(p.tongHocPhiAllConLai),
                              Colors.white70),
                        ]),
                  ])),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildTodaySchedule(BuildContext ctx, AppProvider p) {
    final list = p.getLichHocHomNay();
    if (p.lichHocState == LoadState.loading && list.isEmpty) {
      return [
        SkeletonBox(width: double.infinity, height: 88, radius: 16),
        const SizedBox(height: 8)
      ];
    }
    if (list.isEmpty) {
      return [_EmptyCard('Hôm nay không có lịch học')];
    }
    return list
        .take(3)
        .map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ScheduleCard(lichHoc: l),
            ))
        .toList();
  }

  List<Widget> _buildUpcomingExams(BuildContext ctx, AppProvider p) {
    final list = p.getUpcomingExams(daysAhead: 30);
    if (list.isEmpty) return [_EmptyCard('Không có lịch thi sắp tới')];
    return list
        .take(3)
        .map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ExamCard(lichThi: e),
            ))
        .toList();
  }

  String _fmt(double v) {
    final f = NumberFormat('#,###', 'vi_VN');
    return v >= 1000000000
        ? '${f.format(v / 1000000000)}B VNĐ'
        : '${f.format(v)} VNĐ';
  }
}

class _FinStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _FinStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Colors.white70, letterSpacing: 1)),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

class _EmptyCard extends StatelessWidget {
  final String msg;
  const _EmptyCard(this.msg);
  @override
  Widget build(BuildContext ctx) => SurfaceCard(
        child: Center(
            child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(msg,
              style: const TextStyle(color: AppTheme.onSurfaceVariant)),
        )),
      );
}
