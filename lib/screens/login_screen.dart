import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/shared_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mssvCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_login') ?? false;
    if (remember) {
      final mssv = prefs.getString('saved_mssv') ?? '';
      final pw = prefs.getString('saved_pw') ?? '';
      setState(() {
        _mssvCtrl.text = mssv;
        _pwCtrl.text = pw;
        _remember = remember;
      });
    }
  }

  @override
  void dispose() {
    _mssvCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final mssv = _mssvCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (mssv.isEmpty || pw.isEmpty) return;

    setState(() => _loading = true);
    final ok =
        await context.read<AppProvider>().login(mssv, pw, remember: _remember);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!ok) {
      // Sai tk/mk → hiển thị lỗi từ server
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<AppProvider>().authError),
        backgroundColor: AppTheme.error,
      ));
    } else {
      // Đúng → vào app ngay, hiển thị banner sync nền
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lần đầu đăng nhập — đang tải dữ liệu, vui lòng đợi 1-2 phút...',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ]),
        backgroundColor: Color(0xFF1A73E8),
        duration: Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.surface,
        body: Stack(children: [
          // Background blobs
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryFixed.withOpacity(0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryContainer.withOpacity(0.2),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(children: [
                const SizedBox(height: 40),

                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child:
                      const Icon(Icons.school, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),

                Text('Đại học Kiến trúc Hà Nội',
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface,
                      letterSpacing: -0.5,
                    )),
                const SizedBox(height: 8),
                Text('Đăng nhập bằng tài khoản trường cấp',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 48),

                // Form card
                SurfaceCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MSSV
                        Text('MÃ SINH VIÊN',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                    letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _mssvCtrl,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDeco(
                            hint: 'Nhập mã sinh viên',
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Password
                        Text('MẬT KHẨU',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppTheme.onSurfaceVariant,
                                    letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pwCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          decoration: _inputDeco(
                            hint: 'Nhập mật khẩu',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppTheme.outline,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Ghi nhớ đăng nhập ──────────────────
                        GestureDetector(
                          onTap: () => setState(() => _remember = !_remember),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _remember
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _remember
                                      ? AppTheme.primary
                                      : AppTheme.outline,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: _remember
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ghi nhớ đăng nhập',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.onSurface,
                                      )),
                                  Text(
                                      'Tự động đăng nhập lần sau, xem được khi không có mạng',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        color: AppTheme.onSurfaceVariant,
                                      )),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: MaterialButton(
                              onPressed: _loading ? null : _login,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                          Text('Đăng nhập',
                                              style: GoogleFonts.manrope(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              )),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward,
                                              color: Colors.white, size: 20),
                                        ]),
                            ),
                          ),
                        ),
                      ]),
                ),

                const SizedBox(height: 28),

                // Ghi chú
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryFixed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      'Sử dụng tài khoản và mật khẩu do trường HAU cấp '
                      '(giống khi đăng nhập tinchi.hau.edu.vn)',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.primary),
                    )),
                  ]),
                ),

                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 14, color: AppTheme.outline),
                  const SizedBox(width: 6),
                  Text('Trợ Lý Học Tập HAU v1.0.0',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppTheme.outline)),
                ]),
              ]),
            ),
          ),
        ]),
      );

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.outline),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppTheme.primary.withOpacity(0.4), width: 2),
        ),
      );
}
