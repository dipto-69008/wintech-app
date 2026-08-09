import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'config/theme.dart';
import 'services/local_storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/onboarding/employee_type_screen.dart';
import 'screens/notifications/notification_screen.dart';
import 'screens/support/support_screen.dart';
import 'screens/settings/edit_profile_screen.dart';
import 'screens/settings/digital_id_card_screen.dart';
import 'screens/admin/all_employees_screen.dart';
import 'screens/target/target_screen.dart';
import 'screens/commission/commission_screen.dart';
import 'models/order_model.dart';
import 'screens/employee/pos_order_screen.dart';
import 'screens/employee/order_detail_screen.dart';
import 'home_shell.dart';

Future<void> _requestLocationOnStartup() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.seedDemoData();
  await _requestLocationOnStartup();
  final isDark = await LocalStorageService.isDarkMode();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(WintechAgroApp(initialDarkMode: isDark));
}

class WintechAgroApp extends StatefulWidget {
  final bool initialDarkMode;
  const WintechAgroApp({super.key, required this.initialDarkMode});

  @override
  State<WintechAgroApp> createState() => _WintechAgroAppState();
}

class _WintechAgroAppState extends State<WintechAgroApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void _onThemeToggle(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wintech Agro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return _slide(const SplashScreen(), settings);
          case '/login':
            return _slide(const LoginScreen(), settings);
          case '/signup':
            return _slide(const SignupScreen(), settings);
          case '/otp':
            return _slide(const OtpScreen(), settings);
          case '/employee-type':
            return _slide(const EmployeeTypeScreen(), settings);
          case '/home':
            return _slide(HomeShell(onThemeToggle: _onThemeToggle), settings);
          case '/pos-order':
            return _slide(const PosOrderScreen(), settings);
          case '/notifications':
            return _slide(const NotificationScreen(), settings);
          case '/support':
            return _slide(const SupportScreen(), settings);
          case '/edit-profile':
            return _slide(const EditProfileScreen(), settings);
          case '/digital-id':
            return _slide(const DigitalIdCardScreen(), settings);
          case '/all-employees':
            return _slide(const AllEmployeesScreen(), settings);
          case '/target':
            return _slide(const TargetScreen(), settings);
          case '/commission':
            return _slide(const CommissionScreen(), settings);
          case '/order-detail':
            final order = settings.arguments as OrderModel;
            return _slide(OrderDetailScreen(order: order), settings);
          default:
            return _slide(const SplashScreen(), settings);
        }
      },
    );
  }

  PageRouteBuilder _slide(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOut))
            .animate(anim),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}
