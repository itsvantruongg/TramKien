import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/notifications_screen.dart';

// ── AcademicAppBar ────────────────────────────────────────────

class AcademicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? subtitle;
  final List<Widget>? actions;

  const AcademicAppBar({super.key, this.subtitle, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.7),
          boxShadow: [
            BoxShadow(
              color: AppTheme.onSurface.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          left: false,
          right: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryFixed,
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.school,
                      color: AppTheme.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Đại học Kiến trúc Hà Nội',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 18,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              height:
                                  1.2, // Tăng nhẹ từ 1.1 lên 1.2 để chữ thoáng hơn
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.outline,
                                    letterSpacing: 1.2,
                                    height: 1.2, // Tăng nhẹ từ 1.0 lên 1.2
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                ...?actions,
              ],
            ),
          ),
        ),
      );
}

// ── NotificationBell ──────────────────────────────────────────

class NotificationBell extends StatelessWidget {
  final void Function(int)? onNavigate;
  const NotificationBell({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon:
              const Icon(Icons.notifications_outlined, color: AppTheme.primary),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(onNavigate: onNavigate),
              ),
            );
            // Trigger rebuild để cập nhật badge
            if (context.mounted) {
              (context as Element).markNeedsBuild();
            }
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
                  p.unreadNotifCount > 9 ? '9+' : '${p.unreadNotifCount}',
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
    );
  }
}

// ── SurfaceCard ───────────────────────────────────────────────

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color ?? AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: AppTheme.onSurface.withOpacity(0.04),
                blurRadius: 20,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              )
            ],
          ),
          padding: padding ??
              (MediaQuery.of(context).size.width < 360
                  ? const EdgeInsets.all(16)
                  : const EdgeInsets.all(20)),
          child: child,
        ),
      );
}

// ── GradientCard ──────────────────────────────────────────────

class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const GradientCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            )
          ],
        ),
        padding: padding ??
            (MediaQuery.of(context).size.width < 360
                ? const EdgeInsets.all(16)
                : const EdgeInsets.all(24)),
        child: child,
      );
}

// ── StatusChip ────────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? backgroundColor;

  const StatusChip({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor ?? (color ?? AppTheme.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: color ?? AppTheme.primary,
            )),
      );
}

enum StudentAcademicStatus {
  dangHoc,
  baoLuu,
  thoiHoc,
  daTotNghiep,
  dinhChi,
}

extension StudentAcademicStatusExt on StudentAcademicStatus {
  String get label {
    switch (this) {
      case StudentAcademicStatus.dangHoc:
        return 'ĐANG HỌC';
      case StudentAcademicStatus.baoLuu:
        return 'BẢO LƯU';
      case StudentAcademicStatus.thoiHoc:
        return 'THÔI HỌC';
      case StudentAcademicStatus.daTotNghiep:
        return 'ĐÃ TỐT NGHIỆP';
      case StudentAcademicStatus.dinhChi:
        return 'ĐÌNH CHỈ';
    }
  }

  Color get textColor {
    switch (this) {
      case StudentAcademicStatus.dangHoc:
        return AppTheme.primary;
      case StudentAcademicStatus.baoLuu:
        return const Color(0xFFF9A825);
      case StudentAcademicStatus.thoiHoc:
        return AppTheme.error;
      case StudentAcademicStatus.daTotNghiep:
        return const Color(0xFF2E7D32);
      case StudentAcademicStatus.dinhChi:
        return const Color(0xFFE65100);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case StudentAcademicStatus.dangHoc:
        return AppTheme.primary.withOpacity(0.1);
      case StudentAcademicStatus.baoLuu:
        return const Color(0xFFFFF9C4);
      case StudentAcademicStatus.thoiHoc:
        return AppTheme.error.withOpacity(0.1);
      case StudentAcademicStatus.daTotNghiep:
        return const Color(0xFFE8F5E9);
      case StudentAcademicStatus.dinhChi:
        return const Color(0xFFFFF3E0);
    }
  }
}

