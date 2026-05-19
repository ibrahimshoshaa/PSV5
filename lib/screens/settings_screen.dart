import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/device.dart';
import '../widgets/match_price_card.dart';
import 'cashiers_screen.dart';
import '../widgets/subscription_card.dart';
import 'shift_screen.dart'; // ✅ استيراد شاشة تقارير الشيفتات

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isAdmin = state.isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('الإعدادات',
            style: TextStyle(
                color: Color(0xFF38bdf8),
                fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

			// ─── الاشتراك (compact) ────────────────────────────────────
		if (state.subscriptionExpiry != null) ...[
		  _SubscriptionBanner(state: state),
		  const SizedBox(height: 20),
		],
			
          // ─── اسم المحل ─────────────────────────────────────────────
          if (isAdmin) ...[
            _SectionHeader('🏪 المحل'),
            const SizedBox(height: 8),
            _SettingCard(
              icon: Icons.storefront,
              title: 'اسم المحل',
              subtitle: state.shopName,
              color: const Color(0xFF38bdf8),
              onTap: () => _showShopNameDialog(context),
            ),
            const SizedBox(height: 20),
          ],
		

          // ─── إدارة الأجهزة ─────────────────────────────────────────
          _SectionHeader('🎮 إدارة الأجهزة'),
          const SizedBox(height: 8),
          if (isAdmin)
            _SettingCard(
              icon: Icons.sports_esports,
              title: 'إدارة الأجهزة',
              subtitle: '${state.devices.length} أجهزة | أسعار | ماتشات',
              color: const Color(0xFFfbbf24),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _DeviceSettingsScreen())),
            )
          else
            _LockedCard('إدارة الأجهزة والأسعار'),

          const SizedBox(height: 20),

          // ─── إدارة البوفيه ─────────────────────────────────────────
          _SectionHeader('🥤 إدارة البوفيه'),
          const SizedBox(height: 8),
          if (isAdmin)
            _SettingCard(
              icon: Icons.fastfood,
              title: 'منتجات البوفيه',
              subtitle: '${state.menu.length} منتجات | المخزون متاح',
              color: Colors.orange,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _MenuManagementScreen())),
            )
          else
            _LockedCard('إدارة البوفيه'),

          const SizedBox(height: 20),


	// ─── المخزن ────────────────────────────────────────────────────────
   	
          // ─── إدارة التربيزات ───────────────────────────────────────
          _SectionHeader('🎱 إدارة التربيزات'),
          const SizedBox(height: 8),
          if (isAdmin)
            _SettingCard(
              icon: Icons.table_bar,
              title: 'تربيزات بنج / بلياردو',
              subtitle: '${state.tables.length} تربيزات',
              color: const Color(0xFF34d399),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _TablesManagementScreen())),
            )
          else
            _LockedCard('إدارة التربيزات'),

          const SizedBox(height: 20),

          // ─── إدارة تربيزات المشروبات ───────────────────────────────
          _SectionHeader('🍹 إدارة تربيزات المشروبات'),
          const SizedBox(height: 8),
          if (isAdmin)
            _SettingCard(
              icon: Icons.local_drink,
              title: 'تربيزات المشروبات',
              subtitle: '${state.drinkTables.length} تربيزات',
              color: Colors.orange,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _DrinkTablesManagementScreen())),
            )
          else
            _LockedCard('إدارة تربيزات المشروبات'),

          const SizedBox(height: 20),

          // ✅ ─── تقارير الشيفتات ──────────────────────────────────────
          

          // ─── كلمات السر ────────────────────────────────────────────
          if (isAdmin) ...[
            _SectionHeader('🔐 كلمات السر'),
            const SizedBox(height: 8),
            _SettingCard(
              icon: Icons.lock,
              title: 'كلمة سر الأدمن',
              subtitle: 'تغيير باسورد الأدمن',
              color: Colors.redAccent,
              onTap: () => _showPasswordDialog(context, isAdmin: true),
            ),
            const SizedBox(height: 20),

            // ✅ قسم جديد — إدارة الكاشيرين
            _SectionHeader('🧾 إدارة الكاشيرين'),
            const SizedBox(height: 8),
            _SettingCard(
              icon: Icons.people,
              title: 'الكاشيرين',
              subtitle: '${state.cashiers.length} كاشير | أضف، عدّل، احذف',
              color: const Color(0xFF38bdf8),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CashiersScreen())),
            ),
          ] else
            _LockedCard('تغيير كلمات السر'),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─── Add Device Dialog ────────────────────────────────────────────

  void _showAddDeviceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String selectedType = 'ps4';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.add_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('إضافة جهاز',
                style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: _inputDeco('اسم الجهاز'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Text('النوع:',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 12),
                _TypeChip(
                  label: 'PS4',
                  selected: selectedType == 'ps4',
                  color: const Color(0xFF38bdf8),
                  onTap: () => setState(() => selectedType = 'ps4'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'PS5',
                  selected: selectedType == 'ps5',
                  color: Colors.purple,
                  onTap: () => setState(() => selectedType = 'ps5'),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                context
                    .read<AppState>()
                    .addDevice(name, selectedType);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.green),
              child: const Text('إضافة',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showShopNameDialog(BuildContext context) {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(text: state.shopName);
    showDialog(
      context: context,
      builder: (_) => _Dialog(
        title: 'اسم المحل',
        icon: Icons.storefront,
        color: const Color(0xFF38bdf8),
        child:
            TextField(controller: ctrl, decoration: _inputDeco('اسم المحل')),
        onSave: () {
          if (ctrl.text.trim().isEmpty) return false;
          state.updateShopName(ctrl.text.trim());
          return true;
        },
      ),
    );
  }

  void _showMatchPriceDialog(BuildContext context) {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(
        text: '${state.prices['match_price'] ?? 10}');
    showDialog(
      context: context,
      builder: (_) => _Dialog(
        title: 'سعر الماتش',
        icon: Icons.sports_soccer,
        color: const Color(0xFF4ade80),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('سعر الماتش الواحد (ج)')),
          const SizedBox(height: 8),
          const Text(
              'مدة الماتش بتتحسب تلقائي على أساس السعر/ساعة',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
        onSave: () {
          final v = int.tryParse(ctrl.text);
          if (v != null && v > 0) {
            final newPrices = Map<String, int>.from(state.prices);
            newPrices['match_price'] = v;
            state.updatePrices(newPrices);
          }
        },
      ),
    );
  }

  void _showPricesDialog(BuildContext context, String type) {
    final state = context.read<AppState>();
    final label = type == 'ps5' ? 'PS5' : 'PS4';
    final color =
        type == 'ps5' ? Colors.purple : const Color(0xFF38bdf8);
    final normalCtrl = TextEditingController(
        text:
            '${state.prices['${type}_normal'] ?? (type == 'ps5' ? 40 : 25)}');
    final multiCtrl = TextEditingController(
        text:
            '${state.prices['${type}_multi'] ?? (type == 'ps5' ? 50 : 35)}');
    showDialog(
      context: context,
      builder: (_) => _Dialog(
        title: 'أسعار $label',
        icon: Icons.attach_money,
        color: color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: normalCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('سعر عادي (ج/س)')),
            const SizedBox(height: 12),
            TextField(
                controller: multiCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDeco('سعر مالتي (ج/س)')),
          ],
        ),
        onSave: () {
          final n = int.tryParse(normalCtrl.text);
          final m = int.tryParse(multiCtrl.text);
          if (n != null && m != null) {
            final newPrices = Map<String, int>.from(state.prices);
            newPrices['${type}_normal'] = n;
            newPrices['${type}_multi'] = m;
            state.updatePrices(newPrices);
          }
        },
      ),
    );
  }

  void _showPasswordDialog(BuildContext context,
      {required bool isAdmin}) {
    final state = context.read<AppState>();
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    String? error;
    final label = isAdmin ? 'الأدمن' : 'الكاشير';
    final color =
        isAdmin ? Colors.redAccent : const Color(0xFF38bdf8);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => _Dialog(
          title: 'كلمة سر $label',
          icon: Icons.lock,
          color: color,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: oldCtrl,
                  obscureText: true,
                  decoration: _inputDeco('الباسورد القديم')),
              const SizedBox(height: 12),
              TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: _inputDeco('الباسورد الجديد')),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          onSave: () {
            final currentHash = isAdmin
                ? state.adminPasswordHash
                : state.cashierPasswordHash;
            if (AppState.hashPassword(oldCtrl.text) !=
                currentHash) {
              setState(() => error = '❌ الباسورد القديم غلط!');
              return false;
            }
            if (newCtrl.text.length < 4) {
              setState(
                  () => error = '❌ الباسورد قصير جداً');
              return false;
            }
            if (isAdmin) {
              state.changePassword(newCtrl.text);
            } else {
              state.changeCashierPassword(newCtrl.text);
            }
            return true;
          },
        ),
      ),
    );
  }
}

