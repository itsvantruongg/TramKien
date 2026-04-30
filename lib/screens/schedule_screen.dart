import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'schedule_manage_screen.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class ScheduleScreen extends StatefulWidget {
  final void Function(int)? onNavigate;
  const ScheduleScreen({super.key, this.onNavigate});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _showFilter = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScheduleManageScreen()),
          ),
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Column(children: [
        AcademicAppBar(
          subtitle: 'LỊCH HỌC & THI',
          actions: [
            NotificationBell(onNavigate: widget.onNavigate),
            IconButton(
              icon: (p.lichHocState == LoadState.loading ||
                      p.lichThiState == LoadState.loading)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary))
                  : const Icon(Icons.sync_outlined, color: AppTheme.primary),
              onPressed: () => p.syncSchedule(forceRefresh: true),
              tooltip: 'Đồng bộ lịch',
            ),
          ],
        ),

        // Filter panel
        // AnimatedSize(
        //   duration: const Duration(milliseconds: 250),
        //   curve: Curves.easeInOut,
        //   child: _showFilter ? _FilterPanel(p: p) : const SizedBox.shrink(),
        // ),

        // Tab bar: Tháng | Tuần
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: 'Tháng'), Tab(text: 'Tuần')],
          ),
        ),

        Expanded(
            child: TabBarView(
          controller: _tabCtrl,
          children: [
            _MonthView(p: p),
            _WeekView(p: p),
          ],
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// MONTH VIEW
// ════════════════════════════════════════════════════════════

class _MonthView extends StatefulWidget {
  final AppProvider p;
  const _MonthView({required this.p});
  @override
  State<_MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<_MonthView> {
  late PageController _pageCtrl;
  // Page 0 = Jan 2018, tính offset từ đó
  static const _baseYear = 2018;
  static const _baseMonth = 1;

  late int _currentPage;
  late DateTime _selected;

  int get _displayYear => _pageToDate(_currentPage).year;
  int get _displayMonth => _pageToDate(_currentPage).month;

  int _dateToPage(int year, int month) =>
      (year - _baseYear) * 12 + (month - _baseMonth);

  DateTime _pageToDate(int page) {
    var newMonth = _baseMonth + page;
    var newYear = _baseYear + (newMonth - 1) ~/ 12;
    newMonth = (newMonth - 1) % 12 + 1;
    return DateTime(newYear, newMonth);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentPage = _dateToPage(now.year, now.month);
    _selected = now;
    _pageCtrl = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Đổi ListView thành Column để PageView có thể nhận chiều cao cố định
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _buildMonthHeader(),
        ),
        const SizedBox(height: 12),

        // Khu vực Lịch vuốt được (bao gồm header T2-CN và lưới 7x6)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.onSurface.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildDayHeaders(),
              const SizedBox(height: 15),
              // PageView bọc lấy GridView
              Builder(
                builder: (context) {
                  // Tính số hàng thực tế của tháng đang hiển thị
                  final firstDay = DateTime(_displayYear, _displayMonth, 1);
                  final startOffset = firstDay.weekday - 1; // 0=T2, 6=CN
                  final daysInMonth =
                      DateTime(_displayYear, _displayMonth + 1, 0).day;
                  final totalCells = startOffset + daysInMonth;
                  final rowCount = (totalCells / 7).ceil(); // 5 hoặc 6

                  // Mỗi ô = (screenWidth - 40 margin - 40 padding) / 7
                  final cellSize = (MediaQuery.of(context).size.width - 80) / 7;
                  final gridHeight = rowCount * cellSize;

                  return SizedBox(
                    height: gridHeight,
                    child: PageView.builder(
                      controller: _pageCtrl,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                          int selDay = _selected.day;
                          int maxDay =
                              DateTime(_displayYear, _displayMonth + 1, 0).day;
                          if (selDay > maxDay) selDay = maxDay;
                          _selected =
                              DateTime(_displayYear, _displayMonth, selDay);
                        });
                      },
                      itemBuilder: (ctx, page) {
                        final date = _pageToDate(page);
                        return _MonthGrid(
                          year: date.year,
                          month: date.month,
                          p: widget.p,
                          selected: _selected,
                          onSelect: (d) => setState(() => _selected = d),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Danh sách sự kiện bên dưới (cuộn độc lập)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            children: [
              _buildSelectedDayEvents(context, widget.p),
            ],
          ),
        ),
      ],
    );
  }

  // ── Trong _MonthViewState ─────────────────────────────────────
// Sửa _buildMonthHeader() - thêm onTap vào title:

  Widget _buildMonthHeader() {
    final monthLabel = DateFormat('MMMM yyyy', 'vi_VN')
        .format(DateTime(_displayYear, _displayMonth));
    final title = monthLabel[0].toUpperCase() + monthLabel.substring(1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // ✅ Tap vào title để mở date picker
        GestureDetector(
          onTap: _showMonthYearPicker,
          child: Row(children: [
            Text(title,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                )),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppTheme.primary, size: 22),
          ]),
        ),
        Row(children: [
          _NavBtn(
            icon: Icons.chevron_left_rounded,
            onTap: () => _pageCtrl.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
          ),
          const SizedBox(width: 4),
          _NavBtn(
            icon: Icons.chevron_right_rounded,
            onTap: () => _pageCtrl.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
          ),
        ]),
      ],
    );
  }

