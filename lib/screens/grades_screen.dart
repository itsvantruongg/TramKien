import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/shared_widgets.dart';

class GradesScreen extends StatefulWidget {
  final void Function(int)? onNavigate;
  const GradesScreen({super.key, this.onNavigate});
  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

//bool _showHe10 = true;

class _GradesScreenState extends State<GradesScreen> {
  String? _selectedKy;
  String?
      _lastSemesterKy; // Lưu lại kỳ học thực tế cuối cùng để giữ trạng thái biểu đồ
  bool _showHe10 = true;

  double _swipeOffset = 0.0;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final sortedKys = p.gpaByKy.keys
        .where((k) => !k.toLowerCase().contains('overview'))
        .toList()
      ..sort(_compareKyKey);
    // allKyKeys = tất cả kỳ có môn (cho chart X-axis)
    final allKyKeys = p.diemByKy.keys
        .where((k) => !k.toLowerCase().contains('overview'))
        .toList()
      ..sort(_compareKyKey);
    // Kỳ hiện tại: ưu tiên _selectedKy, fallback kỳ MỚI NHẤT
    final currentKy = _selectedKy ?? 'overview';

    // Cập nhật kỳ học thực tế gần nhất (không phải 'overview')
    if (currentKy != null && currentKy != 'overview') {
      _lastSemesterKy = currentKy;
    }

    // Điểm hiển thị: Nếu là 'overview' thì lấy toàn bộ, ngược lại lấy theo kỳ
    final List<DiemMonHoc> diemHienThi;
    if (currentKy == 'overview') {
      diemHienThi = p.diemOverview;
    } else {
      diemHienThi =
          currentKy != null ? (p.diemByKy[currentKy] ?? []) : <DiemMonHoc>[];
    }
    // Lấy chiều rộng màn hình để tính % vuốt
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // 2. SỬA LẠI TOÀN BỘ CÁC SỰ KIỆN VUỐT MÀN HÌNH Ở ĐÂY
        onHorizontalDragUpdate: (details) {
          setState(() {
            // Cập nhật vị trí đang vuốt (-1.0 đến 1.0)
            _swipeOffset += details.delta.dx / screenWidth;
            _swipeOffset = _swipeOffset.clamp(-1.0, 1.0);
          });
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          bool nextShowHe10 = _showHe10;

          // Nếu vuốt mạnh (velocity) hoặc kéo lố 25% màn hình (offset) thì chuyển
          if (velocity > 200 || _swipeOffset > 0.25) {
            nextShowHe10 = true; // Vuốt sang phải -> Chọn Hệ 10
          } else if (velocity < -200 || _swipeOffset < -0.25) {
            nextShowHe10 = false; // Vuốt sang trái -> Chọn Hệ 4
          }

          if (nextShowHe10 != _showHe10) {
            setState(() => _showHe10 = nextShowHe10);
          }
          // Vuốt xong thì nhả offset về 0 để phần xanh trượt vào vị trí cố định
          setState(() => _swipeOffset = 0.0);
        },
        onHorizontalDragCancel: () {
          setState(() => _swipeOffset = 0.0);
        },
        child: RefreshIndicator(
          onRefresh: () => p.syncGrades(),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
                child: AcademicAppBar(
              subtitle: 'ĐIỂM HỌC TẬP',
              actions: [
                NotificationBell(onNavigate: widget.onNavigate),
                IconButton(
                  icon: p.diemState == LoadState.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary))
                      : const Icon(Icons.sync_outlined,
                          color: AppTheme.primary),
                  onPressed: () => p.syncGrades(forceRefresh: true),
                  tooltip: 'Đồng bộ điểm',
                ),
              ],
            )),
            // Toggle Hệ 10 / Hệ 4
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    const Text('Hiển thị theo:',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    _ScaleToggle(
                      value: _showHe10,
                      swipeOffset:
                          _swipeOffset, // 3. TRUYỀN OFFSET VÀO THANH CHỌN
                      onChanged: (v) => setState(() => _showHe10 = v),
                    ),
                  ],
                ),
              ),
            ),
            // ── GPA Hero ──────────────────────────────────────────
            // SliverToBoxAdapter(
            //   child: Padding(
            //     padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            //     child: SurfaceCard(  // ← Đổi từ GradientCard sang SurfaceCard
            //       padding: const EdgeInsets.all(20),
            //       child: Row(
            //         children: [
            //           // ← Bên TRÁI: Chỉ hiển thị số GPA to
            //           Expanded(
            //             child: Column(
            //               crossAxisAlignment: CrossAxisAlignment.start,
            //               children: [
            //                 const Text(
            //                   'GPA TÍCH LŨY',
            //                   style: TextStyle(
            //                     fontSize: 10,
            //                     color: AppTheme.outline,
            //                     letterSpacing: 1.5,
            //                     fontWeight: FontWeight.w700,
            //                   ),
            //                 ),
            //                 const SizedBox(height: 12),
            //                 Text(
            //                   p.gpa.toStringAsFixed(2),
            //                   style: GoogleFonts.manrope(
            //                     fontSize: 56,
            //                     fontWeight: FontWeight.w800,
            //                     color: AppTheme.primary,
            //                     height: 1,
            //                   ),
            //                 ),
            //                 const SizedBox(height: 4),
            //                 Text(
            //                   '/ 10.0 hệ điểm',
            //                   style: TextStyle(
            //                     color: AppTheme.onSurfaceVariant,
            //                     fontSize: 13,
            //                   ),
            //                 ),
            //                 const SizedBox(height: 12),
            //                 Container(
            //                   padding: const EdgeInsets.symmetric(
            //                     horizontal: 12,
            //                     vertical: 6,
            //                   ),
            //                   decoration: BoxDecoration(
            //                     color: AppTheme.primaryFixed,
            //                     borderRadius: BorderRadius.circular(99),
            //                   ),
            //                   child: Text(
            //                     p.xepLoaiHocLuc,
            //                     style: const TextStyle(
            //                       color: AppTheme.primary,
            //                       fontSize: 12,
            //                       fontWeight: FontWeight.w700,
            //                     ),
            //                   ),
            //                 ),
            //               ],
            //             ),
            //           ),
            //           // ← Bên PHẢI: Chỉ giữ vòng tròn
            //           CircularProgressWidget(
            //             value: (p.gpa / 10.0).clamp(0.0, 1.0),
            //             center: p.gpa.toStringAsFixed(1),
            //             subtitle: '/10',
            //             size: 110,
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
            // ),
            // Sau SliverToBoxAdapter chứa GPA Hero, thêm:
            // Tìm đoạn hiển thị GPA (SurfaceCard đầu tiên sau toggle), sửa:
            // Thay SliverToBoxAdapter chứa DiemSummaryCard (if p.diemSummary != null):
