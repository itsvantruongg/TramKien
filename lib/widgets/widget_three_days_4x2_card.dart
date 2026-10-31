import 'package:flutter/material.dart';
import '../services/widget/widget_service.dart';
import 'widget_today_2x2_card.dart';

/// Widget Lịch 3 ngày (4x2, ~320x150 dp/pt)
/// Tuân thủ nghiêm ngặt SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 1, 3.3, 3.5, 3.6, 7
class WidgetThreeDays4x2Card extends StatelessWidget {
  final ThreeDays4x2Data data;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final ValueChanged<ThreeDaysColumnData>? onColumnTap;
  final ValueChanged<ThreeDaysCardItem>? onCardTap;

  const WidgetThreeDays4x2Card({
    super.key,
    required this.data,
    this.isDarkMode = false,
    this.onTap,
    this.onColumnTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? WidgetDesignTokens.darkBg : WidgetDesignTokens.lightBg;
    final borderColor = isDarkMode ? WidgetDesignTokens.darkBorder : WidgetDesignTokens.lightBorder;

    return Semantics(
      label: 'Widget Lịch 3 ngày 4x2',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 320,
          height: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: !data.hasSnapshot
              ? _buildEmptyState(context)
              : _buildThreeColumns(context),
        ),
      ),
    );
  }

  /// Trạng thái trống toàn widget khi chưa có bản chụp (Mục 3.6 & AC-10)
  Widget _buildEmptyState(BuildContext context) {
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

  /// Khung 3 cột bằng nhau, khoảng cách 8dp (Mục 3.3)
  Widget _buildThreeColumns(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < data.columns.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildColumn(context, data.columns[i]),
          ),
        ],
      ],
    );
  }

  /// Vẽ 1 cột ngày (Hôm nay, Ngày mai hoặc Ngày kia)
  Widget _buildColumn(BuildContext context, ThreeDaysColumnData column) {
    final textPrimary = isDarkMode
        ? WidgetDesignTokens.darkTextPrimary
        : WidgetDesignTokens.lightTextPrimary;
    final textSecondary = isDarkMode
        ? WidgetDesignTokens.darkTextSecondary
        : WidgetDesignTokens.lightTextSecondary;
    final textDimmed = isDarkMode
        ? WidgetDesignTokens.darkTextDimmed
        : WidgetDesignTokens.lightTextDimmed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onColumnTap?.call(column),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tiêu đề cột: "Hôm nay dd" hoặc "Thứ · dd", bên phải là "+N" (nếu N > 0)
          Row(
            children: [
              Expanded(
                child: Text(
                  column.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'sans-serif-medium',
                  ),
                ),
              ),
              if (column.badgeText != null)
                Text(
                  column.badgeText!,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'sans-serif',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Thân cột: Hoặc "Trống", hoặc tối đa 2 thẻ môn
          Expanded(
            child: column.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        column.emptyText,
                        style: TextStyle(
                          color: textDimmed,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int k = 0; k < column.visibleCards.length; k++) ...[
                        if (k > 0) const SizedBox(height: 4),
                        _buildCard(context, column.visibleCards[k]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Vẽ 1 thẻ môn trong cột: Bo góc 8dp, padding 4dp dọc x 6dp ngang
  Widget _buildCard(BuildContext context, ThreeDaysCardItem card) {
    final colorTokens = isDarkMode
        ? WidgetDesignTokens.darkSubjectColors
        : WidgetDesignTokens.lightSubjectColors;

    final Color cardBg;
    final Color textColor;
    Border? border;

    if (card.isExam) {
      cardBg = isDarkMode
          ? WidgetDesignTokens.darkExamBg
          : WidgetDesignTokens.lightExamBg;
      textColor = isDarkMode
          ? WidgetDesignTokens.darkExamText
          : WidgetDesignTokens.lightExamText;

      if (card.isCurrent) {
        final accentBorder = isDarkMode
            ? WidgetDesignTokens.darkAccentBorder
            : WidgetDesignTokens.lightAccentBorder;
        border = Border.all(color: accentBorder, width: 1.0);
      }
    } else {
      final safeColorIdx = card.colorIndex.clamp(0, colorTokens.length - 1);
      final token = colorTokens[safeColorIdx];
      cardBg = token.bg;
      textColor = token.text;

      if (card.isCurrent) {
        final accentBorder = isDarkMode
            ? WidgetDesignTokens.darkAccentBorder
            : WidgetDesignTokens.lightAccentBorder;
        border = Border.all(color: accentBorder, width: 1.0);
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onCardTap?.call(card),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dòng 1: "HH:mm · phòng" (vừa)
            Text(
              card.timeRoomLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFamily: 'sans-serif-medium',
                height: 1.15,
              ),
            ),
            const SizedBox(height: 1),
            // Dòng 2: shortName (tên rút gọn 1 dòng)
            Text(
              card.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                fontFamily: 'sans-serif',
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
