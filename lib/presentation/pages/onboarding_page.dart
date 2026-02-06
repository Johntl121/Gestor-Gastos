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
  String _selectedCurrency = 'S/';

  // Balances
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _bankController = TextEditingController();
  final TextEditingController _savingsController = TextEditingController();

  // Budget
  final TextEditingController _budgetController = TextEditingController();

  bool _isProcessing = false;

  @override
  void dispose() {
    _pageController.dispose();

    _nameController.dispose();
    _cashController.dispose();
    _bankController.dispose();
    _savingsController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Validation
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Por favor, ingresa tu nombre.")));
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final dataSource = sl.sl<TransactionLocalDataSource>();
    final navigator = Navigator.of(context);

    // 1. Save Currency
    await provider.setCurrency(_selectedCurrency);

    // 2. Save Name
    await dataSource.saveUserName(_nameController.text.trim().isEmpty
        ? "Usuario"
        : _nameController.text.trim());

    // 3. Save Budget
    final budget = double.tryParse(_budgetController.text) ?? 2400.0;
    provider.setBudgetLimit(budget);
    await dataSource.saveBudgetLimit(budget);

    // 4. Create Initial Balances
    final cash = double.tryParse(_cashController.text) ?? 0;
    final bank = double.tryParse(_bankController.text) ?? 0;
    final savings = double.tryParse(_savingsController.text) ?? 0;

    // Helper to add initial transaction
    Future<void> addInitTx(double amount, int accountId, String desc) async {
      if (amount > 0) {
        final t = TransactionEntity(
            accountId: accountId,
            categoryId: 0, // Incomes/Initial
            amount: amount,
            date: DateTime.now(),
            description: desc,
            note: "Saldo Inicial",
            type: TransactionType.income);
        await provider.addTransaction(t);
      }
    }

    // Add sequentially to ensure order (though date is same)
    await addInitTx(cash, 1, "Saldo Inicial Efectivo");
    await addInitTx(bank, 2, "Saldo Inicial Banco");
    await addInitTx(savings, 3, "Saldo Inicial Ahorros");

    // 5. Complete
    await dataSource.setFirstTime(false);

    if (mounted) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF1E293B);
    const accentColor = Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentPage + 1) / 3,
              backgroundColor: Colors.white10,
              color: accentColor,
              minHeight: 4,
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildProfileStep(),
                  _buildBalancesStep(),
                  _buildBudgetStep(),
                ],
              ),
            ),

            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                      child: const Text("Atrás",
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : (_currentPage == 2 ? _finishOnboarding : _nextPage),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : Text(
                            _currentPage == 2 ? "¡Comenzar!" : "Siguiente",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- STEPS ---

  Widget _buildProfileStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_outline, size: 64, color: Color(0xFF00E5FF)),
          const SizedBox(height: 24),
          const Text("Configuremos tu perfil",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
              "Para darte una mejor experiencia, necesitamos conocerte un poco.",
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 40),
          _buildTextField("Nombre", _nameController, icon: Icons.badge),
          const SizedBox(height: 30),
          const Text("Moneda Principal",
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _currencyChip("S/"),
              _currencyChip("\$"),
              _currencyChip("€"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBalancesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("¿Con cuánto empezamos?",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
              "Para simplificar tu vida financiera, organizaremos tu dinero en 3 Cuentas Maestras (por ahora):",
              style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 24),
          _buildAccountInputCard(
              "Efectivo (Cash)",
              "Dinero físico en tu bolsillo. Úsalo para gastos diarios rápidos (pasajes, snacks).",
              _cashController,
              Icons.payments_outlined,
              Colors.green),
          const SizedBox(height: 16),
          _buildAccountInputCard(
              "Banco (Bank)",
              "Tu dinero digital. Aquí recibes tu sueldo y manejas tus transferencias.",
              _bankController,
              Icons.credit_card,
              Colors.blue),
          const SizedBox(height: 16),
          _buildAccountInputCard(
              "Ahorros (Savings)",
              "Tu dinero intocable. Úsalo solo para cumplir Metas o Emergencias.",
              _savingsController,
              Icons.savings,
              Colors.purple),
          const SizedBox(height: 24),
          const Center(
            child: Text(
                "💡 Pro-tip: Más adelante podrás crear cuentas personalizadas.",
                style: TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pie_chart_outline,
              size: 64, color: Color(0xFF00E5FF)),
          const SizedBox(height: 24),
          const Text("Define tu límite",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
              "Establece un presupuesto mensual objetivo para mantener tus gastos bajo control.",
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 40),
          _buildMoneyInput("Presupuesto Mensual", _budgetController,
              Icons.speed, Colors.orange),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildTextField(String label, TextEditingController controller,
      {IconData? icon}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          prefixIcon: icon != null ? Icon(icon, color: Colors.white60) : null,
          enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF00E5FF)),
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05)),
    );
  }

  Widget _buildMoneyInput(String label, TextEditingController controller,
      IconData icon, Color iconColor) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: iconColor),
          prefixText: "$_selectedCurrency ",
          prefixStyle:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: iconColor),
              borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05)),
    );
  }

  Widget _currencyChip(String symbol) {
    final isSelected = _selectedCurrency == symbol;
    return GestureDetector(
      onTap: () => setState(() => _selectedCurrency = symbol),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
          border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          symbol,
          style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAccountInputCard(String title, String desc,
      TextEditingController controller, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold))
            ],
          ),
          const SizedBox(height: 8),
          Text(desc,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
                prefixText: "$_selectedCurrency ",
                prefixStyle: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold),
                hintText: "0.00",
                hintStyle: const TextStyle(color: Colors.white24),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
                enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white10),
                    borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: color),
                    borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.black26),
          )
        ],
      ),
    );
  }
}
