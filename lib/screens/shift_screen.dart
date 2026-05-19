// lib/screens/shift_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/shift_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// شاشة بداية الشيفت — بتظهر بعد لوج إن الكاشير مباشرة
// ══════════════════════════════════════════════════════════════════════════════

class ShiftStartScreen extends StatelessWidget {
  final String cashierName;
  final VoidCallback onShiftStarted;

  const ShiftStartScreen({
    super.key,
    required this.cashierName,
    required this.onShiftStarted,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day}/${now.month}/${now.year}';

    // أول حرف من الاسم للأفاتار
    final initial =
        cashierName.isNotEmpty ? cashierName[0].toUpperCase() : 'K';

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── أيقونة الكاشير ──────────────────────────────────────────
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38bdf8).withOpacity(0.15),
                  border: Border.all(
                      color: const Color(0xFF38bdf8).withOpacity(0.5),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38bdf8).withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38bdf8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── الاسم ────────────────────────────────────────────────────
              Text(
                'أهلاً، $cashierName 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$dateStr  •  $timeStr',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 40),

              // ── بطاقة معلومات الشيفت ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1c2128),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF38bdf8).withOpacity(0.2)),
                ),
                child: Column(children: [
                  const Icon(Icons.access_time_filled,
                      color: Color(0xFF38bdf8), size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'جاهز تبدأ شيفتك؟',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'كل العمليات اللي هتعملها هتتسجل\nتحت اسمك في تقرير الشيفت',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                  ),
                ]),
              ),
              const SizedBox(height: 32),

              // ── زرار بداية الشيفت ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    context.read<AppState>().startShift(cashierName);
                    onShiftStarted();
                  },
                  icon: const Icon(Icons.play_circle_fill, size: 24),
                  label: const Text(
                    'بداية الشيفت',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38bdf8),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── رجوع للوجين ──────────────────────────────────────────────
              TextButton(
                onPressed: () => context.read<AppState>().logout(),
                child: const Text(
                  'مش أنا، رجوع',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ويدجت زرار إنهاء الشيفت — بيتضاف في AppBar الكاشير
// ══════════════════════════════════════════════════════════════════════════════

class EndShiftButton extends StatelessWidget {
  const EndShiftButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withOpacity(0.4)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.stop_circle_outlined, color: Colors.red, size: 16),
          SizedBox(width: 4),
          Text('إنهاء الشيفت',
              style: TextStyle(
                  color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
      onPressed: () => _confirmEndShift(context),
      tooltip: 'إنهاء الشيفت',
    );
  }

  void _confirmEndShift(BuildContext context) {
    final state = context.read<AppState>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.stop_circle_outlined, color: Colors.red),
          SizedBox(width: 8),
          Text('إنهاء الشيفت؟',
              style:
                  TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'هيتم حفظ تقرير الشيفت وتسجيل الخروج',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final shift = await state.endShift();
              if (context.mounted && shift != null) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ShiftReportDialog(shift: shift),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إنهاء وعرض التقرير'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ديالوج تقرير الشيفت
// ══════════════════════════════════════════════════════════════════════════════

class ShiftReportDialog extends StatelessWidget {
  final ShiftRecord shift;
  const ShiftReportDialog({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    final dur = shift.duration;
    final durStr =
        '${dur.inHours}س ${dur.inMinutes.remainder(60)}د';
    final startStr =
        '${shift.startTime.hour.toString().padLeft(2, '0')}:${shift.startTime.minute.toString().padLeft(2, '0')}';
    final endStr = shift.endTime != null
        ? '${shift.endTime!.hour.toString().padLeft(2, '0')}:${shift.endTime!.minute.toString().padLeft(2, '0')}'
        : '--:--';

    // أكتر 3 أصناف مبيعاً
    final itemsSorted = shift.itemsSold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = itemsSorted.take(3).toList();

    // أكتر 3 أجهزة شغلت
    final deviceCounts = <String, int>{};
    for (final t in shift.transactions) {
      final name = t['name'] as String?;
      if (name != null &&
          t['device_type'] != 'drink_table' &&
          t['is_match'] != true &&
          t['is_game'] != true) {
        deviceCounts[name] = (deviceCounts[name] ?? 0) + 1;
      }
    }
    final topDevices = deviceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3Devices = topDevices.take(3).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0b0e14),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFF38bdf8).withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── هيدر التقرير ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF38bdf8).withOpacity(0.15),
                    const Color(0xFF1c2128),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF38bdf8).withOpacity(0.15),
                      border: Border.all(
                          color: const Color(0xFF38bdf8).withOpacity(0.5)),
                    ),
                    child: Center(
                      child: Text(
                        shift.cashierName.isNotEmpty
                            ? shift.cashierName[0].toUpperCase()
                            : 'K',
                        style: const TextStyle(
                            color: Color(0xFF38bdf8),
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تقرير شيفت ${shift.cashierName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '$startStr → $endStr  •  $durStr',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ]),
                  ),
                  const Icon(Icons.receipt_long,
                      color: Color(0xFF38bdf8), size: 24),
                ]),
              ]),
            ),

            // ── المحتوى القابل للتمرير ────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── الإجماليات ────────────────────────────────────────
                    Row(children: [
                      Expanded(
                          child: _ReportStat(
                              label: '🎮 لعب',
                              value:
                                  '${shift.totalTime.toStringAsFixed(1)} ج',
                              color: const Color(0xFF38bdf8))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _ReportStat(
                              label: '🥤 بوفيه',
                              value:
                                  '${shift.totalBuffet.toStringAsFixed(1)} ج',
                              color: Colors.orange)),
                    ]),
                    const SizedBox(height: 8),

                    // ── الإجمالي الكبير ───────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ade80).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF4ade80).withOpacity(0.4)),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('💰 إجمالي الشيفت',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text(
                              '${shift.totalRevenue.toStringAsFixed(1)} ج',
                              style: const TextStyle(
                                  color: Color(0xFF4ade80),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 12),

                    // ── إحصائيات سريعة ───────────────────────────────────
                    Row(children: [
                      Expanded(
                          child: _MiniStat(
                              icon: Icons.receipt,
                              label: 'جلسات',
                              value: '${shift.sessionCount}')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _MiniStat(
                              icon: Icons.schedule,
                              label: 'مدة الشيفت',
                              value: durStr)),
                    ]),
                    const SizedBox(height: 16),

                    // ── أكتر أجهزة شغلت ──────────────────────────────────
                    if (top3Devices.isNotEmpty) ...[
                      _ReportSectionTitle(
                          '🎮 أكتر أجهزة اشتغلت',
                          const Color(0xFF38bdf8)),
                      const SizedBox(height: 8),
                      ...top3Devices.asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        return _RankRow(
                          rank: i + 1,
                          name: e.key,
                          value: '${e.value} جلسة',
                          color: const Color(0xFF38bdf8),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // ── أكتر أصناف اتباعت ────────────────────────────────
                    if (topItems.isNotEmpty) ...[
                      _ReportSectionTitle(
                          '🥤 أكتر أصناف اتباعت',
                          Colors.orange),
                      const SizedBox(height: 8),
                      ...topItems.asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        return _RankRow(
                          rank: i + 1,
                          name: e.key,
                          value: '${e.value} قطعة',
                          color: Colors.orange,
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // ── تفاصيل الجلسات ────────────────────────────────────
                    _ReportSectionTitle(
                        '📋 تفاصيل الجلسات',
                        const Color(0xFF4ade80)),
                    const SizedBox(height: 8),

                    if (shift.transactions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('لا يوجد جلسات في هذا الشيفت',
                              style: TextStyle(color: Colors.white38)),
                        ),
                      )
                    else
                      ...shift.transactions.reversed.map((t) =>
                          _TransactionRow(transaction: t)),
                  ],
                ),
              ),
            ),

            // ── زرار الإغلاق ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<AppState>().logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج',
                      style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38bdf8),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// شاشة تقارير الشيفتات للأدمن