//           if (p.diemSummary != null )
//             SliverToBoxAdapter(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
//                 child: _GpaHeroCard(
//                   tbcTichLuyHe10: p.diemSummary?.tbcTichLuyHe10 ?? p.gpa,
//                   tbcTichLuyHe4:  p.diemSummary?.tbcTichLuyHe4,
//                   showHe10: _showHe10,
//                   gpaCalculated: p.gpa,
//                   xepLoai: p.xepLoaiHocLuc,
//                 ),
//               ),
//             ),
            if (p.diemSummary != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _DiemSummaryCard(
                    summary: p.diemSummary!,
                    showHe10: _showHe10,
                    mssv: p.student?.mssv,
                  ),
                ),
              ),
            // ── Line chart — hiện kể cả khi chưa có GPA ──────────
            if (allKyKeys.isNotEmpty || p.diemState == LoadState.loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 360),
                    // SỬA 1: Chỉ dùng FadeTransition (hiệu ứng mờ) để loại bỏ hoàn toàn độ nẩy (Slide).
                    // Khi đổi hệ 10/4 nó sẽ chỉ mờ chuyển nhẹ nhàng.
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: p.diemState == LoadState.loading && allKyKeys.isEmpty
                        ? KeyedSubtree(
                            key: const ValueKey('grades_loading'),
                            child: SkeletonBox(
                                width: double.infinity,
                                height: 220,
                                radius: 24),
                          )
                        : KeyedSubtree(
                            // SỬA 2 (QUAN TRỌNG NHẤT): Xóa bỏ 'currentKy' ra khỏi ValueKey.
                            // Nhờ vậy khi user bấm đổi kỳ, biểu đồ sẽ KHÔNG bị tái tạo lại,
                            // mà chỉ truyền index mới vào CustomPainter để vẽ chấm tròn.
                            key:
                                ValueKey('chart_${_showHe10 ? 'he10' : 'he4'}'),
                            child: _GpaLineChart(
                              gpaByKy: _showHe10 ? p.gpaByKy : p.gpaByKyHe4,
                              allKyKeys: allKyKeys,
                              sortedKeys: _showHe10
                                  ? sortedKys
                                  : p.gpaByKyHe4.keys
                                      .where((k) =>
                                          !k.toLowerCase().contains('overview'))
                                      .toList()
                                ..sort(_compareKyKey),
                              selectedKey: currentKy,
                              onSelectKy: (key) =>
                                  setState(() => _selectedKy = key),
                              isHe10: _showHe10,
                            ),
                          ),
                  ),
                ),
              ),

            // ── Kỳ selector + GPA kỳ ──────────────────────────────
            if (allKyKeys.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(children: [
                    const Icon(Icons.school_outlined,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    // Dropdown chọn kỳ
                    Expanded(
                      child: _SemesterSelector(
                        value: currentKy,
                        allKyKeys: allKyKeys,
                        onChanged: (v) => setState(() => _selectedKy = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge số môn
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryFixed,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('${diemHienThi.length} môn',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                    // GPA kỳ hoặc Badge Tổng kết
                    if (currentKy == 'overview')
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 8),
                        Text(
                          (_showHe10 ? p.gpa : p.gpaHe4).toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ])
                    else if (currentKy != null) ...[
                      // Lấy GPA theo hệ đang chọn
                      Builder(builder: (context) {
                        final gpaKy = _showHe10
                            ? p.gpaByKy[currentKy]
                            : p.gpaByKyHe4[currentKy];
                        if (gpaKy == null) return const SizedBox.shrink();
                        return Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(width: 8),
                          Text(
                            gpaKy.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                        ]);
                      }),
                    ],
                  ]),
                ),
              ),

            // ── Danh sách điểm ────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (p.diemState == LoadState.loading && p.diem.isEmpty)
                    ...List.generate(
                        4,
                        (_) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SkeletonBox(
                                  width: double.infinity,
                                  height: 72,
                                  radius: 16),
                            )),

                  if (p.diem.isEmpty && p.diemState != LoadState.loading)
                    SurfaceCard(
                        child: const Center(
                            child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(children: [
                        Icon(Icons.grade_outlined,
                            size: 48, color: AppTheme.outlineVariant),
                        SizedBox(height: 12),
                        Text('Chưa có dữ liệu điểm',
                            style: TextStyle(color: AppTheme.onSurfaceVariant)),
                      ]),
                    ))),

                  // Chỉ hiện điểm của kỳ đang chọn
                  if (diemHienThi.isNotEmpty)
                    ...diemHienThi.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DiemCard(
                            diem: d,
                            showHe10: _showHe10,
                            isOverview: currentKy == 'overview',
                          ),
                        ))
                  else if (currentKy != null &&
                      p.diem.isNotEmpty &&
                      p.diemState != LoadState.loading)
                    SurfaceCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Không có điểm cho kỳ này',
                            style: TextStyle(color: AppTheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // "2023-2024_HK1" hoặc "HK1 2023-2024" → comparable int
  int _compareKyKey(String a, String b) {
    int toInt(String k) {
      // Format 1: "2023-2024_HK1"
      final m1 = RegExp(r'^(\d{4})-\d{4}_HK(\d)$').firstMatch(k);
      if (m1 != null) {
        final year = int.tryParse(m1.group(1)!) ?? 0;
        final ky = int.tryParse(m1.group(2)!) ?? 0;
        return year * 10 + ky;
      }
      // Format 2: "HK1 2023-2024"
      final m2 = RegExp(r'HK(\d)\s+(\d{4})').firstMatch(k);
      if (m2 != null) {
        final ky = int.tryParse(m2.group(1)!) ?? 0;
        final year = int.tryParse(m2.group(2)!) ?? 0;
        return year * 10 + ky;
      }
      return 0;
    }

    return toInt(a).compareTo(toInt(b));
  }
}

