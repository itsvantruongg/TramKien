import 'package:flutter/material.dart';
import '../services/widget/widget_service.dart';

/// Thẻ mô phỏng Widget Màn hình khóa (Lock Screen) iOS 16+ & Android
/// Đơn sắc (Monochrome) theo SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 3.5
/// Phục vụ Flutter testing & Live Preview trong Widget Studio

/// 1. accessoryRectangular (~160x58 dp/pt)
class WidgetLockScreenRectangularCard extends StatelessWidget {
  final LockScreenRectangularData data;
  final bool isLightWallpaper;
  final VoidCallback? onTap;

  const WidgetLockScreenRectangularCard({
    super.key,
    required this.data,
    this.isLightWallpaper = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Đơn sắc: Chữ trắng trên nền tối (mặc định lock screen), chữ đen trên nền sáng
    final textColor = isLightWallpaper ? const Color(0xFF1F1F1E) : Colors.white;
    final secondaryTextColor = isLightWallpaper
        ? const Color(0xFF1F1F1E).withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.7);
    final cardBg = isLightWallpaper
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.12);
    final borderColor = isLightWallpaper
        ? Colors.black.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.2);

    return Semantics(
      button: true,
      label: 'Lock Screen Rectangular: ${data.line1} - ${data.line2}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 160,
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dòng 1: "Đang học · HH:mm" / "Đang thi · HH:mm" / "Tiếp theo · HH:mm" (font vừa 500)
              Text(
                data.line1,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Dòng 2: Tên môn học (1 dòng, cắt "…")
              if (data.line2.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  data.line2,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: textColor,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Dòng 3: "phòng · còn N phút" (bỏ khi ca thi endEstimated = true hoặc null)
              if (data.line3 != null && data.line3!.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  data.line3!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w400,
                    color: secondaryTextColor,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 2. accessoryCircular (~64x64 dp/pt)
class WidgetLockScreenCircularCard extends StatelessWidget {
  final LockScreenCircularData data;
  final bool isLightWallpaper;
  final VoidCallback? onTap;

  const WidgetLockScreenCircularCard({
    super.key,
    required this.data,
    this.isLightWallpaper = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isLightWallpaper ? const Color(0xFF1F1F1E) : Colors.white;
    final cardBg = isLightWallpaper
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.12);
    final progressTrack = isLightWallpaper
        ? Colors.black.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.25);
    final progressFill = textColor;

    return Semantics(
      button: true,
      label: 'Lock Screen Circular: ${data.centerText}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cardBg,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vòng cung Gauge / ProgressView (0.0..1.0)
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  value: data.progress > 0 ? data.progress : null,
                  strokeWidth: 3.5,
                  backgroundColor: progressTrack,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    data.progress > 0 ? progressFill : Colors.transparent,
                  ),
                ),
              ),

              // Chữ ở giữa: Giờ bắt đầu môn kế tiếp (định dạng HH:mm)
              Text(
                data.centerText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3. accessoryInline (1 dòng duy nhất)
class WidgetLockScreenInlineCard extends StatelessWidget {
  final LockScreenInlineData data;
  final bool isLightWallpaper;
  final VoidCallback? onTap;

  const WidgetLockScreenInlineCard({
    super.key,
    required this.data,
    this.isLightWallpaper = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isLightWallpaper ? const Color(0xFF1F1F1E) : Colors.white;
    final cardBg = isLightWallpaper
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.12);
    final borderColor = isLightWallpaper
        ? Colors.black.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.2);

    return Semantics(
      button: true,
      label: 'Lock Screen Inline: ${data.text}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: textColor,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  data.text,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Composite: Bộ 3 widget Lock Screen hiển thị cùng nhau
class WidgetLockScreenPreviewSet extends StatelessWidget {
  final LockScreenData data;
  final bool isLightWallpaper;

  const WidgetLockScreenPreviewSet({
    super.key,
    required this.data,
    this.isLightWallpaper = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isLightWallpaper ? const Color(0xFF1F1F1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLightWallpaper ? const Color(0xFFE8E8E6) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MÀN HÌNH KHÓA (LOCK SCREEN)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          // Inline
          WidgetLockScreenInlineCard(
            data: data.inline,
            isLightWallpaper: isLightWallpaper,
          ),
          const SizedBox(height: 10),
          // Row of Rectangular & Circular
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WidgetLockScreenRectangularCard(
                data: data.rectangular,
                isLightWallpaper: isLightWallpaper,
              ),
              const SizedBox(width: 12),
              WidgetLockScreenCircularCard(
                data: data.circular,
                isLightWallpaper: isLightWallpaper,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
