import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

/// شاشة الطلبات الواردة من العملاء عبر QR
class CustomerOrdersScreen extends StatefulWidget {
  final String shopId;
  const CustomerOrdersScreen({super.key, required this.shopId});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  List<_CustomerOrder> _orders = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // تحديث كل 15 ثانية تلقائياً
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await FirebaseService.get(
          'shops/${widget.shopId}/customer_orders');
      if (data == null || data is! Map) {
        setState(() { _orders = []; _loading = false; });
        return;
      }

      final list = data.entries.map((e) {
        final v = Map<String, dynamic>.from(e.value as Map);
        return _CustomerOrder(
          key: e.key.toString(),
          deviceId:   (v['device_id'] as num?)?.toInt() ?? 0,
          deviceName: v['device_name']?.toString() ?? 'جهاز',
          orderText:  v['order_text']?.toString() ?? '',
          timestamp:  (v['timestamp'] as num?)?.toInt() ?? 0,
          status:     v['status']?.toString() ?? 'pending',
        );
      }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // ✅ تم حذف إرسال الإشعارات من هنا
      // الإشعارات بتتبعت بس من HomeScreen و CashierScreen عشان منتبعتش مرتين

      setState(() { _orders = list; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markDone(String key) async {
    await FirebaseService.set(
        'shops/${widget.shopId}/customer_orders/$key/status', 'done');
    await _load();
  }

  Future<void> _delete(String key) async {
    await FirebaseService.delete(
        'shops/${widget.shopId}/customer_orders/$key');
    await _load();
  }

  Future<void> _clearDone() async {
    final done = _orders.where((o) => o.status == 'done').toList();
    for (final o in done) {
      await FirebaseService.delete(
          'shops/${widget.shopId}/customer_orders/${o.key}');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _orders.where((o) => o.status == 'pending').toList();
    final done    = _orders.where((o) => o.status == 'done').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Row(children: [
          const Text('🛎️ طلبات العملاء',
              style: TextStyle(
                  color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
          if (pending.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${pending.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (done.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined,
                  color: Colors.white38),
              tooltip: 'مسح المنجزة',
              onPressed: _clearDone,
            ),
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38bdf8)))
          : _orders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('لا يوجد طلبات حالياً',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 16)),
                      SizedBox(height: 6),
                      Text('بيتحدث كل 15 ثانية تلقائياً',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (pending.isNotEmpty) ...[
                      _Header('🔴 جديدة (${pending.length})'),
                      ...pending.map((o) => _OrderTile(
                            order: o,
                            onDone: () => _markDone(o.key),
                            onDelete: () => _delete(o.key),
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (done.isNotEmpty) ...[
                      _Header('✅ منجزة (${done.length})'),
                      ...done.map((o) => _OrderTile(
                            order: o,
                            onDone: () => _markDone(o.key),
                            onDelete: () => _delete(o.key),
                            isDone: true,
                          )),
                    ],
                  ],
                ),
    );
  }
}

// ─── Order Tile ───────────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final _CustomerOrder order;
  final VoidCallback onDone;
  final VoidCallback onDelete;
  final bool isDone;
  const _OrderTile({
    required this.order,
    required this.onDone,
    required this.onDelete,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(order.timestamp);
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDone
                ? Colors.white12
                : Colors.orange.withOpacity(0.5),
            width: isDone ? 1 : 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF38bdf8).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF38bdf8).withOpacity(0.4)),
            ),
            child: Text(order.deviceName,
                style: const TextStyle(
                    color: Color(0xFF38bdf8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(timeStr,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          if (!isDone)
            GestureDetector(
              onTap: onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ade80).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF4ade80).withOpacity(0.5)),
                ),
                child: const Text('✅ تم',
                    style: TextStyle(
                        color: Color(0xFF4ade80),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, color: Colors.white24, size: 18),
          ),
        ]),
        const SizedBox(height: 10),
        Text(order.orderText,
            style: TextStyle(
                fontSize: 15,
                color: isDone ? Colors.white38 : Colors.white,
                decoration:
                    isDone ? TextDecoration.lineThrough : null)),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class _CustomerOrder {
  final String key;
  final int deviceId;
  final String deviceName;
  final String orderText;
  final int timestamp;
  final String status;
  const _CustomerOrder({
    required this.key,
    required this.deviceId,
    required this.deviceName,
    required this.orderText,
    required this.timestamp,
    required this.status,
  });
}