// ═══════════════════════════════════════════════════
// LINE CHART
// ═══════════════════════════════════════════════════

class _GpaLineChart extends StatelessWidget {
  final Map<String, double> gpaByKy;
  final List<String> allKyKeys; // ← TẤT CẢ kỳ có môn (kể cả chưa có điểm)
  final List<String> sortedKeys; // ← Kỳ có điểm số (để vẽ đường)
  final String? selectedKey;
  final ValueChanged<String> onSelectKy;
  final bool isHe10;

  const _GpaLineChart({
    required this.gpaByKy,
    required this.allKyKeys,
    required this.sortedKeys,
    required this.selectedKey,
    required this.onSelectKy,
    required this.isHe10,
  });

  @override
  Widget build(BuildContext context) {
    // Dùng allKyKeys để hiện đủ trục X, dùng sortedKeys để vẽ đường
    final displayKeys = allKyKeys.isNotEmpty ? allKyKeys : sortedKeys;
    if (displayKeys.isEmpty) return const SizedBox.shrink();

    const chartH = 200.0;
    const dotR = 6.0;
    const padL = 28.0;
    const padR = 24.0;
    const padTop = 24.0;
    const padBot = 36.0;
    final yMax = isHe10 ? 10.0 : 4.0;
    const yMin = 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('BIỂU ĐỒ GPA THEO KỲ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppTheme.outline,
              )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryFixed,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(isHe10 ? 'Thang 10' : 'Thang 4',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ),
        ]),
        const SizedBox(height: 4),

        // Hint text nếu chưa có điểm
        if (sortedKeys.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Chưa có điểm — biểu đồ sẽ hiện sau khi có kết quả',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant.withOpacity(0.7)),
            ),
          ),

        // Chart area
        SizedBox(
          height: chartH,
          child: LayoutBuilder(builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final n = displayKeys.length;
            final usableW = w - padL - padR;
            final step = n > 1 ? usableW / (n - 1) : usableW / 2;

            // Điểm của các kỳ CÓ điểm (để vẽ đường)
            final linePoints = <Offset>[];
            for (int i = 0; i < n; i++) {
              final key = displayKeys[i];
              if (!gpaByKy.containsKey(key)) continue;
              final x = padL + (n == 1 ? usableW / 2 : i * step);
              final v = gpaByKy[key]!.clamp(0.0, 10.0);
              final y = padTop +
                  (chartH - padTop - padBot) * (1 - (v - yMin) / (yMax - yMin));
              linePoints.add(Offset(x, y));
            }

            // Tất cả điểm X (để vẽ dot trên trục X)
            final allXPoints = List.generate(n, (i) {
              final x = padL + (n == 1 ? usableW / 2 : i * step);
              final key = displayKeys[i];
              final v = (gpaByKy[key] ?? 0.0).clamp(0.0, 10.0);
              final y = gpaByKy.containsKey(key)
                  ? padTop +
                      (chartH - padTop - padBot) *
                          (1 - (v - yMin) / (yMax - yMin))
                  : chartH - padBot; // dot ở đáy nếu chưa có điểm
              return Offset(x, y);
            });

            final selectedIdx =
                selectedKey != null ? displayKeys.indexOf(selectedKey!) : -1;

            return Stack(children: [
              // Grid + đường line
              CustomPaint(
                size: Size(w, chartH),
                painter: _GridPainter(
                  linePoints: linePoints,
                  allXPoints: allXPoints,
                  displayKeys: displayKeys,
                  gpaByKy: gpaByKy,
                  selectedIdx: selectedIdx,
                  padL: padL,
                  padR: padR,
                  padTop: padTop,
                  padBot: padBot,
                  yMax: yMax,
                  yMin: yMin,
                ),
              ),

              // Nhãn trục X
              ...List.generate(n, (i) {
                final pt = allXPoints[i];
                final key = displayKeys[i];
                final isSelected = key == selectedKey;
                final hasGrade = gpaByKy.containsKey(key);

                // Tính toán Năm học (1, 2, 3...) dựa trên index trong danh sách các năm duy nhất
                final uniqueYears = displayKeys
                    .map((k) => k.split('_')[0])
                    .toSet()
                    .toList()
                  ..sort();
                final currentYear = key.split('_')[0];
                final yearIndex = uniqueYears.indexOf(currentYear) + 1;

                final kyLbl = key.contains('_') ? key.split('_')[1] : '';

                return Positioned(
                  left: (pt.dx - 30).clamp(0.0, w - 60),
                  top: 0,
                  bottom: 0,
                  width: 60,
                  child: GestureDetector(
                    onTap: () => onSelectKy(key),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Spacer(),
                          Text('Năm $yearIndex',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppTheme.primary
                                    : (hasGrade
                                        ? AppTheme.onSurfaceVariant
                                        : AppTheme.outlineVariant
                                            .withOpacity(0.5)),
                              ),
                              textAlign: TextAlign.center),
                          Text(kyLbl,
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.primary
                                    : (hasGrade
                                        ? AppTheme.onSurfaceVariant
                                        : AppTheme.outlineVariant),
                              ),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                        ]),
                  ),
                );
              }),

              // Tooltip
              ...List.generate(n, (i) {
                final key = displayKeys[i];
                if (key != selectedKey) return const SizedBox.shrink();
                if (!gpaByKy.containsKey(key)) {
                  // Hiện "Chưa có điểm" tooltip
                  final pt = allXPoints[i];
                  return Positioned(
                    left: (pt.dx - 40).clamp(0.0, w - 80),
                    top: padTop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.outlineVariant.withOpacity(0.4)),
                      ),
                      child: const Text('Chưa có điểm',
                          style: TextStyle(
                              color: AppTheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  );
                }
                final pt = allXPoints[i];
                final v = gpaByKy[key]!;
                return Positioned(
                  left: pt.dx,
                  top: (pt.dy - 10).clamp(10.0, chartH),
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(v.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                  ),
                );
              }),

              // Dots (tap targets)
              ...List.generate(n, (i) {
                final pt = allXPoints[i];
                final key = displayKeys[i];
                final isSelected = key == selectedKey;
                final hasGrade = gpaByKy.containsKey(key);

                return Positioned(
                  left: pt.dx - 16,
                  top: pt.dy - 16,
                  child: GestureDetector(
                    onTap: () => onSelectKy(key),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                          child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? dotR * 2.4 : dotR * 2,
                        height: isSelected ? dotR * 2.4 : dotR * 2,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary
                              : (hasGrade
                                  ? AppTheme.surfaceContainerLowest
                                  : AppTheme.outlineVariant.withOpacity(0.2)),
                          border: Border.all(
                            color: hasGrade
                                ? AppTheme.primary
                                : AppTheme.outlineVariant.withOpacity(0.4),
                            width: isSelected ? 0 : 1.5,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withOpacity(0.35),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                      )),
                    ),
                  ),
                );
              }),
            ]);
          }),
        ),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  final List<Offset> linePoints; // ← chỉ kỳ CÓ điểm
  final List<Offset> allXPoints; // ← tất cả kỳ (để vẽ vertical line)
  final List<String> displayKeys;
  final Map<String, double> gpaByKy;
  final int selectedIdx;
  final double padL, padR, padTop, padBot, yMax, yMin;

  const _GridPainter({
    required this.linePoints,
    required this.allXPoints,
    required this.displayKeys,
    required this.gpaByKy,
    required this.selectedIdx,
    required this.padL,
    required this.padR,
    required this.padTop,
    required this.padBot,
    required this.yMax,
    required this.yMin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final usableH = size.height - padTop - padBot;

    final gridPaint = Paint()
      ..color = const Color(0xFF94908A).withOpacity(0.12)
      ..strokeWidth = 0.7;

    final linePaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.primary.withOpacity(0.15),
          AppTheme.primary.withOpacity(0.0)
        ],
      ).createShader(
          Rect.fromLTWH(0, padTop, size.width, size.height - padTop - padBot))
      ..style = PaintingStyle.fill;

    // Grid ngang
    final gridValues = yMax == 4.0
        ? [0.0, 1.0, 2.0, 3.0, 4.0]
        : [0.0, 2.0, 4.0, 6.0, 8.0, 10.0];
    for (final gv in gridValues) {
      final y = padTop + usableH * (1 - (gv - yMin) / (yMax - yMin));
      // Kéo dài đường kẻ sang 2 bên một chút (8px)
      canvas.drawLine(
          Offset(padL - 8, y), Offset(size.width - padR + 10, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: gv.toStringAsFixed(0),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Label bên trái
      tp.paint(canvas, Offset(padL - tp.width - 12, y - 5));
    }

    // Vẽ fill + đường chỉ khi có ≥ 2 điểm
    if (linePoints.length >= 2) {
      final fillPath = Path()
        ..moveTo(linePoints.first.dx, size.height - padBot)
        ..lineTo(linePoints.first.dx, linePoints.first.dy);
      for (int i = 1; i < linePoints.length; i++) {
        final cp1 = Offset((linePoints[i - 1].dx + linePoints[i].dx) / 2,
            linePoints[i - 1].dy);
        final cp2 = Offset(
            (linePoints[i - 1].dx + linePoints[i].dx) / 2, linePoints[i].dy);
        fillPath.cubicTo(
            cp1.dx, cp1.dy, cp2.dx, cp2.dy, linePoints[i].dx, linePoints[i].dy);
      }
      fillPath
        ..lineTo(linePoints.last.dx, size.height - padBot)
        ..close();
      canvas.drawPath(fillPath, fillPaint);

      final linePath = Path()..moveTo(linePoints.first.dx, linePoints.first.dy);
      for (int i = 1; i < linePoints.length; i++) {
        final cp1 = Offset((linePoints[i - 1].dx + linePoints[i].dx) / 2,
            linePoints[i - 1].dy);
        final cp2 = Offset(
            (linePoints[i - 1].dx + linePoints[i].dx) / 2, linePoints[i].dy);
        linePath.cubicTo(
            cp1.dx, cp1.dy, cp2.dx, cp2.dy, linePoints[i].dx, linePoints[i].dy);
      }
      canvas.drawPath(linePath, linePaint);
    } else if (linePoints.length == 1) {
      // Chỉ 1 điểm → vẽ chấm lớn
      canvas.drawCircle(
          linePoints.first,
          4,
          Paint()
            ..color = AppTheme.primary
            ..style = PaintingStyle.fill);
    }

    // Vertical highlight tại kỳ được chọn
    if (selectedIdx >= 0 && selectedIdx < allXPoints.length) {
      final x = allXPoints[selectedIdx].dx;
      canvas.drawLine(
        Offset(x, padTop),
        Offset(x, size.height - padBot),
        Paint()
          ..color = AppTheme.primary.withOpacity(0.2)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.linePoints != linePoints ||
      old.selectedIdx != selectedIdx ||
      old.allXPoints != allXPoints ||
      old.padL != padL ||
      old.padR != padR;
}

// ═══════════════════════════════════════════════════
// DIEM CARD (giữ nguyên từ file cũ)
// ═══════════════════════════════════════════════════

class _DiemCard extends StatelessWidget {
  final DiemMonHoc diem;
  final bool showHe10;
  final bool isOverview;
  const _DiemCard({
    required this.diem,
    required this.showHe10,
    this.isOverview = false,
  });

  @override
  Widget build(BuildContext context) {
    if (diem.canVote) return _VoteCard(diem: diem);

    // Lấy giá trị theo hệ
    final displayGrade =
        showHe10 ? (diem.avgGrade ?? 0.0) : (diem.diemTongKet ?? 0.0);
    final gradeLabel = showHe10 ? '/ 10' : '/ 4';
    final hasGrade =
        showHe10 ? diem.avgGrade != null : diem.diemTongKet != null;

    // Lấy điểm chữ hiển thị trên Badge: nếu Overview và có 'F | B' thì lấy 'B'
    String badgeGrade = '';
    if (isOverview &&
        diem.rawXepLoai != null &&
        diem.rawXepLoai!.contains('|')) {
      badgeGrade = diem.rawXepLoai!.split('|').last.trim();
    } else {
      badgeGrade = diem.xepLoai ?? diem.rawXepLoai ?? '';
    }

    return SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GradeBadge(grade: badgeGrade),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(diem.tenMonHoc,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${diem.soTinChi} tín chỉ',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          if (hasGrade)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // CHIÊU BÀI Ở ĐÂY: Dùng AnimatedNumber thay vì Text thường
              AnimatedNumber(
                value: displayGrade,
                fractionDigits: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800, color: AppTheme.primary),
              ),
              // Chuyển đổi mượt chữ "/ 10" thành "/ 4"
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(gradeLabel,
                    key: ValueKey(gradeLabel),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.outline)),
              ),
            ])
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('—',
                  style: TextStyle(
                      color: AppTheme.outline, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (diem.rawComponentScore != null &&
                diem.rawComponentScore!.isNotEmpty)
              _ScoreChip(label: 'Thành phần', value: diem.rawComponentScore!)
            else if (diem.componentScore != null &&
                diem.componentScore!.isNotEmpty)
              _ScoreChip(label: 'Thành phần', value: diem.componentScore!),
            if (diem.rawExamScore != null && diem.rawExamScore!.isNotEmpty)
              _ScoreChip(label: 'Thi', value: diem.rawExamScore!)
            else if (diem.examScore != null && diem.examScore!.isNotEmpty)
              _ScoreChip(label: 'Thi', value: diem.examScore!),
            if (diem.rawAvgGrade != null && diem.rawAvgGrade!.isNotEmpty)
              _ScoreChip(
                label: 'TBCHP',
                value: diem.rawAvgGrade!,
                highlight: showHe10,
              )
            else if (diem.avgGrade != null)
              _ScoreChip(
                label: 'TBCHP',
                value: diem.avgGrade!.toStringAsFixed(2),
                highlight: showHe10,
              ),
            if (diem.rawDiemSo != null && diem.rawDiemSo!.isNotEmpty)
              _ScoreChip(
                label: 'Điểm số',
                value: diem.rawDiemSo!,
                highlight: !showHe10,
              )
            else if (diem.diemTongKet != null)
              _ScoreChip(
                label: 'Điểm số',
                value: diem.diemTongKet!.toStringAsFixed(0),
                highlight: !showHe10,
              ),
            if (diem.rawXepLoai != null && diem.rawXepLoai!.isNotEmpty)
              _ScoreChip(
                label: 'Điểm chữ',
                value: diem.rawXepLoai!,
                isGradeLetter: true,
              )
            else if (diem.xepLoai != null && diem.xepLoai!.isNotEmpty)
              _ScoreChip(
                label: 'Điểm chữ',
                value: diem.xepLoai!,
                isGradeLetter: true,
              ),
          ],
        ),
      ]),
    );
  }
}