// ✅ Thêm hàm này vào _MonthViewState:
  Future<void> _showMonthYearPicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _MonthYearPickerDialog(
        initialYear: _displayYear,
        initialMonth: _displayMonth,
      ),
    );
    if (picked != null && mounted) {
      final page = _dateToPage(picked.year, picked.month);
      _pageCtrl.animateToPage(page,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      setState(() {
        _selected = DateTime(
            picked.year,
            picked.month,
            _selected.day
                .clamp(1, DateTime(picked.year, picked.month + 1, 0).day));
      });
    }
  }

  Widget _buildDayHeaders() {
    const dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Row(
      children: dayNames
          .map((n) => Expanded(
                child: Center(
                  child: Text(n,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: n == 'CN' ? AppTheme.tertiary : AppTheme.outline,
                      )),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSelectedDayEvents(BuildContext context, AppProvider p) {
    final classes = p.getLichHocForDate(_selected);
    final exams = p.lichThi.where((t) {
      final d = t.ngayThiDate;
      return d != null && _isSameDay(d, _selected);
    }).toList();

    final label = DateFormat('EEEE, dd MMMM', 'vi_VN').format(_selected);
    final title = label[0].toUpperCase() + label.substring(1);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppTheme.outline, letterSpacing: 1)),
        if (classes.isNotEmpty || exams.isNotEmpty)
          Text('${classes.length + exams.length} sự kiện',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.primary)),
      ]),
      const SizedBox(height: 12),
      if (classes.isEmpty && exams.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              const Icon(Icons.event_available,
                  size: 40, color: AppTheme.outlineVariant),
              const SizedBox(height: 8),
              Text('Không có lịch',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.outline)),
            ]),
          ),
        ),
      ...exams.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ExamCard(lichThi: t))),
      ...classes.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ScheduleCardFull(lichHoc: l))),
    ]);
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialYear, initialMonth;
  const _MonthYearPickerDialog(
      {required this.initialYear, required this.initialMonth});
  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year, _month;
  late PageController _pageCtrl;

  // Page 0 = Jan 2018
  static const _baseYear = 2018;
  static const _baseMonth = 1;

  static const _months = [
    'Tháng 1',
    'Tháng 2',
    'Tháng 3',
    'Tháng 4',
    'Tháng 5',
    'Tháng 6',
    'Tháng 7',
    'Tháng 8',
    'Tháng 9',
    'Tháng 10',
    'Tháng 11',
    'Tháng 12',
  ];

  int _dateToPage(int year) => year - _baseYear;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
    final initialPage = _dateToPage(_year);
    _pageCtrl = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header năm
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
              onPressed: () {
                final prevPage = _dateToPage(_year) - 1;
                if (prevPage >= 0) {
                  _pageCtrl.animateToPage(
                    prevPage,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
            GestureDetector(
              onTap: () async {
                final y = await _pickYear(context, _year);
                if (y != null) {
                  _pageCtrl.animateToPage(_dateToPage(y),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              },
              child: Text('$_year',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppTheme.primary),
              onPressed: () {
                final nextPage = _dateToPage(_year) + 1;
                _pageCtrl.animateToPage(
                  nextPage,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ]),
          const SizedBox(height: 12),
          // PageView cho phép vuốt trái/phải theo tháng
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (page) {
                setState(() {
                  _year = _baseYear + page;
                });
              },
              itemBuilder: (ctx, page) {
                final pageYear = _baseYear + page;
                return GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(12, (i) {
                    final isSelected =
                        i + 1 == _month && pageYear == widget.initialYear;
                    return GestureDetector(
                      onTap: () =>
                          Navigator.pop(context, DateTime(pageYear, i + 1)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(_months[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.onSurface,
                            )),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // Hint vuốt
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     Icon(Icons.swipe_rounded, size: 14, color: AppTheme.outline),
          //     const SizedBox(width: 4),
          //     Text('Vuốt để chọn tháng',
          //         style: TextStyle(fontSize: 11, color: AppTheme.outline)),
          //   ],
          // ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Đóng', style: TextStyle(color: AppTheme.outline)),
          ),
        ]),
      ),
    );
  }

  Future<int?> _pickYear(BuildContext context, int current) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        final years = List.generate(20, (i) => current - 5 + i);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            height: 300,
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chọn năm',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: years.length,
                  itemBuilder: (_, i) {
                    final y = years[i];
                    final isSel = y == current;
                    return ListTile(
                      title: Text('$y',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight:
                                isSel ? FontWeight.w800 : FontWeight.w500,
                            color:
                                isSel ? AppTheme.primary : AppTheme.onSurface,
                          )),
                      tileColor: isSel ? AppTheme.primaryFixed : null,
                      onTap: () => Navigator.pop(ctx, y),
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Tách lưới lịch ra làm Widget riêng để PageView gọi ──
class _MonthGrid extends StatelessWidget {
  final int year, month;
  final AppProvider p;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.year,
    required this.month,
    required this.p,
    required this.selected,
    required this.onSelect,
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final startOffset = (firstDay.weekday - 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final prevMonthDays = DateTime(year, month, 0).day;

    final Map<int, bool> hasClass = {};
    final Map<int, bool> hasExam = {};

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      // Sửa: Kiểm tra lịch của ngày cụ thể, không phải toàn bộ thứ
      final classesThisDay = p.getLichHocForDate(date);
      if (classesThisDay.isNotEmpty) hasClass[day] = true;
      final dayExams = p.lichThi.where((t) {
        final d = t.ngayThiDate;
        return d != null && _isSameDay(d, date);
      });
      if (dayExams.isNotEmpty) hasExam[day] = true;
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics:
          const NeverScrollableScrollPhysics(), // Đã dùng PageView ở ngoài nên tắt scroll trong grid
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount:
          startOffset + daysInMonth + (7 - (startOffset + daysInMonth) % 7) % 7,
      itemBuilder: (ctx, index) {
        if (index < startOffset) {
          final d = prevMonthDays - startOffset + index + 1;
          return Center(
            child: Text('$d',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.outlineVariant)),
          );
        }
        final dayNum = index - startOffset + 1;
        if (dayNum > daysInMonth) {
          final d = dayNum - daysInMonth;
          return Center(
            child: Text('$d',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.outlineVariant)),
          );
        }

        final date = DateTime(year, month, dayNum);
        final isToday = _isSameDay(date, DateTime.now());
        final isSel = _isSameDay(date, selected);
        final isSunday = date.weekday == 7;
        final cls = hasClass[dayNum] ?? false;
        final exam = hasExam[dayNum] ?? false;

        return GestureDetector(
          onTap: () => onSelect(date),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSel
                      ? AppTheme.primary
                      : isToday
                          ? AppTheme.primaryFixed
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSel || isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isSel
                          ? Colors.white
                          : isToday
                              ? AppTheme.primary
                              : isSunday
                                  ? AppTheme.tertiary
                                  : AppTheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (cls)
                  Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                          color: AppTheme.primary, shape: BoxShape.circle)),
                if (exam)
                  Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          color: AppTheme.error, shape: BoxShape.circle)),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ── Helper Widgets for Month View ───────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
      );
}

class _MonthEventTile extends StatelessWidget {
  final String label, title, time, room;
  final bool isExam;
  const _MonthEventTile({
    required this.label,
    required this.title,
    required this.time,
    required this.room,
    required this.isExam,
  });

  @override
  Widget build(BuildContext context) {
    final color = isExam ? AppTheme.error : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppTheme.onSurface.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: color)),
            ),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.schedule_outlined, size: 12, color: AppTheme.outline),
              const SizedBox(width: 4),
              Text(time,
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.onSurfaceVariant)),
              const SizedBox(width: 12),
              Icon(Icons.location_on_outlined,
                  size: 12, color: AppTheme.outline),
              const SizedBox(width: 4),
              Expanded(
                child: Text(room,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
// ════════════════════════════════════════════════════════════
// WEEK VIEW
// ════════════════════════════════════════════════════════════

class _WeekView extends StatefulWidget {
  final AppProvider p;
  const _WeekView({required this.p});
  @override
  State<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<_WeekView> {
  late PageController _pageCtrl;
  // Page 0 = tuần chứa 01/01/2018
  static final _baseMonday = _getMondayOfWeek(DateTime(2018, 1, 1));

  late int _currentPage;
  DateTime get _currentMonday =>
      _baseMonday.add(Duration(days: _currentPage * 7));

  // Ngày được select trong tuần hiện tại
  DateTime _selectedDay = DateTime.now();

  static DateTime _getMondayOfWeek(DateTime d) {
    final m = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(m.year, m.month, m.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = now;
    final monday = _getMondayOfWeek(now);
    _currentPage = monday.difference(_baseMonday).inDays ~/ 7;
    _pageCtrl = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Column(children: [
      // Week label + arrows
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
            onPressed: () => _pageCtrl.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => _showWeekPicker(p), // ✅ thêm tap
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _weekLabel(_currentMonday),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.primary, size: 18),
                ]),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppTheme.primary),
            onPressed: () => _pageCtrl.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
          ),
        ]),
      ),

      // 7-day strip — luôn fit vừa màn hình
      SizedBox(
        height: 80,
        child: PageView.builder(
          controller: _pageCtrl,
          onPageChanged: (page) => setState(() {
            _currentPage = page;
            // Auto-select thứ 2 khi chuyển tuần
            _selectedDay = _baseMonday.add(Duration(days: page * 7));
          }),
          itemBuilder: (ctx, page) {
            final monday = _baseMonday.add(Duration(days: page * 7));
            return _WeekStrip(
              monday: monday,
              selected: _selectedDay,
              onSelect: (d) => setState(() => _selectedDay = d),
            );
          },
        ),
      ),

      // Schedule list for selected day
      // Trong _WeekView.build(), thay _DayList cũ:
      Expanded(
          child: RefreshIndicator(
        onRefresh: () => p.syncSchedule(),
        child: _DayList(
          selectedDay: _selectedDay,
          weekMonday: _currentMonday, // ← truyền thêm
          p: p,
        ),
      )),
    ]);
  }

  Future<void> _showWeekPicker(AppProvider p) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _WeekPickerDialog(
        currentMonday: _currentMonday,
        baseMonday: _baseMonday,
      ),
    );
    if (picked != null && mounted) {
      final page = picked.difference(_baseMonday).inDays ~/ 7;
      _pageCtrl.animateToPage(page,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      setState(() {
        _currentPage = page;
        _selectedDay = picked;
      });
    }
  }

  String _weekLabel(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    final fmt = DateFormat('dd/MM', 'vi_VN');
    return '${fmt.format(monday)} – ${fmt.format(sunday)}';
  }
}

