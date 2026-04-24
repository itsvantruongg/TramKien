import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
                  onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Điều khoản & Dịch vụ',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800)),
                    Text('TERMS OF SERVICE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.outline, letterSpacing: 1.5)),
                  ])),
            ]),
          )),
        )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          sliver: SliverList(
              delegate: SliverChildListDelegate([
            SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Trạm Kiến',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Cập nhật: 24/04/2026 • Phiên bản 1.0.1',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppTheme.outline)),
                    ])),
              ]),
            ),
            const SizedBox(height: 16),
            _Section(
              icon: Icons.lock_outline,
              color: AppTheme.primary,
              title: 'Bảo mật thông tin',
              items: const [
                'Ứng dụng KHÔNG lưu trữ mật khẩu của bạn dưới bất kỳ hình thức nào.',
                'Thông tin đăng nhập chỉ được sử dụng để xác thực với cổng thông tin HAU và không được chia sẻ với bên thứ ba.',
                'Dữ liệu học tập (điểm, lịch, học phí) chỉ được lưu cục bộ trên thiết bị của bạn.',
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              icon: Icons.visibility_off_outlined,
              color: AppTheme.secondary,
              title: 'Quyền truy cập',
              items: const [
                'Ứng dụng KHÔNG truy cập camera, micro, danh bạ hoặc vị trí của bạn.',
                'Ứng dụng chỉ kết nối đến máy chủ chính thức của Đại học Kiến trúc Hà Nội (tinchi.hau.edu.vn).',
                'Ứng dụng KHÔNG thực hiện bất kỳ giao dịch tài chính nào thay bạn.',
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              icon: Icons.storage_outlined,
              color: AppTheme.tertiary,
              title: 'Dữ liệu cục bộ',
              items: const [
                'Dữ liệu được cache cục bộ giúp xem thông tin nhanh khi offline.',
                'Bạn có thể xóa toàn bộ dữ liệu bằng cách đăng xuất khỏi ứng dụng.',
                'Ứng dụng KHÔNG gửi dữ liệu cá nhân đến máy chủ của bên phát triển.',
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              icon: Icons.info_outline,
              color: const Color(0xFF2E7D32),
              title: 'Phạm vi sử dụng',
              items: const [
                'Đây là ứng dụng không chính thức, được phát triển độc lập nhằm hỗ trợ sinh viên HAU.',
                'Ứng dụng không có liên kết chính thức với Đại học Kiến trúc Hà Nội.',
                'Thông tin hiển thị phụ thuộc vào dữ liệu từ cổng thông tin HAU; độ chính xác phụ thuộc vào hệ thống gốc.',
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              icon: Icons.update_outlined,
              color: AppTheme.primary,
              title: 'Cập nhật điều khoản',
              items: const [
                'Điều khoản có thể được cập nhật khi ứng dụng phát hành phiên bản mới.',
                'Việc tiếp tục sử dụng ứng dụng sau khi cập nhật đồng nghĩa với việc bạn chấp nhận các điều khoản mới.',
              ],
            ),
            const SizedBox(height: 20),
            SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Icon(Icons.favorite, color: AppTheme.error, size: 28),
                const SizedBox(height: 8),
                Text('Được phát triển với ♥ cho sinh viên HAU',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Mọi thắc mắc gửi về: ',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppTheme.primary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12), // Khoảng cách từ chữ xuống ảnh QR

                // --- PHẦN CHÈN ẢNH QR CODE ---
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.surfaceContainerHigh,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), // Bo góc ảnh
                    child: Image.asset(
                      'assets/qrcode_itsvantruongg.github.io.png', // Thay đúng với đường dẫn ảnh của bạn
                      width: 150, // Cố định chiều rộng (tùy chỉnh theo ý thích)
                      height: 150, // Cố định chiều cao
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ]),
            ),
          ])),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;
  const _Section(
      {required this.icon,
      required this.color,
      required this.title,
      required this.items});

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.surfaceContainerHigh),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppTheme.onSurfaceVariant,
                                      height: 1.5))),
                    ]),
              )),
        ]),
      );
}