// Widget chip nhỏ cho từng chỉ số điểm
class _ScoreChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool isGradeLetter;

  const _ScoreChip({
    required this.label,
    required this.value,
    this.highlight = false,
    this.isGradeLetter = false,
  });

  // Màu theo điểm chữ
  Color _letterColor(String letter) {
    switch (letter.toUpperCase().trim()) {
      case 'A':
        return const Color(0xFF2E7D32); // xanh lá đậm
      case 'B':
        return AppTheme.primary;
      case 'C':
        return AppTheme.tertiary;
      case 'D':
        return const Color(0xFFE65100); // cam
      case 'F':
        return AppTheme.error;
      default:
        return AppTheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final valueColor = isGradeLetter
        ? _letterColor(value)
        : (highlight ? AppTheme.primary : AppTheme.onSurface);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppTheme.onSurfaceVariant)),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}

// Vote card giữ nguyên từ file cũ
class _VoteCard extends StatefulWidget {
  final DiemMonHoc diem;
  const _VoteCard({required this.diem});
  @override
  State<_VoteCard> createState() => _VoteCardState();
}

// Thay constructor và build:
class _DiemSummaryCard extends StatelessWidget {
  final DiemSummary summary;
  final bool showHe10;
  final String? mssv;

  const _DiemSummaryCard({
    required this.summary,
    required this.showHe10,
    this.mssv,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TỔNG KẾT HỌC TẬP',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppTheme.outline)),
            if (mssv != null)
              Text(mssv!,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: 14),
        // Row 1: TBC Tích lũy (Chính)
        Row(children: [
          _SummaryItem(
            label: showHe10 ? 'TBC tích lũy (Hệ 10)' : 'TBC tích lũy (Hệ 4)',
            valueNum: showHe10 ? summary.tbcTichLuyHe10 : summary.tbcTichLuyHe4,
            highlight: true,
          ),
          _SummaryItem(
            label: showHe10 ? 'TBC học tập (Hệ 10)' : 'TBC học tập (Hệ 4)',
            valueNum: showHe10 ? summary.tbcHocTapHe10 : summary.tbcHocTapHe4,
          ),
        ]),
        const SizedBox(height: 12),
        // Row 2: TBC Học tập
        Row(children: [
          _SummaryItem(
            label: showHe10 ? 'Xếp loại (Hệ 10)' : 'Xếp loại (Hệ 4)',
            fallbackText: showHe10
                ? (summary.xepLoaiHe10.isNotEmpty ? summary.xepLoaiHe10 : '—')
                : (summary.xepLoaiHe4.isNotEmpty ? summary.xepLoaiHe4 : '—'),
            highlight: true,
          ),
          _SummaryItem(
            label: 'TC tích lũy (A/B)',
            fallbackText: (summary.soTinChiTichLuy != null)
                ? '${summary.soTinChiTichLuy}'
                    '${summary.soTinChiTichLuyMax != null ? " / ${summary.soTinChiTichLuyMax}" : ""}'
                : '—',
          ),
        ]),
        const SizedBox(height: 12),
        // Row 3: Tín chỉ & Khen thưởng
        Row(children: [
          _SummaryItem(
            label: 'Số TC học tập',
            valueNum: summary.soTinChiHocTap?.toDouble(),
            fractionDigits: 0,
          ),
          if (summary.diemKhenThuong != null && summary.diemKhenThuong! > 0)
            _SummaryItem(
              label: 'Điểm khen thưởng',
              valueNum: summary.diemKhenThuong,
              fractionDigits: 0,
            )
          else
            const Expanded(child: SizedBox()),
        ]),
      ]),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double? valueNum;
  final String fallbackText;
  final bool highlight;
  final int fractionDigits;

