import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FirebaseService {
  static const String _baseUrl =
      'https://ps-harifa-default-rtdb.firebaseio.com';
  static const String _secret =
      'loFnECpWdlhEHnzGdPW1VoWKbZPepbgrqDVjTnEY';

  static String _url(String path) => '$_baseUrl/$path.json?auth=$_secret';

  static Future<dynamic> get(String path) async {
    try {
      final r = await http
          .get(Uri.parse(_url(path)))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (e) {
      print('Firebase GET error: $e');
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
      print('Firebase SET error: $e');
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
      print('Firebase PUSH error: $e');
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
      print('Firebase DELETE error: $e');
      return false;
    }
  }

  // ─── Shop-specific helpers ──────────────────────────────────────────────────

  static String shopDataPath(String shopId)          => 'shops/$shopId/app_data';
  static String shopArchivePath(String shopId)       => 'shops/$shopId/archives';
  static String shopYearlyArchivePath(String shopId) => 'shops/$shopId/yearly_archives';
  static String shopSubscriptionPath(String shopId)  => 'shops/$shopId/subscription';
  static String shopTournamentsPath(String shopId)   => 'shops/$shopId/tournaments';

  /// التحقق من اشتراك المحل مع وقت Firebase الحقيقي (ضد التلاعب في تاريخ الموبيل)
  ///
  /// بيرجع Map فيها بيانات الاشتراك + مفتاح `_server_time_ms` بوقت Firebase
  static Future<Map<String, dynamic>?> getSubscriptionWithTimestamp(
      String shopId) async {
    try {
      // ── جيب بيانات الاشتراك ──────────────────────────────────────────
      final subFuture = http
          .get(Uri.parse(_url(shopSubscriptionPath(shopId))))
          .timeout(const Duration(seconds: 10));

      // ── جيب وقت Firebase عن طريق .json مع shallow=true ────────────────
      // Firebase REST API بيحط الـ Date header في الـ response
      // ده أدق طريقة من غير Cloud Functions
      final timeFuture = http
          .get(Uri.parse('$_baseUrl/.json?shallow=true&auth=$_secret'))
          .timeout(const Duration(seconds: 10));

      final results = await Future.wait([subFuture, timeFuture]);

      final subResponse  = results[0];
      final timeResponse = results[1];

      if (subResponse.statusCode != 200) return null;

      final subData = jsonDecode(subResponse.body);
      if (subData == null || subData is! Map) return null;

      final result = Map<String, dynamic>.from(subData);

      // ── استخرج وقت Firebase من الـ Date header ──────────────────────
      final dateHeader = timeResponse.headers['date'];
      if (dateHeader != null) {
        try {
          final serverTime = DateTime.parse(dateHeader);
          result['_server_time_ms'] = serverTime.millisecondsSinceEpoch;
        } catch (_) {
          // لو فشل parse، استخدم وقت الموبيل كـ fallback
          result['_server_time_ms'] = DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        result['_server_time_ms'] = DateTime.now().millisecondsSinceEpoch;
      }

      return result;
    } catch (e) {
      print('Firebase getSubscriptionWithTimestamp error: $e');
      return null;
    }
  }

  /// التحقق القديم (للتوافق مع الكود القديم)
  static Future<Map<String, dynamic>?> getSubscription(String shopId) async {
    final data = await get(shopSubscriptionPath(shopId));
    if (data == null || data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  // ─── Real-time SSE Listener ─────────────────────────────────────────────────

  /// يستمع لتغييرات Firebase على path معين بشكل real-time عبر SSE.
  ///
  /// بيرجع [StreamSubscription] — احتفظ بيه واعمله [cancel()] لما الـ widget يتdispose.
  ///
  /// مثال الاستخدام:
  /// ```dart
  /// _sub = FirebaseService.listen(
  ///   FirebaseService.shopDataPath(shopId),
  ///   onData: (data) => setState(() => _shopData = data),
  ///   onError: (e) => print('SSE error: $e'),
  /// );
  /// // في dispose():
  /// _sub?.cancel();
  /// ```
  static StreamSubscription<dynamic> listen(
    String path, {
    required void Function(dynamic data) onData,
    void Function(Object error)? onError,
    void Function()? onDone,
    Duration retryDelay = const Duration(seconds: 3),
  }) {
    final controller = StreamController<dynamic>.broadcast();
    bool cancelled = false;

    Future<void> connect() async {
      while (!cancelled) {
        http.Client? client;
        try {
          client = http.Client();
          final request = http.Request('GET', Uri.parse(_url(path)));
          request.headers['Accept']        = 'text/event-stream';
          request.headers['Cache-Control'] = 'no-cache';

          final response = await client.send(request);

          if (response.statusCode != 200) {
            client.close();
            await Future.delayed(retryDelay);
            continue;
          }

          // Firebase SSE بيبعت events بالشكل ده:
          // event: put\n
          // data: {"path":"/","data": { ... }}\n\n
          StringBuffer buffer = StringBuffer();

          await for (final chunk in response.stream.transform(utf8.decoder)) {
            if (cancelled) break;

            buffer.write(chunk);
            final raw = buffer.toString();

            // Firebase بيبعت blocks مفصولة بـ \n\n
            final blocks = raw.split('\n\n');

            // آخر block ممكن يكون ناقص — سيبه في الـ buffer
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

  /// يحلل SSE block واحد ويبعت الـ data على الـ stream
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

    // Firebase بيبعت: put (initial + updates) و patch (partial updates)
    if ((eventType == 'put' || eventType == 'patch') && dataLine != null) {
      try {
        final parsed = jsonDecode(dataLine);
        if (!controller.isClosed) {
          controller.add(parsed['data']);
        }
      } catch (_) {
        // تجاهل blocks ناقصة أو corrupted
      }
    }
  }
}

// ─── Helper class ─────────────────────────────────────────────────────────────

/// Wrapper يضمن إن cancel() بيوقف الـ reconnect loop كمان
class _CancellableSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _inner;
  final void Function() onCancel;

  _CancellableSubscription(this._inner, {required this.onCancel});

  @override
  Future<void> cancel() {
    onCancel();
    return _inner.cancel();
  }

  @override bool get isPaused                                          => _inner.isPaused;
  @override void pause([Future<void>? resumeSignal])                  => _inner.pause(resumeSignal);
  @override void resume()                                             => _inner.resume();
  @override void onData(void Function(T data)? handleData)           => _inner.onData(handleData);
  @override void onError(Function? handleError)                      => _inner.onError(handleError);
  @override void onDone(void Function()? handleDone)                 => _inner.onDone(handleDone);
  @override Future<E> asFuture<E>([E? futureValue])                  => _inner.asFuture(futureValue);
}
