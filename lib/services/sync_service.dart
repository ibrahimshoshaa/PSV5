// lib/services/sync_service.dart
//
// طبقة المزامنة — مقسّمة حسب نوع البيانات
// ═══════════════════════════════════════════════════
//
// الاستراتيجيات:
//   1. الأجهزة          → SSE (فوري من Firebase) + push عند كل تغيير
//   2. التربيزات        → SSE (فوري من Firebase) + push عند كل تغيير ← تغيّر
//   3. تربيزات مشروبات  → SSE (فوري من Firebase) + push عند كل تغيير ← تغيّر
//   4. البيانات الثابتة → push عند التعديل فقط
//   5. السجلات          → push عند الإضافة فقط (append)
//   6. المديونيات       → push عند التغيير

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

  /// بيتبعت لما تيجي حالة تربيزات جديدة من Firebase (SSE) ← جديد
  final void Function(List<Map<String, dynamic>> tables) onRemoteTables;

  /// بيتبعت لما تيجي حالة تربيزات مشروبات جديدة من Firebase (SSE) ← جديد
  final void Function(List<Map<String, dynamic>> drinkTables) onRemoteDrinkTables;
  final void Function(Map<String, dynamic> data) onRemoteStatic;

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
    required this.onRemoteTables,
    required this.onRemoteDrinkTables,
    required this.buildDevicesState,
    required this.buildTables,
    required this.buildDrinkTables,
    required this.buildStaticData,
    required this.buildHistory,
    required this.buildOpenShifts,
    required this.buildShiftsHistory,
    required this.buildDebts,
    required this.buildTournaments,
    required this.onRemoteStatic,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SyncService
// ═══════════════════════════════════════════════════════════════════════════════

class SyncService {
  final String shopId;
  final SyncCallbacks callbacks;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _debounceTimer;

  // ── SSE subscriptions ─────────────────────────────────────────────────────
  StreamSubscription? _devicesSSE;
  StreamSubscription? _tablesSSE;      // ← جديد
  StreamSubscription? _drinkTablesSSE; // ← 
  جديد
  StreamSubscription? _staticSSE;
  // ── حالة ──────────────────────────────────────────────────────────────────
  bool _paused = false;
  bool _disposed = false;

  // ── pending flags ──────────────────────────────────────────────────────────
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
  _startTablesSSE();
  _startDrinkTablesSSE();
  _startStaticSSE();
}

  void pause() => _paused = true;

  void resume() {
    _paused = false;
    _flushPending();
  }

 void dispose() {
  _disposed = true;
  _devicesSSE?.cancel();
  _tablesSSE?.cancel();
  _drinkTablesSSE?.cancel();
  _staticSSE?.cancel();
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
      onError: (_) {},
      retryDelay: const Duration(seconds: 2),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SSE للتربيزات — فوري (بدل polling كل 3 ثواني) ← جديد
  // ═══════════════════════════════════════════════════════════════════════════

  void _startTablesSSE() {
    _tablesSSE?.cancel();
    _tablesSSE = FirebaseService.listenToTables(
      shopId,
      onData: (tables) {
        if (_disposed || _paused) return;
        callbacks.onRemoteTables(tables);
      },
      onError: (_) {},
      retryDelay: const Duration(seconds: 2),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SSE لتربيزات المشروبات — فوري (بدل polling كل 3 ثواني) ← جديد
  // ═══════════════════════════════════════════════════════════════════════════

  void _startDrinkTablesSSE() {
    _drinkTablesSSE?.cancel();
    _drinkTablesSSE = FirebaseService.listenToDrinkTables(
      shopId,
      onData: (drinkTables) {
        if (_disposed || _paused) return;
        callbacks.onRemoteDrinkTables(drinkTables);
      },
      onError: (_) {},
      retryDelay: const Duration(seconds: 2),
    );
  }

  void _startStaticSSE() {
  _staticSSE?.cancel();
  _staticSSE = FirebaseService.listenToStatic(
    shopId,
    onData: (data) {
      if (_disposed || _paused) return;
      callbacks.onRemoteStatic(data);
    },
    onError: (_) {},
    retryDelay: const Duration(seconds: 2),
  );
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

  /// التربيزات — فورية عبر SSE (مع debounce 500ms للـ push) ← تغيّر
  void schedulePushTables() {
    _pendingTables = true;
    _scheduleDebounce();
  }

  /// البيانات الثابتة — مع debounce
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

  /// بيرفع التربيزات على مسار الـ realtime (SSE) ← تغيّر
  Future<void> _pushTables() async {
    if (_paused || _disposed) return;
    _pendingTables = false;
    try {
      await Future.wait([
        FirebaseService.pushTablesState(shopId, callbacks.buildTables()),
        FirebaseService.pushDrinkTablesState(
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
