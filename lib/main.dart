import 'injection_container.dart' as di;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'data/datasources/transaction_local_data_source.dart';
import 'presentation/pages/main_page.dart';
import 'presentation/pages/intro_page.dart';
import 'presentation/providers/dashboard_provider.dart';
import 'presentation/pages/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  await di.init();

  // Check First Time
  final isFirstTime = di.sl<TransactionLocalDataSource>().isFirstTime();

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

  void _checkInitialLock() {
    final pin = di.sl<TransactionLocalDataSource>().getSecurityPin();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App went to background: Lock if PIN is enabled
      final pin = di.sl<TransactionLocalDataSource>().getSecurityPin();
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
        ChangeNotifierProvider(create: (_) => di.sl<DashboardProvider>()),
      ],
      child: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
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
            useMaterial3: true,
          );

          // Dark Theme
          final darkTheme = ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            cardColor: const Color(0xFF1E293B),
            primaryColor: Colors.cyanAccent,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.cyanAccent,
              brightness: Brightness.dark,
              primary: Colors.cyanAccent,
              surface: const Color(0xFF1E293B),
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
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
