import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/models.dart';
import '../models/widget_models.dart';
import '../services/db/schedule_db.dart';
import '../services/widget_data_sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

/// Màn hình Xưởng tùy biến Widget (SPEC-WIDGET-STUDIO-02)
/// Thiết kế chuẩn Thụy Sĩ (Swiss Typography), Light Theme đồng bộ toàn hệ thống.
class WidgetStudioScreen extends StatefulWidget {
  final WidgetThemeConfig? initialConfig;
  final WidgetScheduleData? previewScheduleData;

  const WidgetStudioScreen({
    super.key,
    this.initialConfig,
    this.previewScheduleData,
  });

  @override
  State<WidgetStudioScreen> createState() => _WidgetStudioScreenState();
}

class _WidgetStudioScreenState extends State<WidgetStudioScreen> {
  late WidgetThemeConfig _config;
  WidgetScheduleData? _scheduleData;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUsingSampleData = false;
  String? _selectedPresetName;
  int _previewClassCount =
      4; // 1 | 4 (Kịch bản ca học mẫu: 1 ca hoặc 4 ca học dồn)

  // Biến thể Widget (2x2 đã lược bỏ, single_day mặc định 4x2 Timeline)
  String _singleDayVariant = '4x2'; // '4x2'
  String _weeklyVariant = 'grid'; // 'grid'
  Uint8List? _nativePreviewBytes;
  bool _isFetchingPreview = false;
  Timer? _debouncePreviewTimer;

