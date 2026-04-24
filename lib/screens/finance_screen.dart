import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/shared_widgets.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  String _fmt(double v, NumberFormat f) => v >= 1000000000
      ? '${(v / 1000000000).toStringAsFixed(1)}B\nVNĐ'
      : '${f.format(v)}\nVNĐ';

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final f = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () => p.syncFinance(),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: AcademicAppBar(
            subtitle: 'TÀI CHÍNH',
            actions: [
              IconButton(
                icon: p.hocPhiState == LoadState.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary))
                    : const Icon(Icons.sync_outlined, color: AppTheme.primary),
                onPressed: () => p.syncFinance(forceRefresh: true),
                tooltip: 'Đồng bộ học phí',
              ),
            ],
          )),

          // Hero card
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tài chính',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('HK${p.currentHocKy} · ${p.namHocLabel}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppTheme.outline, letterSpacing: 1.5)),
              const SizedBox(height: 20),
              GradientCard(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TỔNG HỌC PHÍ ĐÃ NỘP',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(_fmt(p.tongHocPhiAllDaDong, f),
                      style: GoogleFonts.manrope(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1)),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Text('Tiến độ thanh toán',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const Spacer(),
                    Text('${(p.progressHocPhiAll * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: p.progressHocPhiAll,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Phải nộp',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(_fmt(p.tongHocPhiAllPhaiDong, f),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.2)),
                          ]),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Còn lại',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(_fmt(p.tongHocPhiAllConLai, f),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.2)),
                          ]),
                    )),
                  ]),
                ],
              )),
            ]),
          )),

          // Transaction list
          // Thay toàn bộ phần "Transaction list" SliverPadding:

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              // ── BẢNG 1: Học phí theo kỳ ──
              SectionHeader(title: 'Lịch sử giao dịch'),
              const SizedBox(height: 12),

              if (p.paymentReceipts.isEmpty &&
                  p.feeDetails.isEmpty &&
                  p.feeSummaries.isEmpty)
                SurfaceCard(
                    child: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Text('Chưa có dữ liệu học phí',
                        style: TextStyle(color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text(
                        'Receipts: ${p.paymentReceipts.length}, Details: ${p.feeDetails.length}, Summaries: ${p.feeSummaries.length}',
                        style: TextStyle(
                            fontSize: 10, color: AppTheme.onSurfaceVariant),
                        textAlign: TextAlign.center),
                  ]),
                ))),

              // Hiển thị payment receipts (bảng 2 web = hóa đơn)
              ...p.paymentReceipts.map((r) {
                final soTien = (r['tong_tien_phieu'] as num?)?.toDouble() ?? 0;
                final ngayThu = r['ngay_thu']?.toString() ?? '';
                final namHoc = r['nam_hoc']?.toString() ?? '';
                final hocKy = r['hoc_ky'];
                final soPhieu = r['so_phieu']?.toString() ?? '';
                final lanThu = r['lan_thu'] ?? 1;
                final dotThu = r['dot_thu'] ?? 1;
                final daDong = true; // receipt = đã nộp

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long_outlined,
                            color: AppTheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Phiếu #$soPhieu',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            Text('HK$hocKy · $namHoc',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppTheme.onSurfaceVariant)),
                            Text('Lần $lanThu · Đợt $dotThu · $ngayThu',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 10)),
                          ])),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_fmt(soTien, f),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2E7D32),
                                        height: 1.2),
                                textAlign: TextAlign.right,
                                maxLines: 2),
                            const SizedBox(height: 4),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check_circle,
                                  size: 13, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 4),
                              const Text('Đã nộp',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32))),
                            ]),
                          ]),
                    ]),
                  ),
                );
              }),

              // ── BẢNG 3: Chi tiết các khoản ──
              if (p.feeDetails.isNotEmpty) ...[
                const SizedBox(height: 20),
                SectionHeader(title: 'Chi tiết các khoản nộp'),
                const SizedBox(height: 12),

                // Group by so_phieu
                ...(() {
                  print('📋 FeeDetails count: ${p.feeDetails.length}');
                  final grouped = <String, List<Map<String, Object?>>>{};
                  int filtered = 0;
                  for (final d in p.feeDetails) {
                    // KHÔNG filter - hiển thị tất cả 43 dòng
                    final tenHoc = d['ten_hoc_phan']?.toString() ?? '';

                    final key = '${d['so_phieu']} · ${d['ngay_nop']}';
                    grouped.putIfAbsent(key, () => []).add(d);
                  }
                  print(
                      '📋 After filter: grouped=${grouped.length}, filtered=$filtered');
                  return grouped.entries
                      .map((entry) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('📄 Phiếu ${entry.key}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                            color: AppTheme.onSurfaceVariant,
                                            letterSpacing: 0.5)),
                              ),
                              ...entry.value.map((d) {
                                final tenHocPhan =
                                    d['ten_hoc_phan']?.toString() ??
                                        'Chưa xác định';
                                final phaiNop = (d['so_tien_phai_nop'] as num?)
                                        ?.toDouble() ??
                                    0;
                                final daNop =
                                    (d['so_tien_da_nop'] as num?)?.toDouble() ??
                                        0;
                                final chenhlech = daNop - phaiNop;
                                final trangThai =
                                    d['trang_thai']?.toString() ?? '';
                                final daDong = chenhlech >= 0;
                                final trangThaiText = daDong
                                    ? 'Đã thanh toán'
                                    : 'Chưa thanh toán';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: SurfaceCard(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: AppTheme
                                                    .surfaceContainerLow,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                  Icons.book_outlined,
                                                  size: 18,
                                                  color: AppTheme.primary),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(tenHocPhan,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                      maxLines: 2,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ])),
                                            Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                      '${f.format(chenhlech.abs())}\nVNĐ',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: daDong
                                                                  ? const Color(
                                                                      0xFF2E7D32)
                                                                  : AppTheme
                                                                      .tertiary,
                                                              height: 1.2),
                                                      textAlign:
                                                          TextAlign.right,
                                                      maxLines: 2),
                                                ]),
                                          ]),
                                          const SizedBox(height: 10),
                                          Row(children: [
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(
                                                      'Phải nộp: ${f.format(phaiNop)} VNĐ',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme
                                                              .onSurfaceVariant,
                                                          height: 1.2),
                                                      maxLines: 2),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                      'Đã nộp: ${f.format(daNop)} VNĐ',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: const Color(
                                                              0xFF2E7D32),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          height: 1.2),
                                                      maxLines: 2),
                                                ])),
                                            Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: daDong
                                                          ? const Color(
                                                                  0xFF2E7D32)
                                                              .withOpacity(0.12)
                                                          : AppTheme
                                                              .surfaceContainerLow,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(trangThaiText,
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: daDong
                                                                ? const Color(
                                                                    0xFF2E7D32)
                                                                : AppTheme
                                                                    .onSurfaceVariant,
                                                            height: 1.2),
                                                        textAlign:
                                                            TextAlign.center),
                                                  ),
                                                ]),
                                          ]),
                                        ]),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 12),
                            ],
                          ))
                      .toList();
                })(),
              ],
            ])),
          ),
        ]),
      ),
    );
  }
}
