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

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  int _navDirection = 1;
  DateTime? _lastBackPress;
  double? _navDragValue;
  bool _navDragging = false;
  Timer? _navHoldTimer;
  double? _pendingNavDragValue;
  late final List<Widget> _screens;
  int _prevIdx = 0;
  late final AnimationController _animController;

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
    if (_animController.isAnimating) {
      _animController.stop();
    }
    setState(() {
      _prevIdx = _idx;
      _idx = idx;
    });
    _logCurrentScreen();
    _animController.forward(from: 0.0);
  }

  double get _navBaseValue => _idx.toDouble();

  double get _navVisualValue =>
      (_navDragValue ?? _navBaseValue).clamp(0.0, 4.0);

  void _startNavDrag(double dx, double itemWidth) {
    _navHoldTimer?.cancel();
    _pendingNavDragValue = ((dx / itemWidth) - 0.5).clamp(0.0, 4.0);

    // Bắt đầu timer 300ms trước khi cho phép kéo theo tay
    _navHoldTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _navDragging = true;
          _navDragValue = _pendingNavDragValue;
        });
        HapticFeedback.selectionClick();
      }
    });
  }

  void _updateNavDrag(double dx, double itemWidth) {
    final newValue = ((dx / itemWidth) - 0.5).clamp(0.0, 4.0);
    _pendingNavDragValue = newValue;

    if (_navDragging) {
      setState(() {
        _navDragValue = newValue;
      });
    }
  }

  void _endNavDrag() {
    _navHoldTimer?.cancel();
    _navHoldTimer = null;

    if (_navDragging) {
      // Nếu đang trong chế độ kéo -> về index gần nhất
      final nextIdx = _navVisualValue.round().clamp(0, 4);
      if (nextIdx != _idx) {
        _navigate(nextIdx);
      }
    } else {
      // Nếu nhả tay trước 500ms -> coi như là một cú chạm (tap)
      if (_pendingNavDragValue != null) {
        final nextIdx = _pendingNavDragValue!.round().clamp(0, 4);
        _navigate(nextIdx);
      }
    }

    if (!mounted) return;
    setState(() {
      _navDragging = false;
      _navDragValue = null;
      _pendingNavDragValue = null;
    });
  }

  void _cancelNavDrag() {
    _navHoldTimer?.cancel();
    _navHoldTimer = null;
    if (!mounted) return;
    setState(() {
      _navDragging = false;
      _navDragValue = null;
      _pendingNavDragValue = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onNavigate: _navigate),
      const ScheduleScreen(),
      const GradesScreen(),
      const FinanceScreen(),
      const ProfileScreen(),
    ];
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _prevIdx = _idx;
          });
        }
      });
    _logCurrentScreen();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Nếu đang ở tab khác Dashboard → về Dashboard
        if (_idx != 0) {
          _navigate(0);
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
        body: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final bool isAnimating = _idx != _prevIdx;

            if (!isAnimating) {
              return RepaintBoundary(
                key: ValueKey('screen_$_idx'),
                child: TickerMode(enabled: true, child: _screens[_idx]),
              );
            }

            final animationValue =
                Curves.easeInOut.transform(_animController.value);

            return Stack(
              children: [
                // 1. Trang cũ (mờ dần đi)
                Opacity(
                  opacity: (1.0 - animationValue).clamp(0.0, 1.0),
                  child: RepaintBoundary(
                    key: ValueKey('screen_$_prevIdx'),
                    child: TickerMode(
                      enabled: false,
                      child: _screens[_prevIdx],
                    ),
                  ),
                ),
                // 2. Trang mới (hiện dần lên)
                Opacity(
                  opacity: animationValue.clamp(0.0, 1.0),
                  child: RepaintBoundary(
                    key: ValueKey('screen_$_idx'),
                    child: TickerMode(
                      enabled: true,
                      child: _screens[_idx],
                    ),
                  ),
                ),
              ],
            );
          },
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
      // Margin cố định — KHÔNG cộng bottomPadding vào margin (sẽ làm nav bar nổi quá cao).
      // bottomPadding được xử lý bên trong bằng cách mở rộng chiều cao xuống phía dưới.
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
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
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          // Mở rộng SizedBox xuống thêm bottomPadding (home indicator area),
          // nhưng nội dung icon/label CHỈ chiếm 64px phía trên — giống App Store iOS.
          child: SizedBox(
            height:
                52 + bottomPadding, // 64px nav content + khoảng home indicator
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
                  onPanCancel: () => _cancelNavDrag(),
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
                          height:
                              52, // chỉ có 64px — không tràn xuống vng home indicator
                          decoration: BoxDecoration(
                            color: AppTheme.primaryFixed.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      // Giới hạn Row chỉ chiếm 64px (icon zone).
                      // Phần bên dưới là khoảng trống trong suốt dành cho home indicator.
                      SizedBox(
                        height: 52,
                        child: Row(
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
            const SizedBox(height: 3), // Khoảng cách giữa icon và chữ
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