  const _SummaryItem({
    required this.label,
    this.valueNum,
    this.fallbackText = '—',
    this.highlight = false,
    this.fractionDigits = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hiệu ứng mờ khi đổi tên nhãn
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(label,
                key: ValueKey(label),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.onSurfaceVariant,
                )),
          ),
          const SizedBox(height: 2),
          if (valueNum != null)
            AnimatedNumber(
              value: valueNum!,
              fractionDigits: fractionDigits,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: highlight ? AppTheme.primary : AppTheme.onSurface,
              ),
            )
          else
            Text(
              fallbackText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: highlight ? AppTheme.primary : AppTheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScaleToggle extends StatefulWidget {
  final bool value; // true = Hệ 10
  final ValueChanged<bool> onChanged;
  final double swipeOffset; // <-- Nhận tỷ lệ vuốt từ màn hình cha

  const _ScaleToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.swipeOffset = 0.0,
  });

  @override
  State<_ScaleToggle> createState() => _ScaleToggleState();
}

class _ScaleToggleState extends State<_ScaleToggle> {
  double? _dragValue;
  bool _dragging = false;
  Offset? _downPosition;
  bool _dragStarted = false;

  double get _baseValue => widget.value ? 0.0 : 1.0;

  // CÔNG THỨC VÀNG: Kết hợp vị trí hiện tại và lực vuốt ngón tay
  double get _visualValue {
    if (_dragValue != null) return _dragValue!.clamp(0.0, 1.0);
    // Khi màn hình bị vuốt, ô xanh sẽ trượt theo tỷ lệ tương ứng
    return (_baseValue - widget.swipeOffset).clamp(0.0, 1.0);
  }

