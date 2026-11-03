import 'package:flutter/material.dart';
import '../services/widget/widget_service.dart';

/// Hằng số Token thiết kế chuẩn cho Widget Lịch học (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 1.4 & 1.5)
class WidgetDesignTokens {
  // Light Mode
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE5E5E5);
  static const Color lightTextPrimary = Color(0xFF1F1F1E);
  static const Color lightTextSecondary = Color(0xFF5F5E5A);
  static const Color lightTextDimmed = Color(0xFF888780);
  static const Color lightAccent = Color(0xFF185FA5);
  static const Color lightAccentBorder = Color(0xFF378ADD);
  static const Color lightAccentOn = Color(0xFFFFFFFF);
  static const Color lightExamBg = Color(0xFFFCEBEB);
  static const Color lightExamText = Color(0xFF791F1F);

  // Dark Mode
  static const Color darkBg = Color(0xFF262624);
  static const Color darkBorder = Color(0xFF3D3D3A);
  static const Color darkTextPrimary = Color(0xFFF1EFE8);
  static const Color darkTextSecondary = Color(0xFFD3D1C7);
  static const Color darkTextDimmed = Color(0xFFA8A69E);
  static const Color darkAccent = Color(0xFF85B7EB);
  static const Color darkAccentBorder = Color(0xFF85B7EB);
  static const Color darkAccentOn = Color(0xFF042C53);
  static const Color darkExamBg = Color(0xFF791F1F);
  static const Color darkExamText = Color(0xFFFCA5A5);

  // 8 Môn học Token (Light: Bg / Text) - 100% Cool Tones (Phân định triệt để với Lịch Thi màu ấm)
  static const List<({Color bg, Color text})> lightSubjectColors = [
    (bg: Color(0xFFEFF6FF), text: Color(0xFF2563EB)), // 0: Blue - Xanh lam
    (bg: Color(0xFFECFDF5), text: Color(0xFF059669)), // 1: Emerald - Xanh ngọc lục bảo
    (bg: Color(0xFFF5F3FF), text: Color(0xFF7C3AED)), // 2: Purple - Tím lạnh
    (bg: Color(0xFFF0FDFA), text: Color(0xFF0D9488)), // 3: Teal - Xanh ngọc biển
    (bg: Color(0xFFECFEFF), text: Color(0xFF0891B2)), // 4: Cyan - Xanh mòng két
    (bg: Color(0xFFF0F9FF), text: Color(0xFF0284C7)), // 5: Sky - Xanh da trời
    (bg: Color(0xFFF0F9FF), text: Color(0xFF0369A1)), // 6: Ocean Blue - Xanh biển
    (bg: Color(0xFFEEF2FF), text: Color(0xFF4F46E5)), // 7: Indigo - Chàm
  ];

  // 8 Môn học Token (Dark: Bg / Text) - 100% Cool Tones (High Contrast Pastels)
  static const List<({Color bg, Color text})> darkSubjectColors = [
    (bg: Color(0xFF1E3A8A), text: Color(0xFF93C5FD)), // 0: Blue
    (bg: Color(0xFF064E3B), text: Color(0xFF6EE7B7)), // 1: Emerald
    (bg: Color(0xFF4C1D95), text: Color(0xFFC4B5FD)), // 2: Purple
    (bg: Color(0xFF134E4A), text: Color(0xFF5EEAD4)), // 3: Teal
    (bg: Color(0xFF164E63), text: Color(0xFF67E8F9)), // 4: Cyan
    (bg: Color(0xFF0C4A6E), text: Color(0xFF7DD3FC)), // 5: Sky
    (bg: Color(0xFF075985), text: Color(0xFF7DD3FC)), // 6: Ocean Blue light
    (bg: Color(0xFF312E81), text: Color(0xFFA5B4FC)), // 7: Indigo
  ];
}

/// Giao diện Widget Hôm nay 2x2 (~150x150 dp/pt, bo góc 20dp, padding 12dp, viền 0.5dp)
class WidgetToday2x2Card extends StatelessWidget {
  final Today2x2Data data;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const WidgetToday2x2Card({
    super.key,
    required this.data,
    this.isDarkMode = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? WidgetDesignTokens.darkBg : WidgetDesignTokens.lightBg;
    final borderColor = isDarkMode ? WidgetDesignTokens.darkBorder : WidgetDesignTokens.lightBorder;
    final textPrimary = isDarkMode ? WidgetDesignTokens.darkTextPrimary : WidgetDesignTokens.lightTextPrimary;
    final textSecondary = isDarkMode ? WidgetDesignTokens.darkTextSecondary : WidgetDesignTokens.lightTextSecondary;
    final accentColor = isDarkMode ? WidgetDesignTokens.darkAccent : WidgetDesignTokens.lightAccent;
    final examTextColor = isDarkMode ? WidgetDesignTokens.darkExamText : WidgetDesignTokens.lightExamText;

    Color labelColor = textSecondary;
    if (data.statusLabel == 'Đang học') {
      labelColor = accentColor;
    } else if (data.statusLabel == 'Đang thi') {
      labelColor = examTextColor;
    }

    return Semantics(
      button: true,
      label: 'Widget Hôm nay 2x2: ${data.displayTitle}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 150,
          height: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Nhãn trạng thái (cỡ 11, font vừa 500)
              if (data.statusLabel.isNotEmpty) ...[
                Text(
                  data.statusLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: labelColor,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
              ],

              // 2. Tên môn / Tiêu đề (cỡ 13, font vừa 500, tối đa 3 dòng, cắt "…")
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.displayTitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: data.hasSession ? 13 : 12,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                        height: 1.25,
                      ),
                      maxLines: data.hasSession ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // 3. Dòng thông tin phụ: "HH:mm · phòng" (cỡ 11, màu phụ)
                    if (data.subInfo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        data.subInfo,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: textSecondary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 4. Thanh tiến độ ca học (cao 4dp, bo góc 2dp, đáy)
              if (data.showProgressBar) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Container(
                    height: 4,
                    width: double.infinity,
                    color: borderColor,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: data.progress.clamp(0.0, 1.0),
                      child: Container(
                        color: data.isExam ? examTextColor : accentColor,
                      ),
                    ),
                  ),
                ),
              ],

              // 5. Dòng đếm ngược đáy: Cỡ 11, màu phụ ("Đến HH:mm" hoặc "Còn N phút")
              if (data.countdownAndroid != null || data.countdownIos != null) ...[
                const SizedBox(height: 4),
                Text(
                  data.countdownAndroid ?? data.countdownIos ?? '',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: textSecondary,
                    height: 1.2,
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
