import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

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
            child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 4, 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryFixed,
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2), width: 2),
              ),
              child:
                  const Icon(Icons.school, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Đại học Kiến trúc Hà Nội',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.25)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.outline, letterSpacing: 1.5)),
              ],
            )),
            ...?actions,
          ]),
        )),
      );
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
          padding: padding ?? const EdgeInsets.all(20),
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
        padding: padding ?? const EdgeInsets.all(24),
        child: child,
      );
}

// ── StatusChip ────────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusChip({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? AppTheme.primary).withOpacity(0.1),
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
  Widget build(BuildContext context) => SizedBox(
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
  const ScheduleCard({super.key, required this.lichHoc});

  @override
  Widget build(BuildContext context) => SurfaceCard(
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
        ]),
      );
}

// ── ExamCard (shared) ─────────────────────────────────────────

class ExamCard extends StatelessWidget {
  final LichThi lichThi;
  const ExamCard({super.key, required this.lichThi});

  @override
  Widget build(BuildContext context) {
    // ✅ Hiển thị "07:30 - 09:30" từ gioBatDau + gioKetThuc
    final gioHienThi = lichThi.gioBatDau.isNotEmpty
        ? (lichThi.gioKetThuc.isNotEmpty
            ? '${lichThi.gioBatDau} - ${lichThi.gioKetThuc}'
            : lichThi.gioBatDau)
        : lichThi.caThi; // fallback sang Ca thi nếu không có giờ

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const StatusChip(label: 'LỊCH THI', color: AppTheme.error),
          if (gioHienThi.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                gioHienThi,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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

        // Hàng 1: Ngày thi + Ca thi + Phòng thi
        Wrap(spacing: 16, runSpacing: 6, children: [
          if (lichThi.ngayThi.isNotEmpty)
            _ExamChip(Icons.calendar_today_outlined, lichThi.ngayThi),
          if (lichThi.caThi.isNotEmpty)
            _ExamChip(Icons.wb_sunny_outlined, lichThi.caThi),
          if (lichThi.phong.isNotEmpty)
            _ExamChip(Icons.location_on_outlined, lichThi.phong),
        ]),
        const SizedBox(height: 6),

        // Hàng 2: Hình thức + Lần thi + Đợt thi
        Wrap(spacing: 16, runSpacing: 6, children: [
          if (lichThi.hinhThucThi.isNotEmpty)
            _ExamChip(Icons.edit_outlined, lichThi.hinhThucThi),
          if (lichThi.lanThi != null && lichThi.lanThi! > 0)
            _ExamChip(Icons.repeat_outlined, 'Lần ${lichThi.lanThi}'),
          if (lichThi.dotThi != null && lichThi.dotThi! > 0)
            _ExamChip(Icons.event_note_outlined, 'Đợt ${lichThi.dotThi}'),
        ]),

        // Hàng 3: Số tín chỉ
        if (lichThi.soTinChi > 0) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 16, children: [
            _ExamChip(Icons.school_outlined, '${lichThi.soTinChi} tín chỉ'),
          ]),
        ],
        if (lichThi.gioBatDau.isNotEmpty && lichThi.gioKetThuc.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 16, children: [
            _ExamChip(Icons.schedule_outlined,
                '${lichThi.gioBatDau} - ${lichThi.gioKetThuc}'),
          ]),
        ],
        // Số báo danh: chỉ chữ in nghiêng
        if (lichThi.sooBaoDanh.isNotEmpty) ...[
          const Divider(height: 20),
          Text(
            'Báo danh: ${lichThi.sooBaoDanh}',
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppTheme.onSurfaceVariant,
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
  const _ExamChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppTheme.outline),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.onSurfaceVariant)),
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
