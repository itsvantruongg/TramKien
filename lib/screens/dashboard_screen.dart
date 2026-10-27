import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int, {DateTime? focusDate})? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          AcademicAppBar(
            subtitle: 'DASHBOARD',
            actions: [
              NotificationBell(onNavigate: onNavigate),
              IconButton(
                icon: (p.isSyncing || p.isSyncingHistory)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync_outlined, color: AppTheme.primary),
                onPressed: () async {
                  await p.syncAll(forceRefresh: true);
                  if (p.lastSyncSkipped && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đang đồng bộ, vui lòng đợi...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: RefreshIndicator(
                  onRefresh: () async {
                    await p.syncAll(forceRefresh: true);
                    if (p.lastSyncSkipped && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đang đồng bộ, vui lòng đợi...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: CustomScrollView(slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
                                          ?.copyWith(
                                              color:
                                                  AppTheme.onSurfaceVariant)),
                                  if (!p.isCacheLoaded && p.student == null)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 4),
                                      child:
                                          SkeletonBox(width: 180, height: 28),
                                    )
                                  else
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
                                  if (p.tongHocPhiConLai > 0) ...[
                                    const SizedBox(height: 12),
                                    TuitionWarningCard(
                                        amount: p.tongHocPhiConLai),
                                  ],
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
                                        child: (!p.isCacheLoaded &&
                                                p.diemSummary == null &&
                                                p.isSyncing)
                                            ? const Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SkeletonBox(
                                                      width: 80,
                                                      height: 12,
                                                      radius: 4),
                                                  SizedBox(height: 12),
                                                  SkeletonBox(
                                                      width: 72,
                                                      height: 36,
                                                      radius: 6),
                                                  SizedBox(height: 20),
                                                  SkeletonBox(
                                                      width: double.infinity,
                                                      height: 6,
                                                      radius: 3),
                                                  SizedBox(height: 8),
                                                  SkeletonBox(
                                                      width: 110,
                                                      height: 12,
                                                      radius: 4),
                                                ],
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('GPA TÍCH LŨY',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                Colors.white70,
                                                          )),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Flexible(
                                                          child: FittedBox(
                                                            fit: BoxFit
                                                                .scaleDown,
                                                            alignment: Alignment
                                                                .bottomLeft,
                                                            child: Text(
                                                                (p.diemSummary
                                                                            ?.tbcTichLuyHe4 ??
                                                                        0.0)
                                                                    .toStringAsFixed(
                                                                        2),
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .displayMedium
                                                                    ?.copyWith(
                                                                      color: Colors
                                                                          .white,
                                                                      height: 1,
                                                                    )),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  bottom: 8,
                                                                  left: 4),
                                                          child: Text('/ 4.0',
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .titleMedium
                                                                  ?.copyWith(
                                                                      color: Colors
                                                                          .white70)),
                                                        ),
                                                      ]),
                                                  const SizedBox(height: 16),
                                                  Text('Tiến độ học tập',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                              color: Colors
                                                                  .white70)),
                                                  const SizedBox(height: 6),
                                                  LinearProgressIndicator(
                                                    value: (p.totalCredits /
                                                            p.curriculumTotalCredits)
                                                        .clamp(0.0, 1.0),
                                                    backgroundColor:
                                                        Colors.white24,
                                                    valueColor:
                                                        const AlwaysStoppedAnimation(
                                                            Colors.white),
                                                    minHeight: 6,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      '${p.totalCredits} / ${p.curriculumTotalCredits} tín chỉ',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                Colors.white70,
                                                            fontWeight:
                                                                FontWeight.w600,
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
                                    child: (!p.isCacheLoaded &&
                                            p.diemSummary == null &&
                                            p.isSyncing)
                                        ? const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SkeletonBox(
                                                  width: 50,
                                                  height: 12,
                                                  radius: 4),
                                              SizedBox(height: 12),
                                              SkeletonBox(
                                                  width: 80,
                                                  height: 80,
                                                  radius: 40),
                                              SizedBox(height: 12),
                                              SkeletonBox(
                                                  width: 70,
                                                  height: 12,
                                                  radius: 4),
                                            ],
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text('TÍN CHỈ',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                          color: AppTheme
                                                              .onSurfaceVariant)),
                                              const SizedBox(height: 12),
                                              CircularProgressWidget(
                                                value: (p.totalCredits /
                                                        p.curriculumTotalCredits)
                                                    .clamp(0.0, 1.0),
                                                center: '${p.totalCredits}',
                                                subtitle:
                                                    'của ${p.curriculumTotalCredits}',
                                                size: 88,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                  'Còn ${(p.curriculumTotalCredits - p.totalCredits).clamp(0, p.curriculumTotalCredits)} TC',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                          color: AppTheme
                                                              .onSurfaceVariant),
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

                          // Lịch học ngày mai
                          SectionHeader(
                            title: 'Lịch học ngày mai',
                            action: 'Xem tất cả',
                            onAction: () => onNavigate?.call(1),
                          ),
                          const SizedBox(height: 12),
                          ..._buildTomorrowSchedule(context, p),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('TỔNG ĐÃ NỘP',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: Colors.white70,
                                                    )),
                                            const SizedBox(height: 4),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                  _fmt(p.tongHocPhiAllDaDong),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                      )),
                                            ),
                                          ]),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${(p.progressHocPhiAll * 100).toStringAsFixed(0)}%',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ]),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: p.progressHocPhiAll,
                                backgroundColor: Colors.white24,
                                valueColor:
                                    const AlwaysStoppedAnimation(Colors.white),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                  child: _FinStat(
                                      'Tổng học phí',
                                      _fmt(p.tongHocPhiAllPhaiDong),
                                      Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _FinStat(
                                    'Còn phải nộp',
                                    _fmt(p.tongHocPhiAllConLai),
                                    p.tongHocPhiAllConLai > 0
                                        ? const Color(0xFFFFAB40)
                                        : Colors.white.withOpacity(0.8),
                                    labelColor: p.tongHocPhiAllConLai > 0
                                        ? const Color(0xFFFFB74D)
                                        : null,
                                  ),
                                ),
                              ]),
                            ])),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTodaySchedule(BuildContext ctx, AppProvider p) {
    final today = DateTime.now();
    return _buildScheduleList(
      ctx,
      p,
      p.getLichHocHomNay(),
      'Hôm nay không có lịch học',
      onItemTap: (l) => onNavigate?.call(1, focusDate: today),
      onViewAllTap: () => onNavigate?.call(1, focusDate: today),
    );
  }

  List<Widget> _buildTomorrowSchedule(BuildContext ctx, AppProvider p) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return _buildScheduleList(
      ctx,
      p,
      p.getLichHocNgayMai(),
      'Ngày mai không có lịch học',
      onItemTap: (l) => onNavigate?.call(1, focusDate: tomorrow),
      onViewAllTap: () => onNavigate?.call(1, focusDate: tomorrow),
    );
  }

  List<Widget> _buildScheduleList(
    BuildContext ctx,
    AppProvider p,
    List<LichHoc> list,
    String emptyMessage, {
    void Function(LichHoc)? onItemTap,
    VoidCallback? onViewAllTap,
  }) {
    final bool hasCachedSchedule = p.isCacheLoaded || p.lichHoc.isNotEmpty;
    if (!hasCachedSchedule &&
        (p.isSyncing || p.lichHocState == LoadState.loading)) {
      return [
        const SkeletonBox(width: double.infinity, height: 88, radius: 16),
        const SizedBox(height: 8)
      ];
    }
    if (list.isEmpty) {
      return [_EmptyCard(emptyMessage)];
    }
    final widgets = list
        .take(2)
        .map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PressScale(
                onTap: onItemTap != null ? () => onItemTap(l) : null,
                child: ScheduleCard(lichHoc: l),
              ),
            ))
        .toList();

    if (list.length > 2) {
      final remaining = list.length - 2;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: Center(
            child: InkWell(
              onTap: onViewAllTap ?? () => onNavigate?.call(1),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  '(+$remaining ca học khác • Xem tất cả)',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildUpcomingExams(BuildContext ctx, AppProvider p) {
    final list = p.getUpcomingExams(daysAhead: 30);
    if (list.isEmpty) return [const _EmptyCard('Không có lịch thi sắp tới')];
    return list
        .take(3)
        .map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PressScale(
                onTap: () {
                  final examDate = e.ngayThiDate;
                  onNavigate?.call(1, focusDate: examDate);
                },
                child: ExamCard(lichThi: e),
              ),
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
  final Color? labelColor;
  const _FinStat(this.label, this.value, this.color, {this.labelColor});
  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                color: labelColor ?? Colors.white.withOpacity(0.7),
                letterSpacing: 1)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700, color: color, height: 1.2)),
        ),
      ],
    );
  }
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
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.onSurfaceVariant)),
        )),
      );
}
