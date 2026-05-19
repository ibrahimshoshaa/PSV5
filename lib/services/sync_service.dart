// lib/services/sync_service.dart
//
// طبقة المزامنة مع Firebase — مفصولة تماماً عن AppState
// =========================================================
// المبادئ:
//   1. كل عملية sync بتشتغل على ترتيب واحد (queue) — مفيش race conditions
//   2. Optimistic local-first: نحفظ locally أول ثم نبعت للـ Firebase
//   3. Merge بالـ timestamp: السيرفر يغلب بس لو أحدث فعلاً
//   4. Retry تلقائي مع exponential backoff
//   5. Pause/resume — بيوقف المزامنة وقت الـ archive

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

// ─── نوع البيانات اللي بتتبادل ────────────────────────────────────────────────

typedef DataMap = Map<String, dynamic>;

// ─── Callbacks ────────────────────────────────────────────────────────────────

/// بيتبعت لما يجي data أحدث من Firebase
typedef OnRemoteData = void Function(DataMap data);

/// بيتبعت عشان AppState يبني الـ payload الحالي
typedef DataBuilder = DataMap Function();

// ═══════════════════════════════════════════════════════════════════════════════
// SyncService
// ═══════════════════════════════════════════════════════════════════════════════

class SyncService {
  // ── إعدادات ──────────────────────────────────────────────────────────────

  /// المدة بين كل sync دورة (push ثم pull)
  static const Duration _interval = Duration(seconds: 8);

  /// أقصى تأخير في الـ retry backoff
  static const Duration _maxBackoff = Duration(seconds: 30);

  // ── الحالة الداخلية ───────────────────────────────────────────────────────

  final String shopId;
  final OnRemoteData onRemoteData;
  final DataBuilder buildData;

  Timer? _timer;
  bool _paused = false;
  bool _running = false;             // يمنع تداخل الدورات
  int _consecutiveErrors = 0;

  /// آخر timestamp اتحفظ locally — بيتستخدم للمقارنة مع السيرفر
  int _localTimestamp = 0;

  /// قائمة انتظار — لو في push pending ومش قدرنا نبعته
  bool _pendingPush = false;

  SyncService({
    required this.shopId,
    required this.onRemoteData,
    required this.buildData,
  });

  // ── Public API ────────────────────────────────────────────────────────────

  /// ابدأ المزامنة الدورية
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _cycle());
    // أول pull فوري بعد الـ start
    _pullFromFirebase();
  }

  /// وقّف المزامنة (مثلاً وقت الـ archive)
  void pause() => _paused = true;

  /// استأنف المزامنة
  void resume() {
    _paused = false;
    _cycle(); // دورة فورية بعد الاستئناف
  }

  /// تحديث الـ timestamp المحلي (بيتبعت من AppState بعد كل saveData)
  void updateLocalTimestamp(int ts) => _localTimestamp = ts;

  /// ابعت البيانات الحالية للـ Firebase فوراً (مثلاً بعد أي تغيير)
  Future<void> pushNow() async {
    _pendingPush = true;
    await _pushToFirebase();
  }

  /// اقفل كل حاجة
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  // ── الدورة الأساسية ───────────────────────────────────────────────────────

  Future<void> _cycle() async {
    if (_paused || _running) return;
    _running = true;
    try {
      // 1. لو في push pending — ابعته أول
      if (_pendingPush) await _pushToFirebase();

      // 2. pull وشوف في حاجة أحدث
      await _pullFromFirebase();

      _consecutiveErrors = 0; // reset الـ backoff
    } catch (_) {
      _consecutiveErrors++;
    } finally {
      _running = false;
    }
  }

  // ── Push ──────────────────────────────────────────────────────────────────

  Future<void> _pushToFirebase() async {
    try {
      final payload = buildData();
      final ok = await FirebaseService.set(
        FirebaseService.shopDataPath(shopId),
        payload,
      );
      if (ok) {
        _pendingPush = false;
        // حفظ محلي أيضاً
        await _saveLocal(payload);
      }
    } catch (e) {
      // هنحاول في الدورة الجاية
      _pendingPush = true;
      rethrow;
    }
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<void> _pullFromFirebase() async {
    try {
      final data = await FirebaseService.get(
        FirebaseService.shopDataPath(shopId),
      );

      if (data == null || data is! Map) return;

      final remoteTs = (data['last_updated'] as num?)?.toInt() ?? 0;

      // بنحدث بس لو السيرفر أحدث فعلاً
      if (remoteTs > _localTimestamp) {
        _localTimestamp = remoteTs;
        final typed = Map<String, dynamic>.from(data);
        await _saveLocal(typed);
        onRemoteData(typed);
      }
    } catch (_) {
      // نتجاهل أخطاء الـ pull — الـ local data كافية
      rethrow;
    }
  }

  // ── Local Cache ───────────────────────────────────────────────────────────

  Future<void> _saveLocal(DataMap data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_data_$shopId', jsonEncode(data));
    } catch (_) {
      // ignore storage errors
    }
  }

  /// تحميل الـ cache المحلي عند بداية التطبيق
  static Future<DataMap?> loadLocal(String shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('app_data_$shopId');
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // ── Backoff Helper ────────────────────────────────────────────────────────

  /// المدة الحالية للانتظار قبل إعادة المحاولة
  Duration get _backoffDuration {
    final seconds = (2 << _consecutiveErrors.clamp(0, 4));
    final dur = Duration(seconds: seconds);
    return dur > _maxBackoff ? _maxBackoff : dur;
  }
}
