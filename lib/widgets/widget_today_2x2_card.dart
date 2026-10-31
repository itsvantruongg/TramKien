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
  static const Color darkTextSecondary = Color(0xFFB4B2A9);
  static const Color darkTextDimmed = Color(0xFF888780);
  static const Color darkAccent = Color(0xFF85B7EB);
  static const Color darkAccentBorder = Color(0xFF85B7EB);
  static const Color darkAccentOn = Color(0xFF042C53);
  static const Color darkExamBg = Color(0xFF791F1F);
  static const Color darkExamText = Color(0xFFF7C1C1);

  // 8 Môn học Token (Light: Bg / Text)
  static const List<({Color bg, Color text})> lightSubjectColors = [
    (bg: Color(0xFFE6F1FB), text: Color(0xFF0C447C)), // 0: Xanh dương
    (bg: Color(0xFFEAF3DE), text: Color(0xFF27500A)), // 1: Xanh lá
    (bg: Color(0xFFEEEDFE), text: Color(0xFF3C3489)), // 2: Tím
    (bg: Color(0xFFFAEEDA), text: Color(0xFF633806)), // 3: Hổ phách
    (bg: Color(0xFFE1F5EE), text: Color(0xFF085041)), // 4: Xanh ngọc
    (bg: Color(0xFFFBEAF0), text: Color(0xFF72243E)), // 5: Hồng
    (bg: Color(0xFFFAECE7), text: Color(0xFF712B13)), // 6: San hô
    (bg: Color(0xFFF1EFE8), text: Color(0xFF444441)), // 7: Xám
  ];

  // 8 Môn học Token (Dark: Bg / Text)
  static const List<({Color bg, Color text})> darkSubjectColors = [
    (bg: Color(0xFF0C447C), text: Color(0xFFB5D4F4)), // 0: Xanh dương
    (bg: Color(0xFF27500A), text: Color(0xFFC0DD97)), // 1: Xanh lá
    (bg: Color(0xFF3C3489), text: Color(0xFFCECBF6)), // 2: Tím
    (bg: Color(0xFF633806), text: Color(0xFFFAC775)), // 3: Hổ phách
    (bg: Color(0xFF085041), text: Color(0xFF9FE1CB)), // 4: Xanh ngọc
    (bg: Color(0xFF72243E), text: Color(0xFFF4C0D1)), // 5: Hồng
    (bg: Color(0xFF712B13), text: Color(0xFFF5C4B3)), // 6: San hô
    (bg: Color(0xFF444441), text: Color(0xFFD3D1C7)), // 7: Xám
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