class _WeekPickerDialog extends StatefulWidget {
  final DateTime currentMonday, baseMonday;
  const _WeekPickerDialog(
      {required this.currentMonday, required this.baseMonday});
  @override
  State<_WeekPickerDialog> createState() => _WeekPickerDialogState();
}

class _WeekPickerDialogState extends State<_WeekPickerDialog> {
  late ScrollController _scrollCtrl;
  late DateTime _selected;

  // Tạo list tuần: 26 tuần trước → 26 tuần sau (tổng 53)
  static const _range = 26;
  late List<DateTime> _weeks;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentMonday;
    // Tạo danh sách tuần xung quanh tuần hiện tại
    _weeks = List.generate(
      _range * 2 + 1,
      (i) => widget.currentMonday.add(Duration(days: (i - _range) * 7)),
    );
    // Scroll đến tuần hiện tại (index = _range)
    _scrollCtrl = ScrollController(
      initialScrollOffset: _range * 72.0 - 100, // 72px/item, căn giữa
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Trả về số tuần ISO (tuần đầu tiên chứa thứ Hai đầu tiên của năm = Tuần 1)
  int _weekNumber(DateTime monday) {
    // Tìm thứ Hai đầu tiên của năm
    final jan1 = DateTime(monday.year, 1, 1);
    // weekday: 1=Mon ... 7=Sun
    final daysToFirstMonday = (8 - jan1.weekday) % 7;
    final firstMonday = jan1.add(Duration(days: daysToFirstMonday));
    if (monday.isBefore(firstMonday)) {
      // Thuộc tuần cuối năm trước
      return _weekNumber(DateTime(monday.year - 1, 12, 28));
    }
    final diff = monday.difference(firstMonday).inDays;
    return (diff ~/ 7) + 1;
  }

  String _weekRangeLabel(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    final fmt = DateFormat('dd/MM/yyyy', 'vi_VN');
    return '${fmt.format(monday)} – ${fmt.format(sunday)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chọn tuần',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List tuần
        SizedBox(
          height: 320,
          child: ListView.builder(
            controller: _scrollCtrl,
            itemCount: _weeks.length,
            itemBuilder: (ctx, i) {
              final monday = _weeks[i];
              final isSelected = monday == _selected;
              final isCurrent = monday == widget.currentMonday;
              final weekNum = _weekNumber(monday);
              // Hiển thị divider năm khi đây là Tuần 1 của một năm mới
              final isFirstWeekOfYear = weekNum == 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isFirstWeekOfYear)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppTheme.outlineVariant,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${monday.year}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppTheme.outlineVariant,
                          ),
                        ),
                      ]),
                    ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, monday),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 72,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : (isCurrent
                                ? AppTheme.primaryFixed
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        // Nội dung tuần
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Tuần $weekNum',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _weekRangeLabel(monday),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.85)
                                      : AppTheme.onSurfaceVariant,
                                ),
                              ),
                              if (isCurrent && !isSelected)
                                Text('Tuần hiện tại',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    )),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 18),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final DateTime monday, selected;
  final void Function(DateTime) onSelect;
  const _WeekStrip(
      {required this.monday, required this.selected, required this.onSelect});

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          final isSel = _same(day, selected);
          final isToday = _same(day, today);

          return Expanded(
              child: GestureDetector(
            onTap: () => onSelect(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              decoration: BoxDecoration(
                color: isSel
                    ? AppTheme.primary
                    : (isToday
                        ? AppTheme.primaryFixed
                        : AppTheme.surfaceContainerLow),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : null,
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(names[i],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: isSel
                              ? Colors.white70
                              : AppTheme.onSurfaceVariant,
                        )),
                    const SizedBox(height: 3),
                    Text('${day.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSel
                              ? Colors.white
                              : (isToday
                                  ? AppTheme.primary
                                  : AppTheme.onSurface),
                        )),
                  ]),
            ),
          ));
        }),
      ),
    );
  }
}

