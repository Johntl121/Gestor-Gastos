import 'injection_container.dart' as di;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/datasources/transaction_local_data_source.dart';
import 'presentation/pages/main_page.dart';
import 'presentation/pages/onboarding_page.dart';
import 'presentation/providers/dashboard_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();

  // Check First Time
  final isFirstTime = di.sl<TransactionLocalDataSource>().isFirstTime();

  runApp(MyApp(isFirstTime: isFirstTime));
}

class MyApp extends StatelessWidget {
  final bool isFirstTime;
  const MyApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<DashboardProvider>()),
      ],
      child: MaterialApp(
        title: 'Gestor de Gastos',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: isFirstTime ? const OnboardingPage() : const MainPage(),
      ),
    );
  }
}