// ─── Device Settings Screen ───────────────────────────────────────────────────

class _DeviceSettingsScreen extends StatelessWidget {
  const _DeviceSettingsScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('إدارة الأجهزة',
            style: TextStyle(
                color: Color(0xFFfbbf24), fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── الأجهزة ───────────────────────────────────────────────
          _SectionHeader('🎮 الأجهزة'),
          const SizedBox(height: 8),
          _SettingCard(
            icon: Icons.sports_esports,
            title: 'الأجهزة',
            subtitle: '${state.devices.length} أجهزة - أضف، عدّل، احذف',
            color: const Color(0xFFfbbf24),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const _DeviceNamesScreen())),
          ),

          const SizedBox(height: 20),

          // ─── الأسعار ───────────────────────────────────────────────
          _SectionHeader('💰 الأسعار'),
          const SizedBox(height: 8),
          _SettingCard(
            icon: Icons.attach_money,
            title: 'أسعار PS4',
            subtitle:
                'عادي: ${state.prices['ps4_normal'] ?? 25} ج/س | مالتي: ${state.prices['ps4_multi'] ?? 35} ج/س',
            color: const Color(0xFF38bdf8),
            onTap: () => _showPricesDialog(context, 'ps4'),
          ),
          const SizedBox(height: 8),
          _SettingCard(
            icon: Icons.attach_money,
            title: 'أسعار PS5',
            subtitle:
                'عادي: ${state.prices['ps5_normal'] ?? 40} ج/س | مالتي: ${state.prices['ps5_multi'] ?? 50} ج/س',
            color: Colors.purple,
            onTap: () => _showPricesDialog(context, 'ps5'),
          ),

