import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../widgets/device_card.dart';
import 'device_detail_screen.dart';
import 'table_detail_screen.dart';
import 'drink_table_screen.dart';
import 'customer_orders_screen.dart';
import 'settings_screen.dart';
import 'debts_screen.dart';
import 'tournament_screen.dart';
import 'shift_screen.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});
  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabCount = 1;
  int _pendingOrdersCount = 0;
  Timer? _ordersTimer;
  final Set<String> _notifiedOrderKeys = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildTabs();
      _startOrdersPolling();
    });
  }

  void _startOrdersPolling() {
    _pollOrders();
    _ordersTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _pollOrders());
  }

  Future<void> _pollOrders() async {
    final shopId = context.read<AppState>().shopId;
    if (shopId == null) return;
    try {
      final data =
          await FirebaseService.get('shops/$shopId/customer_orders');
      if (data == null || data is! Map) {
        if (mounted) setState(() => _pendingOrdersCount = 0);
        return;
      }

      int pendingCount = 0;
      for (final entry in (data as Map).entries) {
        final key = entry.key.toString();
        final v = entry.value;
        if (v is! Map) continue;
        final status = v['status']?.toString() ?? '';
        if (status != 'pending') continue;
        pendingCount++;
        if (!_notifiedOrderKeys.contains(key)) {
          _notifiedOrderKeys.add(key);
          final deviceName = v['device_name']?.toString() ?? 'جهاز';
          final orderText = v['order_text']?.toString() ?? '';
          await NotificationService.showCustomerOrderAlert(
              deviceName, orderText);
        }
      }
      _notifiedOrderKeys
          .removeWhere((key) => !(data as Map).containsKey(key));
      if (mounted) setState(() => _pendingOrdersCount = pendingCount);
    } catch (_) {}
  }

  void _rebuildTabs() {
    final state = context.read<AppState>();
    final hasDevices = state.devices.isNotEmpty;
    final hasTables = state.tables.isNotEmpty;
    final hasDrinkTables = state.drinkTables.isNotEmpty;

    final newCount = (hasDevices ? 1 : 0) +
        (hasTables ? 1 : 0) +
        (hasDrinkTables ? 1 : 0);

    final safeCount = newCount == 0 ? 1 : newCount;

    if (safeCount != _tabCount) {
      setState(() {
        _tabCount = safeCount;
        _tabController.dispose();
        _tabController = TabController(length: safeCount, vsync: this);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ordersTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasDevices = state.devices.isNotEmpty;
    final hasTables = state.tables.isNotEmpty;
    final hasDrinkTables = state.drinkTables.isNotEmpty;
    final hasAnything = hasDevices || hasTables || hasDrinkTables;

    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildTabs());

    // ── Tabs ────────────────────────────────────────────────────────────────
    final tabs = <Tab>[
      if (hasDevices)
        const Tab(
            icon: Icon(Icons.sports_esports, size: 18),
            text: 'الأجهزة'),
      if (hasTables)
        const Tab(
            icon: Icon(Icons.table_bar,
                size: 18, color: Color(0xFF34d399)),
            text: 'بنج / بلياردو'),
      if (hasDrinkTables)
        const Tab(
            icon: Icon(Icons.local_drink,
                size: 18, color: Colors.orange),
            text: 'تربيزات'),
    ];

    // ── Tab Views ───────────────────────────────────────────────────────────
    final tabViews = <Widget>[
      if (hasDevices)
        GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.devices.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (ctx, i) {
            final d = state.devices[i];
            return DeviceCard(
              device: d,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DeviceDetailScreen(device: d)),
              ),
            );
          },
        ),
      if (hasTables)
        GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.tables.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.95,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (ctx, i) => _CashierTableCard(tableIndex: i),
        ),
      if (hasDrinkTables)
        GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.drinkTables.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (ctx, i) => _CashierDrinkTableCard(index: i),
        ),
    ];

    final showTabs = tabs.length > 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        elevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '⚡ ${state.shopName}',
              style: const TextStyle(
                color: Color(0xFF38bdf8),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (state.currentCashierName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF38bdf8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, color: Color(0xFF38bdf8), size: 11),
                    const SizedBox(width: 4),
                    Text(
                      state.currentCashierName!,
                      style: const TextStyle(
                        color: Color(0xFF38bdf8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_active_outlined,
                    color: Colors.orange, size: 26),
                tooltip: 'طلبات العملاء',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CustomerOrdersScreen(
                            shopId: state.shopId ?? '')),
                  );
                  _pollOrders();
                },
              ),
              if (_pendingOrdersCount > 0)
                Positioned(
                  top: 6,
                  left: 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                          minWidth: 18, minHeight: 18),
                      child: Text(
                        '$_pendingOrdersCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          IconButton(
            icon: const Icon(Icons.money_off, color: Colors.redAccent),
            tooltip: 'المديونيات',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DebtsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Color(0xFFfbbf24)),
            tooltip: 'البطولات',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TournamentScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () => context.read<AppState>().logout(),
            tooltip: 'خروج',
          ),
        ],
        bottom: showTabs
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF38bdf8),
                labelColor: const Color(0xFF38bdf8),
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
                tabs: tabs,
              )
            : null,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Colors.orange.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Row(children: [
                  Icon(Icons.person, color: Colors.orange, size: 16),
                  SizedBox(width: 6),
                  Text('وضع الكاشير',
                      style: TextStyle(color: Colors.orange, fontSize: 13)),
                ]),
                EndShiftButton(),
              ],
            ),
          ),
          Expanded(
            child: !hasAnything
                ? const _EmptyWelcomeScreen()
                : (showTabs
                    ? TabBarView(
                        controller: _tabController,
                        children: tabViews)
                    : tabViews.first),
          ),
        ],
      ),
    );
  }

  void _showAdminLogin(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, color: Colors.amber),
          SizedBox(width: 8),
          Text('دخول الأدمن',
              style: TextStyle(
                  color: Colors.amber, fontWeight: FontWeight.bold)),
        ]),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, letterSpacing: 4),
          decoration: InputDecoration(
            hintText: '••••••',
            hintStyle:
                TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: const Color(0xFF0b0e14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _tryAdminLogin(context, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => _tryAdminLogin(context, ctrl.text),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black),
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

  void _tryAdminLogin(BuildContext context, String password) {
final result = context.read<AppState>().login(password, targetRole: 'admin');
    if (result == 'admin') {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ كلمة السر غلط'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

// ─── شاشة الترحيب لما مفيش حاجة ──────────────────────────────────────────────

class _EmptyWelcomeScreen extends StatelessWidget {
  const _EmptyWelcomeScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1c2128),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38bdf8).withOpacity(0.15),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.storefront_outlined,
                  size: 72, color: Color(0xFF38bdf8)),
            ),
            const SizedBox(height: 28),
            const Text(
              'أهلاً بك! 👋',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38bdf8)),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا يوجد محتوى بعد\nتواصل مع الأدمن لإضافة الأجهزة أو التربيزات',
              style: TextStyle(
                  color: Colors.white54, fontSize: 15, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _SuggestionCard(
              icon: Icons.sports_esports,
              color: const Color(0xFF38bdf8),
              title: 'أجهزة بلايستيشن',
              sub: 'PS4 / PS5 مع تتبع الوقت والحساب',
            ),
            const SizedBox(height: 10),
            _SuggestionCard(
              icon: Icons.table_bar,
              color: const Color(0xFF34d399),
              title: 'تربيزات بنج / بلياردو',
              sub: 'تتبع الوقت والجيمات والبوفيه',
            ),
            const SizedBox(height: 10),
            _SuggestionCard(
              icon: Icons.local_drink,
              color: Colors.orange,
              title: 'تربيزات المشروبات',
              sub: 'إدارة الطلبات والمنيو بسهولة',
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  const _SuggestionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(sub,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ]),
        ),
      ]),
    );
  }
}

