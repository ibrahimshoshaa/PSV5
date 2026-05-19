import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'archive_screen.dart';
import 'daily_report_screen.dart'; // ✅ استيراد شاشة التقرير اليومي

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history.reversed.toList();
    final totalTime =
        state.history.fold(0.0, (s, h) => s + (h['time_cost'] ?? 0));
    final totalBuffet =
        state.history.fold(0.0, (s, h) => s + (h['buffet_cost'] ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('سجلات اليوم',
            style: TextStyle(
                color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          // ✅ زرار التقرير المفصل
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Color(0xFFf59e0b)),
            tooltip: 'تقرير اليوم المفصل',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DailyReportScreen()),
            ),
          ),
          // زرار أرشفة اليوم
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Color(0xFF4ade80)),
            tooltip: 'أرشفة وتصفير اليوم',
            onPressed: history.isEmpty
                ? null
                : () => _confirmArchive(context, state),
          ),
          IconButton(
            icon: const Icon(Icons.history_edu, color: Colors.white54),
            tooltip: 'الأرشيف الشامل',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ArchiveScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem('🎮 اللعب', totalTime, const Color(0xFF38bdf8)),
                Container(width: 1, height: 30, color: Colors.white12),
                _SummaryItem('🥤 البوفيه', totalBuffet, Colors.orange),
                Container(width: 1, height: 30, color: Colors.white12),
                _SummaryItem('💰 الإجمالي', totalTime + totalBuffet, const Color(0xFF4ade80)),
              ],
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text('لا توجد سجلات لليوم بعد',
                        style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: history.length,
                    itemBuilder: (ctx, i) => _HistoryItem(record: history[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmArchive(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('أرشفة وتصفير اليوم؟',
            style: TextStyle(color: Color(0xFF4ade80))),
        content: const Text(
            'هيتم حفظ سجلات اليوم في الأرشيف الشامل وتصفير السجلات',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await state.archiveAndClear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? '✅ تم الأرشفة بنجاح' : '❌ فشل الأرشفة'),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ));
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4ade80),
                foregroundColor: Colors.black),
            child: const Text('أرشفة'),
          ),
        ],
      ),
    );
  }
}


class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SummaryItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(1)} ج',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> record;
  const _HistoryItem({required this.record});

  @override
  Widget build(BuildContext context) {
    final isTable = record['device_type'] == 'table';
    final isDrink = record['device_type'] == 'drink_table';
    final isMatch = record['is_match'] == true;
    final isGame = record['is_game'] == true;

    Color typeColor = const Color(0xFF38bdf8);
    IconData icon = Icons.sports_esports;

    if (isTable) {
      typeColor = Colors.purpleAccent;
      icon = Icons.table_restaurant;
    } else if (isDrink) {
      typeColor = Colors.orange;
      icon = Icons.local_cafe;
    } else if (isMatch) {
      typeColor = Colors.green;
      icon = Icons.sports_soccer;
    }

    final dateStr = record['date'] as String? ?? '';
    final timeStr = dateStr.length > 16 ? dateStr.substring(11, 16) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: typeColor, size: 20),
        ),
        title: Text(record['name'] ?? 'جهاز',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          isMatch || isGame ? 'جيم سريع' : '${record['duration'] ?? ''} • $timeStr',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: Text('${(record['total'] ?? 0).toStringAsFixed(1)} ج',
            style: const TextStyle(
                color: Color(0xFF4ade80),
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _DetailRow(isTable ? '🎱 التربيزة' : '🎮 اللعب',
                    '${(record['time_cost'] ?? 0).toStringAsFixed(1)} ج'),
                _DetailRow('🥤 البوفيه',
                    '${(record['buffet_cost'] ?? 0).toStringAsFixed(1)} ج'),

                // تفاصيل الطلبات
                if ((record['orders'] as Map?)?.isNotEmpty == true) ...[
                  const Divider(color: Colors.white12),
                  ...(record['orders'] as Map).entries.map((e) =>
                      _DetailRow('  • ${e.key}', 'x${e.value}')),
                ],

                // ✅ سجل الجلسة
                if (record['session_log'] != null &&
                    (record['session_log'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('📋 سجل الجلسة',
                        style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  ...(record['session_log'] as List)
                      .map((ev) => _LogEntryRow(event: ev)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ✅ ويدجت عرض حركة واحدة في سجل الجلسة
class _LogEntryRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _LogEntryRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String;
    final time = event['time'] as String? ?? '';
    final note = event['note'] as String? ?? '';
    final role = event['role'] as String? ?? '';

    Color c;
    switch (type) {
      case 'start':
        c = Colors.green;
        break;
      case 'pause':
        c = Colors.amber;
        break;
      case 'resume':
        c = const Color(0xFF38bdf8);
        break;
      case 'add_time':
        final m = event['minutes'] as int? ?? 0;
        c = m > 0 ? const Color(0xFF4ade80) : Colors.redAccent;
        break;
      case 'stop':
        c = Colors.red;
        break;
      default:
        c = Colors.white38;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: c.withOpacity(0.8), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$note${role.isNotEmpty ? " ($role)" : ""}',
              style: TextStyle(color: c.withOpacity(0.9), fontSize: 11),
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
