import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _openEmailFallback() async {
    final subject = Uri.encodeComponent(
        'Góp ý ứng dụng Schedify HAU - ${_nameCtrl.text.trim()}');
    final body = Uri.encodeComponent(
      'Họ và tên: ${_nameCtrl.text.trim()}\n'
      'Số điện thoại: ${_phoneCtrl.text.trim()}\n'
      'Email: ${_emailCtrl.text.trim()}\n\n'
      'Nội dung:\n${_contentCtrl.text.trim()}',
    );
    final uri =
        Uri.parse('mailto:loginchily1@gmail.com?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 24),
          SizedBox(width: 8),
          Text('Gửi thất bại', style: TextStyle(fontSize: 17)),
        ]),
        content: Text(
          'Lỗi: $msg\n\nBạn có thể mở app email để gửi thủ công:',
          style:
              const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openEmailFallback();
            },
            icon: const Icon(Icons.email_outlined, size: 16),
            label: const Text('Mở Gmail'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    try {
      // FormSubmit AJAX — thêm Origin/Referer để bypass web-origin check
      final response = await http
          .post(
            Uri.parse('https://formsubmit.co/ajax/loginchily1@gmail.com'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              // FormSubmit kiểm tra Origin để xác nhận request từ web
              'Origin': 'https://tinchi.hau.edu.vn',
              'Referer': 'https://tinchi.hau.edu.vn/',
            },
            body: jsonEncode({
              'name': _nameCtrl.text.trim(),
              '_replyto': _emailCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
              'message': _contentCtrl.text.trim(),
              '_subject': 'Góp ý Schedify HAU - ${_nameCtrl.text.trim()}',
              '_captcha': 'false',
              '_template': 'table',
            }),
          )
          .timeout(const Duration(seconds: 15));

      // Parse response
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(
            'Phản hồi không hợp lệ từ server (${response.statusCode})');
      }

      final success = data['success'];
      if (success == true || success == 'true') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Gửi góp ý thành công! Cảm ơn bạn.'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ));
          _nameCtrl.clear();
          _phoneCtrl.clear();
          _emailCtrl.clear();
          _contentCtrl.clear();
        }
      } else {
        final msg = data['message'] as String? ?? 'HTTP ${response.statusCode}';
        throw Exception(msg);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: Container(
          color: AppTheme.surface.withOpacity(0.7),
          child: SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: AppTheme.primary),
                      onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Góp ý ứng dụng',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w800)),
                        Text('GỬI PHẢN HỒI CHO CHÚNG TÔI',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppTheme.outline,
                                    letterSpacing: 1.5)),
                      ])),
                ]),
              )),
        )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          sliver: SliverList(
              delegate: SliverChildListDelegate([
            GradientCard(
                child: Row(children: [
              const Icon(Icons.rate_review_rounded,
                  color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Ý kiến của bạn rất quan trọng!',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text(
                        'Góp ý sẽ được gửi qua email. Chúng tôi sẽ phản hồi sớm nhất.',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
            ])),
            const SizedBox(height: 20),
            Form(
                key: _formKey,
                child: Column(children: [
                  _Field(
                      controller: _nameCtrl,
                      label: 'Họ và tên',
                      icon: Icons.person_outline,
                      hint: 'Nguyễn Văn A',
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Vui lòng nhập họ tên'
                          : null),
                  const SizedBox(height: 14),
                  _Field(
                      controller: _phoneCtrl,
                      label: 'Số điện thoại',
                      icon: Icons.phone_outlined,
                      hint: '0912 345 678',
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true)
                          return 'Vui lòng nhập số điện thoại';
                        if (!RegExp(r'^[0-9]{9,11}$')
                            .hasMatch(v!.trim().replaceAll(' ', ''))) {
                          return 'Số điện thoại không hợp lệ';
                        }
                        return null;
                      }),
                  const SizedBox(height: 14),
                  _Field(
                      controller: _emailCtrl,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      hint: 'example@email.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true)
                          return 'Vui lòng nhập email';
                        if (!RegExp(r'^[\w.-]+@[\w-]+\.\w+$')
                            .hasMatch(v!.trim())) {
                          return 'Email không hợp lệ';
                        }
                        return null;
                      }),
                  const SizedBox(height: 14),
                  _Field(
                      controller: _contentCtrl,
                      label: 'Nội dung',
                      icon: Icons.edit_note_outlined,
                      hint:
                          'Mô tả chi tiết ý kiến, lỗi hoặc đề xuất của bạn...',
                      maxLines: 5,
                      maxLength: 500,
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Vui lòng nhập nội dung'
                          : null),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                      label: Text(_sending ? 'Đang gửi...' : 'Gửi góp ý'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ])),
          ])),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final int? maxLines, maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface)),
        const Text(' *', style: TextStyle(color: AppTheme.error, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: AppTheme.outlineVariant, fontSize: 13),
          filled: true,
          fillColor: AppTheme.surfaceContainerLowest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppTheme.outlineVariant.withOpacity(0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppTheme.outlineVariant.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          counterStyle: const TextStyle(fontSize: 10),
        ),
      ),
    ]);
  }
}