  // Giả lập ảnh nền điện thoại trong Live Preview
  int _selectedWallpaperIndex = 0;
  static const List<({String name, LinearGradient gradient})> _wallpapers = [
    (
      name: 'Dark Obsidian',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF020617)],
      ),
    ),
    (
      name: 'Deep Forest',
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF064E3B), Color(0xFF022C22), Color(0xFF0F172A)],
      ),
    ),
    (
      name: 'Sunset Minimal',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4C1D95), Color(0xFF831843), Color(0xFF18181B)],
      ),
    ),
    (
      name: 'Studio Gray',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF27272A), Color(0xFF18181B), Color(0xFF09090B)],
      ),
    ),
    (
      name: 'Light Paper',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
      ),
    ),
    (
      name: 'Soft Pastel',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF1F2), Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
      ),
    ),
    (
      name: 'Clean Minimal',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig ?? WidgetThemeConfig.minimalSwiss();
    _scheduleData = _buildFallbackPreviewData(_config.layoutMode);
    _syncPresetSelectionFromConfig();
    _initData();
  }

  void _updateConfigAndRefreshPreview(WidgetThemeConfig newConfig,
      {String? presetName}) {
    setState(() {
      _config = newConfig;
      if (presetName != null) {
        _selectedPresetName = presetName;
      } else {
        _syncPresetSelectionFromConfig();
      }
      _nativePreviewBytes = null;
    });
  }

  @override
  void dispose() {
    _debouncePreviewTimer?.cancel();
    super.dispose();
  }

  void _syncPresetSelectionFromConfig() {
    if (_config.bgStyle == 'solid' &&
        (_config.bgColorHex.toUpperCase() == '#1C1C1E' ||
            _config.bgColorHex.toUpperCase() == '#121212')) {
      _selectedPresetName = 'Tối giản Thụy Sĩ';
    } else if (_config.bgStyle == 'solid' &&
        _config.bgColorHex.toUpperCase() == '#FFFFFF') {
      _selectedPresetName = 'Nền Sáng Tinh Gọn';
    } else if (_config.bgStyle == 'transparent' && _config.bgOpacity == 0.0) {
      _selectedPresetName = 'Ghost Mode';
    } else if (_config.bgColorHex.toUpperCase() == '#0B0C10' &&
        _config.textPrimaryHex.toUpperCase() == '#66FCF1') {
      _selectedPresetName = 'Cyberpunk Neon';
    } else if (_config.bgColorHex.toUpperCase() == '#0F172A') {
      _selectedPresetName = 'Dark Obsidian';
    } else if (_config.bgColorHex.toUpperCase() == '#064E3B') {
      _selectedPresetName = 'Deep Forest';
    } else if (_config.bgColorHex.toUpperCase() == '#4C1D95') {
      _selectedPresetName = 'Sunset Minimal';
    } else {
      _selectedPresetName = null;
    }
  }

  @override
  void didUpdateWidget(covariant WidgetStudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.previewScheduleData != oldWidget.previewScheduleData) {
      if (widget.previewScheduleData != null) {
        final data = widget.previewScheduleData!;
        final hasClasses = data.days.any((d) => d.classes.isNotEmpty);
        if (!hasClasses) {
          _scheduleData = _buildFallbackPreviewData(_config.layoutMode);
          _isUsingSampleData = true;
        } else {
          _scheduleData = data;
          _isUsingSampleData = false;
        }
      }
    }
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.initialConfig == null) {
        _config = await WidgetDataSyncService.getThemeConfig();
        _syncPresetSelectionFromConfig();
      }
      if (widget.previewScheduleData != null) {
        final data = widget.previewScheduleData!;
        final hasClasses = data.days.any((d) => d.classes.isNotEmpty);
        if (!hasClasses) {
          _scheduleData = _buildFallbackPreviewData(_config.layoutMode);
          _isUsingSampleData = true;
        } else {
          _scheduleData = data;
          _isUsingSampleData = false;
        }
      } else {
        _isUsingSampleData = true;
        _scheduleData = _buildFallbackPreviewData(_config.layoutMode);
      }
    } catch (_) {
      // Fallback preview data mẫu nếu có lỗi
      _isUsingSampleData = true;
      _scheduleData = _buildFallbackPreviewData(_config.layoutMode);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  WidgetScheduleData _buildFallbackPreviewData(String layoutMode,
      [int? classCount]) {
    final count = classCount ?? _previewClassCount;
    final now = DateTime.now();

    const sampleClasses = [
      WidgetClassItem(
        courseName: 'Môn học 1',
        classCode: 'TH4327_23CN 2',
        timeSlot: '06:55 – 09:20 (T1–3)',
        room: 'P.I801',
        teacher: 'ThS. Nguyễn Thị Huệ',
        isCurrentOrNext: true,
        isFinished: false,
      ),
      WidgetClassItem(
        courseName: 'Môn học 2',
        classCode: 'TH5216_23CN 2',
        timeSlot: '09:30 – 11:55 (T4–6)',
        room: 'P.H302',
        teacher: 'TS. Nguyễn Văn A',
        isCurrentOrNext: false,
        isFinished: false,
      ),
      WidgetClassItem(
        courseName: 'Môn học 3',
        classCode: 'KT1002_23CN 1',
        timeSlot: '12:55 – 17:05 (T8–12)',
        room: 'P.M-M5.03',
        teacher: 'TS. Trần Văn C',
        isCurrentOrNext: false,
        isFinished: false,
      ),
      WidgetClassItem(
        courseName: 'Môn học 4',
        classCode: 'LL1001_23CN 2',
        timeSlot: '17:15 – 19:40 (T13–15)',
        room: 'P.H101',
        teacher: 'TS. Nguyễn Quốc Huy',
        isCurrentOrNext: false,
        isFinished: false,
      ),
    ];

    if (layoutMode == 'three_days') {
      final day1 = now;
      final day2 = now.add(const Duration(days: 1));
      final day3 = now.add(const Duration(days: 2));
      return WidgetScheduleData(
        updatedAt: now.toIso8601String(),
        widgetTitle: 'Lịch 3 ngày',
        widgetSubtitle:
            '${WidgetDataSyncService.formatDateShort(day1)} – ${WidgetDataSyncService.formatDateShort(day3)}',
        layoutMode: layoutMode,
        days: [
          WidgetDaySchedule(
            dayLabel: 'HÔM NAY',
            dateStr: WidgetDataSyncService.formatDateShort(day1),
            weekdayStr: WidgetDataSyncService.formatWeekdayShort(day1.weekday),
            isToday: true,
            isDimmed: false,
            classes: [sampleClasses[0]],
          ),
          WidgetDaySchedule(
            dayLabel: 'NGÀY MAI',
            dateStr: WidgetDataSyncService.formatDateShort(day2),
            weekdayStr: WidgetDataSyncService.formatWeekdayShort(day2.weekday),
            isToday: false,
            isDimmed: false,
            classes: [sampleClasses[2]],
          ),
          WidgetDaySchedule(
            dayLabel: 'NGÀY KIA',
            dateStr: WidgetDataSyncService.formatDateShort(day3),
            weekdayStr: WidgetDataSyncService.formatWeekdayShort(day3.weekday),
            isToday: false,
            isDimmed: false,
            classes: [sampleClasses[3]],
          ),
        ],
      );
    } else if (layoutMode == 'seven_days') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final sampleClassesForDays = [
        [sampleClasses[0]], // Thứ 2: Môn 1
        [sampleClasses[1]], // Thứ 3: Môn 2
        [sampleClasses[2]], // Thứ 4: Môn 3
        [sampleClasses[3]], // Thứ 5: Môn 4
        [sampleClasses[0]], // Thứ 6: Môn 1
        [sampleClasses[1]], // Thứ 7: Môn 2
        [sampleClasses[2]], // Chủ nhật: Môn 3
      ];
      final days = List.generate(7, (i) {
        final d = monday.add(Duration(days: i));
        final isToday =
            (d.year == now.year && d.month == now.month && d.day == now.day);
        return WidgetDaySchedule(
          dayLabel: WidgetDataSyncService.formatWeekdayShort(d.weekday),
          dateStr: WidgetDataSyncService.formatDateShort(d),
          weekdayStr: WidgetDataSyncService.formatWeekdayShort(d.weekday),
          isToday: isToday,
          isDimmed: false,
          classes: sampleClassesForDays[i],
        );
      });
      return WidgetScheduleData(
        updatedAt: now.toIso8601String(),
        widgetTitle: 'Lịch tuần',
        widgetSubtitle:
            '${WidgetDataSyncService.formatDateShort(monday)} – ${WidgetDataSyncService.formatDateShort(sunday)}',
        layoutMode: layoutMode,
        days: days,
      );
    } else if (layoutMode == 'tomorrow') {
      final tomorrow = now.add(const Duration(days: 1));
      return WidgetScheduleData(
        updatedAt: now.toIso8601String(),
        widgetTitle: 'Lịch ngày mai',
        widgetSubtitle:
            '${WidgetDataSyncService.formatWeekdayFull(tomorrow.weekday)}, ${WidgetDataSyncService.formatDateShort(tomorrow)}',
        layoutMode: layoutMode,
        days: [
          WidgetDaySchedule(
            dayLabel: 'NGÀY MAI',
            dateStr: WidgetDataSyncService.formatDateShort(tomorrow),
            weekdayStr:
                WidgetDataSyncService.formatWeekdayShort(tomorrow.weekday),
            isToday: false,
            isDimmed: false,
            classes: sampleClasses,
          ),
        ],
      );
    } else {
      // single_day: Luôn trung thành với ngày hôm nay
      final targetDate = now;
      const dayTitle = 'Lịch hôm nay';
      return WidgetScheduleData(
        updatedAt: now.toIso8601String(),
        widgetTitle: dayTitle,
        widgetSubtitle:
            '${WidgetDataSyncService.formatWeekdayFull(targetDate.weekday)}, ${WidgetDataSyncService.formatDateShort(targetDate)}',
        layoutMode: layoutMode,
        days: [
          WidgetDaySchedule(
            dayLabel: 'HÔM NAY',
            dateStr: WidgetDataSyncService.formatDateShort(targetDate),
            weekdayStr:
                WidgetDataSyncService.formatWeekdayShort(targetDate.weekday),
            isToday: true,
            isDimmed: false,
            classes: sampleClasses,
          ),
        ],
      );
    }
  }

  void _onLayoutModeChanged(String newMode) {
    if (newMode == _config.layoutMode) return;
    setState(() {
      _nativePreviewBytes = null;
      _config = _config.copyWith(layoutMode: newMode);
      if (newMode == 'single_day') {
        _singleDayVariant = '4x2';
      } else if (newMode == 'seven_days') {
        _weeklyVariant = 'grid';
      }
      _refreshScheduleDataForMode(newMode);
    });
  }

  Future<void> _refreshScheduleDataForMode(String mode) async {
    if (widget.previewScheduleData != null) {
      final data = widget.previewScheduleData!;
      final hasClasses = data.days.any((d) => d.classes.isNotEmpty);
      if (hasClasses) {
        _isUsingSampleData = false;
        if (mounted) setState(() => _scheduleData = data);
        return;
      }
    }
    _isUsingSampleData = true;
    if (mounted) {
      setState(() => _scheduleData = _buildFallbackPreviewData(mode));
    }
  }

  void _applyPreset(String name, WidgetThemeConfig preset) {
    _updateConfigAndRefreshPreview(
      preset.copyWith(layoutMode: _config.layoutMode),
      presetName: name,
    );
  }

  Future<void> _handleApply() async {
    setState(() => _isSaving = true);
    try {
      await WidgetDataSyncService.saveThemeConfig(_config);

      // SPEC-REQ-5: Gỡ bỏ hoàn toàn ongoing notification ID 8888 và hủy sạch
      try {
        FlutterLocalNotificationsPlugin()
            .cancel(WidgetDataSyncService.lockscreenNotificationId)
            .catchError((_) {});
      } catch (_) {}

      WidgetScheduleData syncedData;
      try {
        syncedData = await WidgetDataSyncService.loadAndSyncFromDb(
          layoutMode: _config.layoutMode,
          updateNotification: false,
          themeConfig: _config,
        );
        if (!_isUsingSampleData &&
            _scheduleData != null &&
            syncedData.days.every((d) => d.classes.isEmpty) &&
            _scheduleData!.days.any((d) => d.classes.isNotEmpty)) {
          syncedData = _scheduleData!;
          await WidgetDataSyncService.saveScheduleData(syncedData);
        }
      } catch (e) {
        debugPrint('⚠️ Sync fallback in studio: $e');
        if (!_isUsingSampleData && _scheduleData != null) {
          syncedData = _scheduleData!;
        } else {
          try {
            final schedules = await ScheduleDb.getLichHoc();
            final exams = await ScheduleDb.getLichThi();
            if (schedules.isNotEmpty || exams.isNotEmpty) {
              syncedData = WidgetDataSyncService.calculateScheduleWindow(
                allSchedules: schedules,
                allExams: exams,
                layoutMode: _config.layoutMode,
              );
            } else {
              syncedData =
                  _scheduleData ?? _buildFallbackPreviewData(_config.layoutMode);
            }
          } catch (_) {
            syncedData =
                _scheduleData ?? _buildFallbackPreviewData(_config.layoutMode);
          }
        }
        await WidgetDataSyncService.saveScheduleData(syncedData);
      }

      // Kích hoạt cập nhật native widget tức thì (CHỈ lưu và cập nhật, không gọi requestPinWidget)
      await WidgetDataSyncService.triggerNativeWidgetUpdate();

      if (mounted) {
        if (widget.previewScheduleData == null) {
          setState(() {
            _isUsingSampleData = true;
            _scheduleData = _buildFallbackPreviewData(_config.layoutMode);
          });
        }
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              '✓ Đã cập nhật giao diện Widget',
              style:
                  TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Lỗi khi lưu cấu hình: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // AC-01: Full Light Theme matching AppTheme.surface (#F8F9FA)
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WIDGET STUDIO',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppTheme.primary,
              ),
            ),
            Text(
              'XƯỞNG TÙY BIẾN THỜI KHÓA BIỂU THỤY SĨ',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppTheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _handleApply,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 18, color: Colors.white),
            label: Text(
              _isSaving ? 'ĐANG LƯU' : 'ÁP DỤNG',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1D64F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1D64F2)))
          : Column(
              children: [
                // ── 1. LIVE PREVIEW CONTAINER (Nửa trên) ─────────────────
                _buildLivePreviewSection(),

                // ── 2. CONTROLS CONTROLLER (Nửa dưới cuộn) ───────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('CHẾ ĐỘ HIỂN THỊ (LAYOUT MODE)'),
                        _buildCard(
                            child: _buildLayoutModeSelector(),
                            padding: const EdgeInsets.all(8)),
                        const SizedBox(height: 18),

                        _buildSectionHeader('PRESETS MẪU 1 CHẠM'),
                        _buildCard(child: _buildPresetsSelector()),
                        const SizedBox(height: 18),

                        _buildSectionHeader('KIỂU NỀN (BACKGROUND STYLE)'),
                        _buildCard(child: _buildBgStyleSelector()),
                        const SizedBox(height: 18),

                        _buildSectionHeader('BỘ MÀU CHUẨN THỤY SĨ'),
                        _buildCard(child: _buildColorSelectors()),
                        const SizedBox(height: 18),

                        _buildSectionHeader('CÔNG TẮC TRƯỜNG DỮ LIỆU'),
                        _buildCard(
                            child: _buildFieldSwitches(),
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                        const SizedBox(height: 24),

                        // Action Button Áp Dụng
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _handleApply,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D64F2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _isSaving
                                  ? 'ĐANG LƯU DỮ LIỆU...'
                                  : 'ÁP DỤNG CẤU HÌNH VÀO WIDGET',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lightbulb_outline_rounded,
                                  size: 16, color: AppTheme.primary),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Để đưa widget ra màn hình: Nhấn giữ màn hình chính ➔ Widget ➔ Chọn Trạm Kiến',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.outlineVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── LIVE PREVIEW SECTION ───────────────────────────────────────────────

  Widget _buildLivePreviewSection() {
    final wp = _wallpapers[_selectedWallpaperIndex];
    final isWeekly = _config.layoutMode == 'seven_days';
    final bool is2x2 =
        _config.layoutMode == 'single_day' && _singleDayVariant == '2x2';
    final bool isWeeklyGrid = isWeekly && _weeklyVariant == 'grid';

    String previewTitleSuffix = '3 NGÀY';
    if (_config.layoutMode == 'single_day') {
      previewTitleSuffix = '1 NGÀY';
    } else if (_config.layoutMode == 'three_days') {
      previewTitleSuffix = '3 NGÀY';
    } else if (isWeekly) {
      previewTitleSuffix = _weeklyVariant == 'grid'
          ? '7 NGÀY · GRID 8 Ô'
          : '7 NGÀY · STRIP';
    } else if (_config.layoutMode == 'tomorrow') {
      previewTitleSuffix = 'NGÀY MAI';
    }
    final previewTitle = 'LIVE PREVIEW ($previewTitleSuffix)';

    double previewHeight = 248;
    if (isWeeklyGrid) {
      previewHeight = 400;
    } else if (is2x2) {
      previewHeight = 240;
    } else {
      previewHeight = 248;
    }

    final double avgLuminance = wp.gradient.colors
            .fold<double>(0.0, (acc, c) => acc + c.computeLuminance()) /
        wp.gradient.colors.length;
    final bool isLightWallpaper = wp.name == 'Light Paper' ||
        wp.name == 'Soft Pastel' ||
        wp.name == 'Clean Minimal' ||
        avgLuminance > 0.5;
    final Color statusBarColor = isLightWallpaper
        ? const Color(0xFF1E293B)
        : Colors.white.withOpacity(0.85);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Toolbar: Title & Wallpaper Switcher
          Row(
            children: [
              Expanded(
                child: Text(
                  previewTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nút chuyển đổi tinh gọn 2 trạng thái: [ NỀN TỐI ] | [ NỀN SÁNG ]
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      key: const Key('btn_bg_dark'),
                      onTap: () => setState(
                          () => _selectedWallpaperIndex = 0), // Dark Obsidian
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: !isLightWallpaper
                              ? const Color(0xFF0F172A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'NỀN TỐI',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: !isLightWallpaper
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      key: const Key('btn_bg_light'),
                      onTap: () => setState(
                          () => _selectedWallpaperIndex = 4), // Light Paper
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isLightWallpaper
                              ? const Color(0xFF1D64F2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'NỀN SÁNG',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isLightWallpaper
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Khung giả lập màn hình nền điện thoại chứa Widget (Bo góc 26dp, hairline border 0.5dp, Status Bar giả lập)
          // RepaintBoundary cô lập GPU repaints & AnimatedContainer 320ms + AnimatedSwitcher 250ms
          RepaintBoundary(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              width: double.infinity,
              height: previewHeight,
              decoration: BoxDecoration(
                gradient: wp.gradient,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 0.5, // Hairline 0.5dp
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  children: [
                    // Thanh Status Bar giả lập siêu mảnh phía trên
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '09:41',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusBarColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.signal_cellular_4_bar,
                                size: 11,
                                color: statusBarColor,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.wifi,
                                size: 11,
                                color: statusBarColor,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.battery_std,
                                size: 12,
                                color: statusBarColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Simulated Widget inside Phone
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: [
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: OverflowBox(
                                minHeight: 0,
                                maxHeight: 420,
                                alignment: Alignment.topCenter,
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(
                                '${_config.layoutMode}_${_singleDayVariant}_$_weeklyVariant'),
                            child: is2x2
                                ? Center(
                                    child: SizedBox(
                                      width: 170,
                                      height: 170,
                                      child: _buildSimulatedWidgetCard(),
                                    ),
                                  )
                                : SizedBox(
                                    height: isWeeklyGrid ? 350 : 206,
                                    child: _buildSimulatedWidgetCard(),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Render Widget Card theo đúng chuẩn Thụy Sĩ (Swiss typography, không emoji)
  /// Single Source of Truth Live Preview: Luôn dùng _buildFlutterWidgetCard() loại bỏ hoàn toàn hiện tượng co giật chớp nạp 2 lần
  Widget _buildSimulatedWidgetCard() {
    final Widget card = KeyedSubtree(
      key: const ValueKey('flutter_fallback_card'),
      child: _buildFlutterWidgetCard(),
    );

    final is2x2 = _config.layoutMode == 'single_day' && (_singleDayVariant == '2x2' || _singleDayVariant == 'square_2x2');
    final isWeeklyGrid = _config.layoutMode == 'seven_days' && (_weeklyVariant == 'grid' || _weeklyVariant == 'grid_8cell');
    final targetWidth = is2x2 ? 170.0 : 330.0;
    final targetHeight = is2x2 ? 170.0 : (isWeeklyGrid ? 350.0 : 206.0);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: targetWidth,
        height: targetHeight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: card,
        ),
      ),
    );
  }

  Widget _buildFlutterWidgetCard() {
    final isWeeklyGrid = _config.layoutMode == 'seven_days';
    var data = _scheduleData;
    if (data == null ||
        data.days.isEmpty ||
        data.days.every((d) => d.classes.isEmpty)) {
      data = _buildFallbackPreviewData(_config.layoutMode);
    }

    Color primaryTextColor = _config.textPrimaryColor;
    Color secondaryTextColor = _config.textSecondaryColor;
    final accent = _config.accentColor;

    final isLightBg = _config.bgStyle != 'transparent' &&
        (_config.bgColorHex.toUpperCase() == '#FFFFFF' ||
            _config.bgColorHex.toUpperCase() == '#F8F9FA' ||
            WidgetThemeConfig.hexToColor(_config.bgColorHex)
                    .computeLuminance() >
                0.6);

    // SPEC-REQ-4: Màu sắc độc lập - Hiển thị đúng mã hex người dùng chọn, không tự động ghi đè

    BoxDecoration containerDecoration;
    Widget backgroundLayer;

    if (_config.bgStyle == 'transparent') {
      containerDecoration = const BoxDecoration(
        color: Colors.transparent,
      );
      backgroundLayer = Container(decoration: containerDecoration);
    } else {
      // Solid Card (Default & Recommended)
      containerDecoration = BoxDecoration(
        color: WidgetThemeConfig.hexToColor(_config.bgColorHex, 1.0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLightBg
              ? const Color(0xFFE2E8F0)
              : Colors.white.withOpacity(0.15),
          width: 0.5,
        ),
      );
      backgroundLayer = Container(decoration: containerDecoration);
    }

    final is2x2 =
        _config.layoutMode == 'single_day' && _singleDayVariant == '2x2';
    final isWeekly = _config.layoutMode == 'seven_days';

    // Header tách biệt trái / phải, bỏ hoàn toàn dấu "|"
    String displayTitle;
    String displaySubtitle;
    if (data.widgetTitle.contains('|')) {
      final parts = data.widgetTitle.split('|');
      final p0 = parts[0].trim();
      final p1 = parts.length > 1 ? parts[1].trim() : '';
      if (p0.contains('3 ngày')) {
        displayTitle = 'Lịch 3 ngày';
      } else if (p0.contains('tuần') || p0.contains('7 ngày')) {
        displayTitle = 'Lịch tuần';
      } else if (p0.contains('ngày mai') || p0.contains('Ngày mai')) {
        displayTitle = 'Lịch ngày mai';
      } else {
        displayTitle = 'Lịch hôm nay';
      }
      displaySubtitle =
          data.widgetSubtitle.isNotEmpty ? data.widgetSubtitle : p1;
    } else {
      displayTitle = (data.widgetTitle == 'Lịch 7 ngày' || isWeekly)
          ? 'Lịch tuần'
          : data.widgetTitle;
      displaySubtitle = data.widgetSubtitle;
    }

    if (is2x2) {
      if (data.days.isNotEmpty) {
        displaySubtitle = data.days.first.dateStr;
      } else {
        displaySubtitle = WidgetDataSyncService.formatDateShort(DateTime.now());
      }
    }

    final bool hasCustomBgImage = _config.customBgImagePath != null &&
        _config.customBgImagePath!.isNotEmpty &&
        File(_config.customBgImagePath!).existsSync();

    final Widget cardMain = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(child: backgroundLayer),
          if (hasCustomBgImage) ...[
            Positioned.fill(
              child: Image.file(
                File(_config.customBgImagePath!),
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Tách Trái / Phải, Bỏ vạch cam ở header)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: isWeeklyGrid ? 15.5 : (is2x2 ? 13 : 14),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    if (displaySubtitle.isNotEmpty)
                      Text(
                        displaySubtitle,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: isWeeklyGrid ? 11.5 : 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          color: secondaryTextColor,
                        ),
                      ),
                  ],
                ),

                // Hairline Divider 0.5dp (Ẩn đi khi chọn trong suốt 100%)
                if (_config.bgStyle != 'transparent')
                  Container(
                    margin: EdgeInsets.only(
                      top: is2x2 ? 6 : 8,
                      bottom: is2x2 ? 6 : 8,
                    ),
                    height: 0.5,
                    color: isLightBg
                        ? const Color(0xFFE2E8F0)
                        : secondaryTextColor.withOpacity(0.2),
                  )
                else
                  SizedBox(height: is2x2 ? 6 : 8),

                // Nội dung theo Layout Mode
                Expanded(
                  child: ClipRect(
                    child: _buildLayoutContent(
                        data, primaryTextColor, secondaryTextColor, accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // LỚP 1: Khung đệm ngoài trong suốt (Outer Transparent Inset 10dp)
    // LỚP 2: Thẻ widget chính bo góc 16dp
    // LỚP 3: Khối nội dung bên trong padding 10dp
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(10),
      child: cardMain,
    );
  }

  Widget _buildLayoutContent(
    WidgetScheduleData? data,
    Color primaryColor,
    Color secondaryColor,
    Color accent,
  ) {
    if (data == null || data.days.isEmpty) {
      return Center(
        child: Text(
          'KHÔNG CÓ LỊCH HỌC TRONG KHOẢNG NÀY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: secondaryColor,
          ),
        ),
      );
    }

    if (_config.layoutMode == 'seven_days') {
      return _buildSevenDaysGridContent(
          data, primaryColor, secondaryColor, accent);
    } else if (_config.layoutMode == 'three_days') {
      return _buildThreeDaysContent(data, primaryColor, secondaryColor, accent);
    } else {
      return _buildSingleDay4x2TimelineContent(
          data, primaryColor, secondaryColor, accent);
    }
  }

  // ── BIẾN THỂ 1B (1 Ngày · 4x2 Timeline Trực Quan) ──────────────────────────
  Widget _buildSingleDay4x2TimelineContent(
    WidgetScheduleData data,
    Color primaryColor,
    Color secondaryColor,
    Color accent,
  ) {
    final day = data.days.first;
    List<WidgetClassItem> classes = day.classes;
    if (classes.isEmpty) {
      final fallback = _buildFallbackPreviewData('single_day');
      classes = fallback.days.first.classes;
    }

    if (classes.isEmpty) {
      return Center(
        child: Text(
          'Không có ca học nào',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: secondaryColor,
          ),
        ),
      );
    }

    final displayClasses = classes.take(2).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < displayClasses.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildTimelineRow(
            displayClasses[i],
            primaryColor,
            secondaryColor,
            accent,
          ),
        ],
        if (classes.length > 2) ...[
          const Spacer(),
          Text(
            '(+${classes.length - 2} môn nữa)',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineRow(
    WidgetClassItem c,
    Color primaryColor,
    Color secondaryColor,
    Color accent,
  ) {
    final startHour = ScheduleCard.formatStartHour(c.timeSlot);
    final endHour = ScheduleCard.formatEndHour(c.timeSlot);
    final isExam = c.isExam || c.courseName.startsWith('[THI]');
    final itemAccent = isExam ? const Color(0xFFEF4444) : accent;
    final itemTextColor = isExam ? const Color(0xFFEF4444) : primaryColor;

    final hybrid = WidgetDataSyncService.formatHybridTimeAndRoom(
      timeSlot: '',
      room: c.room,
      showTime: false,
      showRoom: _config.showRoom,
      teacher: c.teacher,
      showTeacher: _config.showTeacher,
      classCode: c.classCode,
      showClassCode: _config.showClassCode,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Cột trái: Giờ bắt đầu & Giờ kết thúc
        SizedBox(
          width: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                startHour,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: itemAccent,
                ),
              ),
              if (endHour.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  endHour,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: secondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Trục Timeline Indicator (Capsule / Line màu Accent)
        Container(
          width: 3,
          height: 28,
          margin: const EdgeInsets.only(left: 4, right: 10),
          decoration: BoxDecoration(
            color: itemAccent,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),

        // Cột phải: 2 dòng (Dòng 1: Tên môn to rõ; Dòng 2: Hàng thông tin phụ trợ gom trên 1 hàng)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.courseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: itemTextColor,
                ),
              ),
              if (hybrid.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  hybrid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: secondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── BIẾN THỂ 1 (1 Ngày · 2x2 Thẻ Vuông) ─────────────────────────────────────
  Widget _buildSingleDay2x2Content(
    WidgetScheduleData data,
    Color primaryColor,
    Color secondaryColor,
    Color accent,
  ) {
    final day = data.days.first;
    List<WidgetClassItem> classes = day.classes;
    if (classes.isEmpty) {
      final fallback = _buildFallbackPreviewData('single_day');
      classes = fallback.days.first.classes;
    }

    if (classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'SẮP TỚI',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hôm nay nghỉ',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: secondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    final allFinished = classes.isNotEmpty && classes.every((c) => c.isFinished);
    final c1 = classes[0];
    final hybrid1 = WidgetDataSyncService.formatHybridTimeAndRoom(
      timeSlot: c1.timeSlot,
      room: c1.room,
      showTime: _config.showTime,
      showRoom: _config.showRoom,
      teacher: c1.teacher,
      showTeacher: _config.showTeacher,
    );

    final hasC2 = classes.length > 1;
    final c2 = hasC2 ? classes[1] : null;
    final hybrid2 = hasC2
        ? WidgetDataSyncService.formatHybridTimeAndRoom(
            timeSlot: c2!.timeSlot,
            room: c2.room,
            showTime: _config.showTime,
            showRoom: _config.showRoom,
            teacher: c2.teacher,
            showTeacher: _config.showTeacher,
          )
        : '';

    final hasExtra = classes.length > 2;
    final extraCount = classes.length - 2;
    final footerText = '+$extraCount môn nữa';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Môn 1: Tên môn in đậm 1 dòng (Size 11.5sp). Ngay bên dưới là giờ • phòng (Size 9sp, Regular)
        Builder(builder: (_) {
          final isExam1 = c1.isExam || c1.courseName.startsWith('[THI]');
          final title1 = isExam1 && !c1.courseName.startsWith('[THI]') ? '[THI] ${c1.courseName}' : c1.courseName;
          final color1 = isExam1
              ? const Color(0xFFEF4444)
              : (c1.isFinished ? secondaryColor : primaryColor);
          return Text(
            title1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color1,
            ),
          );
        }),
        const SizedBox(height: 1),
        Text(
          hybrid1,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w400,
            color: secondaryColor,
          ),
        ),

        // Đệm giữa 2 môn: 6dp
        if (hasC2) ...[
          const SizedBox(height: 6),
          // Môn 2: Tên môn in đậm 1 dòng (Size 11.5sp). Ngay bên dưới là giờ • phòng (Size 9sp, Regular)
          Builder(builder: (_) {
            final isExam2 = c2!.isExam || c2.courseName.startsWith('[THI]');
            final title2 = isExam2 && !c2.courseName.startsWith('[THI]') ? '[THI] ${c2.courseName}' : c2.courseName;
            final color2 = isExam2
                ? const Color(0xFFEF4444)
                : (c2.isFinished ? secondaryColor : primaryColor);
            return Text(
              title2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color2,
              ),
            );
          }),
          const SizedBox(height: 1),
          Text(
            hybrid2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w400,
              color: secondaryColor,
            ),
          ),
        ],

        // Footer dưới cùng: Hiển thị [ĐÃ XONG] nếu allFinished, hoặc footerText nếu hasExtra
        if (allFinished)
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                '[ĐÃ XONG]',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: secondaryColor,
                ),
              ),
            ),
          )
        else if (hasExtra)
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                footerText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── BIẾN THỂ 2 (3 Ngày · 4x2 Tách 2 Hàng) ──────────────────────────────────
  Widget _buildThreeDaysContent(
    WidgetScheduleData data,
    Color primaryColor,
    Color secondaryColor,
    Color accent,
  ) {
    return Column(
      children: List.generate(data.days.length, (idx) {
        final day = data.days[idx];
        final bool isToday = day.isToday;
        final bool isDimmed = isToday ? false : day.isDimmed;
        final double opacity = (isToday || !isDimmed) ? 1.0 : 0.45;
        final hasClass = day.classes.isNotEmpty;
        final firstClass = hasClass ? day.classes.first : null;

        final hybridInfo = firstClass != null
            ? WidgetDataSyncService.formatHybridTimeAndRoom(
                timeSlot: firstClass.timeSlot,
                room: firstClass.room,
                showTime: _config.showTime,
                showRoom: _config.showRoom,
                teacher: firstClass.teacher,
                showTeacher: _config.showTeacher,
              )
            : '';

        return Expanded(
          child: ClipRect(
            child: Container(
              margin:
                  EdgeInsets.only(bottom: idx < data.days.length - 1 ? 6 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isToday
                    ? accent.withOpacity(0.12)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(isToday ? 8 : 6),
                border: Border.all(
                  color: isToday
                      ? accent.withOpacity(0.55)
                      : Colors.white.withOpacity(0.08),
                  width: isToday ? 0.8 : 0.5,
                ),
              ),
              child: Opacity(
                opacity: opacity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột trái: "T2 17/08" (bỏ hoàn toàn vạch cam chèn ở đầu hàng làm lệch lề)
                    Text(
                      '${day.weekdayStr} ${day.dateStr}',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                        color: isToday ? accent : primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Cột phải: TÁCH RÕ RÀNG 2 HÀNG RIÊNG BIỆT (dóng thẳng hàng từ đỉnh)
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Hàng 1: Tên môn
                            Builder(builder: (_) {
                              final isExam = hasClass && (firstClass!.isExam || firstClass.courseName.startsWith('[THI]'));
                              final isFinished = hasClass && firstClass!.isFinished;
                              final title = hasClass
                                  ? (isExam && !firstClass!.courseName.startsWith('[THI]')
                                      ? '[THI] ${firstClass.courseName}'
                                      : firstClass!.courseName)
                                  : 'Không có lịch';
                              final textColor = hasClass
                                  ? (isExam
                                      ? const Color(0xFFEF4444)
                                      : (isFinished ? secondaryColor : primaryColor))
                                  : secondaryColor.withOpacity(0.6);
                              return Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight:
                                      isToday ? FontWeight.w700 : FontWeight.w600,
                                  color: textColor,
                                ),
                              );
                            }),
                            if (hasClass && hybridInfo.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              // Hàng 2: Giờ (Tiết) • Phòng
                              Text(
                                hybridInfo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── BIẾN THỂ 4 (7 Ngày · 4x4 Grid 2x4 gồm 8 Ô) ──────────────────────────────
  Widget _buildSevenDaysGridContent(
    WidgetScheduleData data,
    Color primaryColor,
    Color secondaryColor,
    Color accent,
  ) {
    final days = data.days;
    int totalClasses = 0;
    int totalExams = 0;
    int emptyDays = 0;
    for (final d in days) {
      if (d.classes.isEmpty) {
        emptyDays++;
      } else {
        for (final c in d.classes) {
          if (c.isExam || c.courseName.startsWith('[THI]')) {
            totalExams++;
          } else {
            totalClasses++;
          }
        }
      }
    }

    return Column(
      children: List.generate(4, (rowIdx) {
        final leftIndex = rowIdx * 2;
        final rightIndex = rowIdx * 2 + 1;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: rowIdx < 3 ? 6 : 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildGridDayCell(
                    leftIndex < days.length ? days[leftIndex] : null,
                    primaryColor,
                    secondaryColor,
                    accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: rightIndex == 7
                      ? _buildGridSummaryCell(totalClasses, totalExams, emptyDays,
                          primaryColor, secondaryColor, accent)
                      : _buildGridDayCell(
                          rightIndex < days.length ? days[rightIndex] : null,
                          primaryColor,
                          secondaryColor,
                          accent,
                        ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGridDayCell(
    WidgetDaySchedule? day,
    Color primaryColor,
    Color secondaryColor,
    Color accent,
  ) {
    if (day == null) return const SizedBox.shrink();

    final isToday = day.isToday;
    final classes = day.classes;
    final count = classes.length;

    return ClipRect(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: isToday
              ? accent.withOpacity(0.16)
              : (_config.bgStyle == 'transparent'
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(
                  color: accent.withOpacity(0.85),
                  width: 1.0,
                )
              : (_config.bgStyle == 'transparent'
                  ? null
                  : Border.all(
                      color: Colors.white.withOpacity(0.07),
                      width: 0.5,
                    )),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '${day.weekdayStr} ${day.dateStr}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                      color: isToday ? accent : secondaryColor,
                    ),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                    child: Text(
                      'HÔM NAY',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 6.5,
                        fontWeight: FontWeight.w800,
                        color: accent.computeLuminance() > 0.5
                            ? const Color(0xFF0F172A)
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
                const SizedBox(height: 1),
                if (count == 0)
                  Text(
                    'Không có lịch',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: secondaryColor.withOpacity(0.6),
                    ),
                  )
                else ...[
                  // Hàng 2: Tên môn 1 (Bold 10.5sp, maxLines: 1, ellipsis)
                  Builder(builder: (_) {
                    final isExam = classes[0].isExam || classes[0].courseName.startsWith('[THI]');
                    final isFinished = classes[0].isFinished;
                    final title = isExam && !classes[0].courseName.startsWith('[THI]')
                        ? '[THI] ${classes[0].courseName}'
                        : classes[0].courseName;
                    final textColor = isExam
                        ? const Color(0xFFEF4444)
                        : (isFinished ? secondaryColor : primaryColor);
                    return Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    );
                  }),
                  // Hàng 3: Giờ • Phòng môn 1 (9sp)
                  Builder(builder: (_) {
                    final tr = WidgetDataSyncService.formatHybridTimeAndRoom(
                      timeSlot: classes[0].timeSlot,
                      room: classes[0].room,
                      showTime: _config.showTime,
                      showRoom: _config.showRoom,
                      teacher: classes[0].teacher,
                      showTeacher: _config.showTeacher,
                    );
                    if (tr.isEmpty) return const SizedBox.shrink();
                    return Text(
                      tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        color: secondaryColor,
                      ),
                    );
                  }),
                  // Hàng môn 2 (khi count >= 2)
                  if (count >= 2) ...[
                    Builder(builder: (_) {
                      final isExam2 = classes[1].isExam || classes[1].courseName.startsWith('[THI]');
                      final isFinished2 = classes[1].isFinished;
                      final title2 = isExam2 && !classes[1].courseName.startsWith('[THI]')
                          ? '[THI] ${classes[1].courseName}'
                          : classes[1].courseName;
                      final textColor2 = isExam2
                          ? const Color(0xFFEF4444)
                          : (isFinished2 ? secondaryColor : primaryColor);
                      return Text(
                        title2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: textColor2,
                        ),
                      );
                    }),
                    Builder(builder: (_) {
                      if (count >= 3) {
                        return const SizedBox.shrink();
                      }
                      final tr2 = WidgetDataSyncService.formatHybridTimeAndRoom(
                        timeSlot: classes[1].timeSlot,
                        room: classes[1].room,
                        showTime: _config.showTime,
                        showRoom: _config.showRoom,
                        teacher: classes[1].teacher,
                        showTeacher: _config.showTeacher,
                      );
                      if (tr2.isEmpty) return const SizedBox.shrink();
                      return Text(
                        tr2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          color: secondaryColor,
                        ),
                      );
                    }),
                  ],
                  // Dòng cuối cùng: (+... môn nữa) khi có >= 3 môn (8sp màu accent)
                  if (count >= 3)
                    Text(
                      '(+${count - 2} môn nữa)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
  }

  Widget _buildGridSummaryCell(
    int totalClasses,
    int totalExams,
    int emptyDays,
    Color primaryColor,
    Color secondaryColor,
    Color accent,
  ) {
    return ClipRect(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accent.withOpacity(0.5),
            width: 0.8,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TỔNG KẾT TUẦN',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalClasses buổi học • $totalExams buổi thi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$emptyDays ngày trống',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassRow(
    WidgetClassItem c,
    Color primaryColor,
    Color secondaryColor,
    Color accent,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (c.isCurrentOrNext)
          Container(
            width: 2.5,
            height: 24,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  if (_config.showClassCode && c.classCode.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        c.classCode,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: primaryColor.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (_config.showTime) ...[
                    Text(
                      c.timeSlot,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_config.showRoom) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        c.room,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_config.showTeacher && c.teacher.isNotEmpty)
                    Expanded(
                      child: Text(
                        c.teacher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 8,
                          color: secondaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── CONTROLS: SECTION HEADERS & PICKERS ─────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildLayoutModeSelector() {
    final modes = [
      ('single_day', 'Lịch hôm nay'),
      ('three_days', 'Lịch 3 ngày'),
      ('seven_days', 'Lịch tuần'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: modes.map((m) {
            final isSelected = _config.layoutMode == m.$1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  key: Key('mode_${m.$1}'),
                  onTap: () => _onLayoutModeChanged(m.$1),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1D64F2)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1D64F2)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      m.$2,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPresetsSelector() {
    final presets = [
      (
        'Tối giản Thụy Sĩ',
        WidgetThemeConfig.minimalSwiss(layoutMode: _config.layoutMode),
      ),
      (
        'Nền Sáng Tinh Gọn',
        WidgetThemeConfig.solidLight(layoutMode: _config.layoutMode),
      ),
      (
        'Ghost Mode',
        WidgetThemeConfig.ghostMode(layoutMode: _config.layoutMode),
      ),
      (
        'Cyberpunk Neon',
        WidgetThemeConfig.cyberpunkNeon(layoutMode: _config.layoutMode),
      ),
      (
        'Dark Obsidian',
        WidgetThemeConfig.darkObsidian(layoutMode: _config.layoutMode),
      ),
      (
        'Deep Forest',
        WidgetThemeConfig.deepForest(layoutMode: _config.layoutMode),
      ),
      (
        'Sunset Minimal',
        WidgetThemeConfig.sunsetMinimal(layoutMode: _config.layoutMode),
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((p) {
        final isSelected = _selectedPresetName == p.$1;
        return InkWell(
          onTap: () => _applyPreset(p.$1, p.$2),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1D64F2)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1D64F2)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1D64F2).withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.$1,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBgStyleSelector() {
    final styles = [
      ('solid', 'Nền Màu Đặc'),
      ('transparent', 'Trong suốt 100%'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: styles.map((s) {
            final isSelected = _config.bgStyle == s.$1;
            return ChoiceChip(
              key: Key('bg_style_${s.$1}'),
              showCheckmark: false,
              label: Text(
                s.$2,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1D64F2),
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide(
                color:
                    isSelected ? const Color(0xFF1D64F2) : const Color(0xFFE2E8F0),
                width: 1,
              ),
              onSelected: (_) {
                WidgetThemeConfig updated;
                if (s.$1 == 'transparent') {
                  updated = _config.copyWith(
                    bgStyle: 'transparent',
                    bgOpacity: 0.0,
                    bgColorHex: '#00000000',
                  );
                } else {
                  updated = _config.copyWith(
                    bgStyle: 'solid',
                    bgOpacity: 1.0,
                    bgColorHex: (_config.bgColorHex == '#00000000' || _config.bgColorHex.isEmpty)
                        ? '#1C1C1E'
                        : _config.bgColorHex,
                  );
                }
                _updateConfigAndRefreshPreview(updated);
              },
            );
          }).toList(),
        ),
        if (_config.bgStyle == 'solid') ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const Key('quick_solid_dark'),
                showCheckmark: false,
                label: const Text(
                  'Nền Tối',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11),
                ),
                selected: _config.bgColorHex != '#FFFFFF' &&
                    _config.bgColorHex != '#F8F9FA',
                selectedColor: const Color(0xFF1E293B),
                labelStyle: TextStyle(
                  color: (_config.bgColorHex != '#FFFFFF' &&
                          _config.bgColorHex != '#F8F9FA')
                      ? Colors.white
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) {
                  _updateConfigAndRefreshPreview(
                    _config.copyWith(
                      bgColorHex: '#1C1C1E',
                      textPrimaryHex: '#FFFFFF',
                      textSecondaryHex: '#CBD5E1',
                      borderColorHex: '#26FFFFFF',
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: const Key('quick_solid_light'),
                showCheckmark: false,
                label: const Text(
                  'Nền Sáng',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11),
                ),
                selected: _config.bgColorHex == '#FFFFFF' ||
                    _config.bgColorHex == '#F8F9FA',
                selectedColor: const Color(0xFFE2E8F0),
                labelStyle: TextStyle(
                  color: (_config.bgColorHex == '#FFFFFF' ||
                          _config.bgColorHex == '#F8F9FA')
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) {
                  _updateConfigAndRefreshPreview(
                    _config.copyWith(
                      bgColorHex: '#FFFFFF',
                      textPrimaryHex: '#0F172A',
                      textSecondaryHex: '#64748B',
                      borderColorHex: '#E2E8F0',
                    ),
                  );
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
              label: const Text(
                'CHỌN ẢNH TỪ MÁY',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1D64F2),
                side: const BorderSide(color: Color(0xFF1D64F2), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () async {
                final path =
                    await WidgetDataSyncService.pickBackgroundImage();
                if (path != null && path.isNotEmpty) {
                  _updateConfigAndRefreshPreview(
                    _config.copyWith(customBgImagePath: path),
                  );
                }
              },
            ),
            if (_config.customBgImagePath != null &&
                _config.customBgImagePath!.isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.close,
                    size: 14, color: Color(0xFFEF4444)),
                label: const Text(
                  'Xóa ảnh',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
                onPressed: () {
                  _updateConfigAndRefreshPreview(
                    _config.copyWith(customBgImagePath: ''),
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildColorSelectors() {
    final bool isTransparent = _config.bgStyle == 'transparent';
    const standardColors = [
      '#1C1C1E',
      '#FFFFFF',
      '#64748B',
      '#1D64F2',
      '#10B981',
      '#F59E0B',
      '#EF4444',
    ];

    return Column(
      children: [
        IgnorePointer(
          ignoring: isTransparent,
          child: Opacity(
            opacity: isTransparent ? 0.4 : 1.0,
            child: _buildColorRow(
              title: 'Màu Nền',
              subtitle: isTransparent
                  ? '(Nền trong suốt - Không áp dụng màu nền)'
                  : null,
              currentHex: _config.bgColorHex,
              presetHexes: standardColors,
              onSelected: (hex) => _updateConfigAndRefreshPreview(
                _config.copyWith(bgColorHex: hex),
              ),
            ),
          ),
        ),
        const Divider(height: 16, color: Color(0xFFF1F5F9)),
        _buildColorRow(
          title: 'Màu Chữ Chính',
          currentHex: _config.textPrimaryHex,
          presetHexes: standardColors,
          onSelected: (hex) => _updateConfigAndRefreshPreview(
            _config.copyWith(textPrimaryHex: hex),
          ),
        ),
        const Divider(height: 16, color: Color(0xFFF1F5F9)),
        _buildColorRow(
          title: 'Màu Chữ Phụ',
          currentHex: _config.textSecondaryHex,
          presetHexes: standardColors,
          onSelected: (hex) => _updateConfigAndRefreshPreview(
            _config.copyWith(textSecondaryHex: hex),
          ),
        ),
        const Divider(height: 16, color: Color(0xFFF1F5F9)),
        _buildColorRow(
          title: 'Màu Điểm Nhấn',
          currentHex: _config.accentColorHex,
          presetHexes: standardColors,
          onSelected: (hex) => _updateConfigAndRefreshPreview(
            _config.copyWith(accentColorHex: hex),
          ),
        ),
      ],
    );
  }

  Widget _buildColorRow({
    required String title,
    String? subtitle,
    required String currentHex,
    required List<String> presetHexes,
    required ValueChanged<String> onSelected,
  }) {
    final bool isCustomSelected = !presetHexes.any(
      (h) => h.toUpperCase() == currentHex.toUpperCase(),
    );
    final customColor = WidgetThemeConfig.hexToColor(currentHex);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...presetHexes.map((hex) {
              final isSelected = currentHex.toUpperCase() == hex.toUpperCase();
              final color = WidgetThemeConfig.hexToColor(hex);
              return GestureDetector(
                onTap: () => onSelected(hex),
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1D64F2)
                          : const Color(0xFFCBD5E1),
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 13,
                          color: (color.computeLuminance() > 0.5)
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }),
            // Ô/Nút Custom Color cho phép nhập mã Hex hoặc chọn màu tự do
            GestureDetector(
              onTap: () => _showCustomColorDialog(
                title: title,
                initialHex: currentHex,
                onSelected: onSelected,
              ),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color:
                      isCustomSelected ? customColor : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCustomSelected
                        ? const Color(0xFF1D64F2)
                        : const Color(0xFF94A3B8),
                    width: isCustomSelected ? 2.5 : 1,
                  ),
                ),
                child: isCustomSelected
                    ? Icon(
                        Icons.check,
                        size: 13,
                        color: (customColor.computeLuminance() > 0.5)
                            ? Colors.black
                            : Colors.white,
                      )
                    : const Icon(
                        Icons.edit,
                        size: 11,
                        color: Color(0xFF475569),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Dialog tùy chỉnh mã màu Hex trực tiếp với HSV Color Wheel tương tác 2 chiều
  void _showCustomColorDialog({
    required String title,
    required String initialHex,
    required ValueChanged<String> onSelected,
  }) {
    String cleanInitial = initialHex.toUpperCase();
    if (!cleanInitial.startsWith('#')) {
      cleanInitial = '#$cleanInitial';
    }
    final textController = TextEditingController(text: cleanInitial);
    String previewHex = cleanInitial;
    HSVColor currentHsv =
        HSVColor.fromColor(WidgetThemeConfig.hexToColor(cleanInitial));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final currentColor = WidgetThemeConfig.hexToColor(previewHex);
            final bool isDark = currentColor.computeLuminance() < 0.5;

            const double wheelRadius = 80.0;
            const double wheelDiameter = wheelRadius * 2;
            const center = Offset(wheelRadius, wheelRadius);
            final angleRad = currentHsv.hue * math.pi / 180.0;
            final dist = currentHsv.saturation * wheelRadius;
            final thumbX = center.dx + dist * math.cos(angleRad);
            final thumbY = center.dy + dist * math.sin(angleRad);

            void handleWheelTouch(Offset localPos) {
              final dx = localPos.dx - center.dx;
              final dy = localPos.dy - center.dy;
              final touchDist = math.sqrt(dx * dx + dy * dy);
              final newSat = (touchDist / wheelRadius).clamp(0.0, 1.0);
              double angleDeg = math.atan2(dy, dx) * 180.0 / math.pi;
              if (angleDeg < 0) angleDeg += 360.0;

              setDialogState(() {
                currentHsv = HSVColor.fromAHSV(
                    1.0, angleDeg, newSat, currentHsv.value);
                final hex =
                    WidgetDataSyncService.colorToHex(currentHsv.toColor());
                previewHex = hex;
                textController.text = hex;
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              title: const Row(
                children: [
                  Icon(Icons.palette_outlined,
                      size: 20, color: Color(0xFF1D64F2)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TÙY CHỈNH MÀU',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Live Preview Box + Input Field
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: currentColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFCBD5E1), width: 1),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.format_paint_outlined,
                              size: 18,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: textController,
                            autofocus: false,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: Color(0xFF1E293B),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Mã màu Hex',
                              hintText: '#1D64F2',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFF1D64F2), width: 2),
                              ),
                            ),
                            onChanged: (val) {
                              String normalized = val.trim();
                              if (!normalized.startsWith('#')) {
                                normalized = '#$normalized';
                              }
                              setDialogState(() {
                                previewHex = normalized;
                                try {
                                  final parsedColor =
                                      WidgetThemeConfig.hexToColor(normalized);
                                  currentHsv =
                                      HSVColor.fromColor(parsedColor);
                                } catch (_) {}
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // HSV Color Wheel (Vòng tròn màu tương tác 2 chiều)
                    Center(
                      child: GestureDetector(
                        onPanDown: (d) => handleWheelTouch(d.localPosition),
                        onPanUpdate: (d) => handleWheelTouch(d.localPosition),
                        child: SizedBox(
                          width: wheelDiameter,
                          height: wheelDiameter,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                size: const Size(wheelDiameter, wheelDiameter),
                                painter:
                                    _HsvWheelPainter(value: currentHsv.value),
                              ),
                              Positioned(
                                left: thumbX - 9,
                                top: thumbY - 9,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: currentColor,
                                    border: Border.all(
                                        color: Colors.white, width: 2.5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black38,
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Thanh trượt Độ sáng (Value / Brightness)
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny_outlined,
                            size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF1D64F2),
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              thumbColor: const Color(0xFF1D64F2),
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              value: currentHsv.value,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (val) {
                                setDialogState(() {
                                  currentHsv = currentHsv.withValue(val);
                                  final hex = WidgetDataSyncService.colorToHex(
                                      currentHsv.toColor());
                                  previewHex = hex;
                                  textController.text = hex;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bảng màu nhanh:',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick Palette Swatches
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        '#000000',
                        '#121212',
                        '#1C1C1E',
                        '#334155',
                        '#64748B',
                        '#94A3B8',
                        '#E2E8F0',
                        '#FFFFFF',
                        '#1D64F2',
                        '#0A84FF',
                        '#06B6D4',
                        '#10B981',
                        '#F59E0B',
                        '#EF4444',
                        '#EC4899',
                        '#8B5CF6',
                      ].map((swatchHex) {
                        final swatchColor =
                            WidgetThemeConfig.hexToColor(swatchHex);
                        return GestureDetector(
                          onTap: () {
                            textController.text = swatchHex;
                            final parsedColor =
                                WidgetThemeConfig.hexToColor(swatchHex);
                            setDialogState(() {
                              previewHex = swatchHex;
                              currentHsv =
                                  HSVColor.fromColor(parsedColor);
                            });
                          },
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: swatchColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (previewHex.toUpperCase() ==
                                        swatchHex.toUpperCase())
                                    ? const Color(0xFF1D64F2)
                                    : const Color(0xFFCBD5E1),
                                width: (previewHex.toUpperCase() ==
                                        swatchHex.toUpperCase())
                                    ? 2.5
                                    : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'HỦY',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D64F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    String finalHex = textController.text.trim();
                    if (!finalHex.startsWith('#')) {
                      finalHex = '#$finalHex';
                    }
                    Navigator.pop(ctx);
                    onSelected(finalHex);
                  },
                  child: const Text(
                    'ÁP DỤNG',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFieldSwitches() {
    return Column(
      children: [
        _buildSwitchRow(
          label: 'Hiện Phòng học',
          value: _config.showRoom,
          onChanged: (v) =>
              _updateConfigAndRefreshPreview(_config.copyWith(showRoom: v)),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        _buildSwitchRow(
          label: 'Hiện Khung giờ & Tiết học',
          value: _config.showTime,
          onChanged: (v) =>
              _updateConfigAndRefreshPreview(_config.copyWith(showTime: v)),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        _buildSwitchRow(
          label: 'Hiện Tên Giảng viên',
          value: _config.showTeacher,
          onChanged: (v) =>
              _updateConfigAndRefreshPreview(_config.copyWith(showTeacher: v)),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        _buildSwitchRow(
          label: 'Hiện Mã lớp học phần (TH4327_23CN 2)',
          value: _config.showClassCode,
          onChanged: (v) =>
              _updateConfigAndRefreshPreview(_config.copyWith(showClassCode: v)),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeColor: const Color(0xFF1D64F2),
            activeTrackColor: const Color(0xFF93C5FD),
            inactiveThumbColor: const Color(0xFF94A3B8),
            inactiveTrackColor: const Color(0xFFE2E8F0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// CustomPainter vẽ vòng tròn màu HSV tương tác
class _HsvWheelPainter extends CustomPainter {
  final double value;
  const _HsvWheelPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Hue Sweep Gradient
    const sweepColors = [
      Color(0xFFFF0000), // 0° Red
      Color(0xFFFFFF00), // 60° Yellow
      Color(0xFF00FF00), // 120° Green
      Color(0xFF00FFFF), // 180° Cyan
      Color(0xFF0000FF), // 240° Blue
      Color(0xFFFF00FF), // 300° Magenta
      Color(0xFFFF0000), // 360° Red
    ];
    final sweepPaint = Paint()
      ..shader = SweepGradient(colors: sweepColors).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, sweepPaint);

    // 2. Saturation Radial Gradient (tâm trắng mờ dần ra rìa)
    final satPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, satPaint);

    // 3. Phủ lớp tối khi điều chỉnh độ sáng (Value < 1.0)
    if (value < 1.0) {
      final valPaint = Paint()
        ..color = Colors.black.withOpacity((1.0 - value).clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, valPaint);
    }

    // 4. Viền mờ tinh tế
    final borderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HsvWheelPainter oldDelegate) =>
      oldDelegate.value != value;
}
