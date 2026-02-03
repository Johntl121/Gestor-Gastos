import 'package:flutter/material.dart';
import '../../data/datasources/transaction_local_data_source.dart';
import '../../injection_container.dart';
import '../pages/main_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _finishOnboarding() async {
    final name = _nameController.text.trim();
    final budgetStr = _budgetController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, ingresa tu nombre")),
      );
      return;
    }

    final budget = double.tryParse(budgetStr);
    if (budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa un presupuesto válido")),
      );
      return;
    }

    // Persist Data using the LocalDataSource directly
    final dataSource = sl<TransactionLocalDataSource>();
    await dataSource.saveUserName(name);
    await dataSource.saveBudgetLimit(budget);
    await dataSource.setFirstTime(false);

    if (!mounted) return;

    // Navigate to Main Page
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dark Theme Colors
    const backgroundColor = Color(0xFF121C22);
    const tealColor = Colors.tealAccent;
    const whiteColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Welcome Image / Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: tealColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: tealColor,
                  ),
                ),
              ),

              const SizedBox(height: 50),

              const Text(
                "Toma el Control\nde tu Dinero",
                style: TextStyle(
                  color: whiteColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Configura tu perfil para empezar a rastrear tus gastos y efectivo.",
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 40),

              // Name Input
              const Text("¿Cómo te llamas?",
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: whiteColor, fontSize: 18),
                decoration: InputDecoration(
                  hintText: "Ej. Alex",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: tealColor)),
                ),
              ),

              const SizedBox(height: 30),

              // Budget Input
              const Text("¿Cuál es tu Presupuesto Mensual?",
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _budgetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: whiteColor, fontSize: 18),
                decoration: InputDecoration(
                  prefixText: "S/ ",
                  prefixStyle: TextStyle(color: tealColor, fontSize: 18),
                  hintText: "2400.00",
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: tealColor)),
                ),
              ),

              const SizedBox(height: 60),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _finishOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Empezar Aventura",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
