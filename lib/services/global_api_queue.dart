import 'dart:async';
import 'dart:io';

/// Mức độ ưu tiên của request trong hàng đợi API
enum RequestPriority {
  critical, // Cao nhất: Thông tin sinh viên, reauth
  high,     // Lịch học, lịch thi của học kỳ hiện tại
  normal,   // Điểm, học phí
  low,      // Lịch học, lịch thi các học kỳ cũ trong quá khứ
}

/// Node đại diện cho 1 task trong hàng đợi
class _QueuedTask<T> {
  final Future<T> Function() task;
  final RequestPriority priority;
  final int sequenceNumber;
  final Completer<T> completer;
  final int retryCount;

  _QueuedTask({
    required this.task,
    required this.priority,
    required this.sequenceNumber,
    required this.completer,
    this.retryCount = 0,
  });
}

/// Global Queue điều phối toàn bộ HTTP Request đến server trường HAU.
/// - Giới hạn tối đa 2 request chạy đồng thời (tránh ASP.NET session state lock / timeout).
/// - Xử lý theo thứ tự ưu tiên (Priority), bảo toàn thứ tự FIFO cho các task cùng mức ưu tiên.
class GlobalApiQueue {
  static final GlobalApiQueue instance = GlobalApiQueue._internal();
  GlobalApiQueue._internal();

  static const int _maxConcurrent = 2;
  int _activeCount = 0;
  int _sequenceCounter = 0;

  final List<_QueuedTask> _queue = [];

  /// Số lượng request đang chờ trong hàng đợi
  int get queueLength => _queue.length;

  /// Số lượng request đang thực thi
  int get activeCount => _activeCount;

  /// Tính timeout động: base 15s + 3s × số task đang chờ, clamp [15s, 45s]
  /// Bug 7 Fix: positionAtStart = _queue.length (lấy TRƯỚC removeAt) — bao gồm cả task hiện tại
  /// Hệ số 3ms/task: 10 task trong queue → timeout 15 + 10×3 = 45s (trùng trần clamp).
  /// .clamp bắt buộc: chần trần 45s tránh timeout tăng vô hạn khi queue dài.
  Duration dynamicTimeout(int queueLengthBeforeRemove) => Duration(
        milliseconds:
            (15000 + queueLengthBeforeRemove * 3000).clamp(15000, 45000),
      );

  /// Thêm 1 request vào hàng đợi và trả về kết quả Future
  Future<T> enqueue<T>(
    Future<T> Function() task, {
    RequestPriority priority = RequestPriority.normal,
  }) {
    final completer = Completer<T>();
    final queuedTask = _QueuedTask<T>(
      task: task,
      priority: priority,
      sequenceNumber: _sequenceCounter++,
      completer: completer,
    );

    _insertSorted(queuedTask);
    _drain();
    return completer.future;
  }

  /// Chèn task vào hàng đợi có thứ tự:
  /// 1. Ưu tiên theo Priority (critical > high > normal > low)
  /// 2. Cùng Priority thì ưu tiên theo FIFO (sequenceNumber bé hơn đứng trước)
  void _insertSorted(_QueuedTask queuedTask) {
    int index = 0;
    while (index < _queue.length) {
      final current = _queue[index];
      if (queuedTask.priority.index < current.priority.index) {
        break;
      } else if (queuedTask.priority.index == current.priority.index) {
        if (queuedTask.sequenceNumber < current.sequenceNumber) {
          break;
        }
      }
      index++;
    }
    _queue.insert(index, queuedTask);
  }

  /// Kích hoạt các task tiếp theo nếu còn slot trống (< 2)
  void _drain() {
    while (_activeCount < _maxConcurrent && _queue.isNotEmpty) {
      // Bug 7 Fix: Lấy _queue.length TRƯỚC removeAt(0) — đây là số task đang chờ kể cả task này.
      // Trần 45s được đảm bảo bởi clamp bên trong dynamicTimeout().
      final queueLengthNow = _queue.length;
      final next = _queue.removeAt(0);
      _activeCount++;
      _runTask(next, queueLengthNow);
    }
  }

  /// Thực thi task với timeout động và retry có backoff cho TimeoutException & SocketException
  Future<void> _runTask(_QueuedTask queuedTask, int positionAtStart) async {
    print('[Queue] start: ${queuedTask.priority}');
    final timeoutDuration = dynamicTimeout(positionAtStart);
    try {
      final result = await queuedTask.task().timeout(timeoutDuration);
      if (!queuedTask.completer.isCompleted) {
        queuedTask.completer.complete(result);
      }
    } on TimeoutException catch (e, st) {
      _handleRetry(queuedTask, e, st);
    } on SocketException catch (e, st) {
      _handleRetry(queuedTask, e, st);
    } catch (e, st) {
      if (!queuedTask.completer.isCompleted) {
        queuedTask.completer.completeError(e, st);
      }
    } finally {
      _activeCount--;
      _drain();
    }
  }

  /// Xử lý retry có backoff qua hàng đợi cho các lỗi transient (TimeoutException, SocketException)
  void _handleRetry(_QueuedTask queuedTask, Object error, StackTrace stackTrace) {
    if (queuedTask.retryCount < 2) {
      final nextRetry = queuedTask.retryCount + 1;
      final delaySec = nextRetry == 1 ? 2 : 4;

      // Trì hoãn theo exponential backoff rồi re-enqueue lại vào hàng đợi để tôn trọng semaphore
      unawaited(Future.delayed(Duration(seconds: delaySec), () {
        if (!queuedTask.completer.isCompleted) {
          final retryTask = _QueuedTask(
            task: queuedTask.task,
            priority: queuedTask.priority,
            sequenceNumber: _sequenceCounter++,
            completer: queuedTask.completer,
            retryCount: nextRetry,
          );
          _insertSorted(retryTask);
          _drain();
        }
      }));
    } else {
      if (!queuedTask.completer.isCompleted) {
        queuedTask.completer.completeError(error, stackTrace);
      }
    }
  }
}
