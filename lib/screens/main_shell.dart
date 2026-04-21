import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'schedule_screen.dart';
import 'grades_screen.dart';
import 'finance_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  DateTime? _lastBackPress;

  void _navigate(int idx) => setState(() => _idx = idx);

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
          setState(() => _idx = 0);
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
        body: Stack(
          children: List.generate(screens.length, (i) {
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              opacity: i == _idx ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: i != _idx,
                child: screens[i],
              ),
            );
          }),
        ),
        bottomNavigationBar: _buildNav(),
      ),
    );
  }

  Widget _buildNav() => Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.85),
          boxShadow: [
            BoxShadow(
              color: AppTheme.onSurface.withOpacity(0.06),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, -8),
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  idx: 0),
              _NavItem(
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today,
                  idx: 1),
              _NavItem(
                  icon: Icons.grade_outlined, activeIcon: Icons.grade, idx: 2),
              _NavItem(
                  icon: Icons.payments_outlined,
                  activeIcon: Icons.payments,
                  idx: 3),
              _NavItem(
                  icon: Icons.person_outline, activeIcon: Icons.person, idx: 4),
            ],
          ),
        ),
      );

  Widget _NavItem({
    required IconData icon,
    required IconData activeIcon,
    required int idx,
  }) {
    final active = _idx == idx;
    return GestureDetector(
      onTap: () => setState(() => _idx = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              active ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          active ? activeIcon : icon,
          color: active ? AppTheme.primary : AppTheme.outline,
          size: 24,
        ),
      ),
    );
  }
}