  void _startPointer(PointerDownEvent details) {
    _downPosition = details.localPosition;
    _dragStarted = false;
  }

  void _updatePointer(PointerMoveEvent details, double totalWidth) {
    final down = _downPosition;
    if (down == null) return;

    final moved = (details.localPosition.dx - down.dx).abs();
    if (!_dragStarted && moved > 6) {
      _dragStarted = true;
      if (!mounted) return;
      setState(() => _dragging = true);
    }

    if (!_dragStarted) return;

    setState(() {
      // Giúp ô màu xanh bám chính xác vào tâm ngón tay khi vuốt trực tiếp lên thanh chọn
      final itemWidth = totalWidth / 2;
      _dragValue = ((details.localPosition.dx - itemWidth / 2) / itemWidth)
          .clamp(0.0, 1.0);
    });
  }

  void _endPointer() {
    if (_dragStarted) {
      final nextValue =
          _visualValue < 0.5; // Nhả tay gần bên nào thì chọn bên đó
      widget.onChanged(nextValue);
    }
    _resetPointer();
  }

  void _cancelPointer() => _resetPointer();

  void _resetPointer() {
    if (!mounted) return;
    setState(() {
      _dragging = false;
      _dragValue = null;
      _downPosition = null;
      _dragStarted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh.withOpacity(0.82),
          borderRadius: BorderRadius.circular(999),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final itemWidth = totalWidth / 2;

            // Đang có tương tác ngón tay hay không? (vuốt màn hình HOẶC vuốt thanh)
            final isInteracting = _dragging || widget.swipeOffset != 0.0;

            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _startPointer,
              onPointerMove: (details) => _updatePointer(details, totalWidth),
              onPointerUp: (_) => _endPointer(),
              onPointerCancel: (_) => _cancelPointer(),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    // QUAN TRỌNG: Nếu đang kéo ngón tay -> duration = 0 để ô xanh bám sát tức thì (ko độ trễ)
                    // Nhả ngón tay ra -> duration = 250 để mượt mà trượt nốt vào đúng ô
                    duration: Duration(milliseconds: isInteracting ? 0 : 250),
                    curve: Curves.easeOutCubic,
                    left: _visualValue * itemWidth,
                    top: 0,
                    child: _pill(itemWidth, constraints.maxHeight),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _Tab(
                          label: 'Hệ 10',
                          active: widget.value,
                          onTap: () => widget.onChanged(true),
                        ),
                      ),
                      Expanded(
                        child: _Tab(
                          label: 'Hệ 4',
                          active: !widget.value,
                          onTap: () => widget.onChanged(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pill(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.primary.withOpacity(0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

// ... class _Tab giữ nguyên như cũ

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: double.infinity,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w800 : FontWeight.w700,
              color: active ? Colors.white : AppTheme.onSurfaceVariant,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// Thêm _GpaHeroCard:
class _GpaHeroCard extends StatelessWidget {
  final double? tbcTichLuyHe10;
  final double? tbcTichLuyHe4;
  final bool showHe10;
  final double gpaCalculated;
  final String xepLoai;
  const _GpaHeroCard({
    required this.tbcTichLuyHe10,
    required this.tbcTichLuyHe4,
    required this.showHe10,
    required this.gpaCalculated,
    required this.xepLoai,
  });

  @override
  Widget build(BuildContext context) {
    final gpaVal =
        showHe10 ? (tbcTichLuyHe10 ?? gpaCalculated) : (tbcTichLuyHe4 ?? 0.0);
    final maxVal = showHe10 ? 10.0 : 4.0;
    final gpaStr = gpaVal.toStringAsFixed(2);
    final maxStr = showHe10 ? '/ 10.0' : '/ 4.0';

    return SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('GPA TÍCH LŨY',
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.outline,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(gpaStr,
                style: GoogleFonts.manrope(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    height: 1)),
            const SizedBox(height: 4),
            Text('$maxStr hệ điểm',
                style: const TextStyle(
                    color: AppTheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppTheme.primaryFixed,
                  borderRadius: BorderRadius.circular(99)),
              child: Text(xepLoai,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        CircularProgressWidget(
          value: (gpaVal / maxVal).clamp(0.0, 1.0),
          center: gpaVal.toStringAsFixed(1),
          subtitle: showHe10 ? '/10' : '/4',
          size: 110,
        ),
      ]),
    );
  }
}

class _VoteCardState extends State<_VoteCard> {
  int? _sel;
  bool _loading = false;
  bool _success = false;

  static const _levels = [
    (1, 'Không\nđồng ý', AppTheme.error),
    (2, 'Phân\nvân', AppTheme.tertiary),
    (3, 'Đồng\ný', AppTheme.primary),
    (4, 'Hoàn toàn\nđồng ý', Color(0xFF2E7D32)),
  ];

  // Mô tả nhãn mức độ
  static const _levelLabels = {
    1: 'Không đồng ý',
    2: 'Phân vân',
    3: 'Đồng ý',
    4: 'Hoàn toàn đồng ý',
  };

  static const _levelColors = {
    1: AppTheme.error,
    2: AppTheme.tertiary,
    3: AppTheme.primary,
    4: Color(0xFF2E7D32),
  };

  @override
  Widget build(BuildContext context) {
    // Trạng thái đã gửi thành công
    if (_success) {
      return SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF2E7D32), size: 40),
          const SizedBox(height: 12),
          const Text('Đánh giá thành công!',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF2E7D32))),
          const SizedBox(height: 6),
          const Text(
            'Tải lại trang để xem điểm của môn học này.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tải lại điểm'),
              onPressed: () => context.read<AppProvider>().syncGrades(),
            ),
          ),
        ]),
      );
    }

