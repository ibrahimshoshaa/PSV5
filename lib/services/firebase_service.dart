import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════════
// FirebaseService — مقسّم لمسارات منفصلة حسب نوع البيانات
//
// المسارات:
//   realtime/devices_state   ← حالة الأجهزة (SSE - فوري)
//   operational/             ← تربيزات وطلبات (push عند التغيير)
//   static/                  ← أسعار ومنيو وإعدادات (push عند التعديل)
//   records/history          ← السجلات اليومية (append)
//   records/shifts           ← الشيفتات (append)
//   archives/                ← الأرشيف (append فقط)
//   yearly_archives/         ← الأرشيف السنوي
//   subscription             ← بيانات الاشتراك
//   tournaments              ← البطولات
//   customer_orders          ← طلبات العملاء
// ═══════════════════════════════════════════════════════════════════════════════

class FirebaseService {
  static const String _baseUrl =
      'https://ps-harifa-default-rtdb.firebaseio.com';
  static const String _secret =
      'loFnECpWdlhEHnzGdPW1VoWKbZPepbgrqDVjTnEY';

  static String _url(String path) => '$_baseUrl/$path.json?auth=$_secret';

  // ─── CRUD الأساسي ──────────────────────────────────────────────────────────

  static Future<dynamic> get(String path) async {
    try {
      final r = await http
          .get(Uri.parse(_url(path)))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (e) {
      print('Firebase GET error [$path]: $e');
    }
    return null;
  }

  static Future<bool> set(String path, dynamic data) async {
    try {
      final r = await http
          .put(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      print('Firebase SET error [$path]: $e');
      return false;
    }
  }

  static Future<String?> push(String path, dynamic data) async {
    try {
      final r = await http
          .post(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        return jsonDecode(r.body)['name'];
      }
    } catch (e) {
      print('Firebase PUSH error [$path]: $e');
    }
    return null;
  }

  static Future<bool> delete(String path) async {
    try {
      final r = await http
          .delete(Uri.parse(_url(path)))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      print('Firebase DELETE error [$path]: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // مسارات المحل — مقسّمة حسب نوع البيانات
  // ═══════════════════════════════════════════════════════════════════════════

  /// حالة الأجهزة اللحظية — بتتزامن بـ SSE
  static String devicesStatePath(String shopId) =>
      'shops/$shopId/realtime/devices_state';

  /// التربيزات والطلبات — بتتزامن عند التغيير
  static String tablesPath(String shopId) =>
      'shops/$shopId/operational/tables';

  static String drinkTablesPath(String shopId) =>
      'shops/$shopId/operational/drink_tables';

  /// البيانات الثابتة — بتتزامن عند التعديل فقط
  static String staticDataPath(String shopId) =>
      'shops/$shopId/static';

  static String pricesPath(String shopId) =>
      'shops/$shopId/static/prices';

  static String menuPath(String shopId) =>
      'shops/$shopId/static/menu';

  static String inventoryPath(String shopId) =>
      'shops/$shopId/static/inventory';

  static String settingsPath(String shopId) =>
      'shops/$shopId/static/settings';

  static String cashiersPath(String shopId) =>
      'shops/$shopId/static/cashiers';

  static String debtsPath(String shopId) =>
      'shops/$shopId/static/debts';

  /// السجلات اليومية — append فقط
  static String historyPath(String shopId) =>
      'shops/$shopId/records/history';

  static String dailySummaryPath(String shopId) =>
      'shops/$shopId/records/daily_summary';

  /// الشيفتات
  static String shiftsHistoryPath(String shopId) =>
      'shops/$shopId/records/shifts_history';

  static String openShiftsPath(String shopId) =>
      'shops/$shopId/records/open_shifts';

  /// الأرشيف
  static String shopArchivePath(String shopId) =>
      'shops/$shopId/archives';

  static String shopYearlyArchivePath(String shopId) =>
      'shops/$shopId/yearly_archives';

  /// الاشتراك
  static String shopSubscriptionPath(String shopId) =>
      'shops/$shopId/subscription';

  /// البطولات
  static String shopTournamentsPath(String shopId) =>
      'shops/$shopId/tournaments';

  /// طلبات العملاء
  static String customerOrdersPath(String shopId) =>
      'shops/$shopId/customer_orders';

  // للتوافق مع الكود القديم
  static String shopDataPath(String shopId) =>
      'shops/$shopId/app_data';

  // ═══════════════════════════════════════════════════════════════════════════
  // Push منفصل لكل نوع بيانات
  // ═══════════════════════════════════════════════════════════════════════════

  /// رفع حالة الأجهزة فقط (الأسرع والأكثر تكراراً)
  static Future<bool> pushDevicesState(
      String shopId, List<Map<String, dynamic>> devicesState) async {
    return set(devicesStatePath(shopId), {
      'devices': devicesState,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// رفع التربيزات
  static Future<bool> pushTables(
      String shopId, List<Map<String, dynamic>> tables) async {
    return set(tablesPath(shopId), tables);
  }

  static Future<bool> pushDrinkTables(
      String shopId, List<Map<String, dynamic>> drinkTables) async {
    return set(drinkTablesPath(shopId), drinkTables);
  }

  /// رفع البيانات الثابتة (أسعار، منيو، إعدادات)
  static Future<bool> pushStaticData(
      String shopId, Map<String, dynamic> staticData) async {
    return set(staticDataPath(shopId), staticData);
  }

  /// رفع السجلات اليومية
  static Future<bool> pushHistory(
      String shopId, List<Map<String, dynamic>> history) async {
    return set(historyPath(shopId), history);
  }

  /// رفع الشيفتات المفتوحة
  static Future<bool> pushOpenShifts(
      String shopId, Map<String, dynamic> openShifts) async {
    return set(openShiftsPath(shopId), openShifts);
  }

  /// رفع تاريخ الشيفتات
  static Future<bool> pushShiftsHistory(
      String shopId, List<Map<String, dynamic>> shifts) async {
    return set(shiftsHistoryPath(shopId), shifts);
  }

  /// رفع المديونيات
  static Future<bool> pushDebts(
      String shopId, List<Map<String, dynamic>> debts) async {
    return set(debtsPath(shopId), debts);
  }

  /// رفع البطولات
  static Future<bool> pushTournaments(
      String shopId, List<Map<String, dynamic>> tournaments) async {
    return set(shopTournamentsPath(shopId), tournaments);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Pull منفصل لكل نوع بيانات
  // ═══════════════════════════════════════════════════════════════════════════

  /// تحميل كل البيانات عند بداية التطبيق (مرة واحدة)
  static Future<Map<String, dynamic>?> pullAllData(String shopId) async {
    try {
      // نشيل app_data القديم أول لو موجود للتوافق
      final oldData = await get(shopDataPath(shopId));

      // نحمّل المسارات الجديدة بالتوازي
      final results = await Future.wait([
        get(devicesStatePath(shopId)),
        get(tablesPath(shopId)),
        get(drinkTablesPath(shopId)),
        get(staticDataPath(shopId)),
        get(historyPath(shopId)),
        get(dailySummaryPath(shopId)),
        get(shiftsHistoryPath(shopId)),
        get(openShiftsPath(shopId)),
        get(debtsPath(shopId)),
        get(shopTournamentsPath(shopId)),
      ]);

      final devicesData = results[0];
      final tablesData = results[1];
      final drinkTablesData = results[2];
      final staticData = results[3];
      final historyData = results[4];
      final dailySummaryData = results[5];
      final shiftsHistoryData = results[6];
      final openShiftsData = results[7];
      final debtsData = results[8];
      final tournamentsData = results[9];

      // لو في بيانات جديدة، استخدمها — لو لأ، استخدم البيانات القديمة
      final hasNewData = staticData != null ||
          devicesData != null ||
          tablesData != null;

      if (!hasNewData && oldData != null && oldData is Map) {
        // migrate من النظام القديم
        return _migrateOldData(Map<String, dynamic>.from(oldData));
      }

      // بناء الـ map الموحد من المسارات المختلفة
      final combined = <String, dynamic>{};

      // الأجهزة
      if (devicesData != null && devicesData is Map) {
        final devices = devicesData['devices'];
        if (devices != null) combined['devices_state'] = devices;
      } else if (oldData != null && oldData is Map) {
        combined['devices_state'] = oldData['devices_state'] ?? [];
      }

      // التربيزات
      if (tablesData != null) {
        combined['tables'] = tablesData is List ? tablesData : [];
      } else if (oldData != null && oldData is Map) {
        combined['tables'] = oldData['tables'] ?? [];
      }

      if (drinkTablesData != null) {
        combined['drink_tables'] =
            drinkTablesData is List ? drinkTablesData : [];
      } else if (oldData != null && oldData is Map) {
        combined['drink_tables'] = oldData['drink_tables'] ?? [];
      }

      // البيانات الثابتة
      if (staticData != null && staticData is Map) {
        final s = Map<String, dynamic>.from(staticData);
        combined['prices'] = s['prices'];
        combined['menu'] = s['menu'];
        combined['inventory'] = s['inventory'];
        combined['cashiers'] = s['cashiers'];
        combined['admin_password_hash'] = s['admin_password_hash'];
        combined['shop_name'] = s['shop_name'];
        combined['match_enabled'] = s['match_enabled'];
        combined['num_devices'] = s['num_devices'];
      } else if (oldData != null && oldData is Map) {
        combined['prices'] = oldData['prices'];
        combined['menu'] = oldData['menu'];
        combined['inventory'] = oldData['inventory'];
        combined['cashiers'] = oldData['cashiers'];
        combined['cashier_password_hash'] =
            oldData['cashier_password_hash'];
        combined['admin_password_hash'] =
            oldData['admin_password_hash'];
        combined['shop_name'] = oldData['shop_name'];
        combined['match_enabled'] = oldData['match_enabled'];
        combined['num_devices'] = oldData['num_devices'];
      }

      // السجلات
      if (historyData != null) {
        combined['history'] =
            historyData is List ? historyData : [];
      } else if (oldData != null && oldData is Map) {
        combined['history'] = oldData['history'] ?? [];
      }

      if (dailySummaryData != null && dailySummaryData is Map) {
        combined['daily_inventory_summary'] =
            Map<String, dynamic>.from(dailySummaryData);
      } else if (oldData != null && oldData is Map) {
        combined['daily_inventory_summary'] =
            oldData['daily_inventory_summary'] ?? {};
      }

      // الشيفتات
      if (shiftsHistoryData != null) {
        combined['shifts_history'] =
            shiftsHistoryData is List ? shiftsHistoryData : [];
      } else if (oldData != null && oldData is Map) {
        combined['shifts_history'] = oldData['shifts_history'] ?? [];
      }

      if (openShiftsData != null && openShiftsData is Map) {
        combined['open_shifts'] =
            Map<String, dynamic>.from(openShiftsData);
      } else if (oldData != null && oldData is Map) {
        combined['open_shifts'] = oldData['open_shifts'] ?? {};
      }

      // المديونيات
      if (debtsData != null) {
        combined['debts'] = debtsData is List ? debtsData : [];
      } else if (oldData != null && oldData is Map) {
        combined['debts'] = oldData['debts'] ?? [];
      }

      // البطولات
      if (tournamentsData != null) {
        combined['tournaments'] =
            tournamentsData is List ? tournamentsData : [];
      } else if (oldData != null && oldData is Map) {
        combined['tournaments'] = oldData['tournaments'] ?? [];
      }

      combined['last_updated'] =
          DateTime.now().millisecondsSinceEpoch;

      return combined;
    } catch (e) {
      print('Firebase pullAllData error: $e');
      return null;
    }
  }

  /// تحميل حالة الأجهزة فقط (للـ polling السريع)
  static Future<List<Map<String, dynamic>>?> pullDevicesState(
      String shopId) async {
    try {
      final data = await get(devicesStatePath(shopId));
      if (data == null || data is! Map) return null;
      final devices = data['devices'];
      if (devices == null) return null;
      if (devices is List) {
        return devices
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Migration من النظام القديم
  // ═══════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _migrateOldData(
      Map<String, dynamic> oldData) {
    return oldData; // نرجعها زي ما هي، الـ _applyData هتتعامل معاها
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SSE Listener (للأجهزة اللحظية)
  // ═══════════════════════════════════════════════════════════════════════════

  static StreamSubscription<dynamic> listenToDevices(
    String shopId, {
    required void Function(List<Map<String, dynamic>> devices) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      devicesStatePath(shopId),
      onData: (data) {
        if (data == null || data is! Map) return;
        final devices = data['devices'];
        if (devices == null) return;
        if (devices is List) {
          try {
            final typed = devices
                .map((d) => Map<String, dynamic>.from(d as Map))
                .toList();
            onData(typed);
          } catch (_) {}
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Real-time SSE Listener (عام)
  // ═══════════════════════════════════════════════════════════════════════════

  static StreamSubscription<dynamic> listen(
    String path, {
    required void Function(dynamic data) onData,
    void Function(Object error)? onError,
    void Function()? onDone,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    final controller = StreamController<dynamic>.broadcast();
    bool cancelled = false;

    Future<void> connect() async {
      while (!cancelled) {
        http.Client? client;
        try {
          client = http.Client();
          final request =
              http.Request('GET', Uri.parse(_url(path)));
          request.headers['Accept'] = 'text/event-stream';
          request.headers['Cache-Control'] = 'no-cache';

          final response = await client.send(request);

          if (response.statusCode != 200) {
            client.close();
            await Future.delayed(retryDelay);
            continue;
          }

          StringBuffer buffer = StringBuffer();

          await for (final chunk
              in response.stream.transform(utf8.decoder)) {
            if (cancelled) break;

            buffer.write(chunk);
            final raw = buffer.toString();
            final blocks = raw.split('\n\n');

            for (int i = 0; i < blocks.length - 1; i++) {
              _processSSEBlock(blocks[i], controller);
            }
            buffer = StringBuffer(blocks.last);
          }
        } catch (e) {
          if (!cancelled) onError?.call(e);
        } finally {
          client?.close();
        }

        if (!cancelled) await Future.delayed(retryDelay);
      }

      if (!controller.isClosed) controller.close();
      onDone?.call();
    }

    connect();

    final subscription = controller.stream.listen(
      onData,
      onError: onError,
    );

    return _CancellableSubscription(subscription, onCancel: () {
      cancelled = true;
    });
  }

  static void _processSSEBlock(
      String block, StreamController<dynamic> controller) {
    String? eventType;
    String? dataLine;

    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLine = line.substring(5).trim();
      }
    }

    if ((eventType == 'put' || eventType == 'patch') &&
        dataLine != null) {
      try {
        final parsed = jsonDecode(dataLine);
        if (!controller.isClosed) {
          controller.add(parsed['data']);
        }
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Subscription
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getSubscriptionWithTimestamp(
      String shopId) async {
    try {
      final subFuture = http
          .get(Uri.parse(_url(shopSubscriptionPath(shopId))))
          .timeout(const Duration(seconds: 10));

      final timeFuture = http
          .get(Uri.parse('$_baseUrl/.json?shallow=true&auth=$_secret'))
          .timeout(const Duration(seconds: 10));

      final results = await Future.wait([subFuture, timeFuture]);

      final subResponse = results[0];
      final timeResponse = results[1];

      if (subResponse.statusCode != 200) return null;

      final subData = jsonDecode(subResponse.body);
      if (subData == null || subData is! Map) return null;

      final result = Map<String, dynamic>.from(subData);

      final dateHeader = timeResponse.headers['date'];
      if (dateHeader != null) {
        try {
          final serverTime = DateTime.parse(dateHeader);
          result['_server_time_ms'] =
              serverTime.millisecondsSinceEpoch;
        } catch (_) {
          result['_server_time_ms'] =
              DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        result['_server_time_ms'] =
            DateTime.now().millisecondsSinceEpoch;
      }

      return result;
    } catch (e) {
      print('Firebase getSubscriptionWithTimestamp error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSubscription(
      String shopId) async {
    final data = await get(shopSubscriptionPath(shopId));
    if (data == null || data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }
}

// ─── Helper class ─────────────────────────────────────────────────────────────

class _CancellableSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _inner;
  final void Function() onCancel;

  _CancellableSubscription(this._inner, {required this.onCancel});

  @override
  Future<void> cancel() {
    onCancel();
    return _inner.cancel();
  }

  @override
  bool get isPaused => _inner.isPaused;
  @override
  void pause([Future<void>? resumeSignal]) =>
      _inner.pause(resumeSignal);
  @override
  void resume() => _inner.resume();
  @override
  void onData(void Function(T data)? handleData) =>
      _inner.onData(handleData);
  @override
  void onError(Function? handleError) =>
      _inner.onError(handleError);
  @override
  void onDone(void Function()? handleDone) =>
      _inner.onDone(handleDone);
  @override
  Future<E> asFuture<E>([E? futureValue]) =>
      _inner.asFuture(futureValue);
}