// ─── Cashier Table Card ───────────────────────────────────────────────────────

class _CashierTableCard extends StatelessWidget {
  final int tableIndex;
  const _CashierTableCard({required this.tableIndex});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (tableIndex >= state.tables.length) return const SizedBox();
    final t = state.tables[tableIndex];
    final bool isActive = t['start_time'] != null;
    final bool isPaused = t['is_paused'] == true;
    final elapsed = state.tableElapsed(tableIndex);
    final h = elapsed ~/ 3600;
    final m = (elapsed % 3600) ~/ 60;
    final s = elapsed % 60;
    final timerText = isActive
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '--:--:--';
    final color = isActive
        ? (isPaused ? Colors.amber : const Color(0xFF34d399))
        : Colors.white24;
    final tableType = t['table_type'] ?? 'ping';
    final typeLabel =
        tableType == 'billiard' ? '🎱 بلياردو' : '🏓 بينج';

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  TableDetailScreen(tableIndex: tableIndex))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: color.withOpacity(0.4),
              width: isActive ? 1.5 : 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(children: [
              Icon(Icons.table_bar, color: color, size: 26),
              const SizedBox(height: 4),
              Text(t['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(typeLabel,
                  style: TextStyle(color: color, fontSize: 11)),
              const SizedBox(height: 4),
              Text(timerText,
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ])),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isActive
                      ? (isPaused ? 'إيقاف مؤقت' : 'شغالة')
                      : '${t['rate']} ج/س',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (!isActive)
              SizedBox(
                width: double.infinity,
                height: 34,
                child: FilledButton.icon(
                  onPressed: () => state.startTable(tableIndex),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('تشغيل',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF34d399),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 34,
                child: FilledButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TableDetailScreen(
                              tableIndex: tableIndex))),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4ade80),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('تفاصيل',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Cashier Drink Table Card ─────────────────────────────────────────────────

class _CashierDrinkTableCard extends StatelessWidget {
  final int index;
  const _CashierDrinkTableCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (index >= state.drinkTables.length) return const SizedBox();
    final t = state.drinkTables[index];
    final Map<String, int> orders =
        Map<String, int>.from(t['orders'] ?? {});
    final int totalItems =
        orders.values.fold(0, (s, q) => s + q);
    double total = 0;
    orders.forEach((item, qty) {
      total += qty * (state.menu[item] ?? 0);
    });

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  DrinkTableScreen(tableIndex: index))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: totalItems > 0
                ? Colors.orange.withOpacity(0.5)
                : Colors.white12,
            width: totalItems > 0 ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(children: [
              Icon(Icons.local_drink,
                  color: totalItems > 0
                      ? Colors.orange
                      : Colors.white38,
                  size: 28),
              const SizedBox(height: 6),
              Text(t['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              if (totalItems > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$totalItems صنف',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                )
              else
                Text('فاضية',
                    style: TextStyle(
                        color: Colors.white38.withOpacity(0.5),
                        fontSize: 12)),
            ]),
            Column(children: [
              Text(
                '${total.toStringAsFixed(1)} ج',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: total > 0
                      ? const Color(0xFF4ade80)
                      : Colors.white24,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: FilledButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DrinkTableScreen(tableIndex: index))),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('إدارة',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
