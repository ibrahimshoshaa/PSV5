// lib/services/sync_service.dart
//
// طبقة المزامنة الجديدة — مقسّمة حسب نوع البيانات
// ═══════════════════════════════════════════════════
//
// الاستراتيجيات:
//   1. الأجهزة        → SSE (فوري من Firebase) + push عند كل تغيير
//   2. التربيزات      → push عند التغيير + pull كل 3 ثواني
//   3. البيانات الثابتة → push عند التعديل فقط
//   4. السجلات        → push عند الإضافة فقط (append)
//   5. المديونيات     → push عند التغيير

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

typedef DataMap = Map<String, dynamic>;

// ═══════════════════════════════════════════════════════════════════════════════
// SyncCallbacks — الـ callbacks اللي AppState بيوفّرها
// ═══════════════════════════════════════════════════════════════════════════════

class SyncCallbacks {
  /// بيتبعت لما تيجي حالة أجهزة جديدة من Firebase
  final void Function(List<Map<String, dynamic>> devices) onRemoteDevices;

  /// بيتبعت لما تيجي بيانات تشغيلية جديدة (تربيزات)
  final void Function(DataMap data) onRemoteOperational;

  /// بناء بيانات الأجهزة للرفع
  final List<Map<String, dynamic>> Function() buildDevicesState;

  /// بناء بيانات التربيزات
  final List<Map<String, dynamic>> Function() buildTables;
  final List<Map<String, dynamic>> Function() buildDrinkTables;

  /// بناء البيانات الثابتة
  final DataMap Function() buildStaticData;

  /// بناء السجلات اليومية
  final List<Map<String, dynamic>> Function() buildHistory;

  /// بناء الشيفتات
  final Map<String, dynamic> Function() buildOpenShifts;
  final List<Map<String, dynamic>> Function() buildShiftsHistory;

  /// بناء المديونيات
  final List<Map<String, dynamic>> Function() buildDebts;

  /// بناء البطولات
  final List<Map<String, dynamic>> Function() buildTournaments;