          const SizedBox(height: 20),

          // ─── الماتش ────────────────────────────────────────────────
          _SectionHeader('⚽ الماتش'),
          const SizedBox(height: 8),
          const MatchPriceCard(deviceType: 'ps4'),
          const SizedBox(height: 8),
          const MatchPriceCard(deviceType: 'ps5'),
          const SizedBox(height: 8),
          
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1c2128),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(children: [
              const Icon(Icons.sports_soccer,
                  color: Color(0xFF4ade80), size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تفعيل زرار الماتش',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('يظهر زرار الماتش في شاشة الجهاز',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ]),
              ),
              Switch(
                value: state.matchEnabled,
                onChanged: (v) => state.setMatchEnabled(v),
                activeColor: const Color(0xFF4ade80),
              ),
            ]),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _showPricesDialog(BuildContext context, String type) {
    final state = context.read<AppState>();
    final label = type == 'ps5' ? 'PS5' : 'PS4';
    final color = type == 'ps5' ? Colors.purple : const Color(0xFF38bdf8);
    final normalCtrl = TextEditingController(
        text: '${state.prices['${type}_normal'] ?? (type == 'ps5' ? 40 : 25)}');
    final multiCtrl = TextEditingController(
        text: '${state.prices['${type}_multi'] ?? (type == 'ps5' ? 50 : 35)}');
    showDialog(
      context: context,
      builder: (_) => _Dialog(
        title: 'أسعار $label',
        icon: Icons.attach_money,
        color: color,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: normalCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('سعر عادي (ج/س)')),
          const SizedBox(height: 12),
          TextField(
              controller: multiCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('سعر مالتي (ج/س)')),
        ]),
        onSave: () {
          final n = int.tryParse(normalCtrl.text);
          final m = int.tryParse(multiCtrl.text);
          if (n != null && m != null) {
            final newPrices = Map<String, int>.from(state.prices);
            newPrices['${type}_normal'] = n;
            newPrices['${type}_multi'] = m;
            state.updatePrices(newPrices);
          }
        },
      ),
    );
  }

  void _showMatchPriceDialog(BuildContext context) {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(
        text: '${state.prices['match_price'] ?? 10}');
    showDialog(
      context: context,
      builder: (_) => _Dialog(
        title: 'سعر الماتش',
        icon: Icons.sports_soccer,
        color: const Color(0xFF4ade80),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('سعر الماتش الواحد (ج)')),
          const SizedBox(height: 8),
          const Text('مدة الماتش بتتحسب تلقائي على أساس السعر/ساعة',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
        onSave: () {
          final v = int.tryParse(ctrl.text);
          if (v != null && v > 0) {
            final newPrices = Map<String, int>.from(state.prices);
            newPrices['match_price'] = v;
            state.updatePrices(newPrices);
          }
        },
      ),
    );
  }
}

