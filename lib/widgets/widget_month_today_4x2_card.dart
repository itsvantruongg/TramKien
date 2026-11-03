import 'package:flutter/material.dart';
import '../services/widget/widget_service.dart';
import 'widget_today_2x2_card.dart';

/// Widget Tháng + Hôm nay 4x2 (~320x150 dp/pt, bo góc 20dp, padding 12dp, viền 0.5dp)
/// Tuân thủ SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 1, 3.2, 7
class WidgetMonthToday4x2Card extends StatelessWidget {
  final MonthToday4x2Data data;
  final bool isDarkMode;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;
  final ValueChanged<MonthGridDay>? onDayTap;
  final ValueChanged<MonthTodayCardItem>? onCardTap;

  const WidgetMonthToday4x2Card({
    super.key,
    required this.data,
    this.isDarkMode = false,
    this.onPrevMonth,
    this.onNextMonth,
    this.onDayTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? WidgetDesignTokens.darkBg : WidgetDesignTokens.lightBg;
    final borderColor = isDarkMode ? WidgetDesignTokens.darkBorder : WidgetDesignTokens.lightBorder;

    return Semantics(
      label: 'Widget Tháng + Hôm nay 4x2',
      child: Container(
        width: 320,
        height: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nửa trái: Lưới tháng
            Expanded(
              child: _buildLeftMonthGrid(context),
            ),
            const SizedBox(width: 10),
            // Nửa phải: Lịch hôm nay
            Expanded(
              child: _buildRightTodaySchedule(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Nửa trái: Lưới tháng
  Widget _buildLeftMonthGrid(BuildContext context) {
    final textPrimary = isDarkMode ? WidgetDesignTokens.darkTextPrimary : WidgetDesignTokens.lightTextPrimary;
    final textSecondary = isDarkMode ? WidgetDesignTokens.darkTextSecondary : WidgetDesignTokens.lightTextSecondary;

    final grid = data.monthGrid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hàng tiêu đề: Nút ‹ (trái), "Tháng M/YYYY" (cỡ 12, vừa), nút › (phải)
        Row(
          children: [
            InkWell(
              onTap: onPrevMonth,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: Text(
                  '‹',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    grid.monthTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onNextMonth,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: Text(
                  '›',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),

        // Hàng thứ: T2 T3 T4 T5 T6 T7 CN (cỡ 11, phụ)
        Row(
          children: grid.weekdayHeaders.map((header) {
            return Expanded(
              child: Center(
                child: Text(
                  header,
                  style: TextStyle(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w400,
                    color: textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 2),

        // Lưới ngày (tối đa 6 hàng)
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: grid.rows.map((row) {
              return Expanded(
                child: Row(
                  children: row.map((cell) {
                    return Expanded(
                      child: _buildDayCell(cell),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Ô ngày trong lưới tháng (cao ~17dp)
  Widget _buildDayCell(MonthGridDay? cell) {
    if (cell == null) {
      return const SizedBox.shrink();
    }

    final textPrimary = isDarkMode ? WidgetDesignTokens.darkTextPrimary : WidgetDesignTokens.lightTextPrimary;
    final textSecondary = isDarkMode ? WidgetDesignTokens.darkTextSecondary : WidgetDesignTokens.lightTextSecondary;
    final accentBg = isDarkMode ? WidgetDesignTokens.darkAccent : WidgetDesignTokens.lightAccent;
    final accentOn = isDarkMode ? WidgetDesignTokens.darkAccentOn : WidgetDesignTokens.lightAccentOn;
    final examColor = isDarkMode ? WidgetDesignTokens.darkExamText : WidgetDesignTokens.lightExamText;

    Color dayTextColor;
    FontWeight dayFontWeight;

    if (cell.isToday) {
      dayTextColor = accentOn;
      dayFontWeight = FontWeight.w500;
    } else if (cell.hasSchedule) {
      dayTextColor = textPrimary;
      dayFontWeight = FontWeight.w500;
    } else {
      dayTextColor = textSecondary;
      dayFontWeight = FontWeight.w400;
    }

    // Hôm nay: Nền tròn accent đầy quanh số
    Widget numberWidget = Text(
      '${cell.day}',
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: dayFontWeight,
        color: dayTextColor,
        height: 1.0,
      ),
    );

    if (cell.isToday) {
      numberWidget = Container(
        width: 14,
        height: 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accentBg,
          shape: BoxShape.circle,
        ),
        child: numberWidget,
      );
    }

    // Chấm đánh dấu dưới số (cao 3pt)
    Widget? dotWidget;
    if (cell.isToday) {
      // NẾU hôm nay có lịch thi: vòng tròn accent kèm chấm đỏ nhỏ 3pt nằm phía DƯỚI vòng tròn (không nằm trong vòng tròn)
      if (cell.hasExam) {
        dotWidget = Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: examColor,
            shape: BoxShape.circle,
          ),
        );
      }
    } else if (cell.hasExam) {
      // Ngày có thi -> Chấm đỏ 3pt
      dotWidget = Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: examColor,
          shape: BoxShape.circle,
        ),
      );
    } else if (cell.hasClasses) {
      // Ngày có học -> Chấm 3pt dưới số (màu phụ)
      dotWidget = Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: textSecondary,
          shape: BoxShape.circle,
        ),
      );
    }

    return InkWell(
      onTap: () => onDayTap?.call(cell),
      borderRadius: BorderRadius.circular(4),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              numberWidget,
              const SizedBox(height: 0.5),
              if (dotWidget != null)
                dotWidget
              else
                const SizedBox(height: 3.5),
            ],
          ),
        ),
      ),
    );
  }

  /// Nửa phải: Lịch hôm nay
  Widget _buildRightTodaySchedule(BuildContext context) {
    final textPrimary = isDarkMode ? WidgetDesignTokens.darkTextPrimary : WidgetDesignTokens.lightTextPrimary;
    final textSecondary = isDarkMode ? WidgetDesignTokens.darkTextSecondary : WidgetDesignTokens.lightTextSecondary;

    final schedule = data.todaySchedule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dòng đầu: "Thứ, dd/MM" (cỡ 12, vừa) bên trái; "N môn" (cỡ 11, màu phụ) bên phải
        Row(
          children: [
            Expanded(
              child: Text(
                schedule.headerLeft,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              schedule.headerRight,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Thẻ môn hoặc trạng thái trống
        if (schedule.visibleCards.isEmpty)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  schedule.emptyTitle ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                if (schedule.emptySubtitle != null &&
                    schedule.emptySubtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    schedule.emptySubtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          )
        else
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < schedule.visibleCards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  _buildCourseCard(schedule.visibleCards[i]),
                ],
                // Footer: "+N môn nữa" (cỡ 11, phụ) nếu còn ca học tiếp theo (chỉ hiện khi N > 0, không hiện +0)
                if (schedule.overflowLabel != null)
                  Text(
                    schedule.overflowLabel!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Thẻ môn (Tối đa 2 thẻ môn, mỗi thẻ 2 dòng)
  Widget _buildCourseCard(MonthTodayCardItem cardItem) {
    // Màu theo token
    final Color cardBg;
    final Color titleColor;
    final Color subColor;

    if (cardItem.isExam) {
      cardBg = isDarkMode ? WidgetDesignTokens.darkExamBg : WidgetDesignTokens.lightExamBg;
      titleColor = isDarkMode ? Colors.white : WidgetDesignTokens.lightExamText;
      subColor = isDarkMode ? WidgetDesignTokens.darkExamText : WidgetDesignTokens.lightExamText;
    } else {
      final colorTokens = isDarkMode
          ? WidgetDesignTokens.darkSubjectColors
          : WidgetDesignTokens.lightSubjectColors;
      final safeColorIdx = cardItem.colorIndex.clamp(0, colorTokens.length - 1);
      final token = colorTokens[safeColorIdx];
      cardBg = token.bg;
      titleColor = isDarkMode ? Colors.white : token.text;
      subColor = token.text;
    }

    final accentBorder = isDarkMode
        ? WidgetDesignTokens.darkAccentBorder
        : WidgetDesignTokens.lightAccentBorder;

    // Viền accent nếu đang thi / đang học (isCurrent)
    final border = cardItem.isCurrent
        ? Border.all(color: accentBorder, width: 1.0)
        : null;

    return InkWell(
      onTap: () => onCardTap?.call(cardItem),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dòng 1: "HH:mm · phòng" hoặc "HH:mm · phòng · Thi" (vừa 500)
            Text(
              cardItem.timeRoomLine,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.1,
                color: subColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            // Dòng 2: Tên môn (1 dòng, cắt "…")
            Text(
              cardItem.displayTitle,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: titleColor,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