class AcademicStatusChip extends StatelessWidget {
  final StudentAcademicStatus status;
  const AcademicStatusChip(
      {super.key, this.status = StudentAcademicStatus.dangHoc});

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: status.label,
      color: status.textColor,
      backgroundColor: status.backgroundColor,
    );
  }
}

// ── CircularProgressWidget ────────────────────────────────────

class CircularProgressWidget extends StatelessWidget {
  final double value;
  final String center, subtitle;
  final double size;

  const CircularProgressWidget({
    super.key,
    required this.value,
    required this.center,
    required this.subtitle,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  strokeCap: StrokeCap.round,
                )),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppTheme.onSurfaceVariant)),
            ]),
          ]),
        ),
      );
}

// ── GradeBadge ────────────────────────────────────────────────

class GradeBadge extends StatelessWidget {
  final String grade;
  const GradeBadge({super.key, required this.grade});

  Color get _color {
    switch (grade) {
      case 'A+':
      case 'A':
        return const Color(0xFF2E7D32);
      case 'B+':
      case 'B':
        return AppTheme.primary;
      case 'C+':
      case 'C':
        return AppTheme.tertiary;
      case 'D+':
      case 'D':
        return const Color(0xFFE65100);
      default:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(grade,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: _color)),
      );
}

// ── SectionHeader ─────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader(
      {super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
          if (action != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Material(
                color: Colors.transparent, // Trong suốt lúc bình thường
                child: InkWell(
                  onTap: onAction,
                  splashColor: AppTheme.primaryFixed,
                  highlightColor: AppTheme.primaryFixed,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(action!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
        ]),
      );
}

// ── SkeletonBox ───────────────────────────────────────────────

class SkeletonBox extends StatefulWidget {
  final double width, height, radius;
  const SkeletonBox(
      {super.key, required this.width, required this.height, this.radius = 8});
  @override
  State<SkeletonBox> createState() => _SkeletonState();
}

class _SkeletonState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.7)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh.withOpacity(_anim.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

// ── CountdownBadge ────────────────────────────────────────────

class CountdownBadge extends StatelessWidget {
  final int days;
  const CountdownBadge({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (days <= 0) {
      color = AppTheme.error;
      label = 'Hôm nay';
    } else if (days <= 3) {
      color = AppTheme.error;
      label = 'Còn $days ngày';
    } else if (days <= 7) {
      color = AppTheme.tertiary;
      label = 'Còn $days ngày';
    } else {
      color = AppTheme.primary;
      label = 'Còn $days ngày';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── ScheduleCard (shared) ─────────────────────────────────────

class ScheduleCard extends StatelessWidget {
  final LichHoc lichHoc;
  final VoidCallback? onTap;
  const ScheduleCard({super.key, required this.lichHoc, this.onTap});

  @override
  Widget build(BuildContext context) => SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const StatusChip(label: 'LỊCH HỌC', color: AppTheme.primary),
            Row(children: [
              const Icon(Icons.schedule_outlined,
                  size: 14, color: AppTheme.outline),
              const SizedBox(width: 4),
              Text(lichHoc.gioHoc,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppTheme.onSurfaceVariant)),
            ]),
          ]),
          const SizedBox(height: 10),
          Text(lichHoc.tenHocPhan,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 6, children: [
            _InfoChip(Icons.location_on_outlined,
                lichHoc.phong.isNotEmpty ? lichHoc.phong : '—'),
            _InfoChip(Icons.class_outlined, 'Tiết ${lichHoc.tiet}'),
            if (lichHoc.giaoVien.isNotEmpty)
              _InfoChip(Icons.person_outline, lichHoc.giaoVien),
          ]),
          if (lichHoc.note != null && lichHoc.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lichHoc.note!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.brown,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ]),
      );
}

// ── ExamCard (shared) ─────────────────────────────────────────