// ─── Device Names Screen ──────────────────────────────────────────────────────

class _DeviceNamesScreen extends StatefulWidget {
  const _DeviceNamesScreen();
  @override
  State<_DeviceNamesScreen> createState() => _DeviceNamesScreenState();
}

class _DeviceNamesScreenState extends State<_DeviceNamesScreen> {
  late List<TextEditingController> _controllers;
  late List<String> _types;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _controllers = state.devices
        .map((d) => TextEditingController(text: d.displayName))
        .toList();
    _types = state.devices.map((d) => d.deviceType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('إدارة الأجهزة',
            style: TextStyle(
                color: Color(0xFFfbbf24),
                fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: Color(0xFFfbbf24), size: 28),
            tooltip: 'إضافة جهاز',
            onPressed: () => _showAddDeviceDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.devices.length,
              itemBuilder: (ctx, i) {
                if (i >= _controllers.length) return const SizedBox();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1c2128),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _controllers[i],
                            decoration: _inputDeco(
                                    'اسم الجهاز ${i + 1}')
                                .copyWith(
                              prefixIcon: const Icon(
                                  Icons.videogame_asset,
                                  color: Color(0xFFfbbf24)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // زرار حذف
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () =>
                              _confirmRemove(context, state, i),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Text('النوع:',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13)),
                        const SizedBox(width: 12),
                        _TypeChip(
                          label: 'PS4',
                          selected: _types[i] == 'ps4',
                          color: const Color(0xFF38bdf8),
                          onTap: () =>
                              setState(() => _types[i] = 'ps4'),
                        ),
                        const SizedBox(width: 8),
                        _TypeChip(
                          label: 'PS5',
                          selected: _types[i] == 'ps5',
                          color: Colors.purple,
                          onTap: () =>
                              setState(() => _types[i] = 'ps5'),
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  for (int i = 0;
                      i < state.devices.length;
                      i++) {
                    if (i < _controllers.length &&
                        _controllers[i].text.isNotEmpty) {
                      state.updateDeviceName(
                          state.devices[i],
                          _controllers[i].text);
                    }
                    if (i < _types.length) {
                      state.updateDeviceType(
                          state.devices[i], _types[i]);
                    }
                  }
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.save),
                label: const Text('حفظ'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFfbbf24),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceDialog(BuildContext context) {
    final state = context.read<AppState>();
    final nameCtrl = TextEditingController();
    String selectedType = 'ps4';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.add_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('إضافة جهاز', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: _inputDeco('اسم الجهاز'), autofocus: true),
            const SizedBox(height: 16),
            Row(children: [
              const Text('النوع:', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(width: 12),
              _TypeChip(label: 'PS4', selected: selectedType == 'ps4', color: const Color(0xFF38bdf8), onTap: () => setS(() => selectedType = 'ps4')),
              const SizedBox(width: 8),
              _TypeChip(label: 'PS5', selected: selectedType == 'ps5', color: Colors.purple, onTap: () => setS(() => selectedType = 'ps5')),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                state.addDevice(name, selectedType);
                setState(() {
                  _controllers.add(TextEditingController(text: name));
                  _types.add(selectedType);
                });
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(
      BuildContext context, AppState state, int index) {
    if (state.devices[index].isActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ مينفعش تحذف جهاز شغال'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف جهاز؟',
            style: TextStyle(color: Colors.red)),
        content: Text(
            'هيتم حذف "${state.devices[index].displayName}"',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              state.removeDevice(index);
              // تحديث الـ controllers
              setState(() {
                if (index < _controllers.length) {
                  _controllers.removeAt(index);
                }
                if (index < _types.length) {
                  _types.removeAt(index);
                }
              });
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ─── Menu Management ──────────────────────────────────────────────────────────

class _MenuManagementScreen extends StatelessWidget {
  const _MenuManagementScreen();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0b0e14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0b0e14),
          title: const Text('إدارة البوفيه',
              style: TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold)),
          leading: const BackButton(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white38,
            labelStyle:
                TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: [
              Tab(icon: Icon(Icons.fastfood, size: 18), text: 'المنتجات'),
              Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'ملخص اليوم'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MenuProductsTab(),
            _MenuDailySummaryTab(),
          ],
        ),
      ),
    );
  }
}

// ─── تاب المنتجات ─────────────────────────────────────────────────────────────

class _MenuProductsTab extends StatelessWidget {
  const _MenuProductsTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      children: [
        Expanded(
          child: state.menu.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.fastfood,
                          size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('البوفيه فاضي!',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 18)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            _showAddItemDialog(context, state),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة أول منتج'),
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.menu.length,
                  itemBuilder: (ctx, i) {
                    final entry = state.menu.entries.toList()[i];
                    return _MenuItemTile(
                      name: entry.key,
                      price: entry.value,
                      qty: state.inventory[entry.key] ?? 0,
                      onEdit: () => _showEditItemDialog(
                          context, state, entry.key, entry.value),
                      onDelete: () =>
                          _confirmDelete(context, state, entry.key),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _showAddItemDialog(context, state),
              icon: const Icon(Icons.add),
              label: const Text('إضافة منتج جديد',
                  style: TextStyle(fontSize: 15)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddItemDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _Dialog(
        title: 'إضافة منتج',
        icon: Icons.add_circle,
        color: Colors.orange,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nameCtrl,
              decoration: _inputDeco('اسم المنتج')),
          const SizedBox(height: 12),
          TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('السعر (ج)')),
          const SizedBox(height: 12),
          TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('الكمية في المخزن (اختياري)')),
        ]),
        onSave: () {
          final name = nameCtrl.text.trim();
          final price = int.tryParse(priceCtrl.text);
          if (name.isEmpty || price == null || price <= 0)
            return false;
          state.addMenuItem(name, price);
          final qty = int.tryParse(qtyCtrl.text);
          if (qty != null && qty > 0) {
            state.addInventory(name, qty);
          }
          return true;
        },
      ),
    );
  }

  void _showEditItemDialog(BuildContext context, AppState state,
      String oldName, int oldPrice) {
    final nameCtrl = TextEditingController(text: oldName);
    final priceCtrl = TextEditingController(text: '$oldPrice');
    final currentQty = state.inventory[oldName] ?? 0;
    final qtyCtrl = TextEditingController(text: '$currentQty');
    showDialog(
      context: context,
      builder: (_) => _Dialog(
        title: 'تعديل منتج',
        icon: Icons.edit,
        color: const Color(0xFF38bdf8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nameCtrl,
              decoration: _inputDeco('اسم المنتج')),
          const SizedBox(height: 12),
          TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('السعر (ج)')),
          const SizedBox(height: 12),
          TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('الكمية في المخزن')),
        ]),
        onSave: () {
          final name = nameCtrl.text.trim();
          final price = int.tryParse(priceCtrl.text);
          if (name.isEmpty || price == null || price <= 0)
            return false;
          state.updateMenuItem(oldName, name, price);
          final qty = int.tryParse(qtyCtrl.text);
          if (qty != null && qty >= 0) {
            state.setInventoryItem(name, qty);
          }
          return true;
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppState state, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف منتج',
            style: TextStyle(color: Colors.red)),
        content: Text('هيتم حذف "$name" من البوفيه',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.removeMenuItem(name);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ─── تاب ملخص اليوم ───────────────────────────────────────────────────────────

class _MenuDailySummaryTab extends StatelessWidget {
  const _MenuDailySummaryTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final summary = state.dailyInventorySummary;
    final menu = state.menu;

    if (summary.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.white12),
            SizedBox(height: 16),
            Text('لا يوجد مبيعات اليوم',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            SizedBox(height: 6),
            Text('هيتحدث تلقائياً لما يتباع حاجة من البوفيه',
                style: TextStyle(color: Colors.white24, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    double totalRevenue = 0;
    int totalQty = 0;
    summary.forEach((item, qty) {
      totalRevenue += qty * (menu[item] ?? 0);
      totalQty += qty;
    });

    final sorted = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // ─── إجماليات ────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1c2128),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SummaryChip(
                icon: Icons.shopping_bag,
                label: 'إجمالي قطع',
                value: '$totalQty',
                color: const Color(0xFF38bdf8),
              ),
              Container(width: 1, height: 36, color: Colors.white12),
              _SummaryChip(
                icon: Icons.payments_outlined,
                label: 'إيرادات البوفيه',
                value: '${totalRevenue.toStringAsFixed(0)} ج',
                color: const Color(0xFF4ade80),
              ),
            ],
          ),
        ),

        // ─── قائمة المبيعات ──────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) {
              final entry = sorted[i];
              final item = entry.key;
              final soldQty = entry.value;
              final price = menu[item] ?? 0;
              final revenue = soldQty * price;
              final remaining = state.inventory[item] ?? 0;
              final ratio = totalQty > 0 ? soldQty / totalQty : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1c2128),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == 0 ? Colors.amber : Colors.white12,
                          ),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: i == 0
                                      ? Colors.amber
                                      : Colors.white38)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: Text('$soldQty قطعة',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MiniSummaryInfo('💰 إيراد', '$revenue ج',
                            const Color(0xFF4ade80)),
                        _MiniSummaryInfo(
                            '📦 متبقي',
                            '$remaining قطعة',
                            remaining <= 3
                                ? Colors.red
                                : Colors.white54),
                        _MiniSummaryInfo('💵 سعر', '$price ج',
                            Colors.white38),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // ─── زرار تصفير ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _confirmResetDaily(context, state),
              icon: const Icon(Icons.refresh, color: Colors.white38),
              label: const Text('تصفير ملخص اليوم',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmResetDaily(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('تصفير ملخص اليوم؟',
            style: TextStyle(color: Colors.red)),
        content: const Text(
            'هيتم تصفير ملخص المبيعات اليومي فقط، المخزون هيفضل زي ما هو',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.resetDailySummary();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تصفير'),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets مساعدة ───────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14)),
    ]);
  }
}

class _MiniSummaryInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniSummaryInfo(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label,
          style: const TextStyle(color: Colors.white24, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    ]);
  }
}