  const SyncCallbacks({
    required this.onRemoteDevices,
    required this.onRemoteOperational,
    required this.buildDevicesState,
    required this.buildTables,
    required this.buildDrinkTables,
    required this.buildStaticData,
    required this.buildHistory,
    required this.buildOpenShifts,
    required this.buildShiftsHistory,
    required this.buildDebts,
    required this.buildTournaments,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SyncService الجديد
// ═══════════════════════════════════════════════════════════════════════════════

class SyncService {
  final String shopId;
  final SyncCallbacks callbacks;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _operationalTimer; // polling للتربيزات كل 3 ثواني
  Timer? _debounceTimer;    // debounce للـ push

  // ── SSE subscription للأجهزة ──────────────────────────────────────────────
  StreamSubscription? _devicesSSE;

  // ── حالة ──────────────────────────────────────────────────────────────────
  bool _paused = false;
  bool _disposed = false;

  // ── pending flags — بيتحددوا لما في تغيير محتاج يتبعت ──────────────────
  bool _pendingDevices = false;
  bool _pendingTables = false;
  bool _pendingStatic = false;
  bool _pendingHistory = false;
  bool _pendingDebts = false;
  bool _pendingShifts = false;
  bool _pendingTournaments = false;

  // ── آخر timestamp للأجهزة اللي اتبعت ─────────────────────────────────────
  int _lastDevicesPushTs = 0;

  SyncService({required this.shopId, required this.callbacks});

  // ═══════════════════════════════════════════════════════════════════════════
  // Start / Stop
  // ═══════════════════════════════════════════════════════════════════════════

  void start() {
    _startDevicesSSE();
    _startOperationalPolling();
  }

  void pause() => _paused = true;

  void resume() {
    _paused = false;
    _flushPending();
  }

  void dispose() {
    _disposed = true;
    _devicesSSE?.cancel();
    _operationalTimer?.cancel();
    _debounceTimer?.cancel();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SSE للأجهزة — فوري
  // ═══════════════════════════════════════════════════════════════════════════

  void _startDevicesSSE() {
    _devicesSSE?.cancel();
    _devicesSSE = FirebaseService.listenToDevices(
      shopId,
      onData: (devices) {
        if (_disposed || _paused) return;
        callbacks.onRemoteDevices(devices);
      },
      onError: (_) {
        // لو SSE انقطع، هيحاول يتوصل تاني تلقائياً
      },
      retryDelay: const Duration(seconds: 2),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Polling للتربيزات — كل 3 ثواني
  // ═══════════════════════════════════════════════════════════════════════════

  void _startOperationalPolling() {
    _operationalTimer?.cancel();
    _operationalTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pullOperational(),
    );
  }

  Future<void> _pullOperational() async {
    if (_paused || _disposed) return;
    try {
      final results = await Future.wait([
        FirebaseService.get(FirebaseService.tablesPath(shopId)),
        FirebaseService.get(FirebaseService.drinkTablesPath(shopId)),
      ]);

      final tablesData = results[0];
      final drinkTablesData = results[1];

      final operational = <String, dynamic>{};
      if (tablesData != null) operational['tables'] = tablesData;
      if (drinkTablesData != null)
        operational['drink_tables'] = drinkTablesData;

      if (operational.isNotEmpty) {
        callbacks.onRemoteOperational(operational);
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Push Methods — بيتبعتوا من AppState عند التغيير
  // ═══════════════════════════════════════════════════════════════════════════

  /// حالة الأجهزة — فورية (بدون debounce)
  Future<void> pushDevices() async {
    if (_paused || _disposed) {
      _pendingDevices = true;
      return;
    }
    _pendingDevices = false;
    try {
      final devices = callbacks.buildDevicesState();
      await FirebaseService.pushDevicesState(shopId, devices);
      _lastDevicesPushTs = DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      _pendingDevices = true;
    }
  }

  /// التربيزات — مع debounce 500ms
  void schedulePushTables() {
    _pendingTables = true;
    _scheduleDebounce();
  }

  /// البيانات الثابتة — مع debounce 1 ثانية
  void schedulePushStatic() {
    _pendingStatic = true;
    _scheduleDebounce();
  }

  /// السجلات — فورية
  Future<void> pushHistory() async {
    if (_paused || _disposed) {
      _pendingHistory = true;
      return;
    }
    _pendingHistory = false;
    try {
      final history = callbacks.buildHistory();
      await FirebaseService.pushHistory(shopId, history);
    } catch (_) {
      _pendingHistory = true;
    }
  }

  /// الشيفتات
  void schedulePushShifts() {
    _pendingShifts = true;
    _scheduleDebounce();
  }

  /// المديونيات
  void schedulePushDebts() {
    _pendingDebts = true;
    _scheduleDebounce();
  }

  /// البطولات
  void schedulePushTournaments() {
    _pendingTournaments = true;
    _scheduleDebounce();
  }

  /// Flush كل البيانات المعلقة (بعد resume أو قبل dispose)
  Future<void> _flushPending() async {
    if (_disposed) return;

    if (_pendingDevices) await pushDevices();
    if (_pendingTables) await _pushTables();
    if (_pendingStatic) await _pushStatic();
    if (_pendingHistory) await pushHistory();
    if (_pendingShifts) await _pushShifts();
    if (_pendingDebts) await _pushDebts();
    if (_pendingTournaments) await _pushTournaments();
  }

  Future<void> flushAll() => _flushPending();

  // ─── Debounce ──────────────────────────────────────────────────────────────

  void _scheduleDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 800),
      _flushPending,
    );
  }

  // ─── Internal Push ────────────────────────────────────────────────────────

  Future<void> _pushTables() async {
    if (_paused || _disposed) return;
    _pendingTables = false;
    try {
      await Future.wait([
        FirebaseService.pushTables(shopId, callbacks.buildTables()),
        FirebaseService.pushDrinkTables(
            shopId, callbacks.buildDrinkTables()),
      ]);
    } catch (_) {
      _pendingTables = true;
    }
  }

  Future<void> _pushStatic() async {
    if (_paused || _disposed) return;
    _pendingStatic = false;
    try {
      await FirebaseService.pushStaticData(
          shopId, callbacks.buildStaticData());
    } catch (_) {
      _pendingStatic = true;
    }
  }

  Future<void> _pushShifts() async {
    if (_paused || _disposed) return;
    _pendingShifts = false;
    try {
      await Future.wait([
        FirebaseService.pushOpenShifts(
            shopId, callbacks.buildOpenShifts()),
        FirebaseService.pushShiftsHistory(
            shopId, callbacks.buildShiftsHistory()),
      ]);
    } catch (_) {
      _pendingShifts = true;
    }
  }

  Future<void> _pushDebts() async {
    if (_paused || _disposed) return;
    _pendingDebts = false;
    try {
      await FirebaseService.pushDebts(shopId, callbacks.buildDebts());
    } catch (_) {
      _pendingDebts = true;
    }
  }

  Future<void> _pushTournaments() async {
    if (_paused || _disposed) return;
    _pendingTournaments = false;
    try {
      await FirebaseService.pushTournaments(
          shopId, callbacks.buildTournaments());
    } catch (_) {
      _pendingTournaments = true;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Local Cache
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> saveLocal(
      String shopId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_data_$shopId', jsonEncode(data));
    } catch (_) {}
  }

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
}
