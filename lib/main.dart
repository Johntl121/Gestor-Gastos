import 'injection_container.dart' as di;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'data/datasources/preferences_local_data_source.dart';
import 'presentation/features/dashboard/main_page.dart';
import 'presentation/features/auth/intro_page.dart';
import 'presentation/features/auth/lock_screen.dart';

// Providers
import 'presentation/providers/ui_provider.dart';
import 'presentation/providers/transaction_provider.dart';
import 'presentation/providers/wallet_provider.dart';
import 'presentation/providers/stats_provider.dart';
import 'presentation/providers/reminder_provider.dart';

import 'core/services/notification_service.dart';
import 'core/services/notification_coordinator.dart';
import 'core/theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación en Vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await initializeDateFormatting('es_ES', null);
  await dotenv.load(fileName: ".env");
  await di.init();

  // Notifications Init
  await di.sl<NotificationService>().init();
  await di.sl<NotificationCoordinator>().init();

  // Check First Time
  final isFirstTime = di.sl<PreferencesLocalDataSource>().isFirstTime();

  runApp(MyApp(isFirstTime: isFirstTime));
}

class MyApp extends StatefulWidget {
  final bool isFirstTime;
  const MyApp({super.key, required this.isFirstTime});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  Future<void> _checkInitialLock() async {
    final pin = await di.sl<PreferencesLocalDataSource>().getSecurityPinAsync();
    if (pin != null && pin.isNotEmpty) {
      setState(() {
        _isLocked = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // App went to background: Lock if PIN is enabled
      final pin =
          await di.sl<PreferencesLocalDataSource>().getSecurityPinAsync();
      if (pin != null && pin.isNotEmpty) {
        setState(() {
          _isLocked = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<UiProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<WalletProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<TransactionProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ReminderProvider>()),
        ChangeNotifierProxyProvider2<TransactionProvider, WalletProvider,
            StatsProvider>(
          create: (_) => di.sl<StatsProvider>(),
          update: (_, txProvider, walletProvider, statsProvider) {
            statsProvider?.setAllTransactions(txProvider.transactions);
            statsProvider?.updateWalletProvider(walletProvider);
            return statsProvider!;
          },
        ),
      ],
      child: Consumer<UiProvider>(
        builder: (context, uiProvider, _) {
          // Light Theme
          final lightTheme = ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            cardColor: Colors.white,
            primaryColor: Colors.teal,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.light,
              primary: Colors.teal,
              secondary: Colors.tealAccent,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF1E293B)),
              titleTextStyle: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              systemOverlayStyle: SystemUiOverlayStyle.dark,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xFF1E293B)),
              bodyMedium: TextStyle(color: Color(0xFF1E293B)),
              titleLarge: TextStyle(
                  color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF1E293B),
              contentTextStyle:
                  const TextStyle(color: Colors.white, fontSize: 14),
              elevation: 4,
            ),
            useMaterial3: true,
          );

          // Dark Theme
          final darkTheme = ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.darkBackground,
            cardColor: AppColors.darkCard,
            primaryColor: AppColors.accent,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.accent,
              brightness: Brightness.dark,
              primary: AppColors.accent,
              surface: AppColors.darkCard,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: AppColors.darkSnackBar,
              contentTextStyle:
                  const TextStyle(color: Colors.white, fontSize: 14),
              elevation: 4,
            ),
            useMaterial3: true,
          );

          return MaterialApp(
            title: 'Gestor de Gastos',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('es', 'ES'),
            ],
            themeMode: uiProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: lightTheme,
            darkTheme: darkTheme,
            home: _isLocked
                ? LockScreen(onUnlocked: () {
                    setState(() {
                      _isLocked = false;
                    });
                  })
                : (widget.isFirstTime ? const IntroPage() : const MainPage()),
          );
        },
      ),
    );
  }
}
