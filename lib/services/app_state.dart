import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/device.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import '../services/shift_service.dart'; // ✅ [PATCH 1] import الشيفت سيرفس

class AppState extends ChangeNotifier {
  List<PSDevice> devices = [];
  List<Map<String, dynamic>> history = [];
  Map<String, int> prices = {
    'ps4_normal': 25,
    'ps4_multi': 35,
    'ps5_normal': 40,
    'ps5_multi': 50,
    'match_ps4_normal': 10,
    'match_ps4_multi': 15,
    'match_ps5_normal': 15,
    'match_ps5_multi': 20,
  };

  bool matchEnabled = true;
  Map<String, int> menu = {};

  List<Map<String, dynamic>> tables = [];
  List<Map<String, dynamic>> drinkTables = [];
  List<Map<String, dynamic>> debts = [];
  List<Map<String, dynamic>> tournaments = [];
  Map<String, int> inventory = {};
  Map<String, int> dailyInventorySummary = {};

  // ✅ [PATCH 2] متغيرات الشيفت
  // كل كاشير ليه شيفته — key = cashierName
  Map<String, ShiftRecord> openShifts = {};
  List<ShiftRecord> shiftsHistory = [];

  String adminPasswordHash = '';

  // ✅ قائمة الكاشيرين — كل عنصر: { 'name': String, 'hash': String }
  List<Map<String, dynamic>> cashiers = [];

  // الكاشير الحالي المسجّل دخوله
  String? currentCashierName;

  int numDevices = 0;
  bool isAdmin = false;
  bool isCashier = false;
  String shopName = 'ElHarifa PlayStation';
  Timer? _clockTimer;
  Timer? _syncTimer;
  bool _archiving = false;
  int _localTimestamp = 0;
  bool _isSyncing = false;

  String? shopId;
  bool isActivated = false;
  bool subscriptionActive = false;
  DateTime? subscriptionExpiry;

  final Set<int> _alertedDevices = {};

  // ✅ [COUNTDOWN] Set لتتبع الأجهزة اللي اتعمتلها إشعار انتهاء العد التنازلي
  final Set<int> _countdownAlertedDevices = {};

  bool get isLoggedIn => isAdmin || isCashier;

  String? get userRole {
    if (isAdmin) return 'admin';
    if (isCashier) return 'cashier';
    return null;
  }

  // ✅ [PATCH 5] getters مساعدة
  bool get hasOpenShift =>
      currentCashierName != null && openShifts.containsKey(currentCashierName);

  ShiftRecord? get currentShift =>
      currentCashierName != null ? openShifts[currentCashierName] : null;

  static String hashPassword(String p) =>
      sha256.convert(utf8.encode(p)).toString();

  static const String _defaultAdminHash =
      '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92';

  // ✅ كاشير افتراضي واحد للتوافق مع النظام القديم
  static const String _defaultCashierHash =
      'ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f';

  // للتوافق مع الكود القديم اللي بيستخدم cashierPasswordHash
  String get cashierPasswordHash =>
      cashiers.isNotEmpty ? cashiers.first['hash'] as String : _defaultCashierHash;

  Function(String deviceName, int minutes)? onTimerAlert;

  // ✅ [COUNTDOWN] callback بيتبعت للـ dialog لما العد التنازلي ينتهي
  Function(PSDevice device)? onCountdownFinished;

  AppState() {
    adminPasswordHash = _defaultAdminHash;
    cashiers = [
      {'name': 'كاشير 1', 'hash': _defaultCashierHash}
    ];
    isCashier = false;
    _loadShopId();
    _startClock();
  }

