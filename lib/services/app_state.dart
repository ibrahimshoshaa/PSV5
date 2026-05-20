import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/device.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import '../services/shift_service.dart';
import 'sync_service.dart';

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

  Map<String, ShiftRecord> openShifts = {};
  List<ShiftRecord> shiftsHistory = [];

  String adminPasswordHash = '';
  List<Map<String, dynamic>> cashiers = [];
  String? currentCashierName;

  int numDevices = 0;
  bool isAdmin = false;
  bool isCashier = false;
  String shopName = 'ElHarifa PlayStation';

  Timer? _clockTimer;
  SyncService? _sync;
  Timer? _historyPollTimer; // ✅ polling للسجلات كل 5 ثواني
  bool archiving = false;

  String? shopId;
  bool isActivated = false;
  bool subscriptionActive = false;
  DateTime? subscriptionExpiry;

  final Set<int> _alertedDevices = {};
  final Set<int> _countdownAlertedDevices = {};
  // ✅ حماية من double-checkout
  final Set<int> _stoppingDevices = {};
  // ✅ أجهزة بتتقفل دلوقتي — بنتجاهل أي SSE جاي عليها لحد ما الـ push يوصل
  final Set<int> _lockingDevices = {};

  bool get isLoggedIn => isAdmin || isCashier;

  String? get userRole {
    if (isAdmin) return 'admin';
    if (isCashier) return 'cashier';
    return null;
  }

  bool get hasOpenShift =>
    currentCashierName != null &&
    openShifts.containsKey(currentCashierName) &&
    openShifts[currentCashierName] != null;

  ShiftRecord? get currentShift =>
      currentCashierName != null ? openShifts[currentCashierName] : null;

  static String hashPassword(String p) =>
      sha256.convert(utf8.encode(p)).toString();

  static const String _defaultAdminHash =
      '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92';

  static const String _defaultCashierHash =
      'ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f';

  String get cashierPasswordHash =>
      cashiers.isNotEmpty
          ? cashiers.first['hash'] as String
          : _defaultCashierHash;

  Function(String deviceName, int minutes)? onTimerAlert;
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

  // ══════════════════════════════════════════════════════════════════════════
  // CLOCK
  // ══════════════════════════════════════════════════════════════════════════

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (var d in devices) {
        if (d.isActive) {
          d.updateTimer();
          _checkTimerAlert(d);
          _checkCountdownAlert(d);
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

  void _checkCountdownAlert(PSDevice d) {
    if (!d.isCountdown || d.countdownTotalSeconds == null) return;
    if (d.countdownAlertSent) return;
    if (!d.countdownFinished) return;

    d.countdownAlertSent = true;
    _countdownAlertedDevices.add(d.id);

    NotificationService.showTimerAlert(
      d.displayName,
      d.countdownTotalSeconds! ~/ 60,
    );

    onCountdownFinished?.call(d);
    saveData();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SYNC
  // ══════════════════════════════════════════════════════════════════════════

  void _startSync() {
    _sync?.dispose();
    _sync = SyncService(
      shopId: shopId!,
      callbacks: SyncCallbacks(
        onRemoteDevices: (remoteDevices) {
          _mergeRemoteDevices(remoteDevices);
          notifyListeners();
        },
        onRemoteTables: (remoteTables) {
          _mergeRemoteTables(remoteTables);
          notifyListeners();
        },
        onRemoteDrinkTables: (remoteDrinkTables) {
          _mergeRemoteDrinkTables(remoteDrinkTables);
          notifyListeners();
        },
        onRemoteStatic: (data) {
  _applyStaticData(data);
  notifyListeners();
},
        buildDevicesState: () => devices.map((d) => d.toJson()).toList(),
        buildTables: () => tables,
        buildDrinkTables: () => drinkTables,
        buildStaticData: _buildStaticData,
        buildHistory: () => history,
        buildOpenShifts: () =>
            openShifts.map((k, v) => MapEntry(k, v.toJson())),
        buildShiftsHistory: () =>
            shiftsHistory.map((s) => s.toJson()).toList(),
        buildDebts: () => debts,
        buildTournaments: () => tournaments,
      ),
    );
    _sync!.start();

    // ✅ polling شامل — fallback لكل البيانات
    // السجلات كل 5 ثواني — الباقي كل 10 ثواني
    _historyPollTimer?.cancel();
    _historyPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollAll();
    });
  }

  Future<void> _pollAll() async {
    if (shopId == null || archiving) return;
    try {
      // نجيب كل البيانات بالتوازي
      final results = await Future.wait([
        FirebaseService.get(FirebaseService.historyPath(shopId!)),
        FirebaseService.get(FirebaseService.staticDataPath(shopId!)),
        FirebaseService.get(FirebaseService.debtsPath(shopId!)),
        FirebaseService.get(FirebaseService.shopTournamentsPath(shopId!)),
        FirebaseService.get(FirebaseService.shiftsHistoryPath(shopId!)),
        FirebaseService.get(FirebaseService.openShiftsPath(shopId!)),
        FirebaseService.get(FirebaseService.dailySummaryPath(shopId!)),
      ]);

      bool changed = false;

      // ── السجلات ───────────────────────────────────────────────────────
      final remoteHistory = results[0];
      if (remoteHistory != null && remoteHistory is List) {
        final typed = List<Map<String, dynamic>>.from(
            remoteHistory.map((h) => Map<String, dynamic>.from(h)));
        if (typed.length != history.length) {
          history = typed;
          changed = true;
        }
      }

      // ── البيانات الثابتة (أسعار / منيو / إعدادات) ────────────────────
      final remoteStatic = results[1];
      if (remoteStatic != null && remoteStatic is Map) {
        final s = Map<String, dynamic>.from(remoteStatic);
        _applyStaticData(s);
        changed = true;
      }

      // ── المديونيات ────────────────────────────────────────────────────
      final remoteDebts = results[2];
      if (remoteDebts != null && remoteDebts is List) {
        final typed = List<Map<String, dynamic>>.from(
            remoteDebts.map((d) => Map<String, dynamic>.from(d)));
        if (typed.length != debts.length) {
          debts = typed;
          changed = true;
        }
      }

      // ── البطولات ──────────────────────────────────────────────────────
      final remoteTournaments = results[3];
      if (remoteTournaments != null && remoteTournaments is List) {
        final typed = List<Map<String, dynamic>>.from(
            remoteTournaments.map((t) => Map<String, dynamic>.from(t)));
        if (typed.length != tournaments.length) {
          tournaments = typed;
          changed = true;
        }
      }

      // ── تاريخ الشيفتات ────────────────────────────────────────────────
      final remoteShiftsHistory = results[4];
      if (remoteShiftsHistory != null && remoteShiftsHistory is List) {
        final typed = List<ShiftRecord>.from(
          (remoteShiftsHistory).map(
            (s) => ShiftRecord.fromJson(Map<String, dynamic>.from(s)),
          ),
        );
        if (typed.length != shiftsHistory.length) {
          shiftsHistory = typed;
          changed = true;
        }
      }

      // ── الشيفتات المفتوحة ─────────────────────────────────────────────
      final remoteOpenShifts = results[5];
      if (remoteOpenShifts != null && remoteOpenShifts is Map) {
        final raw = Map<String, dynamic>.from(remoteOpenShifts);
        final typed = raw.map((k, v) =>
            MapEntry(k, ShiftRecord.fromJson(Map<String, dynamic>.from(v))));
        // حدّث بس الشيفتات اللي مش مفتوحة محلياً
        typed.forEach((name, shift) {
          if (!openShifts.containsKey(name)) {
            openShifts[name] = shift;
            changed = true;
          }
        });
        // شيل الشيفتات اللي اتقفلت في موبايل تاني
        openShifts.removeWhere((name, _) {
  if (name == currentCashierName) return false;
  if (!typed.containsKey(name)) {
    changed = true;
    return true;
  }
  return false;
});
      }

      // ── ملخص المخزون اليومي ───────────────────────────────────────────
      final remoteSummary = results[6];
      if (remoteSummary != null && remoteSummary is Map) {
        final typed = Map<String, int>.from(
            remoteSummary.map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
        if (typed.length != dailyInventorySummary.length) {
          dailyInventorySummary = typed;
          changed = true;
        }
      }

      if (changed) notifyListeners();
    } catch (_) {}
  }

  void _mergeRemoteHistory(List<Map<String, dynamic>> remoteHistory) {
    if (remoteHistory.isEmpty) return;
    if (remoteHistory.length > history.length) {
      history = remoteHistory;
    }
  }

void _mergeRemoteDevices(List<Map<String, dynamic>> remoteDevices) {
  if (remoteDevices.isEmpty) return;

  final remoteIds = remoteDevices
      .map((j) => (j['id'] as num?)?.toInt() ?? 0)
      .toSet();

  devices.removeWhere((d) => !remoteIds.contains(d.id));

  for (final remoteJson in remoteDevices) {
    final remoteId = (remoteJson['id'] as num?)?.toInt() ?? 0;

    // ✅ لو الجهاز ده بنقفله دلوقتي — تجاهل الـ SSE الجاي عليه
    if (_lockingDevices.contains(remoteId)) continue;

    final idx = devices.indexWhere((d) => d.id == remoteId);
    if (idx != -1) {
      final updated = PSDevice.fromJson(remoteJson, remoteId);
      updated.updateTimer();
      devices[idx] = updated;
    } else {
      final newDevice = PSDevice.fromJson(remoteJson, remoteId);
      newDevice.updateTimer();
      devices.add(newDevice);
    }
  }
}

 void _mergeRemoteTables(List<Map<String, dynamic>> remoteTables) {
  if (remoteTables.isEmpty) return;

  while (tables.length < remoteTables.length) {
    tables.add(remoteTables[tables.length]);
  }

  for (int i = 0; i < remoteTables.length; i++) {
    final localStartTime = tables[i]['start_time'];
    final remoteStartTime = remoteTables[i]['start_time'];

    if (remoteStartTime == null) {
      tables[i] = remoteTables[i];
      continue;
    }
    if (localStartTime == null) {
      tables[i] = remoteTables[i];
      continue;
    }
    if ((remoteStartTime as num) < (localStartTime as num)) {
      tables[i] = remoteTables[i];
    } else {
      tables[i]['is_paused'] = remoteTables[i]['is_paused'];
      tables[i]['pause_start_time'] = remoteTables[i]['pause_start_time'];
      tables[i]['orders'] = remoteTables[i]['orders'];
    }
  }

  if (remoteTables.length < tables.length) {
    tables.removeRange(remoteTables.length, tables.length);
  }
}
  void _mergeRemoteDrinkTables(List<Map<String, dynamic>> remoteDrinkTables) {
    if (remoteDrinkTables.isEmpty) return;

    // ✅ ضيف تربيزات مشروبات جديدة من الريموت
    while (drinkTables.length < remoteDrinkTables.length) {
      drinkTables.add(remoteDrinkTables[drinkTables.length]);
    }

    for (int i = 0; i < remoteDrinkTables.length; i++) {
      // اتبع الريموت دايماً — هو الأحدث من Firebase
      drinkTables[i] = remoteDrinkTables[i];
    }

    // ✅ احذف التربيزات اللي اتحذفت
    if (remoteDrinkTables.length < drinkTables.length) {
      drinkTables.removeRange(remoteDrinkTables.length, drinkTables.length);
    }
  }
  void _applyStaticData(Map<String, dynamic> s) {
  if (s['prices'] != null) {
    _migratePrices(Map<String, dynamic>.from(s['prices']));
  }
  if (s['menu'] != null) {
    menu = Map<String, int>.from(s['menu']);
  }
  if (s['inventory'] != null) {
    inventory = Map<String, int>.from(s['inventory']);
  }
  if (s['cashiers'] != null) {
    cashiers = List<Map<String, dynamic>>.from(
        (s['cashiers'] as List).map((c) => Map<String, dynamic>.from(c)));
  }
  if (s['admin_password_hash'] != null) {
    adminPasswordHash = s['admin_password_hash'];
  }
 if (s['shop_name'] != null) {
  shopName = s['shop_name'];
} else if (s['settings'] != null && (s['settings'] as Map)['shop_name'] != null) {
  shopName = (s['settings'] as Map)['shop_name'];
}
if (s['match_enabled'] != null) {
  matchEnabled = s['match_enabled'];
} else if (s['settings'] != null && (s['settings'] as Map)['match_enabled'] != null) {
  matchEnabled = (s['settings'] as Map)['match_enabled'];
}
  if (s['debts'] != null) {
    debts = List<Map<String, dynamic>>.from(
        (s['debts'] as List).map((d) => Map<String, dynamic>.from(d)));
  }
}

  void _mergeRemoteOperational(Map<String, dynamic> data) {
    if (data.containsKey('tables') && data['tables'] != null) {
      final remoteTables = data['tables'];
      if (remoteTables is List) {
        final updatedTables = remoteTables
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
        for (int i = 0; i < updatedTables.length && i < tables.length; i++) {
          if (tables[i]['start_time'] == null) {
            tables[i] = updatedTables[i];
          }
        }
        if (updatedTables.length > tables.length) {
          tables.addAll(updatedTables.sublist(tables.length));
        }
      }
    }

    if (data.containsKey('drink_tables') && data['drink_tables'] != null) {
      final remoteDrink = data['drink_tables'];
      if (remoteDrink is List) {
        final updatedDrink = remoteDrink
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
        for (int i = 0; i < updatedDrink.length && i < drinkTables.length; i++) {
          final localOrders =
              Map<String, int>.from(drinkTables[i]['orders'] ?? {});
          if (localOrders.isEmpty) {
            drinkTables[i] = updatedDrink[i];
          }
        }
        if (updatedDrink.length > drinkTables.length) {
          drinkTables.addAll(updatedDrink.sublist(drinkTables.length));
        }
      }
    }
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

    final localData = await SyncService.loadLocal(savedId);
    if (localData != null) {
      _applyData(localData);
      notifyListeners();
    }

    final cachedExpiry = prefs.getString('sub_expires_$savedId');
    if (cachedExpiry != null) {
      final expiry = DateTime.tryParse(cachedExpiry);
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        isActivated = true;
        subscriptionActive = true;
        subscriptionExpiry = expiry;
        notifyListeners();
        _startSync();
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
      _startSync();
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
          _startSync();
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

    final local = await SyncService.loadLocal(shopId!);
    if (local != null) {
      _applyData(local);
      notifyListeners();
    }

    try {
      final remoteData = await FirebaseService.pullAllData(shopId!);
      if (remoteData != null) {
        _applyData(remoteData);
        await SyncService.saveLocal(shopId!, remoteData);
        notifyListeners();
      }
    } catch (_) {}

    _startSync();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APPLY DATA
  // ══════════════════════════════════════════════════════════════════════════

  void _applyData(Map<String, dynamic> data) {
    if (data['history'] != null) {
      history = List<Map<String, dynamic>>.from(
          (data['history'] as List)
              .map((h) => Map<String, dynamic>.from(h)));
    }

    final pricesRaw = data['prices'] ?? data['static']?['prices'];
    if (pricesRaw != null) {
      final raw = Map<String, dynamic>.from(pricesRaw);
      _migratePrices(raw);
    }

    final menuRaw = data['menu'] ?? data['static']?['menu'];
    if (menuRaw != null) {
      menu = Map<String, int>.from(menuRaw);
    }

    final inventoryRaw = data['inventory'] ?? data['static']?['inventory'];
    if (inventoryRaw != null) {
      inventory = Map<String, int>.from(inventoryRaw);
    }

    final summaryRaw = data['daily_inventory_summary'] ?? data['daily_summary'];
    if (summaryRaw != null) {
      dailyInventorySummary = Map<String, int>.from(summaryRaw);
    }

    final debtsRaw = data['debts'] ?? data['static']?['debts'];
    if (debtsRaw != null) {
      debts = List<Map<String, dynamic>>.from(
          (debtsRaw as List).map((d) => Map<String, dynamic>.from(d)));
    }

    final tablesRaw = data['tables'] ?? data['operational']?['tables'];
    if (tablesRaw != null) {
      tables = List<Map<String, dynamic>>.from(
          (tablesRaw as List).map((t) => Map<String, dynamic>.from(t)));
    }

    final drinkRaw = data['drink_tables'] ?? data['operational']?['drink_tables'];
    if (drinkRaw != null) {
      drinkTables = List<Map<String, dynamic>>.from(
          (drinkRaw as List).map((t) => Map<String, dynamic>.from(t)));
    }

    final settingsRaw = data['static']?['settings'];
    final adminHash = data['admin_password_hash'] ?? settingsRaw?['admin_password_hash'];
    if (adminHash != null) adminPasswordHash = adminHash;

    final shopNameRaw = data['shop_name'] ?? settingsRaw?['shop_name'];
    if (shopNameRaw != null) shopName = shopNameRaw;

    final matchEnabledRaw = data['match_enabled'] ?? settingsRaw?['match_enabled'];
    if (matchEnabledRaw != null) matchEnabled = matchEnabledRaw;

    final cashiersRaw = data['cashiers'] ?? data['static']?['cashiers'];
    if (cashiersRaw != null) {
      cashiers = List<Map<String, dynamic>>.from(
          (cashiersRaw as List).map((c) => Map<String, dynamic>.from(c)));
    } else if (data['cashier_password_hash'] != null) {
      cashiers = [
        {'name': 'كاشير 1', 'hash': data['cashier_password_hash'] as String}
      ];
    }
    if (cashiers.isEmpty) {
      cashiers = [{'name': 'كاشير 1', 'hash': _defaultCashierHash}];
    }

    final tournamentsRaw = data['tournaments'];
    if (tournamentsRaw != null) {
      tournaments = List<Map<String, dynamic>>.from(
          (tournamentsRaw as List).map((t) => Map<String, dynamic>.from(t)));
    }

    final shiftsHistoryRaw = data['shifts_history'] ?? data['records']?['shifts_history'];
    if (shiftsHistoryRaw != null) {
      shiftsHistory = List<ShiftRecord>.from(
        (shiftsHistoryRaw as List).map(
          (s) => ShiftRecord.fromJson(Map<String, dynamic>.from(s)),
        ),
      );
    }

    final openShiftsRaw = data['open_shifts'] ?? data['records']?['open_shifts'];
    if (openShiftsRaw != null) {
      final raw = Map<String, dynamic>.from(openShiftsRaw);
      openShifts = raw.map((k, v) => MapEntry(
          k, ShiftRecord.fromJson(Map<String, dynamic>.from(v))));
    }

    List? devStates;
    if (data['realtime']?['devices_state']?['devices'] != null) {
      devStates = data['realtime']['devices_state']['devices'] as List;
    } else if (data['devices_state'] != null) {
      devStates = data['devices_state'] as List;
    } else if (data['devices'] != null) {
      devStates = data['devices'] as List;
    }

    if (devStates != null) {
      devices = [];
      for (int i = 0; i < devStates.length; i++) {
        devices.add(PSDevice.fromJson(
            Map<String, dynamic>.from(devStates[i]), i + 1));
      }
      numDevices = devices.length;
      for (var d in devices) {
        d.updateTimer();
      }
    }

    numDevices = data['num_devices'] ?? devices.length;
  }

  void _migratePrices(Map<String, dynamic> raw) {
    if (raw.containsKey('match_price') && !raw.containsKey('match_ps4_normal')) {
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

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD DATA
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _buildDataDict() {
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
      'cashier_password_hash': cashierPasswordHash,
      'shop_name': shopName,
      'match_enabled': matchEnabled,
      'tournaments': tournaments,
      'shifts_history': shiftsHistory.map((s) => s.toJson()).toList(),
      'open_shifts': openShifts.map((k, v) => MapEntry(k, v.toJson())),
      'devices_state': devices.map((d) => d.toJson()).toList(),
      'last_updated': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _buildStaticData() {
    return {
      'prices': prices,
      'menu': menu,
      'inventory': inventory,
      'daily_inventory_summary': dailyInventorySummary,
      'cashiers': cashiers,
      'cashier_password_hash': cashierPasswordHash,
      'admin_password_hash': adminPasswordHash,
       'shop_name': shopName,
        'match_enabled': matchEnabled,
      'settings': {
        'num_devices': numDevices,
      },
      'debts': debts,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVE DATA
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> saveData() async {
    if (shopId == null) return;
    final data = _buildDataDict();
    await SyncService.saveLocal(shopId!, data);
    // ✅ بعت الـ static فوراً (أسعار، منيو، إعدادات) عبر SSE
    await FirebaseService.pushStaticData(shopId!, _buildStaticData());
    _sync?.schedulePushStatic();
  }

  Future<void> _saveDevices() async {
    if (shopId == null) return;
    final data = _buildDataDict();
    await SyncService.saveLocal(shopId!, data);
    await _sync?.pushDevices();
  }

  Future<void> _saveTables() async {
    if (shopId == null) return;
    final data = _buildDataDict();
    await SyncService.saveLocal(shopId!, data);
    // ✅ بعت للـ realtime عشان الـ SSE يشتغل فوراً
    await Future.wait([
      FirebaseService.pushTablesState(shopId!, tables),
      FirebaseService.pushDrinkTablesState(shopId!, drinkTables),
    ]);
    // والـ operational كـ backup
    _sync?.schedulePushTables();
  }

  Future<void> _saveHistory() async {
    if (shopId == null) return;
    final data = _buildDataDict();
    await SyncService.saveLocal(shopId!, data);
    // ✅ بعت السجلات فوراً
    await Future.wait([
      FirebaseService.pushHistory(shopId!, history),
      _sync?.pushHistory() ?? Future.value(),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CASHIER MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  void addCashier(String name, String password) {
    cashiers.add({'name': name.trim(), 'hash': hashPassword(password)});
    saveData();
    notifyListeners();
  }

  void removeCashier(int index) {
    if (cashiers.length <= 1) return;
    cashiers.removeAt(index);
    saveData();
    notifyListeners();
  }

  void updateCashierName(int index, String name) {
    cashiers[index]['name'] = name.trim();
    saveData();
    notifyListeners();
  }

  void updateCashierPassword(int index, String newPassword) {
    cashiers[index]['hash'] = hashPassword(newPassword);
    saveData();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION LOG
  // ══════════════════════════════════════════════════════════════════════════

  void _logEvent(PSDevice d, String type, {String? note, int? minutes}) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final role = isAdmin ? 'أدمن' : (currentCashierName ?? 'كاشير');
    d.sessionLog.add({
      'type': type,
      'time': timeStr,
      'timestamp': now.millisecondsSinceEpoch,
      'role': role,
      if (note != null) 'note': note,
      if (minutes != null) 'minutes': minutes,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEVICE ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  void startDevice(PSDevice d, String mode, {int? countdownSeconds}) {
    d.mode = mode;
    d.status = 'شغال';
    d.startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    d.addedSeconds = 0;
    d.isPaused = false;
    d.orders = {};
    d.sessionLog = [];

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
    _saveDevices();
    notifyListeners();
  }

  void togglePause(PSDevice d) {
    if (d.isPaused) {
      final pausedDuration =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) - d.pauseStartTime!;
      d.startTime = d.startTime! + pausedDuration;
      d.isPaused = false;
      d.pauseStartTime = null;
      _logEvent(d, 'resume', note: 'استأنف اللعب');
    } else {
      d.isPaused = true;
      d.pauseStartTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _logEvent(d, 'pause', note: 'إيقاف مؤقت');
    }
    _saveDevices();
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
    _saveHistory();
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
    _saveHistory();
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
    _saveDevices();
    notifyListeners();
  }

  void setDeviceTimer(PSDevice d, int? minutes) {
    d.timerAlertMinutes = minutes;
    if (minutes == null) _alertedDevices.remove(d.id);
    _saveDevices();
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
    d.isCountdown = false;
    d.countdownTotalSeconds = null;
    d.countdownAlertSent = false;
    d.sessionLog = [];
    _alertedDevices.remove(d.id);
    _countdownAlertedDevices.remove(d.id);
    _lockingDevices.add(d.id); // ✅ قفل مؤقت
    _saveDevices().then((_) {
     Future.delayed(const Duration(seconds: 5), () {
  _lockingDevices.remove(d.id);
});
    });
    notifyListeners();
  }

  Map<String, dynamic> stopDevice(PSDevice d) {
    // ✅ حماية من double-checkout
    if (_stoppingDevices.contains(d.id)) return {};
    if (!d.isActive && d.orders.isEmpty) return {};
    _stoppingDevices.add(d.id);

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
    d.isCountdown = false;
    d.countdownTotalSeconds = null;
    d.countdownAlertSent = false;
    d.sessionLog = [];
    _alertedDevices.remove(d.id);
    _countdownAlertedDevices.remove(d.id);
    _stoppingDevices.remove(d.id);

    // ✅ ضيف الجهاز في _lockingDevices — بيمنع الـ SSE يرجّعه شغال
    _lockingDevices.add(d.id);

    // بعت للـ Firebase وبعدين شيل القفل
    _saveDevices().then((_) {
      // بعد ما الـ push وصل لـ Firebase، الـ SSE هيجي بالحالة الصح
      // نستنى ثانيتين عشان الـ SSE يتحدث ثم نشيل القفل
     Future.delayed(const Duration(seconds: 5), () {
  _lockingDevices.remove(d.id);
});
    });
    _saveHistory();
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
    _saveDevices();
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
    to.sessionLog = List<Map<String, dynamic>>.from(from.sessionLog);
    to.isCountdown = from.isCountdown;
    to.countdownTotalSeconds = from.countdownTotalSeconds;
    to.countdownAlertSent = from.countdownAlertSent;
    _logEvent(to, 'transfer', note: 'تم نقل الجلسة من ${from.displayName}');

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

    _saveDevices();
    notifyListeners();
  }

  Future<bool> archiveAndClear() async {
    if (history.isEmpty || shopId == null) return false;
    _sync?.pause();
    archiving = true;
    try {
      final totalTime = history.fold(0.0, (s, h) => s + (h['time_cost'] ?? 0));
      final totalBuffet = history.fold(0.0, (s, h) => s + (h['buffet_cost'] ?? 0));
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
        if (result == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (result == null) return false;
      history.clear();
      await FirebaseService.set(FirebaseService.historyPath(shopId!), []); // ← أضف هذا
      await _saveHistory();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    } finally {
      archiving = false;
      _sync?.resume();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEVICE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

 void addDevice(String name, String type) {
    final id = devices.length + 1;
    final d = PSDevice(id: id, deviceType: type);
    d.displayName = name;
    devices.add(d);
    numDevices = devices.length;
    saveData();
    _saveDevices();
    notifyListeners();
  }

  void removeDevice(int index) {
    devices.removeAt(index);
    for (int i = 0; i < devices.length; i++) {
      devices[i].id = i + 1;
    }
    numDevices = devices.length;
    saveData();
    _saveDevices();
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

  // ══════════════════════════════════════════════════════════════════════════
  // TABLE ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

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
    _saveTables();
    notifyListeners();
  }

 void removeTable(int index) {
    tables.removeAt(index);
    saveData();
    _saveTables();
    notifyListeners();
  }
 void updateTableSettings(int index, String name, int rate,
      {String? tableType, int? gamePrice}) {
    tables[index]['name'] = name;
    tables[index]['rate'] = rate;
    if (tableType != null) tables[index]['table_type'] = tableType;
    if (gamePrice != null) tables[index]['game_price'] = gamePrice;
    saveData();
    _saveTables();
    notifyListeners();
  }

  void startTable(int index) {
    tables[index]['start_time'] =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    tables[index]['is_paused'] = false;
    tables[index]['pause_start_time'] = null;
    tables[index]['orders'] = <String, int>{};
    _saveTables();
    notifyListeners();
  }

  void toggleTablePause(int index) {
    final t = tables[index];
    if (t['is_paused'] == true) {
      final paused = (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
          (t['pause_start_time'] ?? 0);
      t['start_time'] = (t['start_time'] ?? 0) + paused;
      t['is_paused'] = false;
      t['pause_start_time'] = null;
    } else {
      t['is_paused'] = true;
      t['pause_start_time'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
    _saveTables();
    notifyListeners();
  }

  void cancelTable(int index) {
    tables[index]['start_time'] = null;
    tables[index]['is_paused'] = false;
    tables[index]['pause_start_time'] = null;
    tables[index]['orders'] = <String, int>{};
    _saveTables();
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
      elapsed = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - startTime;
    }

    final rate = (t['rate'] as num).toDouble();
    final timeCost = (elapsed / 3600) * rate;
    final Map<String, int> orders = Map<String, int>.from(t['orders'] ?? {});
    double buffetCost = 0;
    orders.forEach((item, qty) => buffetCost += qty * (menu[item] ?? 0));

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

    _saveTables();
    _saveHistory();
    notifyListeners();
    return record;
  }

  String? addTableOrder(int index, String item, int qty) {
    if (qty > 0) {
      final available = inventory[item];
      if (available != null && available <= 0) {
        return 'نفد "$item" من المخزن!';
      }
      final orders = Map<String, int>.from(tables[index]['orders'] ?? {});
      final currentInOrder = orders[item] ?? 0;
      final totalNeeded = currentInOrder + qty;
      if (available != null && totalNeeded > available) {
        return 'الكمية المتاحة هي $available فقط!';
      }
    }
    final orders = Map<String, int>.from(tables[index]['orders'] ?? {});
    orders[item] = (orders[item] ?? 0) + qty;
    if (orders[item]! <= 0) orders.remove(item);
    tables[index]['orders'] = orders;
    _saveTables();
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

  // ══════════════════════════════════════════════════════════════════════════
  // DRINK TABLES
  // ══════════════════════════════════════════════════════════════════════════

  void addDrinkTable(String name) {
    drinkTables.add({'name': name, 'orders': <String, int>{}});
    saveData();
    _saveTables();
    notifyListeners();
  }

  void removeDrinkTable(int index) {
    drinkTables.removeAt(index);
    saveData();
    _saveTables();
    notifyListeners();
  }

  void updateDrinkTableName(int index, String name) {
    drinkTables[index]['name'] = name;
    saveData();
    _saveTables();
    notifyListeners();
  }

  String? addDrinkTableOrder(int index, String item, int qty) {
    if (qty > 0) {
      final available = inventory[item];
      if (available != null && available <= 0) {
        return 'نفد "$item" من المخزن!';
      }
      final orders = Map<String, int>.from(drinkTables[index]['orders'] ?? {});
      final currentInOrder = orders[item] ?? 0;
      final totalNeeded = currentInOrder + qty;
      if (available != null && totalNeeded > available) {
        return 'الكمية المتاحة هي $available فقط!';
      }
    }
    final orders = Map<String, int>.from(drinkTables[index]['orders'] ?? {});
    orders[item] = (orders[item] ?? 0) + qty;
    if (orders[item]! <= 0) orders.remove(item);
    drinkTables[index]['orders'] = orders;
    _saveTables();
    notifyListeners();
    return null;
  }

  Map<String, dynamic> checkoutDrinkTable(int index) {
    final t = drinkTables[index];
    final Map<String, int> orders = Map<String, int>.from(t['orders'] ?? {});
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

    _saveTables();
    _saveHistory();
    notifyListeners();
    return record;
  }

  void transferDrinkTableToDevice(int drinkIndex, PSDevice device) {
    final Map<String, int> orders =
        Map<String, int>.from(drinkTables[drinkIndex]['orders'] ?? {});
    if (!device.isActive) {
      device.mode = 'normal';
      device.status = 'شغال';
      device.startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      device.addedSeconds = 0;
      device.isPaused = false;
      device.sessionLog = [];
      _logEvent(device, 'start', note: 'بدأ اللعب (تحويل من طاولة طلبات)');
      _alertedDevices.remove(device.id);
    }
    orders.forEach((item, qty) {
      device.orders[item] = (device.orders[item] ?? 0) + qty;
    });
    drinkTables[drinkIndex]['orders'] = <String, int>{};
    _saveTables();
    _saveDevices();
    notifyListeners();
  }

  void transferDrinkTableToTable(int drinkIndex, int tableIndex) {
    final Map<String, int> orders =
        Map<String, int>.from(drinkTables[drinkIndex]['orders'] ?? {});
    final t = tables[tableIndex];
    if (t['start_time'] == null) {
      t['start_time'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      t['is_paused'] = false;
      t['pause_start_time'] = null;
    }
    final existing = Map<String, int>.from(t['orders'] ?? {});
    orders.forEach((item, qty) {
      existing[item] = (existing[item] ?? 0) + qty;
    });
    tables[tableIndex]['orders'] = existing;
    drinkTables[drinkIndex]['orders'] = <String, int>{};
    _saveTables();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MENU & INVENTORY
  // ══════════════════════════════════════════════════════════════════════════

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

  void _deductFromInventory(String item, int qty) {
    if (inventory.containsKey(item)) {
      inventory[item] = (inventory[item]! - qty).clamp(0, 99999);
    }
    dailyInventorySummary[item] = (dailyInventorySummary[item] ?? 0) + qty;
    // ✅ بعت الـ inventory محدّث فوراً للـ Firebase
    if (shopId != null) {
      FirebaseService.set(
        FirebaseService.inventoryPath(shopId!),
        inventory,
      );
      FirebaseService.set(
        FirebaseService.dailySummaryPath(shopId!),
        dailyInventorySummary,
      );
    }
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

  void resetDailySummary() {
    dailyInventorySummary.clear();
    saveData();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ══════════════════════════════════════════════════════════════════════════

  void updateShopName(String name) {
    shopName = name;
    saveData();
    notifyListeners();
  }

  String? login(String password, {required String targetRole, String? targetCashierName}) {
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
  notifyListeners();
}

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
    _saveDevices();
    notifyListeners();
  }

  void updateDeviceType(PSDevice d, String type) {
    d.deviceType = type;
    saveData();
    _saveDevices();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEBTS
  // ══════════════════════════════════════════════════════════════════════════

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
    debts[index]['paid'] = false;
    final h = List<Map<String, dynamic>>.from(
        debts[index]['payment_history'] as List? ?? []);
    h.add({
      'type': 'add',
      'amount': amount,
      'note': note,
      'date': DateTime.now().toString(),
      'by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    debts[index]['payment_history'] = h;
    saveData();
    notifyListeners();
  }

  void markDebtPaid(int index) {
    final amount = (debts[index]['amount'] as num?)?.toDouble() ?? 0;
    debts[index]['paid'] = true;
    final h = List<Map<String, dynamic>>.from(
        debts[index]['payment_history'] as List? ?? []);
    h.add({
      'type': 'pay',
      'amount': amount,
      'date': DateTime.now().toString(),
      'by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    debts[index]['payment_history'] = h;
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
    final h = List<Map<String, dynamic>>.from(
        debts[index]['payment_history'] as List? ?? []);
    h.add({
      'type': 'pay',
      'amount': amount,
      'date': DateTime.now().toString(),
      'by': currentCashierName ?? (isAdmin ? 'أدمن' : 'كاشير'),
    });
    debts[index]['payment_history'] = h;
    saveData();
    notifyListeners();
  }

  void deleteDebt(int index) {
    debts.removeAt(index);
    saveData();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOURNAMENTS
  // ══════════════════════════════════════════════════════════════════════════

  int addTournament(Map<String, dynamic> tournament) {
    tournaments.add(Map<String, dynamic>.from(tournament));
    saveData();
    notifyListeners();
    return tournaments.length - 1;
  }

  void updateTournament(int index, Map<String, dynamic> data) {
    if (index < 0 || index >= tournaments.length) return;
    tournaments[index] = Map<String, dynamic>.from(data);
    saveData();
    notifyListeners();
  }

  void deleteTournament(int index) {
    if (index < 0 || index >= tournaments.length) return;
    tournaments.removeAt(index);
    saveData();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHIFT MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  void startShift(String cashierName) {
    openShifts[cashierName] = ShiftRecord(
      cashierName: cashierName,
      startTime: DateTime.now(),
      transactions: [],
    );
    saveData();
    notifyListeners();
  }

  Future<ShiftRecord?> endShift() async {
    final cashierName = currentCashierName;
    if (cashierName == null || !openShifts.containsKey(cashierName)) {
      return null;
    }

    final shift = openShifts[cashierName]!;
    final shiftStart = shift.startTime;

    final shiftTransactions = history.where((h) {
      final date = DateTime.tryParse(h['date']?.toString() ?? '');
      if (date == null) return false;
      final isAfterStart =
          date.isAfter(shiftStart) || date.isAtSameMomentAs(shiftStart);
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

    final data = _buildDataDict();
    await SyncService.saveLocal(shopId!, data);
    _sync?.schedulePushShifts();

    notifyListeners();
    return closedShift;
  }

  void clearShiftsHistory() {
    shiftsHistory.clear();
    saveData();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _clockTimer?.cancel();
    _historyPollTimer?.cancel(); // ✅
    _sync?.flushAll();
    _sync?.dispose();
    super.dispose();
  }
}