class _MenuItemTile extends StatelessWidget {
  final String name;
  final int price;
  final int qty;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MenuItemTile(
      {required this.name,
      required this.price,
      required this.qty,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    Color qtyColor;
    String qtyLabel;
    if (qty == 0) {
      qtyColor = Colors.red;
      qtyLabel = 'نفد!';
    } else if (qty <= 3) {
      qtyColor = Colors.orange;
      qtyLabel = '$qty قطعة';
    } else {
      qtyColor = const Color(0xFF4ade80);
      qtyLabel = '$qty قطعة';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qty == 0 ? Colors.red.withOpacity(0.4) : Colors.white10,
          width: qty == 0 ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        const Icon(Icons.fastfood, color: Colors.orange, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Row(children: [
                  Text('$price ج',
                      style: const TextStyle(
                          color: Color(0xFF4ade80), fontSize: 13)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: qtyColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(qtyLabel,
                        style: TextStyle(
                            color: qtyColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ]),
        ),
        IconButton(
            icon: const Icon(Icons.edit,
                color: Color(0xFF38bdf8), size: 20),
            onPressed: onEdit),
        IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.red, size: 20),
            onPressed: onDelete),
      ]),
    );
  }
}
// ─── Tables Management (بنج/بلياردو) ─────────────────────────────────────────

