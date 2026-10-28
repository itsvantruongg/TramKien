import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../services/widget_data_sync_service.dart';
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
  double _slideDirection = 1.0;
  late final AnimationController _animController;
  late final List<Widget> _screens;
  DateTime? _lastBackPress;
  DateTime? _scheduleFocusDate;

  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _screens = [
      RepaintBoundary(
        key: const ValueKey('screen_0'),
        child: DashboardScreen(
          key: const PageStorageKey('page_dashboard'),
          onNavigate: _navigate,
        ),
      ),
      RepaintBoundary(
        key: const ValueKey('screen_1'),
        child: ScheduleScreen(
          key: const PageStorageKey('page_schedule'),
          onNavigate: _navigate,
          initialDate: _scheduleFocusDate,
        ),
      ),
      RepaintBoundary(
        key: const ValueKey('screen_2'),
        child: GradesScreen(
          key: const PageStorageKey('page_grades'),
          onNavigate: _navigate,
        ),
      ),
      RepaintBoundary(
        key: const ValueKey('screen_3'),
        child: FinanceScreen(
          key: const PageStorageKey('page_finance'),
          onNavigate: _navigate,
        ),
      ),
      const RepaintBoundary(
        key: ValueKey('screen_4'),
        child: ProfileScreen(
          key: PageStorageKey('page_profile'),
        ),
      ),
    ];
    _checkInitialTargetTab();
  }

  Future<void> _checkInitialTargetTab() async {
    try {
      final tab = await WidgetDataSyncService.getInitialTargetTab();
      if (tab != null && tab >= 0 && tab <= 4 && mounted) {
        _navigate(tab);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigate(int idx, {DateTime? focusDate}) {
    if (idx == _idx) {
      if (idx == 1 && focusDate != null && focusDate != _scheduleFocusDate) {
        setState(() {
          _scheduleFocusDate = focusDate;
          _screens[1] = RepaintBoundary(
            key: const ValueKey('screen_1'),
            child: ScheduleScreen(
              key: const PageStorageKey('page_schedule'),
              onNavigate: _navigate,
              initialDate: _scheduleFocusDate,
            ),
          );
        });
      }
      return;
    }
    _slideDirection = idx > _idx ? 1.0 : -1.0;
    if (idx == 1 && focusDate != null) {
      _scheduleFocusDate = focusDate;
      _screens[1] = RepaintBoundary(
        key: const ValueKey('screen_1'),
        child: ScheduleScreen(
          key: const PageStorageKey('page_schedule'),
          onNavigate: _navigate,
          initialDate: _scheduleFocusDate,
        ),
      );
    }
    setState(() {
      _idx = idx;
    });
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    final slideAnimation = Tween<Offset>(
      begin: Offset(_slideDirection * 0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    final bodyContent = SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: IndexedStack(
          index: _idx,
          children: _screens,
        ),
      ),
    );

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
      child: PageStorage(
        bucket: _bucket,
        child: Scaffold(
          extendBody: true,
          body: isWide
              ? Row(
                  children: [
                    _buildNavigationRail(),
                    const VerticalDivider(
                      thickness: 1,
                      width: 1,
                      color: AppTheme.surfaceContainerHigh,
                    ),
                    Expanded(child: bodyContent),
                  ],
                )
              : bodyContent,
          bottomNavigationBar: isWide ? null : _buildNav(),
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _idx,
      onDestinationSelected: (idx) => _navigate(idx),
      backgroundColor: AppTheme.surface,
      indicatorColor: AppTheme.primaryFixed,
      labelType: NavigationRailLabelType.all,
      minWidth: 72,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.outlineVariant.withOpacity(0.5),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
      selectedIconTheme: const IconThemeData(
        color: AppTheme.primary,
        size: 24,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppTheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.primary,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.onSurfaceVariant,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Tổng quan'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today),
          label: Text('Lịch học'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.grade_outlined),
          selectedIcon: Icon(Icons.grade),
          label: Text('Điểm số'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.payments_outlined),
          selectedIcon: Icon(Icons.payments),
          label: Text('Học phí'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Tài khoản'),
        ),
      ],
    );
  }

  Widget _buildNav() {
    const double navBarHeight = 60.0;
    const double navInset =
        6.0; // Khoảng đệm đồng nhất cho cả 4 cạnh (Top = Bottom = Left = Right = 6dp)
    const int tabCount = 5;

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          height: navBarHeight,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          padding: const EdgeInsets.all(navInset),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
                navBarHeight / 2), // Bo góc 30dp ôm tròn tự nhiên
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / tabCount;
              return Stack(
                children: [
                  // Khối thẻ xanh viên thuốc: Tự động căn đều 4 cạnh, đồng tâm với vỏ ngoài
                  AnimatedPositioned(
                    left: _idx * itemWidth,
                    top: 0,
                    bottom: 0,
                    width: itemWidth,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryFixed.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(
                            (navBarHeight - navInset * 2) /
                                2), // R_inner = R_outer - inset = 24dp đồng tâm
                      ),
                    ),
                  ),
                  // Hàng chứa các tabs: Icon + Text tự động căn giữa tuyệt đối theo viên thuốc
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _navItem(
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard,
                        label: 'Tổng quan',
                        idx: 0,
                        active: _idx == 0,
                        onTap: () => _navigate(0),
                      ),
                      _navItem(
                        icon: Icons.calendar_today_outlined,
                        activeIcon: Icons.calendar_today,
                        label: 'Lịch học',
                        idx: 1,
                        active: _idx == 1,
                        onTap: () => _navigate(1),
                      ),
                      _navItem(
                        icon: Icons.grade_outlined,
                        activeIcon: Icons.grade,
                        label: 'Điểm số',
                        idx: 2,
                        active: _idx == 2,
                        onTap: () => _navigate(2),
                      ),
                      _navItem(
                        icon: Icons.payments_outlined,
                        activeIcon: Icons.payments,
                        label: 'Học phí',
                        idx: 3,
                        active: _idx == 3,
                        onTap: () => _navigate(3),
                      ),
                      _navItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Tài khoản',
                        idx: 4,
                        active: _idx == 4,
                        onTap: () => _navigate(4),
                      ),
                    ],
                  ),
                ],
              );
            },
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
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: active ? 1.05 : 1.0,
              child: Icon(
                active ? activeIcon : icon,
                color: active ? AppTheme.primary : AppTheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  height: 1.0,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppTheme.primary : AppTheme.onSurfaceVariant,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
