import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/hau_api_service.dart';
import '../providers/app_provider.dart';
import '../widgets/shared_widgets.dart';
import '../services/mock_data.dart';

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key});
  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  List<Map<String, String>> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<Map<String, String>> result;

      // Thêm đoạn này:
      if (HauApiService.currentMssv == 'admin' && MockData.isEnabled) {
        result = MockData.getChuyenNganhChinh();
      } else {
        result = await HauApiService.fetchChuyenNganhChinh();
      }

      if (mounted) {
        setState(() {
          _data = result;
          _loading = false;
        });
        // Tính tổng TC bắt buộc (không bao gồm tự chọn) và lưu vào cache
        final mandatoryTC =
            result.where((m) => m['tu_chon'] != '1').fold(0, (s, m) {
          final tc = double.tryParse(m['tin_chi'] ?? '');
          return s + (tc?.round() ?? 0);
        });
        if (mandatoryTC > 0 && mounted) {
          context
              .read<AppProvider>()
              .setCurriculumMandatoryCredits(mandatoryTC);
        }
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  // Group: khoi -> ky -> list of courses
  Map<String, Map<String, List<Map<String, String>>>> get _grouped {
    final m = <String, Map<String, List<Map<String, String>>>>{};
    for (final r in _data) {
      final k = r['khoi'] ?? '';
      final ky = r['ky'] ?? '';
      m.putIfAbsent(k, () => {}).putIfAbsent(ky, () => []).add(r);
    }
    return m;
  }

  int get _totalTinChi => _data.fold(0, (s, m) {
        final tc = double.tryParse(m['tin_chi'] ?? '');
        return s + (tc?.round() ?? 0);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: Container(
          color: AppTheme.surface.withOpacity(0.7),
          child: SafeArea(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Chương trình đào tạo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800)),
                    Text('CHUYÊN NGÀNH CHÍNH',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.outline, letterSpacing: 1.5)),
                  ])),
              IconButton(
                icon:
                    const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                onPressed: _load,
              ),
            ]),
          )),
        )),
        if (_loading)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          SliverFillRemaining(
              child: Center(
                  child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
              const SizedBox(height: 12),
              const Text('Không tải được dữ liệu'),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          )))
        else ...[
          // Summary card
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GradientCard(
                child: Row(children: [
              Expanded(
                  child: _StatBox(
                      label: 'Tổng môn học', value: '${_data.length}')),
              Container(width: 1, height: 48, color: Colors.white24),
              Expanded(
                  child:
                      _StatBox(label: 'Tổng tín chỉ', value: '$_totalTinChi')),
              Container(width: 1, height: 48, color: Colors.white24),
              Expanded(
                  child: _StatBox(
                      label: 'Khối kiến thức', value: '${_grouped.length}')),
            ])),
          )),

          // Legend
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(children: [
              _LegendChip(color: AppTheme.primary, label: 'Bắt buộc'),
              const SizedBox(width: 8),
              _LegendChip(color: AppTheme.tertiary, label: 'Tự chọn'),
              const SizedBox(width: 8),
              _LegendChip(color: const Color(0xFF2E7D32), label: 'E-learning'),
            ]),
          )),

          // Grouped list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              for (final khoiEntry in _grouped.entries) ...[
                _KhoiHeader(
                    title: khoiEntry.key.isEmpty ? 'Chung' : khoiEntry.key),
                const SizedBox(height: 8),
                for (final kyEntry in khoiEntry.value.entries) ...[
                  _KyBadge(ky: kyEntry.key),
                  const SizedBox(height: 8),
                  for (final course in kyEntry.value)
                    _CourseCard(course: course),
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 12),
              ],
            ])),
          ),
        ],
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  const _StatBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
            textAlign: TextAlign.center),
      ]);
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
      ]);
}

class _KhoiHeader extends StatelessWidget {
  final String title;
  const _KhoiHeader({required this.title});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.layers_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title.isEmpty ? 'Khối chung' : title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))),
        ]),
      );
}

class _KyBadge extends StatelessWidget {
  final String ky;
  const _KyBadge({required this.ky});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryFixed,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Text('Kỳ thứ $ky',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary)),
        ),
      ]);
}

class _CourseCard extends StatelessWidget {
  final Map<String, String> course;
  const _CourseCard({required this.course});
  @override
  Widget build(BuildContext context) {
    final isTuChon = course['tu_chon'] == '1';
    final isElearning = course['elearning'] == '1';
    final color = isTuChon ? AppTheme.tertiary : AppTheme.primary;
    final tc = course['tin_chi'] ?? '';
    final tiet = course['tong_tiet'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
                child: Text(tc.isNotEmpty ? tc : '?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color))),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(course['ten'] ?? '',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Text(course['ma'] ?? '',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.outline, letterSpacing: 0.5)),
                  if (tiet.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('• $tiet tiết',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppTheme.outline)),
                  ],
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  if (isTuChon) _Tag('Tự chọn', AppTheme.tertiary),
                  if (isElearning) ...[
                    if (isTuChon) const SizedBox(width: 4),
                    _Tag('E-Learning', const Color(0xFF2E7D32)),
                  ],
                  if (!isTuChon && !isElearning)
                    _Tag('Bắt buộc', AppTheme.primary),
                ]),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$tc TC',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ]),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}
