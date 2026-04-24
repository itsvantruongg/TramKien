import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'finance_screen.dart';
import 'grades_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  int _navDirection = 1;
  DateTime? _lastBackPress;
  double? _navDragValue;
  bool _navDragging = false;

  String _screenNameForIndex(int idx) => switch (idx) {
        0 => 'Dashboard',
        1 => 'Schedule',
        2 => 'Grades',
        3 => 'Finance',
        4 => 'Profile',
        _ => 'MainShell',
      };

  void _logCurrentScreen() {
    unawaited(
      AnalyticsService.logScreenView(
        screenName: _screenNameForIndex(_idx),
        screenClass: '${_screenNameForIndex(_idx)}Screen',
      ),
    );
  }

  void _navigate(int idx) {
    if (idx == _idx) return;
    setState(() {
      _navDirection = idx > _idx ? 1 : -1;
      _idx = idx;
    });
    _logCurrentScreen();
  }

  double get _navBaseValue => _idx.toDouble();

  double get _navVisualValue => (_navDragValue ?? _navBaseValue).clamp(0.0, 4.0);

  void _startNavDrag(double dx, double itemWidth) {
    setState(() {
      _navDragging = true;
      // Công thức map tọa độ ngón tay (dx) thành vị trí index (0.0 -> 4.0)
      _navDragValue = ((dx / itemWidth) - 0.5).clamp(0.0, 4.0);
    });
  }

  void _updateNavDrag(double dx, double itemWidth) {
    setState(() {
      _navDragValue = ((dx / itemWidth) - 0.5).clamp(0.0, 4.0);
    });
  }

  void _endNavDrag() {
    final nextIdx = _navVisualValue.round().clamp(0, 4);
    if (nextIdx != _idx) {
      _navigate(nextIdx); // Chuyển màn hình khi nhả tay ra
    }
    if (!mounted) return;
    setState(() {
      _navDragging = false;
      _navDragValue = null;
    });
  }

  void _cancelNavDrag() {
    if (!mounted) return;
    setState(() {
      _navDragging = false;
      _navDragValue = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _logCurrentScreen();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigate: _navigate),
      const ScheduleScreen(),
      const GradesScreen(),
      const FinanceScreen(),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Nếu đang ở tab khác Dashboard → về Dashboard
        if (_idx != 0) {
          setState(() {
            _navDirection = -1;
            _idx = 0;
          });
          _logCurrentScreen();
          return;
        }
        // Đang ở Dashboard → double-press để thoát
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..removeCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const Row(children: [
                    Icon(Icons.exit_to_app, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text('Ấn lần nữa để thoát ứng dụng'),
                  ]),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  backgroundColor: AppTheme.onSurface.withOpacity(0.9),
                ),
              );
          }
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: List.generate(screens.length, (i) {
            final active = i == _idx;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              opacity: active ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: active
                    ? Offset.zero
                    : Offset(0, _navDirection > 0 ? 0.02 : -0.02),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  scale: active ? 1.0 : 0.985,
                  child: IgnorePointer(
                    ignoring: !active,
                    child: screens[i],
                  ),
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar: _buildNav(),
      ),
    );
  }

  Widget _buildNav() {
    // Lấy index dựa trên vị trí kéo thực tế (để đổi màu icon ngay khi đang vuốt)
    final currentVisualIdx = _navVisualValue.round().clamp(0, 4);

    // Lấy bottom safe area padding (home indicator trên iPhone hoặc gesture bar trên Android)
    // Đây là nguyên nhân chính gây lỗi nav bar trên iOS
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      // Margin: thêm bottomPadding vào đáy để nav bar nằm trên home indicator
      // Thay vì dùng SafeArea bên trong ClipRRect (gây lỗi tính toán chiều cao)
      margin: EdgeInsets.fromLTRB(14, 0, 14, 12 + bottomPadding),
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
      decoration: BoxDecoration(
        // Tạo độ bóng 3D cho bề mặt kính bằng Gradient (thay vì dùng màu trơn)
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surface.withOpacity(0.3), // Sáng hơn ở góc trên trái
            AppTheme.surface.withOpacity(0.1), // Trong suốt hơn ở góc dưới phải
          ],
        ),
        borderRadius: BorderRadius.circular(24),

        // Viền trắng mờ để tạo hiệu ứng ánh sáng đập vào mép kính
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1.2,
        ),

        // Bóng đổ để tách biệt khỏi nền app
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: -10,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          // KHÔNG dùng SafeArea bên trong ClipRRect vì nó gây ra lỗi tính chiều cao trên iOS.
          // Thay vào đó, bottomPadding đã được xử lý ở margin bên ngoài.
          child: SizedBox(
            height: 54, // Chiều cao nội dung nav, không đổi trên mọi thiết bị
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 5;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) =>
                      _startNavDrag(details.localPosition.dx, itemWidth),
                  onPanUpdate: (details) =>
                      _updateNavDrag(details.localPosition.dx, itemWidth),
                  onPanEnd: (_) => _endNavDrag(),
                  onPanCancel: () => _endNavDrag(),
                  child: Stack(
                    children: [
                      Positioned(
                        left: _navVisualValue * itemWidth,
                        top: 0,
                        child: AnimatedContainer(
                          duration:
                              Duration(milliseconds: _navDragging ? 0 : 220),
                          curve: Curves.easeOutCubic,
                          width: itemWidth,
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryFixed.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _navItem(
                            icon: Icons.dashboard_outlined,
                            activeIcon: Icons.dashboard,
                            label: 'Dashboard',
                            idx: 0,
                            currentActiveIdx: currentVisualIdx,
                          ),
                          _navItem(
                            icon: Icons.calendar_today_outlined,
                            activeIcon: Icons.calendar_today,
                            label: 'Lịch',
                            idx: 1,
                            currentActiveIdx: currentVisualIdx,
                          ),
                          _navItem(
                            icon: Icons.grade_outlined,
                            activeIcon: Icons.grade,
                            label: 'Điểm',
                            idx: 2,
                            currentActiveIdx: currentVisualIdx,
                          ),
                          _navItem(
                            icon: Icons.payments_outlined,
                            activeIcon: Icons.payments,
                            label: 'Tài chính',
                            idx: 3,
                            currentActiveIdx: currentVisualIdx,
                          ),
                          _navItem(
                            icon: Icons.person_outline,
                            activeIcon: Icons.person,
                            label: 'Profile',
                            idx: 4,
                            currentActiveIdx: currentVisualIdx,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int idx,
    required int currentActiveIdx, // Thêm tham số này
  }) {
    // SỬA: Sử dụng index kéo thực tế thay vì index cố định
    final active = currentActiveIdx == idx;

    return Expanded(
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: active ? 1.04 : 1.0,
              child: Icon(
                activeIcon, // SỬA: Hiển thị icon đã active ngay cả khi đang kéo qua nó
                color: active ? AppTheme.primary : AppTheme.onPrimaryFixed,
                size: 24,
              ),
            ),
            const SizedBox(height: 4), // Khoảng cách giữa icon và chữ
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: active ? AppTheme.primary : AppTheme.onSurfaceVariant,
                letterSpacing: -0.1,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
