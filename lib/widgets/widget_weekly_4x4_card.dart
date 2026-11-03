import 'package:flutter/material.dart';
import '../services/widget/widget_service.dart';
import 'widget_today_2x2_card.dart';

/// Giao diện Widget Tuần 4x4 (~320x318 dp/pt, bo góc 20dp, padding 12dp, viền 0.5dp)
/// Tuân thủ nghiêm ngặt SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 1, 3.4, 3.5, 3.6, 7
class WidgetWeekly4x4Card extends StatelessWidget {
  final Weekly4x4Data data;
  final bool isDarkMode;
  final VoidCallback? onPrevWeek;
  final VoidCallback? onNextWeek;
  final ValueChanged<WeeklySessionItem>? onSessionTap;
  final VoidCallback? onTap;

  const WidgetWeekly4x4Card({
    super.key,
    required this.data,
    this.isDarkMode = false,
    this.onPrevWeek,
    this.onNextWeek,
    this.onSessionTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? WidgetDesignTokens.darkBg : WidgetDesignTokens.lightBg;
    final borderColor = isDarkMode ? WidgetDesignTokens.darkBorder : WidgetDesignTokens.lightBorder;

    return Semantics(
      label: 'Widget Tuần 4x4: ${data.title}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 320,
          height: 318,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Dòng tiêu đề kèm nút ‹ › chuyển tuần (cỡ 12, vừa)
              _buildHeader(context),
              const SizedBox(height: 8),

              // 2. Dải 7 ngày (T2..CN, số lượng môn / ·, hôm nay viên thuốc accent)
              _buildDaysStrip(context),
              const SizedBox(height: 8),

              // Đường kẻ phân cách siêu mảnh 0.5dp
              Divider(
                height: 1,
                thickness: 0.5,
                color: borderColor,
              ),
              const SizedBox(height: 6),

              // 3. Danh sách chi tiết theo nhóm ngày hoặc Empty State
              Expanded(
                child: !data.hasSnapshot
                    ? _buildAuthEmptyState(context)
                    : _buildDetailedList(context),
              ),

              // 4. Footer nếu có tràn chỗ ("+N môn nữa" - AC-11)
              if (data.footerText != null) ...[
                const SizedBox(height: 4),
                _buildFooter(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Dòng tiêu đề "Tuần dd/MM – dd/MM" (cỡ 12, vừa) kèm nút ‹ › chuyển tuần
  Widget _buildHeader(BuildContext context) {
    final textPrimary = isDarkMode
        ? WidgetDesignTokens.darkTextPrimary
        : WidgetDesignTokens.lightTextPrimary;
    final textSecondary = isDarkMode
        ? WidgetDesignTokens.darkTextSecondary
        : WidgetDesignTokens.lightTextSecondary;

    return Row(
      children: [
        // Nút lùi tuần ‹
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPrevWeek,
          child: Container(
            width: 28,
            height: 24,
            alignment: Alignment.center,
            child: Text(
              '‹',
              style: TextStyle(
                color: textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'sans-serif-medium',
                height: 1.0,
              ),
            ),
          ),
        ),
        // Tiêu đề tuần căn giữa
        Expanded(
          child: Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'sans-serif-medium',
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Nút tiến tuần ›
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onNextWeek,
          child: Container(
            width: 28,
            height: 24,
            alignment: Alignment.center,
            child: Text(
              '›',
              style: TextStyle(
                color: textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'sans-serif-medium',
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Dải 7 ngày (Hàng nhãn T2..CN cỡ 11 phụ, Hàng số môn / · mờ, Hôm nay viên thuốc accent)
  Widget _buildDaysStrip(BuildContext context) {
    final textPrimary = isDarkMode
        ? WidgetDesignTokens.darkTextPrimary
        : WidgetDesignTokens.lightTextPrimary;
    final textSecondary = isDarkMode
        ? WidgetDesignTokens.darkTextSecondary
        : WidgetDesignTokens.lightTextSecondary;
    final textDimmed = isDarkMode
        ? WidgetDesignTokens.darkTextDimmed
        : WidgetDesignTokens.lightTextDimmed;
    final accentColor = isDarkMode
        ? WidgetDesignTokens.darkAccent
        : WidgetDesignTokens.lightAccent;
    final accentOn = isDarkMode
        ? WidgetDesignTokens.darkAccentOn
        : WidgetDesignTokens.lightAccentOn;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: data.daysStrip.map((dayItem) {
        final isToday = dayItem.isToday;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hàng nhãn: T2 T3 T4 T5 T6 T7 CN (cỡ 11, màu phụ)
              Text(
                dayItem.weekdayLabel,
                style: TextStyle(
                  color: isToday ? accentColor : textSecondary,
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                  fontFamily: 'sans-serif-medium',
                ),
              ),
              const SizedBox(height: 4),

              // Hàng ngày trong tháng (ví dụ 26/10); Hôm nay là viên thuốc accent đầy
              Builder(builder: (context) {
                final dateStr = '${dayItem.date.day.toString().padLeft(2, '0')}/${dayItem.date.month.toString().padLeft(2, '0')}';
                if (isToday) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      dateStr,
                      style: TextStyle(
                        color: accentOn,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'sans-serif-medium',
                        height: 1.1,
                      ),
                    ),
                  );
                } else {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      dateStr,
                      style: TextStyle(
                        color: dayItem.isPastDay ? textDimmed : textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'sans-serif-medium',
                        height: 1.1,
                      ),
                    ),
                  );
                }
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Trạng thái trống khi chưa có snapshot (AC-10)
  Widget _buildAuthEmptyState(BuildContext context) {
    final textSecondary = isDarkMode
        ? WidgetDesignTokens.darkTextSecondary
        : WidgetDesignTokens.lightTextSecondary;

    return Center(
      child: Text(
        data.authMessage ?? 'Đăng nhập để xem lịch',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'sans-serif-medium',
        ),
      ),
    );
  }

  /// Danh sách chi tiết theo nhóm ngày
  Widget _buildDetailedList(BuildContext context) {
    if (data.items.isEmpty) {
      final textDimmed = isDarkMode
          ? WidgetDesignTokens.darkTextDimmed
          : WidgetDesignTokens.lightTextDimmed;
      return Center(
        child: Text(
          'Tuần này không có lịch',
          style: TextStyle(
            color: textDimmed,
            fontSize: 11,
            fontFamily: 'sans-serif-medium',
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: data.items.map((item) {
          switch (item.type) {
            case WeeklyItemType.dayHeader:
              return _buildDayHeaderRow(context, item.dayGroup!);
            case WeeklyItemType.session:
              return _buildSessionRow(context, item.sessionItem!);
            case WeeklyItemType.mergedEmptyDays:
              return _buildMergedEmptyDaysRow(context, item.emptyDaysItem!);
          }
        }).toList(),
      ),
    );
  }

  /// Tiêu đề nhóm ngày (cỡ 12.5, vừa): "Hôm nay · Thứ dd/MM", "Thứ dd/MM"...
  Widget _buildDayHeaderRow(BuildContext context, WeeklyDayGroup group) {
    final textPrimary = isDarkMode
        ? WidgetDesignTokens.darkTextPrimary
        : WidgetDesignTokens.lightTextPrimary;
    final accentColor = isDarkMode
        ? WidgetDesignTokens.darkAccent
        : WidgetDesignTokens.lightAccent;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        group.headerTitle,
        style: TextStyle(
          color: group.isToday ? accentColor : textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          fontFamily: 'sans-serif-medium',
        ),
      ),
    );
  }

  /// Hàng môn học cao 28dp (to rõ, thoáng đãng)
  Widget _buildSessionRow(BuildContext context, WeeklySessionItem item) {
    final textPrimary = isDarkMode
        ? WidgetDesignTokens.darkTextPrimary
        : WidgetDesignTokens.lightTextPrimary;
    final textSecondary = isDarkMode
        ? WidgetDesignTokens.darkTextSecondary
        : WidgetDesignTokens.lightTextSecondary;
    final textDimmed = isDarkMode
        ? WidgetDesignTokens.darkTextDimmed
        : WidgetDesignTokens.lightTextDimmed;

    // Màu thanh chỉ báo 3.5x20dp
    final Color barColor;
    // Màu chữ tên môn và phòng
    final Color rowTextColor;
    final Color timeColor;

    if (item.isToday && item.isPast) {
      // Môn đã qua của hôm nay: thanh màu chuyển màu xám, toàn hàng chuyển màu mờ #888780
      barColor = isDarkMode ? const Color(0xFF444441) : const Color(0xFFD3D1C7);
      rowTextColor = textDimmed;
      timeColor = textDimmed;
    } else if (item.isExam) {
      // Môn thi: Vạch màu đỏ, tên môn in vừa kèm tiền tố "Thi "
      barColor = const Color(0xFFE24B4A);
      rowTextColor = isDarkMode ? const Color(0xFFF7C1C1) : const Color(0xFF791F1F);
      timeColor = textSecondary;
    } else {
      // Môn học thường: Bảng 8 màu theo colorIndex
      final colorTokens = isDarkMode
          ? WidgetDesignTokens.darkSubjectColors
          : WidgetDesignTokens.lightSubjectColors;
      final safeColorIdx = item.colorIndex.clamp(0, colorTokens.length - 1);
      barColor = colorTokens[safeColorIdx].text;
      rowTextColor = textPrimary;
      timeColor = textSecondary;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSessionTap?.call(item),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thanh màu 3.5x20dp bo 2dp
            Container(
              width: 3.5,
              height: 20,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),

            // Giờ bắt đầu "HH:mm" (rộng 42dp, cỡ 12, màu phụ)
            SizedBox(
              width: 42,
              child: Text(
                item.timeStr,
                style: TextStyle(
                  color: timeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'sans-serif-medium',
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Tên môn (cỡ 13.5, cắt "…")
            Expanded(
              child: Text(
                item.displayTitle,
                style: TextStyle(
                  color: rowTextColor,
                  fontSize: 13.5,
                  fontWeight: item.isExam ? FontWeight.w600 : FontWeight.w400,
                  fontFamily: 'sans-serif-medium',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // Phòng căn phải (cỡ 12, phụ)
            if (item.roomStr.isNotEmpty)
              Text(
                item.roomStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: (item.isToday && item.isPast) ? textDimmed : textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'sans-serif-medium',
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Dòng gộp các ngày trống liên tiếp (ví dụ "T7 – CN: không có lịch") chia 2 cột thẳng hàng
  Widget _buildMergedEmptyDaysRow(BuildContext context, WeeklyMergedEmptyDays item) {
    final textSecondary = isDarkMode
        ? WidgetDesignTokens.darkTextSecondary
        : WidgetDesignTokens.lightTextSecondary;
    final textDimmed = isDarkMode
        ? WidgetDesignTokens.darkTextDimmed
        : WidgetDesignTokens.lightTextDimmed;

    final parts = item.displayTitle.split(':');
    final dayLabel = parts[0].trim();
    final statusLabel = parts.length > 1 ? parts.sublist(1).join(':').trim() : 'Không có lịch';

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: 0,
            child: Text(item.displayTitle, style: const TextStyle(fontSize: 1)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cột 1: Thứ/Ngày trống (bắt đầu sát lề trái, rộng 53.5dp + 6dp để cột 2 bắt đầu đúng mốc 59.5dp thẳng cột tên môn)
              SizedBox(
                width: 53.5,
                child: Text(
                  dayLabel,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'sans-serif-medium',
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Cột 2: "Không có lịch" (bắt đầu tại mốc 59.5dp, cỡ chữ 13.5 đồng bộ với tên môn học)
              Expanded(
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: textDimmed,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'sans-serif-medium',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Footer tràn chỗ "+N môn nữa" (iOS / Overflow)
  Widget _buildFooter(BuildContext context) {
    final textSecondary = isDarkMode
        ? WidgetDesignTokens.darkTextSecondary
        : WidgetDesignTokens.lightTextSecondary;

    return Center(
      child: Text(
        data.footerText!,
        style: TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          fontFamily: 'sans-serif-medium',
        ),
      ),
    );
  }
}