class _TablesManagementScreen extends StatelessWidget {
  const _TablesManagementScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('إدارة التربيزات',
            style: TextStyle(
                color: Color(0xFF34d399),
                fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: Color(0xFF34d399), size: 28),
            onPressed: () => _showAddDialog(context, state),
          ),
        ],
      ),
      body: state.tables.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.table_bar,
                      size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('مفيش تربيزات!',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 18)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        _showAddDialog(context, state),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة تربيزة'),
                    style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF34d399),
                        foregroundColor: Colors.black),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.tables.length,
              itemBuilder: (ctx, i) {
                final t = state.tables[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1c2128),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(children: [
                    Icon(
                      t['table_type'] == 'billiard' ? Icons.sports_golf : Icons.sports_tennis,
                      color: t['table_type'] == 'billiard' ? Colors.purple : const Color(0xFF34d399),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(t['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text(
                              '${t['table_type'] == 'billiard' ? '🎱 بلياردو' : '🏓 بينج'} | ${t['rate']} ج/س${(t['game_price'] ?? 0) > 0 ? ' | جيم: ${t['game_price']} ج' : ''}',
                              style: const TextStyle(
                                    color: Color(0xFF4ade80),
                                    fontSize: 13)),
                          ]),
                    ),
                    IconButton(
                        icon: const Icon(Icons.edit,
                            color: Color(0xFF38bdf8), size: 20),
                        onPressed: () =>
                            _showEditDialog(context, state, i)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () =>
                            _confirmDelete(context, state, i)),
                  ]),
                );
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final gamePriceCtrl = TextEditingController();
    String selectedType = 'ping';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.table_bar, color: Color(0xFF34d399)),
            SizedBox(width: 8),
            Text('إضافة تربيزة', style: TextStyle(color: Color(0xFF34d399), fontWeight: FontWeight.bold)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: _inputDeco('اسم التربيزة (مثال: بينج 1)')),
            const SizedBox(height: 12),
            TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('سعر الساعة (ج/س)')),
            const SizedBox(height: 12),
            TextField(controller: gamePriceCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('سعر الجيم (ج) - اختياري')),
            const SizedBox(height: 14),
            Row(children: [
              const Text('النوع:', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(width: 12),
              _TypeChip(label: '🏓 بينج', selected: selectedType == 'ping', color: const Color(0xFF34d399), onTap: () => setState(() => selectedType = 'ping')),
              const SizedBox(width: 8),
              _TypeChip(label: '🎱 بلياردو', selected: selectedType == 'billiard', color: Colors.purple, onTap: () => setState(() => selectedType = 'billiard')),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final rate = int.tryParse(rateCtrl.text);
                if (name.isEmpty || rate == null || rate <= 0) return;
                final gamePrice = int.tryParse(gamePriceCtrl.text) ?? 0;
                state.addTable(name, rate, tableType: selectedType, gamePrice: gamePrice);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF34d399), foregroundColor: Colors.black),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, AppState state, int index) {
    final t = state.tables[index];
    final nameCtrl = TextEditingController(text: t['name']);
    final rateCtrl = TextEditingController(text: '${t['rate']}');
    final gamePriceCtrl = TextEditingController(text: '${t['game_price'] ?? 0}');
    String selectedType = t['table_type'] ?? 'ping';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1c2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.edit, color: Color(0xFF38bdf8)),
            SizedBox(width: 8),
            Text('تعديل تربيزة', style: TextStyle(color: Color(0xFF38bdf8), fontWeight: FontWeight.bold)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: _inputDeco('اسم التربيزة')),
            const SizedBox(height: 12),
            TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('سعر الساعة (ج/س)')),
            const SizedBox(height: 12),
            TextField(controller: gamePriceCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('سعر الجيم (ج) - اختياري')),
            const SizedBox(height: 14),
            Row(children: [
              const Text('النوع:', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(width: 12),
              _TypeChip(label: '🏓 بينج', selected: selectedType == 'ping', color: const Color(0xFF34d399), onTap: () => setState(() => selectedType = 'ping')),
              const SizedBox(width: 8),
              _TypeChip(label: '🎱 بلياردو', selected: selectedType == 'billiard', color: Colors.purple, onTap: () => setState(() => selectedType = 'billiard')),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final rate = int.tryParse(rateCtrl.text);
                if (name.isEmpty || rate == null || rate <= 0) return;
                final gamePrice = int.tryParse(gamePriceCtrl.text) ?? 0;
                state.updateTableSettings(index, name, rate, tableType: selectedType, gamePrice: gamePrice);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF38bdf8), foregroundColor: Colors.black),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppState state, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف تربيزة',
            style: TextStyle(color: Colors.red)),
        content: Text(
            'هيتم حذف "${state.tables[index]['name']}"',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.removeTable(index);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ─── Drink Tables Management ──────────────────────────────────────────────────

class _DrinkTablesManagementScreen extends StatelessWidget {
  const _DrinkTablesManagementScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFF0b0e14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0b0e14),
        title: const Text('تربيزات المشروبات',
            style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: Colors.orange, size: 28),
            onPressed: () => _showAddDialog(context, state),
          ),
        ],
      ),
      body: state.drinkTables.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_drink,
                      size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('مفيش تربيزات مشروبات!',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 18)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        _showAddDialog(context, state),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة تربيزة'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.drinkTables.length,
              itemBuilder: (ctx, i) {
                final t = state.drinkTables[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1c2128),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_drink,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(t['name'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                    IconButton(
                        icon: const Icon(Icons.edit,
                            color: Color(0xFF38bdf8), size: 20),
                        onPressed: () =>
                            _showEditDialog(context, state, i)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () =>
                            _confirmDelete(context, state, i)),
                  ]),
                );
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _Dialog(
        title: 'إضافة تربيزة مشروبات',
        icon: Icons.local_drink,
        color: Colors.orange,
        child: TextField(
            controller: nameCtrl,
            decoration:
                _inputDeco('اسم التربيزة (مثال: تربيزة 1)')),
        onSave: () {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return false;
          state.addDrinkTable(name);
          return true;
        },
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, AppState state, int index) {
    final nameCtrl = TextEditingController(
        text: state.drinkTables[index]['name']);
    showDialog(
      context: context,
      builder: (_) => _Dialog(
        title: 'تعديل اسم التربيزة',
        icon: Icons.edit,
        color: Colors.orange,
        child: TextField(
            controller: nameCtrl,
            decoration: _inputDeco('اسم التربيزة')),
        onSave: () {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return false;
          state.updateDrinkTableName(index, name);
          return true;
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppState state, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1c2128),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف تربيزة',
            style: TextStyle(color: Colors.red)),
        content: Text(
            'هيتم حذف "${state.drinkTables[index]['name']}"',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          FilledButton(
            onPressed: () {
              state.removeDrinkTable(index);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.white24,
              width: selected ? 2 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : Colors.white54,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: Text(title,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1)),
    );
  }
}

class _LockedCard extends StatelessWidget {
  final String title;
  const _LockedCard(this.title);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.lock, color: Colors.white24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const Text('للأدمن فقط',
                    style: TextStyle(
                        color: Colors.white24, fontSize: 12)),
              ]),
        ),
        const Icon(Icons.lock_outline, color: Colors.white24),
      ]),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _SettingCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1c2128),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ]),
        ),
      ),
    );
  }
}