// ══════════════════════════════════════════════════════════════════════════════

class ShiftHistoryScreen extends StatelessWidget {
  const ShiftHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final shifts = state.shiftsHistory.reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text(
          'تقارير الشيفتات',
          style: TextStyle(
              color: Color(0xFF38bdf8), fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (shifts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: 'مسح كل التقارير',
              onPressed: () => _confirmClearAll(context, state),
            ),
        ],
      ),
      body: shifts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 64, color: Colors.white12),
                  SizedBox(height: 16),
                  Text('لا يوجد شيفتات مسجلة',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: shifts.length,
              itemBuilder: (ctx, i) {
                final shift = shifts[i];
                return _ShiftCard(shift: shift);
              },
            ),
    );
  }

  void _confirmClearAll(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('مسح كل التقارير؟',
            style: TextStyle(color: Colors.red)),
        content: const Text('هيتم حذف كل تقارير الشيفتات نهائياً',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.clearShiftsHistory();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final ShiftRecord shift;
  const _ShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final dur = shift.duration;
    final durStr =
        '${dur.inHours}س ${dur.inMinutes.remainder(60)}د';
    final startStr =
        '${shift.startTime.hour.toString().padLeft(2, '0')}:${shift.startTime.minute.toString().padLeft(2, '0')}';
    final endStr = shift.endTime != null
        ? '${shift.endTime!.hour.toString().padLeft(2, '0')}:${shift.endTime!.minute.toString().padLeft(2, '0')}'
        : 'جاري';
    final dateStr =
        '${shift.startTime.day}/${shift.startTime.month}/${shift.startTime.year}';

    // حساب أكتر 5 أصناف مبيعاً
    final itemsSorted = shift.itemsSold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = itemsSorted.take(5).toList();

    // حساب أكتر 5 أجهزة شغلت
    final deviceCounts = <String, int>{};
    for (final t in shift.transactions) {
      final name = t['name'] as String?;
      if (name != null &&
          t['device_type'] != 'drink_table' &&
          t['is_match'] != true &&
          t['is_game'] != true) {
        deviceCounts[name] = (deviceCounts[name] ?? 0) + 1;
      }
    }
    final topDevices = deviceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Devices = topDevices.take(5).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: shift.isOpen
                ? Colors.green.withOpacity(0.4)
                : Colors.white10),
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF38bdf8).withOpacity(0.12),
            border: Border.all(
                color: const Color(0xFF38bdf8).withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              shift.cashierName.isNotEmpty
                  ? shift.cashierName[0].toUpperCase()
                  : 'K',
              style: const TextStyle(
                  color: Color(0xFF38bdf8),
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ),
        ),
        title: Row(children: [
          Text(shift.cashierName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          if (shift.isOpen) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('جاري',
                  style: TextStyle(color: Colors.green, fontSize: 10)),
            ),
          ],
        ]),
        subtitle: Text(
          '$dateStr  •  $startStr → $endStr  •  $durStr',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: Text(
          '${shift.totalRevenue.toStringAsFixed(1)} ج',
          style: const TextStyle(
              color: Color(0xFF4ade80),
              fontWeight: FontWeight.bold,
              fontSize: 15),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── إجماليات ──────────────────────────────────────────
                Row(children: [
                  Expanded(
                      child: _MiniStat(
                          icon: Icons.sports_esports,
                          label: 'لعب',
                          value:
                              '${shift.totalTime.toStringAsFixed(1)} ج')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MiniStat(
                          icon: Icons.fastfood,
                          label: 'بوفيه',
                          value:
                              '${shift.totalBuffet.toStringAsFixed(1)} ج')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MiniStat(
                          icon: Icons.receipt,
                          label: 'جلسات',
                          value: '${shift.sessionCount}')),
                ]),
                const SizedBox(height: 16),

                // ── أكتر الأجهزة اللي اشتغلت ───────────────────────────
                if (top5Devices.isNotEmpty) ...[
                  _ReportSectionTitle('🎮 أكتر أجهزة اشتغلت', const Color(0xFF38bdf8)),
                  const SizedBox(height: 8),
                  ...top5Devices.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return _RankRow(
                      rank: i + 1,
                      name: e.key,
                      value: '${e.value} جلسة',
                      color: const Color(0xFF38bdf8),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // ── أكتر الأصناف اللي اتباعت ───────────────────────────
                if (topItems.isNotEmpty) ...[
                  _ReportSectionTitle('🥤 أكتر أصناف اتباعت', Colors.orange),
                  const SizedBox(height: 8),
                  ...topItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return _RankRow(
                      rank: i + 1,
                      name: e.key,
                      value: '${e.value} قطعة',
                      color: Colors.orange,
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // ── كل التفاصيل والجلسات ───────────────────────────────
                _ReportSectionTitle('📋 كل تفاصيل الجلسات', const Color(0xFF4ade80)),
                const SizedBox(height: 8),
                const Divider(color: Colors.white12),
                if (shift.transactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا يوجد جلسات مسجلة',
                          style: TextStyle(color: Colors.white38)),
                    ),
                  )
                else
                  // عرض كل الجلسات بالكامل بدون حد أقصى
                  ...shift.transactions.reversed
                      .map((t) => _TransactionRow(transaction: t)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ReportStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(height: 4),
        Text(label,
            style:
                const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white)),
      ]),
    );
  }
}

class _ReportSectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _ReportSectionTitle(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 13));
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final Color color;
  const _RankRow(
      {required this.rank,
      required this.name,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(rank <= 5 ? medals[rank - 1] : '$rank',
            style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13))),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final name = transaction['name'] as String? ?? '';
    final total =
        ((transaction['total'] as num?) ?? 0).toStringAsFixed(1);
    final dateStr =
        transaction['date']?.toString().substring(11, 16) ?? '';
    final isMatch = transaction['is_match'] == true;
    final isGame = transaction['is_game'] == true;
    final isDrink = transaction['device_type'] == 'drink_table';

    IconData icon;
    Color color;
    if (isDrink) {
      icon = Icons.local_drink;
      color = Colors.orange;
    } else if (isMatch) {
      icon = Icons.sports_soccer;
      color = const Color(0xFF4ade80);
    } else if (isGame) {
      icon = Icons.sports_golf;
      color = Colors.purple;
    } else {
      icon = Icons.sports_esports;
      color = const Color(0xFF38bdf8);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70))),
        Text(dateStr,
            style:
                const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(width: 8),
        Text('$total ج',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ]),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text(label,
            style:
                const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(width: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ]),
    );
  }
}