// List sự kiện của 1 ngày
// Thay toàn bộ _DayList widget:
class _DayList extends StatelessWidget {
  final DateTime selectedDay;
  final DateTime weekMonday; // ← thêm để biết cả tuần
  final AppProvider p;
  const _DayList({
    required this.selectedDay,
    required this.weekMonday,
    required this.p,
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isBeforeDay(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return da.isBefore(db);
  }

  @override
  Widget build(BuildContext context) {
    // Lấy tất cả 7 ngày trong tuần
    final weekDays = List.generate(7, (i) => weekMonday.add(Duration(days: i)));

    // Build danh sách sự kiện của cả tuần, lọc bỏ ngày trước selectedDay
    final items = <Widget>[];
    bool hasAny = false;

    for (final day in weekDays) {
      // Ẩn các ngày trước selectedDay (đã qua trong tuần này)
      if (_isBeforeDay(day, selectedDay)) continue;

      final classes = p.getLichHocForDate(day);
      final exams = p.getLichThiForDate(day);

      if (classes.isEmpty && exams.isEmpty) continue;
      hasAny = true;

      // Header ngày
      final label = DateFormat('EEEE, dd/MM', 'vi_VN').format(day);
      final dayLabel = label[0].toUpperCase() + label.substring(1);
      final isSelected = _isSameDay(day, selectedDay);

      items.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(children: [
          Text(
            dayLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected ? AppTheme.primary : AppTheme.outline,
                  letterSpacing: 1,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryFixed,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ]),
      ));

      // Thẻ lịch thi
      for (final t in exams) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ExamCard(lichThi: t),
        ));
      }

