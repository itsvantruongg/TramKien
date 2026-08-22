import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../theme/app_theme.dart';

// ── Shared Help Button ─────────────────────────────────────────

class HelpButton extends StatelessWidget {
  final VoidCallback onTap;
  const HelpButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.help_outline_rounded,
            size: 21,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}

// ── Helper Popup Dialog Wrapper ───────────────────────────────

void showHelpDialog({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final maxHeight = MediaQuery.of(ctx).size.height * 0.78;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        clipBehavior: Clip.antiAlias,
        elevation: 8,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: maxHeight),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content Area - Flexible enables auto-fit content up to maxHeight
              Flexible(child: child),
            ],
          ),
        ),
      );
    },
  );
}

// ══════════════════════════════════════════════════════════════
// 1. FINANCE HELP DIALOG CONTENT
// ══════════════════════════════════════════════════════════════

class FinanceHelpSheet extends StatelessWidget {
  const FinanceHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Cách nộp học phí
          _buildSectionCard(
            title: 'Cách nộp học phí',
            icon: Icons.account_balance_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPaymentSubBlock(
                  number: '①',
                  title: 'Có tài khoản BIDV:',
                  content:
                      'Smartbanking → Thanh toán → tìm "Kiến trúc" → nhập mã khách hàng (V3HAU + mã SV) → không cần nhập số tiền/nội dung → Tiếp tục.',
                ),
                const SizedBox(height: 12),
                _buildPaymentSubBlock(
                  number: '②',
                  title: 'Có tài khoản ngân hàng khác:',
                  content:
                      'Smartbanking → Chuyển tiền nhanh 24/7 (hoặc chuyển tiền trong nước) → nhập:\n'
                      '• Tài khoản thụ hưởng: V3HAU + mã SV\n'
                      '• Ngân hàng thụ hưởng: BIDV\n'
                      '• Số tiền: lấy số sau chữ "HD" trong tên tài khoản\n'
                      '• Nội dung: "nộp học phí kỳ... năm học..."\n'
                      '→ Tiếp tục.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Section 3: Lưu ý (Màu vàng/cam nhạt)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFF57F17), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Lưu ý quan trọng',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFFF57F17),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildBulletItem(
                    'Lưu lại thông tin chuyển khoản để đối chiếu khi cần.'),
                const SizedBox(height: 6),
                _buildBulletItem(
                    'Hóa đơn điện tử tự động gửi về email đã khai tại tinchi.hau.edu.vn → Sinh viên → Thông tin cá nhân → Hồ sơ cá nhân.'),
                const SizedBox(height: 6),
                _buildBulletItem(
                    'Thời hạn nộp học phí theo thông báo đầu mỗi học kỳ.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPaymentSubBlock({
    required String number,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFFF57F17))),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 2. GRADE HELP DIALOG CONTENT (WITH DYNAMIC HEIGHT TAB BAR)
// ══════════════════════════════════════════════════════════════

class GradeHelpSheet extends StatefulWidget {
  const GradeHelpSheet({super.key});

  @override
  State<GradeHelpSheet> createState() => _GradeHelpSheetState();
}