    return SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.how_to_vote_outlined,
                color: AppTheme.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.diem.tenMonHoc,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const Text('Cần đánh giá để xem điểm',
                    style: TextStyle(fontSize: 12, color: AppTheme.error)),
              ])),
        ]),
        const SizedBox(height: 14),

        Text('CHỌN MỨC ĐỘ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.onSurfaceVariant, letterSpacing: 1.5)),
        const SizedBox(height: 10),

        // Rating buttons
        Row(
            children: _levels.map((item) {
          final (val, lbl, color) = item;
          final active = _sel == val;
          return Expanded(
              child: GestureDetector(
            onTap: _loading ? null : () => setState(() => _sel = val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? color : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Text('$val',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : color)),
                const SizedBox(height: 2),
                Text(lbl,
                    style: TextStyle(
                        fontSize: 9, color: active ? Colors.white70 : color),
                    textAlign: TextAlign.center),
              ]),
            ),
          ));
        }).toList()),
        const SizedBox(height: 12),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _loading
                ? Container(
                    key: const ValueKey('loading'),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.primary)),
                          SizedBox(width: 10),
                          Text('Đang gửi đánh giá...',
                              style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ]))
                : MaterialButton(
                    key: const ValueKey('button'),
                    onPressed: _sel == null ? null : _showCommentSheet,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: AppTheme.primary,
                    disabledColor: AppTheme.surfaceContainerHigh,
                    child: Text('Gửi đánh giá',
                        style: TextStyle(
                            color:
                                _sel == null ? AppTheme.outline : Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
          ),
        ),
      ]),
    );
  }

  // Hiển thị bottom sheet nhập nhận xét
  Future<void> _showCommentSheet() async {
    if (_sel == null) return;
    final TextEditingController ctrl = TextEditingController();
    final selVal = _sel!;
    final selColor = _levelColors[selVal]!;
    final selLabel = _levelLabels[selVal]!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.onSurface.withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, -8))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                // Tiêu đề
                const Text('Xác nhận đánh giá',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(widget.diem.tenMonHoc,
                    style: const TextStyle(
                        color: AppTheme.onSurfaceVariant, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),

                // Mức đã chọn
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selColor.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                          color: selColor,
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                          child: Text('$selVal',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16))),
                    ),
                    const SizedBox(width: 12),
                    Text(selLabel,
                        style: TextStyle(
                            color: selColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ]),
                ),
                const SizedBox(height: 16),

                // Nhận xét (optional)
                const Text('Nhận xét (không bắt buộc)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: 'Ý kiến đóng góp để giúp hoạt động dạy-học...',
                    hintStyle: const TextStyle(color: AppTheme.outlineVariant),
                    filled: true,
                    fillColor: AppTheme.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppTheme.outlineVariant.withOpacity(0.4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppTheme.outlineVariant.withOpacity(0.3)),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 4),

                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Bỏ qua'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Gửi đánh giá'),
                      onPressed: () {
                        final nhanXet = ctrl.text.trim();
                        Navigator.pop(ctx, nhanXet);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ]),
              ]),
        ),
      ),
    ).then((nhanXet) async {
      if (nhanXet == null) return; // User đóng sheet
      await _doVote(nhanXet as String);
    });
  }

  Future<void> _doVote(String nhanXet) async {
    if (_sel == null || widget.diem.id == null) return;
    setState(() => _loading = true);

    final ok = await context.read<AppProvider>().voteAndRefreshDiem(
          widget.diem.tenMonHoc,
          _sel!,
          widget.diem.id!,
          nhanXet: nhanXet,
          maMonHoc:
              widget.diem.maMonHoc.isNotEmpty ? widget.diem.maMonHoc : null,
        );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _loading = false;
        _success = true;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gửi đánh giá thất bại — vui lòng thử lại'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ═══════════════════════════════════════════════════
// ANIMATED NUMBER (Hiệu ứng số chạy)
// ═══════════════════════════════════════════════════
class AnimatedNumber extends StatelessWidget {
  final double value;
  final int fractionDigits;
  final TextStyle? style;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.fractionDigits = 1,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Khi 'value' thay đổi, Tween sẽ tự động chạy từ số hiện tại đến số mới
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic, // Số chạy nhanh lúc đầu, chậm dần về cuối
      builder: (context, val, child) {
        return Text(
          val.toStringAsFixed(fractionDigits),
          style: style,
        );
      },
    );
  }
}

