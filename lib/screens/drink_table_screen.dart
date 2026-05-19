import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/device.dart';
import 'qr_screen.dart'; // ✅ إضافة

class DrinkTableScreen extends StatelessWidget {
  final int tableIndex;
  const DrinkTableScreen({super.key, required this.tableIndex});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (tableIndex >= state.drinkTables.length) {
      return const Scaffold(
          body: Center(child: Text('تربيزة مش موجودة')));
    }
    final t = state.drinkTables[tableIndex];
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    double total = 0;
    orders.forEach(
        (item, qty) => total += qty * (state.menu[item] ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text('مشروبات',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(t['name'] ?? '',
              style: const TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold)),
        ]),
        leading: const BackButton(color: Colors.white),
        actions: [
          // ✅ زرار QR - دايماً ظاهر
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white54, size: 26),
            tooltip: 'QR Code',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QrScreen(drinkTableIndex: tableIndex),
              ),
            ),
          ),
          if (orders.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white70),
              tooltip: 'نقل الطلبات',
              onPressed: () => _showTransferDialog(context, state),
            ),
        ],
      ),
      body: Column(
        children: [
          // إجمالي
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('💰 الإجمالي',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text('${total.toStringAsFixed(1)} ج',
                    style: const TextStyle(
                        color: Color(0xFF4ade80),
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
          ),

          // قائمة المشروبات
          Expanded(
            child: state.menu.isEmpty
                ? const Center(
                    child: Text('البوفيه فاضي، أضف منتجات من الإعدادات',
                        style: TextStyle(color: Colors.white38)))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: state.menu.entries.map((e) {
                      final qty = orders[e.key] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1c2128),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: qty > 0
                                  ? Colors.orange.withOpacity(0.4)
                                  : Colors.white10),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(e.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  Text('${e.value} ج',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12)),
                                ]),
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red),
                            onPressed: qty > 0
                                ? () => state.addDrinkTableOrder(
                                    tableIndex, e.key, -1)
                                : null,
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Text('$qty',
                                key: ValueKey(qty),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.add_circle_outline,
                                color: Color(0xFF4ade80)),
                            onPressed: () {
                              final err = state.addDrinkTableOrder(
                                  tableIndex, e.key, 1);
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('⚠️ $err'),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                          SizedBox(
                            width: 60,
                            child: Text('${qty * e.value} ج',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    color: Color(0xFF4ade80),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
          ),

          // أزرار الحساب والنقل
          if (orders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showTransferDialog(context, state),
                      icon: const Icon(Icons.swap_horiz,
                          color: Colors.white70),
                      label: const Text('نقل',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _confirmCheckout(context, state, total, orders),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('حساب وتصفير',
                          style: TextStyle(fontSize: 15)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  void _showTransferDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.swap_horiz, color: Colors.white70),
          SizedBox(width: 8),
          Text('نقل الطلبات لـ',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── أجهزة ───────────────────────────────────────
                if (state.devices.isNotEmpty) ...[
                  const Text('🎮 الأجهزة',
                      style: TextStyle(
                          color: Color(0xFF38bdf8),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  ...state.devices.map((d) => _TransferTile(
                        label: d.displayName,
                        sub: d.isActive ? 'شغال - ${d.timerText}' : 'متاح',
                        color: d.isActive
                            ? const Color(0xFF38bdf8)
                            : const Color(0xFF4ade80),
                        icon: Icons.sports_esports,
                        onTap: () {
                          state.transferDrinkTableToDevice(
                              tableIndex, d);
                          Navigator.pop(context);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(
                                '✅ الطلبات اتنقلت لـ ${d.displayName}'),
                            backgroundColor: Colors.green,
                          ));
                        },
                      )),
                ],

                // ─── تربيزات بنج ─────────────────────────────────
                if (state.tables.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('🎱 تربيزات بنج / بلياردو',
                      style: TextStyle(
                          color: Color(0xFF34d399),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  ...List.generate(state.tables.length, (i) {
                    final t = state.tables[i];
                    final isActive = t['start_time'] != null;
                    return _TransferTile(
                      label: t['name'] ?? '',
                      sub: isActive ? 'شغالة' : 'فاضية',
                      color: isActive
                          ? const Color(0xFF34d399)
                          : Colors.white54,
                      icon: Icons.table_bar,
                      onTap: () {
                        state.transferDrinkTableToTable(
                            tableIndex, i);
                        Navigator.pop(context);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text(
                              '✅ الطلبات اتنقلت لـ ${t['name']}'),
                          backgroundColor: Colors.green,
                        ));
                      },
                    );
                  }),
                ],

                if (state.devices.isEmpty && state.tables.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('مفيش أجهزة أو تربيزات متاحة',
                        style: TextStyle(color: Colors.white38)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  void _confirmCheckout(BuildContext context, AppState state,
      double total, Map<String, int> orders) {
    final t = state.drinkTables[tableIndex];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('حساب ${t['name']}',
            style: const TextStyle(
                color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...orders.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${e.key} ×${e.value}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13)),
                        Text(
                            '${e.value * (state.menu[e.key] ?? 0)} ج',
                            style:
                                const TextStyle(color: Colors.white)),
                      ]),
                )),
            const Divider(color: Colors.white12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('💰 الإجمالي',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${total.toStringAsFixed(1)} ج',
                    style: const TextStyle(
                        color: Color(0xFF4ade80),
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.checkoutDrinkTable(tableIndex);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _TransferTile({
    required this.label,
    required this.sub,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(sub,
                      style: TextStyle(color: color, fontSize: 12)),
                ]),
          ),
          Icon(Icons.arrow_forward_ios, color: color, size: 14),
        ]),
      ),
    );
  }
}