class _GradeHelpSheetState extends State<GradeHelpSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentIndex) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -150) {
      // Vuốt sang trái -> chuyển tab kế tiếp
      if (_currentIndex < 2) {
        _tabController.animateTo(_currentIndex + 1);
      }
    } else if (velocity > 150) {
      // Vuốt sang phải -> chuyển tab trước đó
      if (_currentIndex > 0) {
        _tabController.animateTo(_currentIndex - 1);
      }
    }
  }

  Widget _getTabContent(int index) {
    switch (index) {
      case 0:
        return _buildTabFormulas();
      case 1:
        return _buildTabGrading();
      case 2:
        return _buildTabWarnings();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // TabBar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            onTap: (index) {
              if (index != _currentIndex) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.outline,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Công thức'),
              Tab(text: 'Xếp loại'),
              Tab(text: 'Cảnh báo'),
            ],
          ),
        ),
        const Divider(height: 1),

        // Dynamic Height Body with AnimatedSize & Horizontal Swipe Support
        Flexible(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: _handleSwipe,
              child: SingleChildScrollView(
                key: ValueKey<int>(_currentIndex),
                padding: const EdgeInsets.all(16),
                child: _getTabContent(_currentIndex),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── TAB 1: CÔNG THỨC ──────────────────────────────────────────
  Widget _buildTabFormulas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Block 1: Điểm học phần
        _buildFormulaBlock(
          title: '1. Điểm học phần (Đhp)',
          latexFormula: r'\text{Đ}_{hp} = k \cdot \text{Đ}_{qt} + (1-k) \cdot \text{Đ}_{kt}',
          notes: [
            'Đqt: điểm quá trình (chuyên cần, kiểm tra thường xuyên, giữa kỳ, thực hành, tiểu luận...)',
            'Đkt: điểm thi kết thúc học phần',
            'k = 0,2 (học phần chỉ có lý thuyết) hoặc k = 0,3 (các học phần còn lại)',
          ],
          extraNote:
              'Học phần thực hành: điểm = trung bình cộng các bài thực hành trong kỳ, làm tròn 1 chữ số thập phân.',
        ),
        const SizedBox(height: 14),

        // Block 2: Điểm trung bình chung (TBCHK/TBCNH/TBCTL)
        _buildFormulaBlock(
          title: '2. Điểm trung bình chung (TBCHK/TBCNH/TBCTL)',
          subtitle: 'Quy đổi điểm chữ → điểm số: A=4, B=3, C=2, D=1, F=0',
          latexFormula:
              r'A = \frac{\sum_{i=1}^{n-1} a_i \cdot n_i + \text{Đ}_{đatn} \cdot n_{đatn} \cdot f}{\sum_{i=1}^{n-1} n_i + n_{đatn} \cdot f}',
          notes: [
            'aᵢ, nᵢ: điểm và số tín chỉ học phần thứ i (trừ các học phần chỉ xét điều kiện)',
            'Đđatn, nđatn: điểm và số tín chỉ Đồ án tốt nghiệp',
            'f = 1,5 (ngành năng khiếu) / f = 1,0 (ngành khác) / f = 0 nếu chưa có điểm ĐATN',
            'Kết quả làm tròn 2 chữ số thập phân',
          ],
        ),
        const SizedBox(height: 14),

        // Block 3: Điểm Đồ án tốt nghiệp (ĐATN)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '3. Điểm học phần Đồ án tốt nghiệp (ĐATN)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              _buildLatexBox(
                  r'\text{Đ}_{đatn} = k \cdot \text{Đ}_{qttn} + (1-k) \cdot \text{Đ}_{bvtn}'),
              const SizedBox(height: 8),
              _buildLatexBox(
                  r'\text{Đ}_{qttn} = \frac{\text{Đ}_{hd} + \text{Đ}_{th}}{2}'),
              const SizedBox(height: 8),
              _buildLatexBox(
                  r'\text{Đ}_{bvtn} = \frac{\text{Đ}_{pb} + \sum_{k=1}^{m} \text{Đ}_{tv_k}}{m+1}'),
              const SizedBox(height: 10),
              _buildNotesList([
                'Trọng số k = 0,3',
                'Đhd: điểm GV hướng dẫn; Đth: điểm TB kiểm tra quá trình',
                'Đpb: điểm GV phản biện/Hội đồng sơ khảo/kiểm tra trước bảo vệ',
                'Đtv: điểm từng thành viên Tiểu ban chấm; m: số thành viên',
                'Không tính Đtv chênh ≥1,5 điểm so với TB các thành viên',
                'ĐATN đạt nếu Đđatn ≥ 5,5 (thang 10)',
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormulaBlock({
    required String title,
    String? subtitle,
    required String latexFormula,
    required List<String> notes,
    String? extraNote,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: AppTheme.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildLatexBox(latexFormula),
          const SizedBox(height: 10),
          _buildNotesList(notes),
          if (extraNote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                extraNote,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.blue.shade900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLatexBox(String formula) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(
          child: Math.tex(
            formula,
            textStyle: const TextStyle(fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesList(List<String> notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: notes
          .map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ── TAB 2: XẾP LOẠI ───────────────────────────────────────────
  Widget _buildTabGrading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-block A: Thang điểm chữ
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thang điểm chữ (loại có phân mức)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  border: TableBorder.all(
                      color: Colors.grey.shade300, width: 0.8),
                  children: [
                    _buildTableHeader(['Điểm chữ', 'Thang 10']),
                    _buildTableRow('A', '8,5 – 10,0', false),
                    _buildTableRow('B', '7,0 – 8,4', true),
                    _buildTableRow('C', '5,5 – 6,9', false),
                    _buildTableRow('D', '4,0 – 5,4', true),
                    _buildTableRow('F', 'dưới 4,0', false,
                        textColor: AppTheme.error),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'P: đạt không phân mức (tham quan, thực tập, GDTC, GDQP-AN...)\n'
                'I: chưa hoàn thiện do hoãn thi · X: chưa đủ dữ liệu · R: miễn học/công nhận tín chỉ',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.outline,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Sub-block B: Xếp loại học lực
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Xếp loại học lực (theo điểm TBCTL)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  border: TableBorder.all(
                      color: Colors.grey.shade300, width: 0.8),
                  children: [
                    _buildTableHeader(['TBCTL (Hệ 4)', 'Xếp loại']),
                    _buildTableRow('3,6 – 4,0', 'Xuất sắc', false,
                        textColor: const Color(0xFF6A1B9A),
                        rowBg: const Color(0xFFF3E5F5)),
                    _buildTableRow('3,2 – <3,6', 'Giỏi', true,
                        textColor: const Color(0xFF1B5E20),
                        rowBg: const Color(0xFFE8F5E9)),
                    _buildTableRow('2,5 – <3,2', 'Khá', false,
                        textColor: AppTheme.primary),
                    _buildTableRow('2,0 – <2,5', 'Trung bình', true,
                        textColor: const Color(0xFFF57C00)),
                    _buildTableRow('1,0 – <2,0', 'Yếu', false,
                        textColor: const Color(0xFFE65100)),
                    _buildTableRow('<1,0', 'Kém', true,
                        textColor: AppTheme.error,
                        rowBg: const Color(0xFFFFEBEE)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TableRow _buildTableHeader(List<String> titles) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: titles
          .map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Text(
                t,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.onSurface,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _buildTableRow(String c1, String c2, bool isEven,
      {Color? textColor, Color? rowBg}) {
    return TableRow(
      decoration: BoxDecoration(
        color: rowBg ?? (isEven ? Colors.grey.shade100 : Colors.white),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Text(
            c1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Text(
            c2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor ?? AppTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // ── TAB 3: CẢNH BÁO HỌC TẬP ───────────────────────────────────
  Widget _buildTabWarnings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFE65100), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Điều kiện cảnh báo học tập',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildWarningBullet(
                  'Nợ tín chỉ > 24 tín chỉ từ đầu khóa, HOẶC'),
              const SizedBox(height: 8),
              _buildWarningBullet('TBCTL dưới ngưỡng theo trình độ năm học:'),
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 4, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubThreshold('Năm 1:', 'dưới 1,2'),
                    _buildSubThreshold('Năm 2:', 'dưới 1,4'),
                    _buildSubThreshold('Năm 3:', 'dưới 1,6'),
                    _buildSubThreshold('Năm 4 trở đi:', 'dưới 1,8'),
                  ],
                ),
              ),
              _buildWarningBullet(
                  'Số lần cảnh báo tối đa = số năm học chuẩn toàn khóa, không quá 2 lần cảnh báo liên tiếp.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.blue.shade800, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Ví dụ minh họa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Sinh viên năm 2 có điểm TBCTL = 1,3 (dưới ngưỡng 1,4) → sẽ bị cảnh báo học tập trong năm học đó.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubThreshold(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFFBF360C),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