class ExamCard extends StatelessWidget {
  final LichThi lichThi;
  final VoidCallback? onTap;
  const ExamCard({super.key, required this.lichThi, this.onTap});

  @override
  Widget build(BuildContext context) {
    // ✅ Hiển thị "07:30 - 09:30" từ gioBatDau + gioKetThuc
    final gioHienThi = lichThi.gioBatDau.isNotEmpty
        ? (lichThi.gioKetThuc.isNotEmpty
            ? '${lichThi.gioBatDau} - ${lichThi.gioKetThuc}'
            : lichThi.gioBatDau)
        : lichThi.caThi; // fallback sang Ca thi nếu không có giờ

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const StatusChip(label: 'LỊCH THI', color: AppTheme.error),
          if (gioHienThi.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.outlineVariant, width: 1),
              ),
              child: Text(
                gioHienThi,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),

        Text(lichThi.tenMonHoc,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (lichThi.maMonHoc.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('Mã: ${lichThi.maMonHoc}',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 10),

        // Chi tiết lịch thi (thứ tự: địa điểm -> Ca thi -> Hình thức -> Lần thi -> Đợt thi -> Số tín chỉ)
        Wrap(spacing: 16, runSpacing: 6, children: [
          if (lichThi.phong.isNotEmpty)
            _ExamChip(Icons.location_on_outlined, lichThi.phong, isBold: true),
          if (lichThi.caThi.isNotEmpty)
            _ExamChip(Icons.wb_sunny_outlined, lichThi.caThi),
          if (lichThi.hinhThucThi.isNotEmpty)
            _ExamChip(Icons.edit_outlined, lichThi.hinhThucThi),
          if (lichThi.lanThi != null && lichThi.lanThi! > 0)
            _ExamChip(Icons.repeat_outlined, 'Lần ${lichThi.lanThi}'),
          if (lichThi.dotThi != null && lichThi.dotThi! > 0)
            _ExamChip(Icons.event_note_outlined, 'Đợt ${lichThi.dotThi}'),
          if (lichThi.soTinChi > 0)
            _ExamChip(Icons.school_outlined, '${lichThi.soTinChi} tín chỉ'),
        ]),

        // Số báo danh (được làm đậm)
        if (lichThi.sooBaoDanh.isNotEmpty) ...[
          const Divider(height: 20),
          Text(
            'Báo danh: ${lichThi.sooBaoDanh}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: AppTheme.onSurface,
            ),
          ),
        ],
        if (lichThi.note != null && lichThi.note!.isNotEmpty) ...[
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 14, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lichThi.note!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.brown,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

class _ExamChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isBold;
  const _ExamChip(this.icon, this.label, {this.isBold = false});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: isBold ? AppTheme.onSurface : AppTheme.outline),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isBold ? AppTheme.onSurface : AppTheme.onSurfaceVariant,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                )),
      ]);
}

// ── InfoChip (internal helper) ────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppTheme.outline),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.onSurfaceVariant)),
      ]);
}

// ── PressScale ────────────────────────────────────────────────
/// Widget tạo hiệu ứng co lại + mờ khi nhấn, bật lại khi thả.
/// Dùng được cho card, button, bất kỳ widget nào.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.82 : 1.0,
          duration: widget.duration,
          child: widget.child,
        ),
      ),
    );
  }
}

// ── TuitionWarningCard ────────────────────────────────────────

class TuitionWarningCard extends StatelessWidget {
  final double amount;
  const TuitionWarningCard({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,###', 'vi_VN');
    const redDark = Color(0xFFC62828);
    const redDarker = Color(0xFFB71C1C);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: redDark,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Học phí chưa nộp: ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: redDark,
                ),
              ),
              Text(
                '${f.format(amount)} VNĐ',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: redDarker,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: Color(0xFFFECACA),
            ),
          ),
          const Text(
            'Vui lòng thanh toán sớm để tránh ảnh hưởng đến việc đăng ký học phần kỳ tới.',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: redDark,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