  int matchPriceFor(PSDevice d) {
    final key = 'match_${d.deviceType}_${d.mode}';
    return prices[key] ?? prices['match_ps4_normal'] ?? 10;
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (var d in devices) {
        if (d.isActive) {
          d.updateTimer();
          _checkTimerAlert(d);
          _checkCountdownAlert(d); // ✅ [COUNTDOWN] فحص العد التنازلي
        }
      }
      notifyListeners();
    });
  }

  void _checkTimerAlert(PSDevice d) {
    if (d.timerAlertMinutes == null) return;
    final alertSeconds = d.timerAlertMinutes! * 60;
    final elapsed = d.elapsedSeconds;
    if (elapsed >= alertSeconds && !_alertedDevices.contains(d.id)) {
      _alertedDevices.add(d.id);
      NotificationService.showTimerAlert(d.displayName, d.timerAlertMinutes!);
      onTimerAlert?.call(d.displayName, d.timerAlertMinutes!);
    }
  }

  // ✅ [COUNTDOWN] بيتحقق لو العد التنازلي خلص ويبعت إشعار ويشغّل الـ callback
  void _checkCountdownAlert(PSDevice d) {
    if (!d.isCountdown || d.countdownTotalSeconds == null) return;
    if (d.countdownAlertSent) return;
    if (!d.countdownFinished) return;

    // ضع العلامة على الـ device نفسه عشان منبعتش مرتين
    d.countdownAlertSent = true;
    _countdownAlertedDevices.add(d.id);

    // إشعار محلي
    NotificationService.showTimerAlert(
      d.displayName,
      d.countdownTotalSeconds! ~/ 60,
    );

    // callback للـ dialog / الـ UI
    onCountdownFinished?.call(d);

    saveData();
  }

 void _startSyncTimer() {
  _syncTimer?.cancel();
  _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
    if (!_archiving && shopId != null) {
      await _syncToFirebase(); // ✅ push أولاً
      await _syncFromFirebase(); // ✅ pull تاني
    }
  });
}
  // ══════════════════════════════════════════════════════════════════════════
  // ACTIVATION SYSTEM
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadShopId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('shop_id');

    if (savedId == null) {
      notifyListeners();
      return;
    }

    shopId = savedId;

    final localData = prefs.getString('app_data_$savedId');
    if (localData != null) {
      _applyData(jsonDecode(localData));
    }

    final cachedExpiry = prefs.getString('sub_expires_$savedId');
    if (cachedExpiry != null) {
      final expiry = DateTime.tryParse(cachedExpiry);
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        isActivated = true;
        subscriptionActive = true;
        subscriptionExpiry = expiry;
        notifyListeners();
        _startSyncTimer();
        _syncFromFirebase();
        _checkSubscriptionOnline();
        return;
      }
    }

    isActivated = false;
    subscriptionActive = false;
    notifyListeners();
    await _checkSubscriptionOnline();
  }

  Future<void> _checkSubscriptionOnline() async {
    if (shopId == null) return;
    try {
      final sub = await FirebaseService.getSubscription(shopId!);
      if (sub == null) {
        isActivated = false;
        subscriptionActive = false;
        notifyListeners();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final active = sub['active'] as bool? ?? false;
      final expiresStr = sub['expires'] as String?;

      if (!active) {
        isActivated = false;
        subscriptionActive = false;
        subscriptionExpiry =
            expiresStr != null ? DateTime.tryParse(expiresStr) : null;
        notifyListeners();
        return;
      }

      if (expiresStr != null) {
        final firebaseExpiry = DateTime.tryParse(expiresStr);
        if (firebaseExpiry != null) {
          await prefs.setString('sub_expires_$shopId', expiresStr);
          subscriptionExpiry = firebaseExpiry;

          if (DateTime.now().isAfter(firebaseExpiry)) {
            isActivated = false;
            subscriptionActive = false;
            notifyListeners();
            return;
          }
        }
      }

      isActivated = true;
      subscriptionActive = true;

      if (!isActivated) {
        await loadData();
      } else {
        _startSyncTimer();
        _syncFromFirebase();
      }

      notifyListeners();
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final cachedExpiry = prefs.getString('sub_expires_$shopId');
      if (cachedExpiry != null) {
        final expiry = DateTime.tryParse(cachedExpiry);
        if (expiry != null && DateTime.now().isBefore(expiry)) {
          isActivated = true;
          subscriptionActive = true;
          subscriptionExpiry = expiry;
          notifyListeners();
          _startSyncTimer();
        }
      }
    }
  }

  Future<String?> activateShop(String code) async {
    final id = code.trim().toUpperCase();
    if (id.isEmpty) return '⚠️ اكتب كود التفعيل';
    try {
      final sub = await FirebaseService.getSubscription(id);
      if (sub == null) return '❌ كود غلط، تأكد من الكود وحاول تاني';
      final active = sub['active'] as bool? ?? false;
      if (!active) return '❌ هذا المحل موقوف، تواصل مع المطور';
      final expiresStr = sub['expires'] as String?;
      if (expiresStr != null) {
        final expiry = DateTime.tryParse(expiresStr);
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          final d = '${expiry.day}/${expiry.month}/${expiry.year}';
          return '❌ انتهى الاشتراك في $d، تواصل مع المطور للتجديد';
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sub_expires_$id', expiresStr);
        subscriptionExpiry = expiry;
      }
      shopId = id;
      subscriptionActive = true;
      isActivated = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_id', id);
      final shopNameFromFb = sub['shop_name'] as String?;
      if (shopNameFromFb != null && shopNameFromFb.isNotEmpty) {
        shopName = shopNameFromFb;
      }
      await loadData();
      notifyListeners();
      return null;
    } catch (e) {
      return '❌ تعذر الاتصال بالسيرفر، تأكد من الإنترنت وحاول تاني';
    }
  }

  Future<void> loadData() async {
    if (shopId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString('app_data_$shopId');
    if (local != null) {
      final decoded = jsonDecode(local);
      _applyData(decoded);
      _localTimestamp = decoded['last_updated'] ?? 0;
      notifyListeners();
    }
    await _syncFromFirebase();
    _startSyncTimer();
  }

  void _applyData(Map<String, dynamic> data) {
    history = List<Map<String, dynamic>>.from(data['history'] ?? []);
    if (data['prices'] != null) {
      final raw = Map<String, dynamic>.from(data['prices']);
      if (raw.containsKey('match_price') &&
          !raw.containsKey('match_ps4_normal')) {
        final old = (raw['match_price'] as num).toInt();
        raw['match_ps4_normal'] = old;
        raw['match_ps4_multi'] = (old * 1.5).round();
        raw['match_ps5_normal'] = (old * 1.5).round();
        raw['match_ps5_multi'] = (old * 2).round();
        raw.remove('match_price');
      }
      if (raw.containsKey('normal') && !raw.containsKey('ps4_normal')) {
        prices = {
          'ps4_normal': raw['normal'] ?? 25,
          'ps4_multi': raw['multi'] ?? 35,
          'ps5_normal': 40,
          'ps5_multi': 50,
          'match_ps4_normal': raw['match_ps4_normal'] ?? 10,
          'match_ps4_multi': raw['match_ps4_multi'] ?? 15,
          'match_ps5_normal': raw['match_ps5_normal'] ?? 15,
          'match_ps5_multi': raw['match_ps5_multi'] ?? 20,
        };
      } else {
        prices = raw.map((k, v) => MapEntry(k, (v as num).toInt()));
        prices.putIfAbsent('match_ps4_normal', () => 10);
        prices.putIfAbsent('match_ps4_multi', () => 15);
        prices.putIfAbsent('match_ps5_normal', () => 15);
        prices.putIfAbsent('match_ps5_multi', () => 20);
      }
    }
    menu = Map<String, int>.from(data['menu'] ?? {});
    inventory = Map<String, int>.from(data['inventory'] ?? {});
    dailyInventorySummary =
        Map<String, int>.from(data['daily_inventory_summary'] ?? {});
    debts = List<Map<String, dynamic>>.from(
        (data['debts'] as List? ?? [])
            .map((d) => Map<String, dynamic>.from(d)));

    if (data['tables'] != null) {
      tables = List<Map<String, dynamic>>.from(
          (data['tables'] as List)
              .map((t) => Map<String, dynamic>.from(t)));
    }
    if (data['drink_tables'] != null) {
      drinkTables = List<Map<String, dynamic>>.from(
          (data['drink_tables'] as List)
              .map((t) => Map<String, dynamic>.from(t)));
    }
    numDevices = data['num_devices'] ?? 0;
    adminPasswordHash = data['admin_password_hash'] ?? adminPasswordHash;

    // ✅ تحميل قائمة الكاشيرين مع التوافق مع النظام القديم
    if (data['cashiers'] != null) {
      cashiers = List<Map<String, dynamic>>.from(
          (data['cashiers'] as List)
              .map((c) => Map<String, dynamic>.from(c)));
    } else if (data['cashier_password_hash'] != null) {
      // migration من كاشير واحد
      cashiers = [
        {
          'name': 'كاشير 1',
          'hash': data['cashier_password_hash'] as String
        }
      ];
    }
    if (cashiers.isEmpty) {
      cashiers = [
        {'name': 'كاشير 1', 'hash': _defaultCashierHash}
      ];
    }

    shopName = data['shop_name'] ?? shopName;
    matchEnabled = data['match_enabled'] ?? true;
    if (data['tournaments'] != null) {
      tournaments = List<Map<String, dynamic>>.from(
          (data['tournaments'] as List)
              .map((t) => Map<String, dynamic>.from(t)));
    }

    // ✅ [PATCH 3] تحميل بيانات الشيفتات
    if (data['shifts_history'] != null) {
      shiftsHistory = List<ShiftRecord>.from(
        (data['shifts_history'] as List).map(
          (s) => ShiftRecord.fromJson(Map<String, dynamic>.from(s)),
        ),
      );
    }
    if (data['open_shifts'] != null) {
      final raw = Map<String, dynamic>.from(data['open_shifts']);
      openShifts = raw.map((k, v) =>
          MapEntry(k, ShiftRecord.fromJson(Map<String, dynamic>.from(v))));
    }

    final devStates = data['devices_state'] as List? ?? [];
    devices = [];
    for (int i = 0; i < devStates.length; i++) {
      devices.add(
          PSDevice.fromJson(Map<String, dynamic>.from(devStates[i]), i + 1));
    }
    numDevices = devices.length;
    for (var d in devices) {
      d.updateTimer();
    }
  }

  Map<String, dynamic> _buildDataDict() {
    _localTimestamp = DateTime.now().millisecondsSinceEpoch;
    return {
      'history': history,
      'prices': prices,
      'inventory': inventory,
      'daily_inventory_summary': dailyInventorySummary,
      'menu': menu,
      'tables': tables,
      'drink_tables': drinkTables,
      'debts': debts,
      'num_devices': numDevices,
      'admin_password_hash': adminPasswordHash,
      'cashiers': cashiers,
      // للتوافق مع الكود القديم
      'cashier_password_hash': cashierPasswordHash,
      'shop_name': shopName,
      'match_enabled': matchEnabled,
      'tournaments': tournaments,
      // ✅ [PATCH 4] حفظ بيانات الشيفتات
      'shifts_history': shiftsHistory.map((s) => s.toJson()).toList(),
      'open_shifts': openShifts.map((k, v) => MapEntry(k, v.toJson())),
      'devices_state': devices.map((d) => d.toJson()).toList(),
      'last_updated': _localTimestamp,
    };
  }

  Future<void> saveData() async {
    if (shopId == null) return;
    final data = _buildDataDict();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_data_$shopId', jsonEncode(data));
    await _syncToFirebase(data: data);
  }

  Future<void> _syncToFirebase({Map<String, dynamic>? data}) async {
    if (shopId == null) return;
    final payload = data ?? _buildDataDict();
    await FirebaseService.set(FirebaseService.shopDataPath(shopId!), payload);
  }

  Future<void> _syncFromFirebase() async {
    if (_archiving || shopId == null || _isSyncing) return;
    _isSyncing = true;
    try {
      final data =
          await FirebaseService.get(FirebaseService.shopDataPath(shopId!));
      if (data == null) return;
      final remoteTimestamp = data['last_updated'] ?? 0;
      if (remoteTimestamp > _localTimestamp) {
        _localTimestamp = remoteTimestamp;
        _applyData(Map<String, dynamic>.from(data));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'app_data_$shopId', jsonEncode(data));
        notifyListeners();
      }
    } catch (e) {
      // ignore
    } finally {
      _isSyncing = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ CASHIER MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// إضافة كاشير جديد
  void addCashier(String name, String password) {
    cashiers.add({
      'name': name.trim(),
      'hash': hashPassword(password),
    });
    saveData();
    notifyListeners();
  }

  /// حذف كاشير بالـ index
  void removeCashier(int index) {
    if (cashiers.length <= 1) return; // لازم يفضل كاشير واحد على الأقل
    cashiers.removeAt(index);
    saveData();
    notifyListeners();
  }

  /// تعديل اسم كاشير
  void updateCashierName(int index, String name) {
    cashiers[index]['name'] = name.trim();
    saveData();
    notifyListeners();
  }

  /// تغيير باسورد كاشير
  void updateCashierPassword(int index, String newPassword) {
    cashiers[index]['hash'] = hashPassword(newPassword);
    saveData();
    notifyListeners();
  }

  // ─── Session Logging Helper ────────────────────────────────────────────────

  void _logEvent(PSDevice d, String type,
      {String? note, int? minutes}) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final role = isAdmin
        ? 'أدمن'
        : (currentCashierName ?? 'كاشير');
    d.sessionLog.add({
      'type': type,
      'time': timeStr,
      'timestamp': now.millisecondsSinceEpoch,
      'role': role,
      if (note != null) 'note': note,
      if (minutes != null) 'minutes': minutes,
    });
  }

  // ─── Device Actions ────────────────────────────────────────────────────────

  // ✅ [COUNTDOWN] startDevice معدّل — بيقبل countdownSeconds اختياري
  void startDevice(PSDevice d, String mode, {int? countdownSeconds}) {
    d.mode = mode;
    d.status = 'شغال';
    d.startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    d.addedSeconds = 0;
    d.isPaused = false;
    d.orders = {};
    d.sessionLog = [];

    // ✅ إعداد العد التنازلي لو اتبعتلنا وقت
    if (countdownSeconds != null && countdownSeconds > 0) {
      d.isCountdown = true;
      d.countdownTotalSeconds = countdownSeconds;
      d.countdownAlertSent = false;
      _countdownAlertedDevices.remove(d.id);
      _logEvent(d, 'start',
          note: 'بدأ اللعب (عد تنازلي: ${countdownSeconds ~/ 60} دقيقة)');
    } else {
      d.isCountdown = false;
      d.countdownTotalSeconds = null;
      d.countdownAlertSent = false;
      _countdownAlertedDevices.remove(d.id);
      _logEvent(d, 'start', note: 'بدأ اللعب');
    }

    _alertedDevices.remove(d.id);
    saveData();
    notifyListeners();
  }

  void togglePause(PSDevice d) {
    if (d.isPaused) {
      final pausedDuration =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
              d.pauseStartTime!;
      d.startTime = d.startTime! + pausedDuration;
      d.isPaused = false;
      d.pauseStartTime = null;
      _logEvent(d, 'resume', note: 'استأنف اللعب');
    } else {
      d.isPaused = true;
      d.pauseStartTime =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _logEvent(d, 'pause', note: 'إيقاف مؤقت');
    }
    saveData();
    notifyListeners();
  }

  void addMatchRecord(PSDevice d) {
    final matchPrice = matchPriceFor(d);
    final record = {
      'id': d.id,
      'name': d.displayName,
      'device_type': d.deviceType,
      'duration': '1 ماتش',
      'elapsed_seconds': 0,
      'play_mode': d.mode,
      'time_cost': matchPrice.toDouble(),
      'buffet_cost': 0.0,
      'total': matchPrice.toDouble(),
      'orders': <String, int>{},
      'date': DateTime.now().toString(),
      'is_match': true,
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    };
    history.add(record);
    saveData();
    notifyListeners();
  }

  void addTableGameRecord(int tableIndex) {
    final t = tables[tableIndex];
    final gamePrice = (t['game_price'] as num?)?.toInt() ?? 0;
    if (gamePrice <= 0) return;
    final record = {
      'id': tableIndex,
      'name': t['name'],
      'device_type': 'table',
      'duration': '1 جيم',
      'elapsed_seconds': 0,
      'play_mode': 'game',
      'time_cost': gamePrice.toDouble(),
      'buffet_cost': 0.0,
      'total': gamePrice.toDouble(),
      'orders': <String, int>{},
      'date': DateTime.now().toString(),
      'is_game': true,
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    };
    history.add(record);
    saveData();
    notifyListeners();
  }

  void setMatchEnabled(bool val) {
    matchEnabled = val;
    saveData();
    notifyListeners();
  }

  void addTime(PSDevice d, int minutes) {
    if (d.startTime != null) {
      d.startTime = d.startTime! - minutes * 60;
    }
    final role = isAdmin ? 'أدمن' : (currentCashierName ?? 'كاشير');
    final action = minutes > 0
        ? 'أضاف $minutes دقيقة ($role)'
        : 'خصم ${minutes.abs()} دقيقة ($role)';
    _logEvent(d, 'add_time', note: action, minutes: minutes);
    saveData();
    notifyListeners();
  }

  void setDeviceTimer(PSDevice d, int? minutes) {
    d.timerAlertMinutes = minutes;
    if (minutes == null) _alertedDevices.remove(d.id);
    saveData();
    notifyListeners();
  }

  void cancelDevice(PSDevice d) {
    d.status = 'متاح';
    d.startTime = null;
    d.addedSeconds = 0;
    d.isPaused = false;
    d.pauseStartTime = null;
    d.orders = {};
    d.timerText = '00:00:00';
    d.timerAlertMinutes = null;
    // ✅ [COUNTDOWN] reset حقول العد التنازلي
    d.isCountdown = false;
    d.countdownTotalSeconds = null;
    d.countdownAlertSent = false;
    d.sessionLog = [];
    _alertedDevices.remove(d.id);
    _countdownAlertedDevices.remove(d.id);
    saveData();
    notifyListeners();
  }

  Map<String, dynamic> stopDevice(PSDevice d) {
    _logEvent(d, 'stop', note: 'انتهت الجلسة');
   final timePrice = d.isActive ? d.calculateTimePrice(prices) : 0.0;
final buffetPrice = d.getBuffetPrice(menu);
    final elapsed = d.elapsedSeconds;
    final h = elapsed ~/ 3600;
    final m = (elapsed % 3600) ~/ 60;

    final record = {
      'id': d.id,
      'name': d.displayName,
      'device_type': d.deviceType,
      'duration': '${h}س ${m}د',
      'elapsed_seconds': elapsed,
      'play_mode': d.mode,
      'time_cost': timePrice,
      'buffet_cost': buffetPrice,
      'total': timePrice + buffetPrice,
      'orders': Map<String, int>.from(d.orders),
      'date': DateTime.now().toString(),
      'session_log': List<Map<String, dynamic>>.from(d.sessionLog),
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
      // ✅ [COUNTDOWN] حفظ نوع الجلسة في السجل
      if (d.isCountdown) 'was_countdown': true,
      if (d.countdownTotalSeconds != null)
        'countdown_total_seconds': d.countdownTotalSeconds,
    };

    d.orders.forEach((item, qty) {
      _deductFromInventory(item, qty);
    });
    history.add(record);
    d.status = 'متاح';
    d.startTime = null;
    d.addedSeconds = 0;
    d.isPaused = false;
    d.pauseStartTime = null;
    d.orders = {};
    d.timerText = '00:00:00';
    d.timerAlertMinutes = null;
    // ✅ [COUNTDOWN] reset حقول العد التنازلي
    d.isCountdown = false;
    d.countdownTotalSeconds = null;
    d.countdownAlertSent = false;
    d.sessionLog = [];
    _alertedDevices.remove(d.id);
    _countdownAlertedDevices.remove(d.id);
    saveData();
    notifyListeners();
    return record;
  }

  String? addOrder(PSDevice d, String item, int qty) {
    if (qty > 0) {
      final available = inventory[item];
      if (available != null && available <= 0) {
        return 'نفد "$item" من المخزن!';
      }
      final currentInOrder = d.orders[item] ?? 0;
      final totalNeeded = currentInOrder + qty;
      if (available != null && totalNeeded > available) {
        return 'الكمية المتاحة من "$item" هي $available فقط!';
      }
    }
    d.orders[item] = (d.orders[item] ?? 0) + qty;
    if (d.orders[item]! <= 0) d.orders.remove(item);
    saveData();
    notifyListeners();
    return null;
  }

  void transferSession(PSDevice from, PSDevice to) {
    if (!from.isActive || to.isActive) return;
    to.mode = from.mode;
    to.startTime = from.startTime;
    to.addedSeconds = from.addedSeconds;
    to.isPaused = from.isPaused;
    to.pauseStartTime = from.pauseStartTime;
    to.orders = Map<String, int>.from(from.orders);
    to.status = 'شغال';
    to.timerAlertMinutes = from.timerAlertMinutes;
    to.sessionLog =
        List<Map<String, dynamic>>.from(from.sessionLog);
    // ✅ [COUNTDOWN] نقل حالة العد التنازلي مع الجلسة
    to.isCountdown = from.isCountdown;
    to.countdownTotalSeconds = from.countdownTotalSeconds;
    to.countdownAlertSent = from.countdownAlertSent;
    _logEvent(to, 'transfer',
        note: 'تم نقل الجلسة من ${from.displayName}');

    from.status = 'متاح';
    from.startTime = null;
    from.addedSeconds = 0;
    from.isPaused = false;
    from.pauseStartTime = null;
    from.orders = {};
    from.timerText = '00:00:00';
    from.timerAlertMinutes = null;
    from.isCountdown = false;
    from.countdownTotalSeconds = null;
    from.countdownAlertSent = false;
    from.sessionLog = [];
    _alertedDevices.remove(from.id);
    _countdownAlertedDevices.remove(from.id);

    saveData();
    notifyListeners();
  }

  Future<bool> archiveAndClear() async {
    if (history.isEmpty || shopId == null) return false;
    _archiving = true;
    try {
      final totalTime =
          history.fold(0.0, (s, h) => s + (h['time_cost'] ?? 0));
      final totalBuffet =
          history.fold(0.0, (s, h) => s + (h['buffet_cost'] ?? 0));
      final archive = {
        'date': DateTime.now().toString(),
        'total_time': totalTime,
        'total_buffet': totalBuffet,
        'total_overall': totalTime + totalBuffet,
        'records': List<Map<String, dynamic>>.from(history),
      };
      String? result;
      for (int i = 0; i < 3 && result == null; i++) {
        result = await FirebaseService.push(
            FirebaseService.shopArchivePath(shopId!), archive);
        if (result == null)
          await Future.delayed(const Duration(seconds: 1));
      }
      if (result == null) return false;
      history.clear();
      await saveData();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    } finally {
      _archiving = false;
    }
  }

  // ─── Device Management ─────────────────────────────────────────────────────

  void addDevice(String name, String type) {
    final id = devices.length + 1;
    final d = PSDevice(id: id, deviceType: type);
    d.displayName = name;
    devices.add(d);
    numDevices = devices.length;
    saveData();
    notifyListeners();
  }

  void removeDevice(int index) {
    devices.removeAt(index);
    for (int i = 0; i < devices.length; i++) {
      devices[i].id = i + 1;
    }
    numDevices = devices.length;
    saveData();
    notifyListeners();
  }

  void updateNumDevices(int count) {
    numDevices = count;
    if (count > devices.length) {
      for (int i = devices.length + 1; i <= count; i++) {
        devices.add(PSDevice(id: i));
      }
    } else {
      devices = devices.sublist(0, count);
    }
    saveData();
    notifyListeners();
  }

  // ─── Table Actions ─────────────────────────────────────────────────────────

  void addTable(String name, int ratePerHour,
      {String tableType = 'ping', int gamePrice = 0}) {
    tables.add({
      'name': name,
      'rate': ratePerHour,
      'table_type': tableType,
      'game_price': gamePrice,
      'start_time': null,
      'is_paused': false,
      'pause_start_time': null,
      'orders': <String, int>{},
    });
    saveData();
    notifyListeners();
  }

  void removeTable(int index) {
    tables.removeAt(index);
    saveData();
    notifyListeners();
  }

  void updateTableSettings(int index, String name, int rate,
      {String? tableType, int? gamePrice}) {
    tables[index]['name'] = name;
    tables[index]['rate'] = rate;
    if (tableType != null) tables[index]['table_type'] = tableType;
    if (gamePrice != null) tables[index]['game_price'] = gamePrice;
    saveData();
    notifyListeners();
  }

  void startTable(int index) {
    tables[index]['start_time'] =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    tables[index]['is_paused'] = false;
    tables[index]['pause_start_time'] = null;
    tables[index]['orders'] = <String, int>{};
    saveData();
    notifyListeners();
  }

  void toggleTablePause(int index) {
    final t = tables[index];
    if (t['is_paused'] == true) {
      final paused =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
              (t['pause_start_time'] ?? 0);
      t['start_time'] = (t['start_time'] ?? 0) + paused;
      t['is_paused'] = false;
      t['pause_start_time'] = null;
    } else {
      t['is_paused'] = true;
      t['pause_start_time'] =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
    saveData();
    notifyListeners();
  }

  void cancelTable(int index) {
    tables[index]['start_time'] = null;
    tables[index]['is_paused'] = false;
    tables[index]['pause_start_time'] = null;
    tables[index]['orders'] = <String, int>{};
    saveData();
    notifyListeners();
  }

  Map<String, dynamic> stopTable(int index) {
    final t = tables[index];
    final startTime = t['start_time'] as int?;
    if (startTime == null) return {};

    int elapsed;
    if (t['is_paused'] == true && t['pause_start_time'] != null) {
      elapsed = (t['pause_start_time'] as int) - startTime;
    } else {
      elapsed =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) - startTime;
    }

    final rate = (t['rate'] as num).toDouble();
    final timeCost = (elapsed / 3600) * rate;
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    double buffetCost = 0;
    orders.forEach(
        (item, qty) => buffetCost += qty * (menu[item] ?? 0));

    final h = elapsed ~/ 3600;
    final m = (elapsed % 3600) ~/ 60;

    final record = {
      'id': index,
      'name': t['name'],
      'device_type': 'table',
      'duration': '${h}س ${m}د',
      'elapsed_seconds': elapsed,
      'play_mode': 'table',
      'time_cost': timeCost,
      'buffet_cost': buffetCost,
      'total': timeCost + buffetCost,
      'orders': orders,
      'rate': rate,
      'date': DateTime.now().toString(),
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    };

    orders.forEach((item, qty) {
      _deductFromInventory(item, qty);
    });
    history.add(record);
    tables[index]['start_time'] = null;
    tables[index]['is_paused'] = false;
    tables[index]['pause_start_time'] = null;
    tables[index]['orders'] = <String, int>{};
    saveData();
    notifyListeners();
    return record;
  }

  String? addTableOrder(int index, String item, int qty) {
    if (qty > 0) {
      final available = inventory[item];
      if (available != null && available <= 0)
        return 'نفد "$item" من المخزن!';
      final orders =
          Map<String, int>.from(tables[index]['orders'] ?? {});
      final currentInOrder = orders[item] ?? 0;
      final totalNeeded = currentInOrder + qty;
      if (available != null && totalNeeded > available)
        return 'الكمية المتاحة هي $available فقط!';
    }
    final orders =
        Map<String, int>.from(tables[index]['orders'] ?? {});
    orders[item] = (orders[item] ?? 0) + qty;
    if (orders[item]! <= 0) orders.remove(item);
    tables[index]['orders'] = orders;
    saveData();
    notifyListeners();
    return null;
  }

  int tableElapsed(int index) {
    final t = tables[index];
    final startTime = t['start_time'] as int?;
    if (startTime == null) return 0;
    if (t['is_paused'] == true && t['pause_start_time'] != null) {
      return (t['pause_start_time'] as int) - startTime;
    }
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000) - startTime;
  }

  // ─── Drink Tables ──────────────────────────────────────────────────────────

  void addDrinkTable(String name) {
    drinkTables.add({'name': name, 'orders': <String, int>{}});
    saveData();
    notifyListeners();
  }

  void removeDrinkTable(int index) {
    drinkTables.removeAt(index);
    saveData();
    notifyListeners();
  }

  void updateDrinkTableName(int index, String name) {
    drinkTables[index]['name'] = name;
    saveData();
    notifyListeners();
  }

  String? addDrinkTableOrder(int index, String item, int qty) {
    if (qty > 0) {
      final available = inventory[item];
      if (available != null && available <= 0)
        return 'نفد "$item" من المخزن!';
      final orders =
          Map<String, int>.from(drinkTables[index]['orders'] ?? {});
      final currentInOrder = orders[item] ?? 0;
      final totalNeeded = currentInOrder + qty;
      if (available != null && totalNeeded > available)
        return 'الكمية المتاحة هي $available فقط!';
    }
    final orders =
        Map<String, int>.from(drinkTables[index]['orders'] ?? {});
    orders[item] = (orders[item] ?? 0) + qty;
    if (orders[item]! <= 0) orders.remove(item);
    drinkTables[index]['orders'] = orders;
    saveData();
    notifyListeners();
    return null;
  }

  Map<String, dynamic> checkoutDrinkTable(int index) {
    final t = drinkTables[index];
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    double total = 0;
    orders.forEach((item, qty) {
      total += qty * (menu[item] ?? 0);
    });

    final record = {
      'id': index,
      'name': t['name'],
      'device_type': 'drink_table',
      'duration': '-',
      'elapsed_seconds': 0,
      'play_mode': 'drink',
      'time_cost': 0.0,
      'buffet_cost': total,
      'total': total,
      'orders': orders,
      'date': DateTime.now().toString(),
      'cashier': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    };

    orders.forEach((item, qty) {
      _deductFromInventory(item, qty);
    });
    history.add(record);
    drinkTables[index]['orders'] = <String, int>{};
    saveData();
    notifyListeners();
    return record;
  }

  void transferDrinkTableToDevice(int drinkIndex, PSDevice device) {
    final Map<String, int> orders =
        Map<String, int>.from(drinkTables[drinkIndex]['orders'] ?? {});
    if (!device.isActive) {
      device.mode = 'normal';
      device.status = 'شغال';
      device.startTime =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
      device.addedSeconds = 0;
      device.isPaused = false;
      device.sessionLog = [];
      _logEvent(device, 'start',
          note: 'بدأ اللعب (تحويل من طاولة طلبات)');
      _alertedDevices.remove(device.id);
    }
    orders.forEach((item, qty) {
      device.orders[item] = (device.orders[item] ?? 0) + qty;
    });
    drinkTables[drinkIndex]['orders'] = <String, int>{};
    saveData();
    notifyListeners();
  }

  void transferDrinkTableToTable(int drinkIndex, int tableIndex) {
    final Map<String, int> orders =
        Map<String, int>.from(drinkTables[drinkIndex]['orders'] ?? {});
    final t = tables[tableIndex];
    if (t['start_time'] == null) {
      t['start_time'] =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
      t['is_paused'] = false;
      t['pause_start_time'] = null;
    }
    final existing =
        Map<String, int>.from(t['orders'] ?? {});
    orders.forEach((item, qty) {
      existing[item] = (existing[item] ?? 0) + qty;
    });
    tables[tableIndex]['orders'] = existing;
    drinkTables[drinkIndex]['orders'] = <String, int>{};
    saveData();
    notifyListeners();
  }

  // ─── Menu & Auth & Inventory ───────────────────────────────────────────────

  void addMenuItem(String name, int price) {
    menu[name] = price;
    saveData();
    notifyListeners();
  }

  void removeMenuItem(String name) {
    menu.remove(name);
    saveData();
    notifyListeners();
  }

  void updateMenuItem(String oldName, String newName, int price) {
    menu.remove(oldName);
    menu[newName] = price;
    saveData();
    notifyListeners();
  }

  void updateShopName(String name) {
    shopName = name;
    saveData();
    notifyListeners();
  }

  // ✅ login محدّث — بيدعم قائمة كاشيرين
 String? login(
  String password, {
  required String targetRole,
  String? targetCashierName,
}) {
  final hash = hashPassword(password);

  if (targetRole == 'admin') {
    if (hash == adminPasswordHash) {
      isAdmin = true;
      isCashier = false;
      currentCashierName = null;
      notifyListeners();
      return 'admin';
    }
    return null;
  }

  if (targetRole == 'cashier' && targetCashierName != null) {
    for (final c in cashiers) {
      if (c['name'] == targetCashierName && c['hash'] == hash) {
        isCashier = true;
        isAdmin = false;
        currentCashierName = c['name'] as String;
        notifyListeners();
        return 'cashier';
      }
    }
    return null;
  }

  return null;
}
  void logout() {
    isAdmin = false;
    isCashier = false;
    currentCashierName = null;
    notifyListeners();
  }

  void changePassword(String newPass) {
    adminPasswordHash = hashPassword(newPass);
    saveData();
  }

  // للتوافق مع الكود القديم — بيغير باسورد أول كاشير
  void changeCashierPassword(String newPass) {
    if (cashiers.isNotEmpty) {
      cashiers[0]['hash'] = hashPassword(newPass);
      saveData();
    }
  }

  void updatePrices(Map<String, int> newPrices) {
    prices = newPrices;
    saveData();
    notifyListeners();
  }

  void updateDeviceName(PSDevice d, String name) {
    d.displayName = name;
    saveData();
    notifyListeners();
  }

  void updateDeviceType(PSDevice d, String type) {
    d.deviceType = type;
    saveData();
    notifyListeners();
  }

  void _deductFromInventory(String item, int qty) {
    if (inventory.containsKey(item)) {
      inventory[item] =
          (inventory[item]! - qty).clamp(0, 99999);
    }
    dailyInventorySummary[item] =
        (dailyInventorySummary[item] ?? 0) + qty;
  }

  void addInventory(String item, int qty) {
    inventory[item] = (inventory[item] ?? 0) + qty;
    saveData();
    notifyListeners();
  }

  void setInventoryItem(String item, int qty) {
    inventory[item] = qty;
    saveData();
    notifyListeners();
  }

  void resetInventoryItem(String item) {
    inventory[item] = 0;
    saveData();
    notifyListeners();
  }

  // ─── Debts ────────────────────────────────────────────────────────────────

  void addDebt(String name, double amount, String date, {String? note}) {
    debts.add({
      'name': name,
      'amount': amount,
      'date': date,
      'paid': false,
      'note': note,
      'created_at': DateTime.now().toString(),
      'payment_history': <Map<String, dynamic>>[],
      'created_by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    saveData();
    notifyListeners();
  }
  void addToDebt(int index, double amount, {String? note}) {
    final current = (debts[index]['amount'] as num?)?.toDouble() ?? 0;
    debts[index]['amount'] = current + amount;
    debts[index]['paid'] = false; // لو كانت مسددة وأضاف عليها
 
    // سجل الحركة في payment_history
    final history = List<Map<String, dynamic>>.from(
        debts[index]['payment_history'] as List? ?? []);
    history.add({
      'type': 'add',
      'amount': amount,
      'note': note,
      'date': DateTime.now().toString(),
      'by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    debts[index]['payment_history'] = history;
 
    saveData();
    notifyListeners();
  }

  void markDebtPaid(int index) {
    final amount = (debts[index]['amount'] as num?)?.toDouble() ?? 0;
    debts[index]['paid'] = true;
 
    // سجل الحركة
    final history = List<Map<String, dynamic>>.from(
        debts[index]['payment_history'] as List? ?? []);
    history.add({
      'type': 'pay',
      'amount': amount,
      'date': DateTime.now().toString(),
      'by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
      });
    debts[index]['payment_history'] = history;
    debts[index]['amount'] = 0.0;
 
    saveData();
    notifyListeners();
  }
 void partialPayDebt(int index, double amount) {
    final current = (debts[index]['amount'] as num?)?.toDouble() ?? 0;
    final newAmount = (current - amount).clamp(0, double.infinity);
    if (newAmount <= 0) {
      debts[index]['paid'] = true;
      debts[index]['amount'] = 0.0;
    } else {
      debts[index]['amount'] = newAmount;
    }
    debts[index]['last_partial_pay'] = DateTime.now().toString();
 
    // سجل الحركة في payment_history
    final history = List<Map<String, dynamic>>.from(
        debts[index]['payment_history'] as List? ?? []);
    history.add({
      'type': 'pay',
      'amount': amount,
      'date': DateTime.now().toString(),
      'by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    debts[index]['payment_history'] = history;
 
    saveData();
    notifyListeners();
  }
  void deleteDebt(int index) {
    debts.removeAt(index);
    saveData();
    notifyListeners();
  }

  void resetDailySummary() {
    dailyInventorySummary.clear();
    saveData();
    notifyListeners();
  }

  // ─── Tournaments ───────────────────────────────────────────────────────────

  /// إضافة بطولة جديدة — بترجع الـ key (index) بتاعها
  int addTournament(Map<String, dynamic> tournament) {
    tournaments.add(Map<String, dynamic>.from(tournament));
    saveData();
    notifyListeners();
    return tournaments.length - 1;
  }

  /// تحديث بطولة موجودة بالـ index
  void updateTournament(int index, Map<String, dynamic> data) {
    if (index < 0 || index >= tournaments.length) return;
    tournaments[index] = Map<String, dynamic>.from(data);
    saveData();
    notifyListeners();
  }

  /// حذف بطولة بالـ index
  void deleteTournament(int index) {
    if (index < 0 || index >= tournaments.length) return;
    tournaments.removeAt(index);
    saveData();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ [PATCH 5] SHIFT MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  // ─── بداية الشيفت ──────────────────────────────────────────────────────────
  void startShift(String cashierName) {
    openShifts[cashierName] = ShiftRecord(
      cashierName: cashierName,
      startTime: DateTime.now(),
      transactions: [],
    );
    saveData();
    notifyListeners();
  }

  // ─── إنهاء الشيفت ──────────────────────────────────────────────────────────
  Future<ShiftRecord?> endShift() async {
    final cashierName = currentCashierName;
    if (cashierName == null || !openShifts.containsKey(cashierName)) return null;

    final shift = openShifts[cashierName]!;
    final shiftStart = shift.startTime;

    // فلتر الـ history بالجلسات اللي بعد بداية الشيفت وبإسم الكاشير
    final shiftTransactions = history.where((h) {
      final date = DateTime.tryParse(h['date']?.toString() ?? '');
      if (date == null) return false;
      final isAfterStart = date.isAfter(shiftStart) ||
          date.isAtSameMomentAs(shiftStart);
      final byCashier = h['cashier']?.toString() == cashierName;
      return isAfterStart && byCashier;
    }).toList();

    final closedShift = ShiftRecord(
      cashierName: cashierName,
      startTime: shiftStart,
      endTime: DateTime.now(),
      transactions: shiftTransactions,
    );

    shiftsHistory.add(closedShift);
    openShifts.remove(cashierName);
    await saveData();

    // ── sync الشيفتات لـ Firebase ────────────────────────────────────────────
    if (shopId != null) {
      await FirebaseService.set(
        'shops/$shopId/shifts',
        shiftsHistory.map((s) => s.toJson()).toList(),
      );
    }

    notifyListeners();
    return closedShift;
  }

  // ─── مسح كل تقارير الشيفتات ────────────────────────────────────────────────
  void clearShiftsHistory() {
    shiftsHistory.clear();
    saveData();
    notifyListeners();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _syncTimer?.cancel();
    if (shopId != null) _syncToFirebase();
    super.dispose();
  }
}