class _Dialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final dynamic Function()? onSave;
  const _Dialog(
      {required this.title,
      required this.icon,
      required this.color,
      required this.child,
      this.onSave});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1c2128),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold)),
      ]),
      content: child,
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white54))),
        FilledButton(
          onPressed: () {
            final result = onSave?.call();
            if (result != false) Navigator.pop(context);
          },
          style:
              FilledButton.styleFrom(backgroundColor: color),
          child: const Text('حفظ',
              style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}

class _SubscriptionBanner extends StatelessWidget {
  final AppState state;
  const _SubscriptionBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final expiry = state.subscriptionExpiry!;
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    final isExpired = DateTime.now().isAfter(expiry);

    final color = isExpired
        ? Colors.red
        : daysLeft <= 7
            ? Colors.orange
            : const Color(0xFF4ade80);

    final icon = isExpired
        ? Icons.cancel_outlined
        : daysLeft <= 7
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline;

    final label = isExpired
        ? 'منتهي'
        : daysLeft == 0
            ? 'آخر يوم!'
            : '$daysLeft يوم متبقي';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(Icons.workspace_premium, color: color, size: 18),
        const SizedBox(width: 10),
        const Text('الاشتراك',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const Spacer(),
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 8),
        Text(
          '${expiry.day}/${expiry.month}/${expiry.year}',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ]),
    );
  }
}

InputDecoration _inputDeco(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF0b0e14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF38bdf8), width: 2)),
    );