class _SemesterSelector extends StatelessWidget {
  final String? value;
  final List<String> allKyKeys;
  final ValueChanged<String?> onChanged;

  const _SemesterSelector({
    required this.value,
    required this.allKyKeys,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOverview = value == 'overview';
    String displayLabel = 'Tổng quan';
    if (!isOverview && value != null) {
      final parts = value!.split('_');
      displayLabel = parts.length == 2
          ? '${parts[1].replaceAll('HK', 'HK ')} · ${parts[0]}'
          : value!;
    }

    return PressScale(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryFixed.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(
              isOverview
                  ? Icons.dashboard_outlined
                  : Icons.calendar_today_outlined,
              size: 16,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outlineVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'CHỌN HỌC KỲ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppTheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                children: [
                  _buildOption(context, 'overview', 'Tổng quan',
                      Icons.dashboard_outlined),
                  const Divider(height: 1, indent: 48),
                  ...allKyKeys.reversed.map((ky) {
                    final parts = ky.split('_');
                    final label = parts.length == 2
                        ? '${parts[1].replaceAll('HK', 'HK ')} · ${parts[0]}'
                        : ky;
                    return _buildOption(
                        context, ky, label, Icons.calendar_today_outlined);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, String ky, String label, IconData icon) {
    final isSelected = value == ky;
    return ListTile(
      onTap: () {
        onChanged(ky);
        Navigator.pop(context);
      },
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.primary : AppTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppTheme.primary,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppTheme.primary : AppTheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 22)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