      // Thẻ lịch học
      for (final l in classes) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ScheduleCardFull(lichHoc: l),
        ));
      }
    }

    if (!hasAny) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        children: [
          const SizedBox(height: 40),
          Center(
              child: Column(children: [
            const Icon(Icons.event_available,
                size: 48, color: AppTheme.outlineVariant),
            const SizedBox(height: 12),
            Text('Không có lịch từ ngày này',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.onSurfaceVariant)),
          ])),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      children: items,
    );
  }
}

// Card lịch học đầy đủ (giống style event dot nhưng to hơn)
class _ScheduleCardFull extends StatelessWidget {
  final LichHoc lichHoc;
  const _ScheduleCardFull({required this.lichHoc});

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const StatusChip(label: 'LỊCH HỌC', color: AppTheme.primary),
            // Giờ bắt đầu - kết thúc
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(lichHoc.gioHocFull,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(lichHoc.tenHocPhan,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 6, children: [
            if (lichHoc.phong.isNotEmpty)
              _Chip(Icons.location_on_outlined, lichHoc.phong),
            _Chip(Icons.class_outlined, 'Tiết ${lichHoc.tiet}'),
            if (lichHoc.giaoVien.isNotEmpty)
              _Chip(Icons.person_outline, lichHoc.giaoVien),
          ]),
          if (lichHoc.note != null && lichHoc.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lichHoc.note!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.brown,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ]),
      );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);
  @override
  Widget build(BuildContext ctx) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppTheme.outline),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(ctx)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.onSurfaceVariant)),
      ]);
}

