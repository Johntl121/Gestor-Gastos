import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../../data/datasources/transaction_local_data_source.dart';
import '../../injection_container.dart' as sl;
import '../../domain/entities/transaction_entity.dart';
import 'main_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form Data
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  String _selectedCurrency = 'S/';

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF121C22);
    const cyanColor = Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // Control via buttons
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomeStep(),
                  _buildPersonalizationStep(),
                  _buildFinancialStep(),
                ],
              ),
            ),
            // Bottom Indicator & Navigation
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(3, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color:
                              _currentPage == index ? cyanColor : Colors.grey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  // Button
                  if (_currentPage < 2)
                    TextButton(
                      onPressed: () {
                        if (_currentPage == 1 && _nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Ingresa un nombre para continuar")));
                          return;
                        }
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text("Siguiente",
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.account_balance_wallet,
              size: 100, color: Color(0xFF00E5FF)),
          SizedBox(height: 40),
          Text(
            "Bienvenido a tu\nLibertad Financiera",
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Text(
            "Controla tus gastos, cumple tus metas y mantén la carita feliz.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizationStep() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Personalización",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          const Text("¿Cómo te llamamos?",
              style: TextStyle(color: Colors.grey)),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
                hintText: "Tu nombre o apodo",
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00E5FF)))),
          ),
          const SizedBox(height: 40),
          const Text("Elige tu moneda", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCurrencyOption("S/"),
              _buildCurrencyOption("\$"),
              _buildCurrencyOption("€"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCurrencyOption(String symbol) {
    final isSelected = _selectedCurrency == symbol;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCurrency = symbol);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          symbol,
          style: TextStyle(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFinancialStep() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Configuración Financiera",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          // Budget Limit
          const Text("Límite Mensual de Gastos",
              style: TextStyle(color: Colors.grey)),
          TextField(
            controller: _budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
                prefixText: "$_selectedCurrency ",
                prefixStyle: const TextStyle(color: Color(0xFF00E5FF)),
                hintText: "Ej. 2500.00",
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00E5FF)))),
          ),
          const SizedBox(height: 30),
          // Initial Balance
          const Text("Saldo Inicial (Total Dinero)",
              style: TextStyle(color: Colors.grey)),
          TextField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
                prefixText: "$_selectedCurrency ",
                prefixStyle: const TextStyle(color: Color(0xFF00E5FF)),
                hintText: "Ej. 500.00",
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00E5FF)))),
          ),
          const SizedBox(height: 50),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _finishOnboarding,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF121C22),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25))),
              child: const Text("¡Todo Listo!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final dataSource = sl.sl<TransactionLocalDataSource>();

    // 1. Save Currency
    await provider.setCurrency(_selectedCurrency);

    // 2. Save Name
    if (_nameController.text.isNotEmpty) {
      await dataSource.saveUserName(_nameController.text);
    } else {
      await dataSource.saveUserName("Viajero");
    }

    // 3. Save Budget
    final budget = double.tryParse(_budgetController.text);
    if (budget != null && budget > 0) {
      provider.setBudgetLimit(budget);
      await dataSource.saveBudgetLimit(budget);
    }

    // 4. Create Initial Balance Transaction
    final balance = double.tryParse(_balanceController.text);
    if (balance != null && balance > 0) {
      final t = TransactionEntity(
        accountId: 1, // Cuenta Principal
        categoryId: 0, // Sin Categoría / Ingreso
        amount: balance,
        date: DateTime.now(),
        description: "Saldo Inicial",
      );
      await provider.addTransaction(t);
    }

    // 5. Complete Onboarding
    await dataSource.setFirstTime(false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    }
  }
}
