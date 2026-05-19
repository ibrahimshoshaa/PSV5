import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'services/notification_service.dart';
import 'screens/activation_screen.dart';
import 'screens/home_screen.dart';
import 'screens/cashier_screen.dart';
import 'screens/customer_orders_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shift_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const PSApp(),
    ),
  );
}

class PSApp extends StatelessWidget {
  const PSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0b0e14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38bdf8),
          secondary: Color(0xFF4ade80),
          surface: Color(0xFF1c2128),
        ),
        cardColor: const Color(0xFF1c2128),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF38bdf8),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {

  @override
  void initState() {
    super.initState();
    // سجّل الـ callback لما المستخدم يضغط على إشعار
    NotificationService.onNotificationTap = _handleNotificationTap;
  }

  void _handleNotificationTap(String payload) {
    if (!mounted) return;
    final state = context.read<AppState>();

    // بس لو التطبيق مفعّل والمستخدم logged in
    if (!state.isActivated) return;

    if (payload == 'orders') {
      final shopId = state.shopId ?? '';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerOrdersScreen(shopId: shopId),
        ),
      );
    }
  }

  
@override
Widget build(BuildContext context) {
  final state = context.watch<AppState>();

  if (!state.isActivated) return const ActivationScreen();

  // الأدمن — مفيش شيفت بالنسبة له
  if (state.isAdmin) return const HomeScreen();

  // الكاشير — لازم يبدأ شيفت الأول
  if (state.isCashier) {
    // لو مفيش شيفت مفتوح → اعرض شاشة بداية الشيفت
    if (!state.hasOpenShift) {
      return ShiftStartScreen(
        cashierName: state.currentCashierName ?? 'كاشير',
        onShiftStarted: () {}, // AppState هيتحدث تلقائي
      );
    }
    return const CashierScreen();
  }

  return const LoginScreen();
}
}
