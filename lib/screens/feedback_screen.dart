import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class FeedbackScreen extends StatefulWidget {
  static const String googleFormEndpoint =
      'https://docs.google.com/forms/d/e/1FAIpQLSfe_FG1oCxfXZkRt0R766Rj9aWSX2z-w96-lMZsrxA6kAQlew/formResponse';
  static const String entryName = 'entry.1036072439';
  static const String entryEmail = 'entry.336370746';
  static const String entryContent = 'entry.2114228';

  final http.Client? httpClient;

  const FeedbackScreen({super.key, this.httpClient});

  static Uri buildEmailFallbackUri({
    required String name,
    required String email,
    required String content,
  }) {
    final subject = Uri.encodeComponent('Góp ý ứng dụng Schedify HAU - $name');
    final body = Uri.encodeComponent(
      'Họ và tên: $name\n'
      'Email: $email\n\n'
      'Nội dung:\n$content',
    );
    return Uri.parse(
        'mailto:loginchily1@gmail.com?subject=$subject&body=$body');
  }

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    try {
      final student = context.read<AppProvider>().student;
      if (student != null) {
        if (student.hoTen.trim().isNotEmpty && _nameCtrl.text.isEmpty) {
          _nameCtrl.text = student.hoTen.trim();
        }
        if (student.email.trim().isNotEmpty && _emailCtrl.text.isEmpty) {
          _emailCtrl.text = student.email.trim();
        }
      }
    } catch (_) {
      // In standalone tests or environments without AppProvider
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _openEmailFallback() async {
    final uri = FeedbackScreen.buildEmailFallbackUri(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
    );
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
      final uri = Uri.parse(FeedbackScreen.googleFormEndpoint);
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
      };
      final body = {
        FeedbackScreen.entryName: _nameCtrl.text.trim(),
        FeedbackScreen.entryEmail: _emailCtrl.text.trim(),
        FeedbackScreen.entryContent: _contentCtrl.text.trim(),
      };

      final client = widget.httpClient;
      final response = client != null
          ? await client
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 15))
          : await http
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 15));

      if (response.statusCode < 400) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Gửi góp ý thành công! Cảm ơn bạn.'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ));
          _contentCtrl.clear();
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
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
          color: AppTheme.surface.withValues(alpha: 0.7),
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
            const GradientCard(
                child: Row(children: [
              Icon(Icons.rate_review_rounded, color: Colors.white, size: 32),
              SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Ý kiến của bạn rất quan trọng!',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    SizedBox(height: 4),
                    Text(
                        'Góp ý sẽ được gửi trực tiếp đến ban phát triển. Chúng tôi sẽ phản hồi sớm nhất.',
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
                      controller: _emailCtrl,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      hint: 'example@email.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) {
                          return 'Vui lòng nhập email';
                        }
                        if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$')
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
                      minLines: 3,
                      maxLines: 8,
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
  final int? minLines, maxLines, maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.minLines,
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
        minLines: minLines,
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
                BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
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
