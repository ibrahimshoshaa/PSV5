import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history;

    // ─── حسابات إجمالية ────────────────────────────────────────────────────
    final totalTime =
        history.fold(0.0, (s, h) => s + ((h['time_cost'] as num?)?.toDouble() ?? 0));
    final totalBuffet =
        history.fold(0.0, (s, h) => s + ((h['buffet_cost'] as num?)?.toDouble() ?? 0));
    final totalRevenue = totalTime + totalBuffet;
    final totalSessions = history.length;

    // ─── تصنيف حسب نوع الجهاز ───────────────────────────────────────────────
    final ps4Records =
        history.where((h) => h['device_type'] == 'ps4').toList();
    final ps5Records =
        history.where((h) => h['device_type'] == 'ps5').toList();
    final tableRecords =
        history.where((h) => h['device_type'] == 'table').toList();
    final drinkRecords =
        history.where((h) => h['device_type'] == 'drink_table').toList();
    final matchRecords =
        history.where((h) => h['is_match'] == true).toList();

    // ─── إحصاء الطلبات ──────────────────────────────────────────────────────
    final Map<String, int> allOrders = {};
    for (final rec in history) {
      final orders = rec['orders'] as Map?;
      if (orders != null) {
        orders.forEach((k, v) {
          allOrders[k.toString()] =
              (allOrders[k.toString()] ?? 0) + (v as int? ?? 0);
        });
      }
    }

    // ─── إحصاء حسب الكاشير ──────────────────────────────────────────────────
    final Map<String, _CashierStats> cashierMap = {};
    for (final rec in history) {
      final cashier = rec['cashier']?.toString() ?? 'غير محدد';
      cashierMap.putIfAbsent(cashier, () => _CashierStats(cashier));
      cashierMap[cashier]!.sessions++;
      cashierMap[cashier]!.revenue +=
          ((rec['total'] as num?)?.toDouble() ?? 0);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'تقرير اليوم المفصل',
          style: TextStyle(
              color: Color(0xFF38bdf8),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38bdf8),
          labelColor: const Color(0xFF38bdf8),
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'الملخص'),
            Tab(text: 'الأجهزة'),
            Tab(text: 'البوفيه'),
            Tab(text: 'الكاشير'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── تاب 1: الملخص ──────────────────────────────────────────────
          _SummaryTab(
            totalRevenue: totalRevenue,
            totalTime: totalTime,
            totalBuffet: totalBuffet,
            totalSessions: totalSessions,
            ps4Count: ps4Records.length,
            ps5Count: ps5Records.length,
            tableCount: tableRecords.length,
            drinkCount: drinkRecords.length,
            matchCount: matchRecords.length,
            history: history,
          ),

          // ── تاب 2: تفاصيل الأجهزة ───────────────────────────────────────
          _DevicesTab(
            ps4Records: ps4Records,
            ps5Records: ps5Records,
            tableRecords: tableRecords,
            drinkRecords: drinkRecords,
            matchRecords: matchRecords,
          ),

          // ── تاب 3: البوفيه والطلبات ─────────────────────────────────────
          _BuffetTab(
            allOrders: allOrders,
            totalBuffet: totalBuffet,
            menu: state.menu,
          ),

          // ── تاب 4: الكاشير ──────────────────────────────────────────────
          _CashierTab(
            cashierStats: cashierMap.values.toList()
              ..sort((a, b) => b.revenue.compareTo(a.revenue)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — الملخص
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryTab extends StatelessWidget {
  final double totalRevenue, totalTime, totalBuffet;
  final int totalSessions, ps4Count, ps5Count, tableCount, drinkCount,
      matchCount;
  final List<Map<String, dynamic>> history;

  const _SummaryTab({
    required this.totalRevenue,
    required this.totalTime,
    required this.totalBuffet,
    required this.totalSessions,
    required this.ps4Count,
    required this.ps5Count,
    required this.tableCount,
    required this.drinkCount,
    required this.matchCount,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    // توزيع الإيرادات بالساعة
    final Map<int, double> hourlyRevenue = {};
    for (final rec in history) {
      final dateStr = rec['date']?.toString() ?? '';
      if (dateStr.length >= 13) {
        final hour = int.tryParse(dateStr.substring(11, 13)) ?? 0;
        hourlyRevenue[hour] =
            (hourlyRevenue[hour] ?? 0) +
                ((rec['total'] as num?)?.toDouble() ?? 0);
      }
    }

    // أعلى ساعة إيراداً
    String peakHour = '—';
    if (hourlyRevenue.isNotEmpty) {
      final peak = hourlyRevenue.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      peakHour = '${peak.key}:00 (${peak.value.toStringAsFixed(0)} ج)';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // بطاقة الإجمالي الكبيرة
          _BigRevenueCard(
              totalRevenue: totalRevenue,
              totalTime: totalTime,
              totalBuffet: totalBuffet),
          const SizedBox(height: 14),

          // إحصاءات سريعة
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long,
                  label: 'عدد الجلسات',
                  value: '$totalSessions',
                  color: const Color(0xFF38bdf8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.schedule,
                  label: 'ذروة الإيراد',
                  value: peakHour,
                  color: Colors.amber,
                  smallValue: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // توزيع أنواع الجلسات
          _SectionHeader('توزيع الجلسات'),
          const SizedBox(height: 10),
          _SessionTypeGrid(
            ps4Count: ps4Count,
            ps5Count: ps5Count,
            tableCount: tableCount,
            drinkCount: drinkCount,
            matchCount: matchCount,
          ),
          const SizedBox(height: 14),

          // آخر 5 جلسات
          if (history.isNotEmpty) ...[
            _SectionHeader('آخر الجلسات'),
            const SizedBox(height: 8),
            ...history.reversed
                .take(5)
                .map((r) => _MiniSessionRow(record: r)),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — الأجهزة
// ══════════════════════════════════════════════════════════════════════════════

class _DevicesTab extends StatelessWidget {
  final List<Map<String, dynamic>> ps4Records, ps5Records, tableRecords,
      drinkRecords, matchRecords;

  const _DevicesTab({
    required this.ps4Records,
    required this.ps5Records,
    required this.tableRecords,
    required this.drinkRecords,
    required this.matchRecords,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          if (ps4Records.isNotEmpty)
            _DeviceTypeSection(
              icon: Icons.sports_esports,
              label: 'PS4',
              color: const Color(0xFF38bdf8),
              records: ps4Records,
            ),
          if (ps5Records.isNotEmpty)
            _DeviceTypeSection(
              icon: Icons.sports_esports,
              label: 'PS5',
              color: const Color(0xFF818cf8),
              records: ps5Records,
            ),
          if (matchRecords.isNotEmpty)
            _DeviceTypeSection(
              icon: Icons.sports_soccer,
              label: 'ماتشات سريعة',
              color: Colors.greenAccent,
              records: matchRecords,
            ),
          if (tableRecords.isNotEmpty)
            _DeviceTypeSection(
              icon: Icons.table_restaurant,
              label: 'طاولات اللعب',
              color: Colors.purpleAccent,
              records: tableRecords,
            ),
          if (drinkRecords.isNotEmpty)
            _DeviceTypeSection(
              icon: Icons.local_cafe,
              label: 'طاولات المشروبات',
              color: Colors.orange,
              records: drinkRecords,
            ),
          if (ps4Records.isEmpty &&
              ps5Records.isEmpty &&
              tableRecords.isEmpty &&
              drinkRecords.isEmpty &&
              matchRecords.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: Text('لا توجد جلسات اليوم',
                    style: TextStyle(color: Colors.white38)),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — البوفيه
// ══════════════════════════════════════════════════════════════════════════════

class _BuffetTab extends StatelessWidget {
  final Map<String, int> allOrders;
  final double totalBuffet;
  final Map<String, int> menu;

  const _BuffetTab({
    required this.allOrders,
    required this.totalBuffet,
    required this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = allOrders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // بطاقة إجمالي البوفيه
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1c2128), Color(0xFF1a2035)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text('إجمالي إيرادات البوفيه',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  '${totalBuffet.toStringAsFixed(1)} ج',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                Text('${allOrders.values.fold(0, (s, v) => s + v)} صنف مُباع',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (sorted.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: Text('لا توجد طلبات بوفيه اليوم',
                    style: TextStyle(color: Colors.white38)),
              ),
            )
          else ...[
            _SectionHeader('الأصناف الأكثر طلباً'),
            const SizedBox(height: 10),
            ...sorted.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value.key;
              final qty = entry.value.value;
              final price = menu[item] ?? 0;
              final total = qty * price;
              return _BuffetItemRow(
                  rank: rank, name: item, qty: qty, price: price, total: total);
            }),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — الكاشير
// ══════════════════════════════════════════════════════════════════════════════

class _CashierTab extends StatelessWidget {
  final List<_CashierStats> cashierStats;

  const _CashierTab({required this.cashierStats});

  @override
  Widget build(BuildContext context) {
    if (cashierStats.isEmpty) {
      return const Center(
        child: Text('لا توجد بيانات كاشير',
            style: TextStyle(color: Colors.white38)),
      );
    }

    final totalRevenue =
        cashierStats.fold(0.0, (s, c) => s + c.revenue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _SectionHeader('أداء الكاشير اليوم'),
          const SizedBox(height: 10),
          ...cashierStats.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final stats = entry.value;
            final pct =
                totalRevenue > 0 ? stats.revenue / totalRevenue : 0.0;
            return _CashierCard(
                rank: rank, stats: stats, percentage: pct);
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي الكلي',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                Text(
                  '${totalRevenue.toStringAsFixed(1)} ج',
                  style: const TextStyle(
                      color: Color(0xFF4ade80),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _BigRevenueCard extends StatelessWidget {
  final double totalRevenue, totalTime, totalBuffet;
  const _BigRevenueCard(
      {required this.totalRevenue,
      required this.totalTime,
      required this.totalBuffet});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1e3a4f), Color(0xFF0f2030)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38bdf8).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('إجمالي إيرادات اليوم',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            '${totalRevenue.toStringAsFixed(1)} ج',
            style: const TextStyle(
                color: Color(0xFF4ade80),
                fontSize: 42,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat('🎮 اللعب', totalTime, const Color(0xFF38bdf8)),
              Container(width: 1, height: 30, color: Colors.white12),
              _MiniStat('🥤 البوفيه', totalBuffet, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(1)} ج',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final bool smallValue;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: smallValue ? 13 : 22),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14),
      ),
    );
  }
}

class _SessionTypeGrid extends StatelessWidget {
  final int ps4Count, ps5Count, tableCount, drinkCount, matchCount;
  const _SessionTypeGrid({
    required this.ps4Count,
    required this.ps5Count,
    required this.tableCount,
    required this.drinkCount,
    required this.matchCount,
  });

  @override
  Widget build(BuildContext context) {
    final types = [
      _TypeEntry('PS4', ps4Count, Icons.sports_esports, const Color(0xFF38bdf8)),
      _TypeEntry('PS5', ps5Count, Icons.sports_esports, const Color(0xFF818cf8)),
      _TypeEntry('ماتش', matchCount, Icons.sports_soccer, Colors.greenAccent),
      _TypeEntry('طاولة', tableCount, Icons.table_restaurant, Colors.purpleAccent),
      _TypeEntry('مشروبات', drinkCount, Icons.local_cafe, Colors.orange),
    ].where((t) => t.count > 0).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types
          .map((t) => _TypeChip(entry: t))
          .toList(),
    );
  }
}

class _TypeEntry {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _TypeEntry(this.label, this.count, this.icon, this.color);
}

class _TypeChip extends StatelessWidget {
  final _TypeEntry entry;
  const _TypeChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: entry.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: entry.color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(entry.icon, color: entry.color, size: 16),
          const SizedBox(width: 6),
          Text(entry.label,
              style: TextStyle(color: entry.color, fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: entry.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${entry.count}',
                style: TextStyle(
                    color: entry.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _MiniSessionRow extends StatelessWidget {
  final Map<String, dynamic> record;
  const _MiniSessionRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateStr = record['date']?.toString() ?? '';
    final timeStr = dateStr.length > 16 ? dateStr.substring(11, 16) : '';
    final total = (record['total'] as num?)?.toDouble() ?? 0;
    final cashier = record['cashier']?.toString() ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              record['name']?.toString() ?? '—',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            cashier,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(width: 10),
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${total.toStringAsFixed(1)} ج',
            style: const TextStyle(
                color: Color(0xFF4ade80),
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DeviceTypeSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final List<Map<String, dynamic>> records;

  const _DeviceTypeSection({
    required this.icon,
    required this.label,
    required this.color,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final totalRev =
        records.fold(0.0, (s, r) => s + ((r['total'] as num?)?.toDouble() ?? 0));
    final totalTimeRev =
        records.fold(0.0, (s, r) => s + ((r['time_cost'] as num?)?.toDouble() ?? 0));
    final totalBuffRev =
        records.fold(0.0, (s, r) => s + ((r['buffet_cost'] as num?)?.toDouble() ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '${records.length} جلسة • ${totalRev.toStringAsFixed(1)} ج',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _DeviceStatMini('🎮 اللعب',
                            totalTimeRev, const Color(0xFF38bdf8))),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            _DeviceStatMini('🥤 البوفيه', totalBuffRev, Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _DeviceStatMini(
                            '💰 إجمالي', totalRev, const Color(0xFF4ade80))),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white12),
                ...records.map((r) {
                  final dateStr = r['date']?.toString() ?? '';
                  final timeStr =
                      dateStr.length > 16 ? dateStr.substring(11, 16) : '';
                  final total = (r['total'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(r['name']?.toString() ?? '—',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ),
                        Text(r['duration']?.toString() ?? '—',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                        const SizedBox(width: 10),
                        Text(timeStr,
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 11,
                              fontFeatures: [FontFeature.tabularFigures()],
                            )),
                        const SizedBox(width: 12),
                        Text('${total.toStringAsFixed(1)} ج',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatMini extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _DeviceStatMini(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 4),
          Text('${value.toStringAsFixed(1)}',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _BuffetItemRow extends StatelessWidget {
  final int rank, qty, price, total;
  final String name;
  const _BuffetItemRow({
    required this.rank,
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final Color rankColor = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.grey
            : rank == 3
                ? Colors.brown
                : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#$rank',
                style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Text('x$qty',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 12),
          Text('($price ج/وحدة)',
              style: const TextStyle(color: Colors.white24, fontSize: 11)),
          const SizedBox(width: 12),
          Text('${total} ج',
              style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _CashierStats {
  final String name;
  int sessions = 0;
  double revenue = 0;
  _CashierStats(this.name);
}

class _CashierCard extends StatelessWidget {
  final int rank;
  final _CashierStats stats;
  final double percentage;

  const _CashierCard(
      {required this.rank, required this.stats, required this.percentage});

  @override
  Widget build(BuildContext context) {
    final Color rankColor = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.grey
            : rank == 3
                ? Colors.brown
                : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: rankColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('#$rank',
                      style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stats.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text('${stats.sessions} جلسة',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stats.revenue.toStringAsFixed(1)} ج',
                    style: const TextStyle(
                        color: Color(0xFF4ade80),
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  Text(
                    '${(percentage * 100).toStringAsFixed(0)}% من الإجمالي',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4ade80)),
            ),
          ),
        ],
      ),
    );
  }
}
