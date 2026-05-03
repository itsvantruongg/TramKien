import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/hau_api_service.dart';
import '../services/database_service.dart';
import '../services/api/finance_api.dart';
import '../services/db/finance_db.dart';

class FinanceProvider extends ChangeNotifier {
  // ── Constants ────────────────────────────
  static const Duration _ttlHocPhi = Duration(hours: 6);

  // ── State ────────────────────────────────
  List<Map<String, Object?>> _paymentReceipts = [];
  List<Map<String, Object?>> _feeDetails = [];
  List<Map<String, Object?>> _feeSummaries = [];
  bool _hocPhiState = false; // loading

  // ── Getters ─────────────────────────────
  List<Map<String, Object?>> get paymentReceipts => _paymentReceipts;
  List<Map<String, Object?>> get feeDetails => _feeDetails;
  List<Map<String, Object?>> get feeSummaries => _feeSummaries;
  bool get hocPhiLoading => _hocPhiState;

  // Computed getters - đọc từ fee_summary (da_nop, phai_nop, thua_thieu)
  double get tongHocPhiPhaiDong => _feeSummaries.fold(
      0.0, (s, f) => s + ((f['phai_nop'] as num?) ?? 0).toDouble());

  double get tongHocPhiDaDong => _feeSummaries.fold(
      0.0, (s, f) => s + ((f['da_nop'] as num?) ?? 0).toDouble());

  double get tongHocPhiConLai => _feeSummaries.fold(0.0, (s, f) {
        final phai = (f['phai_nop'] as num?)?.toDouble() ?? 0;
        final da = (f['da_nop'] as num?)?.toDouble() ?? 0;
        return s + (phai - da).clamp(0, double.infinity);
      });

  double get progressHocPhi {
    final total = tongHocPhiPhaiDong;
    if (total == 0) return 0;
    return (tongHocPhiDaDong / total).clamp(0, 1);
  }

  // Toàn bộ học phí từ tất cả kỳ
  double get tongHocPhiAllTerms => _paymentReceipts.fold(
      0.0, (s, r) => s + ((r['tong_tien_phieu'] as num?) ?? 0).toDouble());

  String? get tongThieuHocPhi => null;

  List<Map<String, Object?>> get _currentFeeSummaries {
    final now = DateTime.now();
    return _feeSummaries
        .where((f) => _isSameYear((f['namHoc'] as String?), now))
        .toList();
  }

  // ── Methods ─────────────────────────────

  Future<void> syncHocPhi({bool forceRefresh = false}) async {
    _hocPhiState = true;
    notifyListeners();
    try {
      // Check cache (bypass nếu forceRefresh)
      final isCached = !forceRefresh &&
          !(await DatabaseService.isStale('hoc_phi_all', _ttlHocPhi));
      if (isCached) {
        await refreshFromCache();
        return;
      }

      // Fetch và lưu thẳng vào DB (3 bảng: fee_summary, payment_receipts, fee_details)
      await FinanceApi.fetchAndSaveHocPhi();
      await DatabaseService.updateCacheMeta('hoc_phi_all', 'synced');
      await refreshFromCache();
    } finally {
      _hocPhiState = false;
      notifyListeners();
    }
  }

  Future<void> refreshFromCache() async {
    _paymentReceipts = await FinanceDb.getPaymentReceipts();
    _feeDetails = await FinanceDb.getFeeDetails();
    _feeSummaries = await FinanceDb.getAllFeeSummary();
    notifyListeners();
  }

  // Xóa toàn bộ data trong bộ nhớ (gọi khi logout)
  void clearData() {
    _paymentReceipts = [];
    _feeDetails = [];
    _feeSummaries = [];
    notifyListeners();
  }

  bool _isSameYear(String? namHoc, DateTime now) {
    if (namHoc == null) return false;
    try {
      final year = int.parse(namHoc.split('-').first);
      return year == now.year;
    } catch (_) {
      return false;
    }
  }

  // ── Initialization ──────────────────────

  Future<void> init() async {
    await refreshFromCache();
    await syncHocPhi();
  }
}
