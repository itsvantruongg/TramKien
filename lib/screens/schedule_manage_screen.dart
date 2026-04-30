import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../providers/schedule_provider.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class ScheduleManageScreen extends StatefulWidget {
  const ScheduleManageScreen({super.key});

  @override
  State<ScheduleManageScreen> createState() => _ScheduleManageScreenState();
}

class _ScheduleManageScreenState extends State<ScheduleManageScreen> {
  String _searchQuery = '';
  String? _selectedSemester;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final sp =
        Provider.of<AppProvider>(context, listen: false).scheduleProvider;
    _selectedSemester = '${sp.namHocLabel}_HK${sp.currentHocKy}';
  }

  bool _isDateExpired(String dateStr) {
    try {
      final p = dateStr.trim().split('/');
      if (p.length == 3) {
        final d = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        // Consider expired if it was yesterday or earlier
        return d.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      }
    } catch (_) {}
    return false;
  }

  bool _isRangeExpired(String range) {
    try {
      final parts = range.split('-');
      if (parts.length < 2) return false;
      return _isDateExpired(parts[1].trim());
    } catch (_) {}
    return false;
  }

  bool _isSubjectCompletedNoExam(List<LichHoc> learning) {
    if (learning.isEmpty) return false;
    DateTime? latestDate;
    for (final l in learning) {
      try {
        final parts = l.thoiGian.split('-');
        if (parts.length >= 2) {
          final p = parts[1].trim().split('/');
          if (p.length == 3) {
            final d =
                DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
            if (latestDate == null || d.isAfter(latestDate)) {
              latestDate = d;
            }
          }
        }
      } catch (_) {}
    }
    if (latestDate == null) return false;
    // Completed if today > latestDate + 14 days
    return DateTime.now().isAfter(latestDate.add(const Duration(days: 14)));
  }

  /// Hàm chuẩn hóa tiếng Việt: bỏ dấu, đưa về chữ thường
  String _normalize(String? s) {
    if (s == null) return '';
    var str = s.toLowerCase();
    const vietnamese =
        'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
    const latin =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiiooooooooooooooooouuuuuuuuuuuuyyyyyd';
    for (int i = 0; i < vietnamese.length; i++) {
      str = str.replaceAll(vietnamese[i], latin[i]);
    }
    return str;
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<AppProvider>().scheduleProvider;

    final semesters = <String>{};
    for (final l in sp.lichHoc) semesters.add('${l.namHoc}_HK${l.hocKy}');
    for (final l in sp.lichThi) semesters.add('${l.namHoc}_HK${l.hocKy}');

    final sortedSemesters = semesters.toList()..sort((a, b) => b.compareTo(a));

    if (_selectedSemester == null ||
        (!semesters.contains(_selectedSemester) && semesters.isNotEmpty)) {
      _selectedSemester =
          sortedSemesters.isNotEmpty ? sortedSemesters.first : null;
    }

    final allItems = [
      ...sp.lichHoc.map((l) => _ScheduleItemWrapper(lichHoc: l)),
      ...sp.lichThi.map((t) => _ScheduleItemWrapper(lichThi: t)),
    ];

    final filtered = allItems.where((item) {
      final sem = item.lichHoc != null
          ? '${item.lichHoc!.namHoc}_HK${item.lichHoc!.hocKy}'
          : '${item.lichThi!.namHoc}_HK${item.lichThi!.hocKy}';

      if (sem != _selectedSemester) return false;

      final query = _normalize(_searchQuery);
      if (query.isEmpty) return true;

      final title =
          _normalize(item.lichHoc?.tenHocPhan ?? item.lichThi?.tenMonHoc ?? '');
      final note = _normalize(item.lichHoc?.note ?? item.lichThi?.note ?? '');

      return title.contains(query) || note.contains(query);
    }).toList();

    final Map<String, _GroupedSchedule> groupedMap = {};
    for (final item in filtered) {
      final title =
          item.lichHoc?.tenHocPhan ?? item.lichThi?.tenMonHoc ?? 'Không tên';
      if (!groupedMap.containsKey(title)) {
        groupedMap[title] =
            _GroupedSchedule(title: title, learning: [], exams: []);
      }
      if (item.lichHoc != null) groupedMap[title]!.learning.add(item.lichHoc!);
      if (item.lichThi != null) groupedMap[title]!.exams.add(item.lichThi!);
    }

    // Check for subject-level expiration
    for (final entry in groupedMap.entries) {
      final title = entry.key;
      final schedule = entry.value;

      if (schedule.exams.isNotEmpty) {
        // If has exams, check if all original exams passed
        final originalExams = sp.lichThi.where((t) =>
            t.tenMonHoc == title &&
            '${t.namHoc}_HK${t.hocKy}' == _selectedSemester);
        if (originalExams.isNotEmpty &&
            originalExams.every((t) => _isDateExpired(t.ngayThi))) {
          schedule.isExpired = true;
        }
      } else {
        // No exam: check 14 days after last class
        if (_isSubjectCompletedNoExam(schedule.learning)) {
          schedule.isExpired = true;
        }
      }
    }

    final groupedList = groupedMap.values.toList();
    groupedList.sort((_GroupedSchedule a, _GroupedSchedule b) {
      if (a.isManual != b.isManual) return a.isManual ? -1 : 1;
      return a.title.compareTo(b.title);
    });

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Quản lý lịch học & thi',
            style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary)),
        backgroundColor: AppTheme.surface,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Row 1: Search Bar ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Container(
              decoration: BoxDecoration(boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm học phần hoặc ghi chú...',
                  hintStyle:
                      const TextStyle(fontSize: 14, color: AppTheme.outline),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.primary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceContainerLowest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: AppTheme.outlineVariant.withOpacity(0.2)),
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),

          // ── Row 2: Semester Selector (ListBox / Dropdown) ──────────────────────────────
          if (sortedSemesters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildSemesterDropdown(sortedSemesters),
            ),

          // ── List ──────────────────────────────────────────
          Expanded(
            child: groupedList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded,
                            size: 64,
                            color: AppTheme.outlineVariant.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Không có lịch học hoặc thi khả dụng',
                            style: TextStyle(
                                color: AppTheme.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: groupedList.length + 1,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (index == groupedList.length) {
                        return _buildAddNewSubjectButton(context, sp);
                      }
                      final groupedItem = groupedList[index];
                      return _buildGroupedCard(context, groupedItem, sp);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterDropdown(List<String> sortedSemesters) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSemester,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.primary),
          dropdownColor: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          items: sortedSemesters.map((s) {
            String label = s;
            try {
              final parts = s.split('_');
              if (parts.length == 2) {
                final year = parts[0];
                final ky = parts[1].replaceAll('HK', '');
                label = 'Học kỳ $ky ($year)';
              }
            } catch (_) {}
            return DropdownMenuItem(
              value: s,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface)),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedSemester = v),
        ),
      ),
    );
  }

  Widget _buildAddNewSubjectButton(BuildContext context, ScheduleProvider sp) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: OutlinedButton.icon(
        onPressed: () => _showAddManualSubjectMenu(context, sp),
        icon: const Icon(Icons.add_rounded),
        label: const Text('THÊM HỌC PHẦN MỚI'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: AppTheme.primary,
          textStyle: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildGroupedCard(
      BuildContext context, _GroupedSchedule item, ScheduleProvider sp) {
    final bool isCardDisabled = item.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isCardDisabled
            ? AppTheme.surfaceDim.withOpacity(0.3)
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCardDisabled ? null : () => _showCardMenu(context, item, sp),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Tên môn
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCardDisabled
                      ? AppTheme.outline.withOpacity(0.05)
                      : AppTheme.primary.withOpacity(0.03),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                      bottom: BorderSide(
                          color: AppTheme.outlineVariant.withOpacity(0.2))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: isCardDisabled
                                  ? AppTheme.outline
                                  : AppTheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isCardDisabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppTheme.outline,
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('HẾT HẠN',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w900)),
                      )
                    else ...[
                      if (item.isManual)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('THỦ CÔNG',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),
                        ),
                      const Icon(Icons.add_circle_outline_rounded,
                          size: 20, color: AppTheme.primary),
                    ],
                  ],
                ),
              ),

              // Lịch học
              if (item.learning.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LỊCH HỌC',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.outline,
                              letterSpacing: 1)),
                      const SizedBox(height: 8),
                      ...item.learning.map((l) {
                        final bool isRowExpired = _isRangeExpired(l.thoiGian);
                        return _buildScheduleRow(
                          context,
                          icon: Icons.access_time_filled_rounded,
                          content: '${l.thu} | ${l.tiet} | Phòng ${l.phong}',
                          dateRange: l.thoiGian,
                          note: l.note,
                          isExpired: isRowExpired,
                          onTap: (isCardDisabled || isRowExpired)
                              ? null
                              : () => _showNoteDialog(context,
                                  _ScheduleItemWrapper(lichHoc: l), sp),
                          onDelete: (l.isManual && !isRowExpired)
                              ? () => _confirmDelete(
                                  context, () => sp.deleteManualLichHoc(l.id!))
                              : null,
                        );
                      }),
                    ],
                  ),
                ),

              // Lịch thi
              if (item.exams.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LỊCH THI',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.error,
                              letterSpacing: 1)),
                      const SizedBox(height: 8),
                      ...item.exams.map((t) {
                        final bool isRowExpired = _isDateExpired(t.ngayThi);
                        return _buildScheduleRow(
                          context,
                          icon: Icons.event_available_rounded,
                          content:
                              'Thi: ${t.ngayThi} | Ca ${t.caThi} | Phòng ${t.phong}',
                          note: t.note,
                          color: AppTheme.error,
                          isExpired: isRowExpired,
                          onTap: (isCardDisabled || isRowExpired)
                              ? null
                              : () => _showNoteDialog(context,
                                  _ScheduleItemWrapper(lichThi: t), sp),
                          onDelete: (t.isManual && !isRowExpired)
                              ? () => _confirmDelete(
                                  context, () => sp.deleteManualLichThi(t.id!))
                              : null,
                        );
                      }),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleRow(
    BuildContext context, {
    required IconData icon,
    required String content,
    String? dateRange,
    String? note,
    Color color = AppTheme.primary,
    bool isExpired = false,
    VoidCallback? onTap,
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(content,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isExpired
                                    ? AppTheme.outline
                                    : AppTheme.onSurface,
                                decoration: isExpired
                                    ? TextDecoration.lineThrough
                                    : null)),
                        if (dateRange != null)
                          Text(_shortenDateRange(dateRange),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isExpired
                                      ? AppTheme.outline
                                      : color.withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                  decoration: isExpired
                                      ? TextDecoration.lineThrough
                                      : null)),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppTheme.error.withOpacity(0.7)),
                    )
                  else if (onTap != null)
                    const Icon(Icons.edit_note_rounded,
                        size: 18, color: AppTheme.outline),
                ],
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          child: Text(note,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.brown))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortenDateRange(String range) {
    try {
      final parts = range.split('-');
      if (parts.length < 2) return range;
      String fmt(String s) {
        final d = s.trim().split('/');
        if (d.length == 3) return '${d[0]}/${d[1]}';
        return s;
      }

      return '${fmt(parts[0])} - ${fmt(parts[1])}';
    } catch (_) {
      return range;
    }
  }

  String _formatSemester(String sem) {
    try {
      final parts = sem.split('_');
      if (parts.length == 2) {
        final year = parts[0];
        final ky = parts[1].replaceAll('HK', '');
        return 'HK$ky ($year)';
      }
    } catch (_) {}
    return sem;
  }

  void _showCardMenu(
      BuildContext context, _GroupedSchedule item, ScheduleProvider sp) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(item.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading:
                    const Icon(Icons.add_task_rounded, color: AppTheme.primary),
                title: const Text('Thêm lịch học bù cho môn này',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddLichHocDialog(context, sp, defaultTitle: item.title);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notification_add_rounded,
                    color: AppTheme.error),
                title: const Text('Thêm lịch thi cho môn này',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddLichThiDialog(context, sp, defaultTitle: item.title);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddManualSubjectMenu(BuildContext context, ScheduleProvider sp) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('THÊM HỌC PHẦN THỦ CÔNG',
                  style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary)),
              const SizedBox(height: 16),
              ListTile(
                leading:
                    const Icon(Icons.school_rounded, color: AppTheme.primary),
                title: const Text('Tạo môn học & Lịch học mới',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddLichHocDialog(context, sp);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.event_note_rounded, color: AppTheme.error),
                title: const Text('Tạo môn học & Lịch thi mới',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddLichThiDialog(context, sp);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa lịch thủ công này không?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () {
                onConfirm();
                Navigator.pop(context);
                setState(() {});
              },
              child:
                  const Text('Xóa', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
  }

  void _showNoteDialog(
      BuildContext context, _ScheduleItemWrapper item, ScheduleProvider sp) {
    final controller = TextEditingController(
        text: item.lichHoc?.note ?? item.lichThi?.note ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Ghi chú môn học',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.lichHoc?.tenHocPhan ?? item.lichThi?.tenMonHoc ?? '',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                    hintText: 'Nhập ghi chú quan trọng...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLow)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () {
                if (item.lichHoc != null) {
                  sp.updateNoteLichHoc(item.lichHoc!.id!, controller.text);
                } else {
                  sp.updateNoteLichThi(item.lichThi!.id!, controller.text);
                }
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Lưu ghi chú')),
        ],
      ),
    );
  }

  void _showAddLichHocDialog(BuildContext context, ScheduleProvider sp,
      {String? defaultTitle}) {
    final tenCtrl = TextEditingController(text: defaultTitle);
    final thuCtrl = TextEditingController(text: 'Thứ 2');
    final tietCtrl = TextEditingController(text: '1-3');
    final phongCtrl = TextEditingController();
    final tgCtrl = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('Thêm lịch học mới'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: tenCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tên học phần*')),
                  TextField(
                      controller: thuCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Thứ (vd: Thứ 4)')),
                  TextField(
                      controller: tietCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tiết (vd: 4-6)')),
                  TextField(
                      controller: phongCtrl,
                      decoration: const InputDecoration(labelText: 'Phòng')),
                  TextField(
                      controller: tgCtrl,
                      decoration: const InputDecoration(labelText: 'Thời gian'))
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () {
                        if (tenCtrl.text.isEmpty) return;
                        final item = LichHoc(
                            tenHocPhan: tenCtrl.text,
                            soTinChi: 0,
                            tenLopTinChi: 'Manual',
                            thoiGian: tgCtrl.text,
                            thu: thuCtrl.text,
                            tiet: tietCtrl.text,
                            phong: phongCtrl.text,
                            giaoVien: '',
                            hocKy: sp.currentHocKy,
                            namHoc: sp.namHocLabel,
                            dotHoc: 1,
                            chuyenNganh: '',
                            isManual: true);
                        sp.addManualLichHoc(item);
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: const Text('Thêm'))
                ]));
  }

  void _showAddLichThiDialog(BuildContext context, ScheduleProvider sp,
      {String? defaultTitle}) {
    final tenCtrl = TextEditingController(text: defaultTitle);
    final ngayCtrl = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
    final caCtrl = TextEditingController(text: 'Sáng');
    final phongCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('Thêm lịch thi mới'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: tenCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tên môn thi*')),
                  TextField(
                      controller: ngayCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Ngày thi (dd/MM/yyyy)')),
                  TextField(
                      controller: caCtrl,
                      decoration: const InputDecoration(labelText: 'Ca thi')),
                  TextField(
                      controller: phongCtrl,
                      decoration: const InputDecoration(labelText: 'Phòng thi'))
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () {
                        if (tenCtrl.text.isEmpty) return;
                        final item = LichThi(
                            tenMonHoc: tenCtrl.text,
                            ngayThi: ngayCtrl.text,
                            caThi: caCtrl.text,
                            phong: phongCtrl.text,
                            hocKy: sp.currentHocKy,
                            namHoc: sp.namHocLabel,
                            isManual: true);
                        sp.addManualLichThi(item);
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: const Text('Thêm'))
                ]));
  }
}

class _GroupedSchedule {
  final String title;
  final List<LichHoc> learning;
  final List<LichThi> exams;
  bool isExpired = false;
  _GroupedSchedule(
      {required this.title, required this.learning, required this.exams});

  bool get isManual =>
      (learning.any((l) => l.isManual)) || (exams.any((e) => e.isManual));
}

class _ScheduleItemWrapper {
  final LichHoc? lichHoc;
  final LichThi? lichThi;
  _ScheduleItemWrapper({this.lichHoc, this.lichThi});

  bool get isManual => lichHoc?.isManual ?? lichThi?.isManual ?? false;
}
