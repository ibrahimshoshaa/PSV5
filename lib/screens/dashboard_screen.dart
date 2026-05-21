import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'shift_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // ── إيرادات اليوم ────────────────────────────────────────────────────
    final todayTime =
        state.history.fold(0.0, (s, h) => s + (h['time_cost'] ?? 0));
    final todayBuffet =
        state.history.fold(0.0, (s, h) => s + (h['buffet_cost'] ?? 0));
    final todayTotal = todayTime + todayBuffet;

    // ── إيرادات لحظية ────────────────────────────────────────────────────
    double liveRevenue = 0;
    for (final d in state.devices) {
      if (d.isActive) {
        liveRevenue += d.calculateTimePrice(state.prices);
        liveRevenue += d.getBuffetPrice(state.menu);
      }
    }
    for (int i = 0; i < state.tables.length; i++) {
      if (state.tables[i]['start_time'] != null) {
        final elapsed = state.tableElapsed(i);
        final rate = (state.tables[i]['rate'] as num).toDouble();
        liveRevenue += (elapsed / 3600) * rate;
        final orders =
            Map<String, int>.from(state.tables[i]['orders'] ?? {});
        orders.forEach(
            (item, qty) => liveRevenue += qty * (state.menu[item] ?? 0));
      }
    }

    final activeDevices = state.devices.where((d) => d.isActive).toList();
    final unpaidDebts =
        state.debts.where((d) => d['paid'] != true).toList();
    final totalDebt =
        unpaidDebts.fold(0.0, (s, d) => s + ((d['amount'] as num?) ?? 0));
    final activeTournaments =
        state.tournaments.where((t) => t['status'] == 'ongoing').toList();
    final lowStock = state.inventory.entries
        .where((e) => e.value <= 3 && state.menu.containsKey(e.key))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── AppBar ──────────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: const Color(0xFF080B12),
              expandedHeight: 0,
              floating: true,
              snap: true,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  // يسار: هوم + إعدادات
                  _NavBtn(
                    icon: Icons.home_rounded,
                    color: Colors.white54,
                    onTap: () => Navigator.pop(context),
                    tooltip: 'الرئيسية',
                  ),
                  const SizedBox(width: 4),
                  _NavBtn(
                    icon: Icons.settings_rounded,
                    color: Colors.white38,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen())),
                    tooltip: 'الإعدادات',
                  ),
                  const Spacer(),
                  // وسط: عنوان
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38bdf8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.dashboard_rounded,
                          color: Color(0xFF38bdf8), size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text('الداشبورد',
                        style: TextStyle(
                            color: Color(0xFF38bdf8),
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ]),
                  const Spacer(),
                  // يمين: رسم بياني
                  _NavBtn(
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFFfbbf24),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ChartsScreen(history: state.history))),
                    tooltip: 'الإحصائيات',
                  ),
                ],
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── بطاقة الإيرادات الرئيسية ────────────────────────
                  _RevenueCard(
                    todayTotal: todayTotal,
                    todayTime: todayTime,
                    todayBuffet: todayBuffet,
                    liveRevenue: liveRevenue,
                    sessionsCount: state.history.length,
                  ),
                  const SizedBox(height: 12),

                  // ── تقارير الشيفتات ──────────────────────────────────
                  _ShiftsButton(shiftsCount: state.shiftsHistory.length),
                  const SizedBox(height: 16),

                  // ── الأجهزة ──────────────────────────────────────────
                  if (state.devices.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.sports_esports,
                      title: 'الأجهزة',
                      color: const Color(0xFF38bdf8),
                      badge:
                          '${activeDevices.length}/${state.devices.length} شغال',
                    ),
                    const SizedBox(height: 8),
                    _DevicesGrid(
                        devices: state.devices, prices: state.prices),
                    const SizedBox(height: 16),
                  ],

                  // ── التربيزات ─────────────────────────────────────────
                  if (state.tables.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.table_bar,
                      title: 'بنج / بلياردو',
                      color: const Color(0xFF34d399),
                      badge:
                          '${state.tables.where((t) => t['start_time'] != null).length}/${state.tables.length} شغالة',
                    ),
                    const SizedBox(height: 8),
                    _TablesGrid(tables: state.tables, state: state),
                    const SizedBox(height: 16),
                  ],

                  // ── المشروبات ─────────────────────────────────────────
                  if (state.drinkTables.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.local_drink,
                      title: 'المشروبات',
                      color: Colors.orange,
                      badge:
                          '${state.drinkTables.where((t) => (t['orders'] as Map? ?? {}).isNotEmpty).length}/${state.drinkTables.length} فيها طلبات',
                    ),
                    const SizedBox(height: 8),
                    _DrinkGrid(
                        drinkTables: state.drinkTables, menu: state.menu),
                    const SizedBox(height: 16),
                  ],

                  // ── إحصائيات سريعة ───────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _QuickStat(
                        icon: Icons.money_off,
                        title: 'المديونيات',
                        value: '${totalDebt.toStringAsFixed(0)} ج',
                        sub: '${unpaidDebts.length} غير مسددة',
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickStat(
                        icon: Icons.emoji_events,
                        title: 'البطولات',
                        value: '${activeTournaments.length}',
                        sub: 'جارية الآن',
                        color: const Color(0xFFfbbf24),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── المخزون ──────────────────────────────────────────
                  if (state.inventory.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.inventory_2,
                      title: 'تنبيهات المخزون',
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 8),
                    _InventoryPanel(
                        inventory: state.inventory, menu: state.menu),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// بطاقة الإيرادات الرئيسية
// ══════════════════════════════════════════════════════════════════════════════

class _RevenueCard extends StatelessWidget {
  final double todayTotal, todayTime, todayBuffet, liveRevenue;
  final int sessionsCount;

  const _RevenueCard({
    required this.todayTotal,
    required this.todayTime,
    required this.todayBuffet,
    required this.liveRevenue,
    required this.sessionsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0f2744),
            const Color(0xFF0a1628),
            const Color(0xFF0d1f38),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF38bdf8).withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38bdf8).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── هيدر ────────────────────────────────────────────────────
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF38bdf8).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF38bdf8).withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ade80),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('اليوم',
                    style: TextStyle(
                        color: Color(0xFF38bdf8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            const Spacer(),
            Text(
              '$sessionsCount جلسة',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 16),

          // ── الرقم الكبير ─────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              todayTotal.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFF4ade80),
                fontSize: 44,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 6, right: 4),
              child: Text(' ج',
                  style: TextStyle(
                      color: Color(0xFF4ade80),
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            if (liveRevenue > 0) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ade80).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF4ade80).withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.trending_up,
                      color: Color(0xFF4ade80), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '+${liveRevenue.toStringAsFixed(0)} ج',
                    style: const TextStyle(
                        color: Color(0xFF4ade80),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          const Text('إجمالي إيرادات اليوم',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 16),

          // ── شريط التقسيم ─────────────────────────────────────────────
          if (todayTotal > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(children: [
                Flexible(
                  flex: todayTime > 0 ? todayTime.round() : 1,
                  child: Container(
                    height: 6,
                    color: const Color(0xFF38bdf8),
                  ),
                ),
                Flexible(
                  flex: todayBuffet > 0 ? todayBuffet.round() : 1,
                  child: Container(
                    height: 6,
                    color: Colors.orange,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // ── تفاصيل ───────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _RevDetail(
                color: const Color(0xFF38bdf8),
                label: '🎮 اللعب',
                value: '${todayTime.toStringAsFixed(1)} ج',
              ),
            ),
            Container(
                width: 1, height: 36, color: Colors.white12),
            Expanded(
              child: _RevDetail(
                color: Colors.orange,
                label: '🥤 البوفيه',
                value: '${todayBuffet.toStringAsFixed(1)} ج',
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _RevDetail extends StatelessWidget {
  final Color color;
  final String label, value;
  const _RevDetail(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// زرار الشيفتات
// ══════════════════════════════════════════════════════════════════════════════

class _ShiftsButton extends StatelessWidget {
  final int shiftsCount;
  const _ShiftsButton({required this.shiftsCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ShiftHistoryScreen())),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1c1a2e),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFFa78bfa).withOpacity(0.4)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFa78bfa).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_turned_in_outlined,
                color: Color(0xFFa78bfa), size: 18),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('تقارير الشيفتات',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            Text('$shiftsCount شيفت مسجل',
                style: const TextStyle(
                    color: Color(0xFFa78bfa), fontSize: 12)),
          ]),
          const Spacer(),
          const Icon(Icons.chevron_right,
              color: Color(0xFFa78bfa), size: 20),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section Title
// ══════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String? badge;
  const _SectionTitle(
      {required this.icon,
      required this.title,
      required this.color,
      this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13)),
      const Spacer(),
      if (badge != null)
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(badge!,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Devices Grid (محسّن)
// ══════════════════════════════════════════════════════════════════════════════

class _DevicesGrid extends StatelessWidget {
  final List devices;
  final Map<String, int> prices;
  const _DevicesGrid({required this.devices, required this.prices});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (ctx, i) {
        final d = devices[i];
        final isPs5 = d.deviceType == 'ps5';
        final color = d.isPaused
            ? Colors.amber
            : d.isActive
                ? (isPs5 ? Colors.purple : const Color(0xFF38bdf8))
                : Colors.white24;

        final livePrice = d.isActive
            ? d.calculateTimePrice(prices) + d.getBuffetPrice({})
            : 0.0;

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: d.isActive
                ? color.withOpacity(0.08)
                : const Color(0xFF131820),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(d.isActive ? 0.5 : 0.15),
                width: d.isActive ? 1.5 : 1),
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPs5 ? 'PS5' : 'PS4',
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(d.displayName,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  d.isPaused
                      ? 'وقف'
                      : d.isActive
                          ? d.timerText
                          : 'فاضي',
                  style: TextStyle(
                      color: color,
                      fontSize: d.isActive ? 10 : 11,
                      fontWeight: FontWeight.bold,
                      fontFeatures: d.isActive
                          ? const [FontFeature.tabularFigures()]
                          : null),
                ),
              ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tables Grid
// ══════════════════════════════════════════════════════════════════════════════

class _TablesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> tables;
  final AppState state;
  const _TablesGrid({required this.tables, required this.state});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tables.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (ctx, i) {
        final t = tables[i];
        final isActive = t['start_time'] != null;
        final isPaused = t['is_paused'] == true;
        final tableType = t['table_type'] ?? 'ping';
        final color = isPaused
            ? Colors.amber
            : isActive
                ? const Color(0xFF34d399)
                : Colors.white24;
        final emoji = tableType == 'billiard' ? '🎱' : '🏓';

        final elapsed = isActive ? state.tableElapsed(i) : 0;
        final h = elapsed ~/ 3600;
        final m = (elapsed % 3600) ~/ 60;
        final s = elapsed % 60;
        final timerStr = isActive
            ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
            : '';

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? color.withOpacity(0.08)
                : const Color(0xFF131820),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(isActive ? 0.5 : 0.15),
                width: isActive ? 1.5 : 1),
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 3),
                Text(t['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  isPaused
                      ? 'وقف'
                      : isActive
                          ? timerStr
                          : 'فاضية',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Drink Grid
// ══════════════════════════════════════════════════════════════════════════════

class _DrinkGrid extends StatelessWidget {
  final List<Map<String, dynamic>> drinkTables;
  final Map<String, int> menu;
  const _DrinkGrid({required this.drinkTables, required this.menu});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: drinkTables.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (ctx, i) {
        final t = drinkTables[i];
        final orders = Map<String, int>.from(t['orders'] ?? {});
        final hasBusy = orders.isNotEmpty;
        double total = 0;
        orders.forEach((item, qty) => total += qty * (menu[item] ?? 0));
        final color = hasBusy ? Colors.orange : Colors.white24;

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasBusy
                ? Colors.orange.withOpacity(0.08)
                : const Color(0xFF131820),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(hasBusy ? 0.5 : 0.15),
                width: hasBusy ? 1.5 : 1),
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_drink, color: color, size: 14),
                const SizedBox(height: 3),
                Text(t['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  hasBusy
                      ? '${total.toStringAsFixed(0)} ج'
                      : 'فاضية',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Quick Stat Card
// ══════════════════════════════════════════════════════════════════════════════

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String title, value, sub;
  final Color color;
  const _QuickStat({
    required this.icon,
    required this.title,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(sub,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
              ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Inventory Panel
// ══════════════════════════════════════════════════════════════════════════════

class _InventoryPanel extends StatelessWidget {
  final Map<String, int> inventory;
  final Map<String, int> menu;
  const _InventoryPanel(
      {required this.inventory, required this.menu});

  @override
  Widget build(BuildContext context) {
    final low = inventory.entries
        .where((e) => e.value <= 3 && menu.containsKey(e.key))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (low.isEmpty) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0d1f1a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF4ade80).withOpacity(0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.check_circle_outline,
              color: Color(0xFF4ade80), size: 16),
          SizedBox(width: 8),
          Text('المخزون كويس ✅',
              style: TextStyle(
                  color: Color(0xFF4ade80), fontSize: 13)),
        ]),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: low.map((e) {
        final color = e.value == 0 ? Colors.red : Colors.orange;
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 13),
            const SizedBox(width: 5),
            Text(e.key,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                e.value == 0 ? 'نفد!' : '${e.value} قطعة',
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Nav Button
// ══════════════════════════════════════════════════════════════════════════════

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  const _NavBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHARTS SCREEN — شاشة الإحصائيات والرسوم البيانية
// ══════════════════════════════════════════════════════════════════════════════

class ChartsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  const ChartsScreen({super.key, required this.history});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── تجميع البيانات حسب اليوم ─────────────────────────────────────────────
  Map<String, Map<String, double>> _getDailyData() {
    final Map<String, Map<String, double>> daily = {};
    for (final h in widget.history) {
      final dateStr = h['date']?.toString() ?? '';
      if (dateStr.length < 10) continue;
      final day = dateStr.substring(0, 10);
      daily.putIfAbsent(day, () => {'time': 0, 'buffet': 0, 'total': 0});
      daily[day]!['time'] =
          (daily[day]!['time'] ?? 0) + ((h['time_cost'] as num?) ?? 0);
      daily[day]!['buffet'] =
          (daily[day]!['buffet'] ?? 0) + ((h['buffet_cost'] as num?) ?? 0);
      daily[day]!['total'] =
          (daily[day]!['total'] ?? 0) + ((h['total'] as num?) ?? 0);
    }
    return daily;
  }

  Map<String, int> _getItemsSold() {
    final Map<String, int> items = {};
    for (final h in widget.history) {
      final orders = h['orders'] as Map?;
      orders?.forEach((k, v) {
        items[k.toString()] = (items[k.toString()] ?? 0) + ((v as num?)?.toInt() ?? 0);
      });
    }
    return items;
  }

  Map<String, int> _getDeviceSessions() {
    final Map<String, int> devices = {};
    for (final h in widget.history) {
      final name = h['name']?.toString();
      if (name != null) {
        devices[name] = (devices[name] ?? 0) + 1;
      }
    }
    return devices;
  }

  @override
  Widget build(BuildContext context) {
    final dailyData = _getDailyData();
    final itemsSold = _getItemsSold();
    final deviceSessions = _getDeviceSessions();

    final totalTime = widget.history
        .fold(0.0, (s, h) => s + ((h['time_cost'] as num?) ?? 0));
    final totalBuffet = widget.history
        .fold(0.0, (s, h) => s + ((h['buffet_cost'] as num?) ?? 0));
    final grandTotal = totalTime + totalBuffet;

    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B12),
        title: const Row(children: [
          Icon(Icons.bar_chart_rounded, color: Color(0xFFfbbf24), size: 20),
          SizedBox(width: 8),
          Text('الإحصائيات والمقارنات',
              style: TextStyle(
                  color: Color(0xFFfbbf24), fontWeight: FontWeight.bold)),
        ]),
        leading: const BackButton(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFfbbf24),
          labelColor: const Color(0xFFfbbf24),
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'الإيرادات'),
            Tab(text: 'البوفيه'),
            Tab(text: 'الأجهزة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── تاب الإيرادات ────────────────────────────────────────────
          _RevenueChartTab(
            dailyData: dailyData,
            totalTime: totalTime,
            totalBuffet: totalBuffet,
            grandTotal: grandTotal,
          ),
          // ── تاب البوفيه ──────────────────────────────────────────────
          _BuffetChartTab(itemsSold: itemsSold, totalBuffet: totalBuffet),
          // ── تاب الأجهزة ──────────────────────────────────────────────
          _DevicesChartTab(
              deviceSessions: deviceSessions,
              total: widget.history.length),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// تاب الإيرادات
// ══════════════════════════════════════════════════════════════════════════════

class _RevenueChartTab extends StatelessWidget {
  final Map<String, Map<String, double>> dailyData;
  final double totalTime, totalBuffet, grandTotal;
  const _RevenueChartTab({
    required this.dailyData,
    required this.totalTime,
    required this.totalBuffet,
    required this.grandTotal,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = dailyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final last7 = sorted.length > 7
        ? sorted.sublist(sorted.length - 7)
        : sorted;

    final maxVal = last7.isEmpty
        ? 1.0
        : last7
            .map((e) => e.value['total'] ?? 0.0)
            .reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── ملخص إجمالي ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF0f2744),
              const Color(0xFF0a1628),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF38bdf8).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ChartStat('🎮 لعب',
                  '${totalTime.toStringAsFixed(0)} ج',
                  const Color(0xFF38bdf8)),
              Container(
                  width: 1, height: 40, color: Colors.white12),
              _ChartStat('🥤 بوفيه',
                  '${totalBuffet.toStringAsFixed(0)} ج', Colors.orange),
              Container(
                  width: 1, height: 40, color: Colors.white12),
              _ChartStat('💰 إجمالي',
                  '${grandTotal.toStringAsFixed(0)} ج',
                  const Color(0xFF4ade80)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── عنوان الرسم ──────────────────────────────────────────────
        const Align(
          alignment: Alignment.centerRight,
          child: Text('آخر 7 أيام',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ),
        const SizedBox(height: 12),

        // ── Bar Chart ────────────────────────────────────────────────
        if (last7.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('لا يوجد بيانات كافية',
                  style: TextStyle(color: Colors.white38)),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: last7.map((entry) {
                final total = entry.value['total'] ?? 0.0;
                final time = entry.value['time'] ?? 0.0;
                final buffet = entry.value['buffet'] ?? 0.0;
                final ratio = maxVal > 0 ? total / maxVal : 0.0;
                final timeRatio = total > 0 ? time / total : 0.0;

                final dayLabel = entry.key.length >= 10
                    ? '${entry.key.substring(8, 10)}/${entry.key.substring(5, 7)}'
                    : entry.key;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // القيمة
                        Text(
                          '${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFF4ade80),
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        // الشريط
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                          child: SizedBox(
                            height: 180 * ratio,
                            child: Column(children: [
                              // قسم اللعب
                              Flexible(
                                flex: (timeRatio * 100).round(),
                                child: Container(
                                    color: const Color(0xFF38bdf8)),
                              ),
                              // قسم البوفيه
                              Flexible(
                                flex:
                                    ((1 - timeRatio) * 100).round(),
                                child: Container(
                                    color: Colors.orange
                                        .withOpacity(0.8)),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(dayLabel,
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 9)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 12),
        // legend
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Legend(color: const Color(0xFF38bdf8), label: 'لعب'),
          const SizedBox(width: 16),
          _Legend(color: Colors.orange, label: 'بوفيه'),
        ]),

        const SizedBox(height: 20),
        // ── نسبة اللعب vs البوفيه (دائرة) ──────────────────────────
        if (grandTotal > 0) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Text('توزيع الإيرادات',
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          const SizedBox(height: 16),
          _PieChart(
            timeValue: totalTime,
            buffetValue: totalBuffet,
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Pie Chart بسيط
// ══════════════════════════════════════════════════════════════════════════════

class _PieChart extends StatelessWidget {
  final double timeValue, buffetValue;
  const _PieChart({required this.timeValue, required this.buffetValue});

  @override
  Widget build(BuildContext context) {
    final total = timeValue + buffetValue;
    final timePct = total > 0 ? (timeValue / total * 100).round() : 0;
    final buffetPct = 100 - timePct;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomPaint(
          size: const Size(120, 120),
          painter: _PiePainter(ratio: timeValue / total),
        ),
        const SizedBox(width: 24),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PieLegend(
            color: const Color(0xFF38bdf8),
            label: '🎮 اللعب',
            value: '${timeValue.toStringAsFixed(0)} ج',
            pct: '$timePct%',
          ),
          const SizedBox(height: 12),
          _PieLegend(
            color: Colors.orange,
            label: '🥤 البوفيه',
            value: '${buffetValue.toStringAsFixed(0)} ج',
            pct: '$buffetPct%',
          ),
        ]),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  final double ratio;
  const _PiePainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 20.0;

    // خلفية
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // اللعب
    final timePaint = Paint()
      ..color = const Color(0xFF38bdf8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * ratio,
      false,
      timePaint,
    );

    // البوفيه
    final buffetPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + 2 * pi * ratio,
      2 * pi * (1 - ratio),
      false,
      buffetPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PieLegend extends StatelessWidget {
  final Color color;
  final String label, value, pct;
  const _PieLegend(
      {required this.color,
      required this.label,
      required this.value,
      required this.pct});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 12)),
        Row(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(width: 6),
          Text(pct,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ]),
      ]),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// تاب البوفيه
// ══════════════════════════════════════════════════════════════════════════════

class _BuffetChartTab extends StatelessWidget {
  final Map<String, int> itemsSold;
  final double totalBuffet;
  const _BuffetChartTab(
      {required this.itemsSold, required this.totalBuffet});

  @override
  Widget build(BuildContext context) {
    if (itemsSold.isEmpty) {
      return const Center(
        child: Text('لا يوجد مبيعات بوفيه',
            style: TextStyle(color: Colors.white38, fontSize: 16)),
      );
    }

    final sorted = itemsSold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalQty =
        sorted.fold(0, (s, e) => s + e.value);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── ملخص ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ChartStat('📦 إجمالي قطع', '$totalQty',
                  const Color(0xFF38bdf8)),
              Container(
                  width: 1, height: 36, color: Colors.white12),
              _ChartStat('💰 إيرادات',
                  '${totalBuffet.toStringAsFixed(0)} ج', Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Align(
          alignment: Alignment.centerRight,
          child: Text('أكتر الأصناف مبيعاً',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ),
        const SizedBox(height: 12),

        // ── قائمة الأصناف مع أشرطة ──────────────────────────────────
        ...sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final ratio = totalQty > 0 ? e.value / totalQty : 0.0;
          final medals = ['🥇', '🥈', '🥉'];
          final medal = i < 3 ? medals[i] : '${i + 1}';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131820),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: i == 0
                      ? Colors.amber.withOpacity(0.4)
                      : Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(medal,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${e.value} قطعة',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      i == 0 ? Colors.amber : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(ratio * 100).toStringAsFixed(1)}% من إجمالي المبيعات',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          );
        }),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// تاب الأجهزة
// ══════════════════════════════════════════════════════════════════════════════

class _DevicesChartTab extends StatelessWidget {
  final Map<String, int> deviceSessions;
  final int total;
  const _DevicesChartTab(
      {required this.deviceSessions, required this.total});

  @override
  Widget build(BuildContext context) {
    if (deviceSessions.isEmpty) {
      return const Center(
        child: Text('لا يوجد جلسات مسجلة',
            style: TextStyle(color: Colors.white38, fontSize: 16)),
      );
    }

    final sorted = deviceSessions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFF38bdf8),
      Colors.purple,
      const Color(0xFF34d399),
      Colors.orange,
      Colors.pink,
      Colors.amber,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── ملخص ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF38bdf8).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF38bdf8).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartStat('🎮 إجمالي الجلسات', '$total',
                  const Color(0xFF38bdf8)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Align(
          alignment: Alignment.centerRight,
          child: Text('أكتر الأجهزة استخداماً',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ),
        const SizedBox(height: 12),

        // ── Horizontal Bars ──────────────────────────────────────────
        ...sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final ratio = total > 0 ? e.value / total : 0.0;
          final color = colors[i % colors.length];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: color.withOpacity(0.5))),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  Text('${e.value} جلسة',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(ratio * 100).toStringAsFixed(1)}% من إجمالي الجلسات',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          );
        }),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _ChartStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ChartStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style:
              const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}