// ════════════════════════════════════════════════════════════
// FILTER PANEL (giữ nguyên từ version cũ)
// ════════════════════════════════════════════════════════════

// class _FilterPanel extends StatelessWidget {
//   final AppProvider p;
//   const _FilterPanel({required this.p});
//
//   @override
//   Widget build(BuildContext context) => Container(
//     margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
//     padding: const EdgeInsets.all(16),
//     decoration: BoxDecoration(
//       color: AppTheme.surfaceContainerLowest,
//       borderRadius: BorderRadius.circular(16),
//       boxShadow: [BoxShadow(
//         color: AppTheme.onSurface.withOpacity(0.04),
//         blurRadius: 12, offset: const Offset(0, 4),
//       )],
//     ),
//     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Text('BỘ LỌC', style: Theme.of(context).textTheme.labelSmall
//           ?.copyWith(color: AppTheme.outline, letterSpacing: 1.5)),
//       const SizedBox(height: 12),
//       Row(children: [
//         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text('Học kỳ', style: Theme.of(context).textTheme.bodySmall
//               ?.copyWith(color: AppTheme.onSurfaceVariant)),
//           const SizedBox(height: 6),
//           Row(children: AppProvider.allHocKy.map((hk) => Padding(
//             padding: const EdgeInsets.only(right: 8),
//             child: _FChip(label: 'HK$hk', active: p.currentHocKy == hk,
//                 onTap: () => p.changeHocKy(hk)),
//           )).toList()),
//         ])),
//         const SizedBox(width: 16),
//         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text('Chuyên ngành', style: Theme.of(context).textTheme.bodySmall
//               ?.copyWith(color: AppTheme.onSurfaceVariant)),
//           const SizedBox(height: 6),
//           Row(children: [
//             _FChip(label: 'Chính',  active: p.currentCN == 0, onTap: () => p.changeCN(0)),
//             const SizedBox(width: 8),
//             _FChip(label: 'Thứ 2', active: p.currentCN == 1, onTap: () => p.changeCN(1)),
//           ]),
//         ])),
//       ]),
//       const SizedBox(height: 12),
//       Row(children: [
//         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text('Năm học', style: Theme.of(context).textTheme.bodySmall
//               ?.copyWith(color: AppTheme.onSurfaceVariant)),
//           const SizedBox(height: 6),
//           Container(
//             height: 40,
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             decoration: BoxDecoration(color: AppTheme.surfaceContainerLow,
//                 borderRadius: BorderRadius.circular(10)),
//             child: DropdownButtonHideUnderline(
//               child: DropdownButton<int>(
//                 value: p.currentNamHoc,
//                 isExpanded: true,
//                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
//                 items: AppProvider.allNamHoc.map((n) =>
//                     DropdownMenuItem(value: n, child: Text('$n-${n+1}'))).toList(),
//                 onChanged: (v) { if (v != null) p.changeNamHoc(v); },
//               ),
//             ),
//           ),
//         ])),
//         const SizedBox(width: 16),
//         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text('Đợt học', style: Theme.of(context).textTheme.bodySmall
//               ?.copyWith(color: AppTheme.onSurfaceVariant)),
//           const SizedBox(height: 6),
//           SizedBox(height: 40, child: ListView(
//             scrollDirection: Axis.horizontal,
//             children: [
//               _FChip(label: 'Tất cả', active: p.currentDotHoc == 0, onTap: () => p.changeDotHoc(0)),
//               ...AppProvider.allDotHoc.map((d) => Padding(
//                 padding: const EdgeInsets.only(left: 6),
//                 child: _FChip(label: '$d', active: p.currentDotHoc == d, onTap: () => p.changeDotHoc(d)),
//               )),
//             ],
//           )),
//         ])),
//       ]),
//     ]),
//   );
// }
//
// class _FChip extends StatelessWidget {
//   final String label;
//   final bool active;
//   final VoidCallback onTap;
//   const _FChip({required this.label, required this.active, required this.onTap});
//   @override
//   Widget build(BuildContext context) => GestureDetector(
//     onTap: onTap,
//     child: AnimatedContainer(
//       duration: const Duration(milliseconds: 150),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: active ? AppTheme.primary : AppTheme.surfaceContainerLow,
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Text(label, style: TextStyle(
//         fontSize: 12, fontWeight: FontWeight.w600,
//         color: active ? Colors.white : AppTheme.onSurfaceVariant,
//       )),
//     ),
//   );
// }
