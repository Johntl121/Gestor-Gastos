import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../../data/repositories/transaction_data_source.dart';
import '../../injection_container.dart' as sl;
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/account_entity.dart';
import 'main_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

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
  String _userProfile = "Estudiante";

  String _selectedAvatar = "😎"; // Default Avatar
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 60,
      );

      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        // Use a fixed name or unique one. Let's use unique time based to avoid caching issues on update
        final String fileName =
            'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String savedPath = path.join(directory.path, fileName);

        final File savedFile = await File(pickedFile.path).copy(savedPath);

        setState(() {
          _profileImage = savedFile;
        });

        if (mounted) Navigator.pop(context); // Close sheet if open
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  void _nextPage() {
    // Validation
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Por favor, ingresa tu nombre.")));
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isProcessing) return;

    // Strict Validation for Budget
    final budgetInput = _budgetController.text.trim();
    final budgetValue = double.tryParse(budgetInput);

    if (budgetInput.isEmpty || budgetValue == null || budgetValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "⚠️ Por favor, define un límite mensual válido para continuar."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final dataSource = sl.sl<TransactionLocalDataSource>();
    final navigator = Navigator.of(context);

    // 0. RESET EVERYTHING (Ensures fresh start)
    await provider.resetAllData();

    // 1. Save Currency
    await provider.setCurrency(_selectedCurrency);

    // 2. Save Name
    await dataSource.saveUserName(_nameController.text.trim().isEmpty
        ? "Usuario"
        : _nameController.text.trim());

    // 2.1 Save Profile Image
    if (_profileImage != null) {
      await provider.setProfileImagePath(_profileImage!.path);
    }
    // Also save avatar as fallback
    await dataSource.saveUserAvatar(_selectedAvatar);

    // 3. Save Budget
    // 3. Save Budget
    final budget = budgetValue; // Already validated above
    provider.setBudgetLimit(budget);
    await dataSource.saveBudgetLimit(budget);

    // 4. Create Initial Accounts (Replacing Seed Data)
    final cash = double.tryParse(_cashController.text) ?? 0;
    final bank = double.tryParse(_bankController.text) ?? 0;
    final savings = double.tryParse(_savingsController.text) ?? 0;

    // Account 1: Efectivo
    await provider.createAccount(AccountEntity(
      id: 1, // Force ID for compatibility
      name: "Efectivo",
      initialBalance: cash,
      currentBalance: cash,
      iconCode: Icons.money.codePoint, // Billete
      colorValue: Colors.amber.value,
      currencySymbol: _selectedCurrency,
      includeInTotal: true,
    ));

    // Account 2: Banco
    await provider.createAccount(AccountEntity(
      id: 2,
      name: "Banco",
      initialBalance: bank,
      currentBalance: bank,
      iconCode: Icons.account_balance.codePoint, // Banco
      colorValue: Colors.blueAccent.value,
      currencySymbol: _selectedCurrency,
      includeInTotal: true,
    ));

    // Account 3: Ahorros
    await provider.createAccount(AccountEntity(
      id: 3,
      name: "Ahorros",
      initialBalance: savings,
      currentBalance: savings, // Initialize with same amount
      iconCode: Icons.savings.codePoint, // Chanchito
      colorValue: Colors.purpleAccent.value,
      currencySymbol: _selectedCurrency,
      includeInTotal: true,
    ));

    // Add Initial Transactions for History (Optional but good for records)
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
        // Do NOT update balance, because createAccount already set the initial balance
        await provider.addTransaction(t, updateBalance: false);
      }
    }

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Theme Colors
    final backgroundColor = theme.scaffoldBackgroundColor;
    final cyanColor = theme.primaryColor;
    final blueColor =
        isDarkMode ? const Color(0xFF2979FF) : Colors.blue.shade700;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Elegant Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutExpo,
                  tween: Tween<double>(
                      begin: 0, end: (_currentPage + 1) / 4), // 4 Steps
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(cyanColor),
                    minHeight: 6,
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildProfileStep(),
                  _buildProfileSelectorStep(), // New Step!
                  _buildBalancesStep(),
                  _buildBudgetStep(),
                ],
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor.withOpacity(0),
                    backgroundColor.withOpacity(0.8),
                    backgroundColor,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutQuart);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[400],
                      ),
                      child:
                          const Text("Atrás", style: TextStyle(fontSize: 16)),
                    )
                  else
                    const SizedBox.shrink(),

                  // Gradient Primary Button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        colors: [cyanColor, blueColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cyanColor.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : (_currentPage == 3 ? _finishOnboarding : _nextPage),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _currentPage == 3 ? "Comenzar" : "Siguiente",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
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

  // --- STEP 1: PERFIL ---

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Identity Hub (Avatar Selector)
          GestureDetector(
            onTap: _showAvatarSelectionSheet,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4), // Border width
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF00E5FF).withOpacity(0.5),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF1E293B),
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : null,
                    child: _profileImage == null
                        ? Text(
                            _selectedAvatar,
                            style: const TextStyle(fontSize: 50),
                          )
                        : null,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF), shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Colors.black, size: 16),
                )
              ],
            ),
          ),

          const SizedBox(height: 40),

          Text("Bienvenido",
              style: TextStyle(
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Text("Configura tu identidad financiera para empezar.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 16,
                  height: 1.5)),

          const SizedBox(height: 50),

          // Name Input
          _buildRoundedTextField(
              "¿Cómo te llamas?", _nameController, Icons.badge),

          const SizedBox(height: 30),

          // Currency Selector Expanded
          const Align(
            alignment: Alignment.centerLeft,
            child: Text("Moneda Principal",
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),

          Builder(builder: (context) {
            final currencies = [
              {'symbol': 'S/', 'name': 'Sol', 'code': 'PEN'},
              {'symbol': '\$', 'name': 'Dólar', 'code': 'USD'},
              {'symbol': '€', 'name': 'Euro', 'code': 'EUR'},
              {'symbol': 'mx\$', 'name': 'Peso', 'code': 'MXN'},
              {'symbol': '₽', 'name': 'Rublo', 'code': 'RUB'},
              {'symbol': '£', 'name': 'Libra', 'code': 'GBP'},
              {'symbol': '¥', 'name': 'Yen', 'code': 'JPY'},
              {'symbol': 'R\$', 'name': 'Real', 'code': 'BRL'},
            ];

            return SizedBox(
              height: 90,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                scrollDirection: Axis.horizontal,
                itemCount: currencies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  final isSelected = _selectedCurrency == currency['symbol'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCurrency = currency['symbol']!);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 80,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                            : null,
                        color: isSelected ? null : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00E5FF)
                                : Colors.grey[800]!,
                            width: isSelected ? 0 : 1),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: const Color(0xFF00E5FF)
                                        .withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 1)
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currency['symbol']!,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currency['name']!,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAvatarSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true, // Allow fuller height
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(30),
          height: MediaQuery.of(context).size.height * 0.6, // Taller sheet
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text("Elige tu avatar",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Selecciona una identidad que vaya contigo.",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              const SizedBox(height: 30),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  children: [
                    '😎',
                    '🦸',
                    '🕵️',
                    '🤖',
                    '🦁',
                    '👽',
                    '🦊',
                    '🐱',
                    '🐼',
                    '🐨',
                    '🐯',
                    '🐮',
                    '🐷',
                    '🐸',
                    '🦄',
                    '🐲',
                    '👻',
                    '💀',
                    '👾',
                    '🧘',
                    '🚵',
                    '🤸',
                    '🧖',
                    '🧟',
                    '🧛',
                    '🧝',
                    '🧞',
                    '🧜',
                    '⚽',
                    '🏀',
                    '🎮',
                    '🎵',
                    '🎨',
                    '📷'
                  ]
                      .map((emoji) => GestureDetector(
                            onTap: () {
                              setState(() => _selectedAvatar = emoji);
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _selectedAvatar == emoji
                                        ? const Color(0xFF00E5FF)
                                        : Colors.transparent,
                                    width: 2),
                              ),
                              alignment: Alignment.center,
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 32)),
                            ),
                          ))
                      .toList(),
                ),
              ),

              const SizedBox(height: 20),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Cámara"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: const Color(0xFF00E5FF),
                          side: const BorderSide(
                              color: Color(0xFF00E5FF), width: 1),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Galería"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: const Color(0xFF00E5FF),
                          side: const BorderSide(
                              color: Color(0xFF00E5FF), width: 1),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  double _getBudgetSuggestion(double baseAmountPEN) {
    double factor = 1.0;
    double rounding = 100.0;

    switch (_selectedCurrency) {
      case '\$': // USD
        factor = 0.3;
        rounding = 10.0;
        break;
      case '€': // EUR
        factor = 0.28;
        rounding = 10.0;
        break;
      case '₽': // RUB
        factor = 25.0;
        rounding = 1000.0;
        break;
      case '¥': // JPY
        factor = 40.0;
        rounding = 1000.0;
        break;
      case 'MX\$': // MXN
        factor = 5.0;
        rounding = 100.0;
        break;
      case 'COP': // COP - Just in case
        factor = 1100.0;
        rounding = 5000.0;
        break;
      default: // PEN, S/, etc
        factor = 1.0;
        rounding = 50.0;
    }

    double raw = baseAmountPEN * factor;

    // Smart Rounding
    if (raw > 10000) {
      return (raw / 1000).round() * 1000.0;
    } else {
      return (raw / rounding).round() * rounding;
    }
  }

  // --- STEP 2: PROFILE SELECTOR ---

  Widget _buildProfileSelectorStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text("¿Qué te describe mejor?",
              style: TextStyle(
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text("Esto nos ayuda a personalizar la experiencia para ti.",
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 16)),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildProfileCard(
                  "Estudiante", "Gestionando lo justo.", Icons.school),
              _buildProfileCard(
                  "Profesional", "Sueldo fijo y metas.", Icons.work),
              _buildProfileCard(
                  "Freelance", "Ingresos variables.", Icons.rocket_launch),
              _buildProfileCard("Hogar", "Finanzas familiares.", Icons.home),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProfileCard(String title, String subtitle, IconData icon) {
    bool isSelected = _userProfile == title;
    return GestureDetector(
      onTap: () => setState(() => _userProfile = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withOpacity(0.1)
              : const Color(0xFF1E293B),
          border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
              width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 40,
                color: isSelected ? const Color(0xFF00E5FF) : Colors.grey),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[200],
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // --- STEP 3: CUENTAS ---

  Widget _buildBalancesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Cuentas Iniciales",
              style: TextStyle(
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text("Define los saldos iniciales de tus cuentas principales.",
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 16)),
          const SizedBox(height: 32),

          // Glass Cards
          _buildGlassAccountCard("Efectivo", _cashController,
              Icons.payments_outlined, Colors.amber),
          const SizedBox(height: 16),
          _buildGlassAccountCard("Banco", _bankController,
              Icons.account_balance, Colors.blueAccent),
          const SizedBox(height: 16),
          _buildGlassAccountCard("Ahorros", _savingsController,
              Icons.savings_outlined, Colors.purpleAccent),
        ],
      ),
    );
  }

  // --- STEP 4: LIMITES (DYNAMIC) ---

  Widget _buildBudgetStep() {
    String message = "Establece un límite de gastos.";
    double suggestedAmount = 2400;

    switch (_userProfile) {
      case "Estudiante":
        message = "Evita los gastos hormiga. Te sugerimos un límite manejable.";
        suggestedAmount = _getBudgetSuggestion(500);
        break;
      case "Profesional":
        message = "Aplica la regla 50/30/20. Destina una parte al ahorro.";
        suggestedAmount = _getBudgetSuggestion(2500);
        break;
      case "Freelance":
        message =
            "Prepárate para los meses bajos. Crea un fondo de estabilidad.";
        suggestedAmount = _getBudgetSuggestion(1500);
        break;
      case "Hogar":
        message = "Controla los gastos fijos y variables del hogar.";
        suggestedAmount = _getBudgetSuggestion(3000);
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Gradient Speedometer
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.orange, Colors.redAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child:
                const Icon(Icons.speed_rounded, size: 100, color: Colors.white),
          ),

          const SizedBox(height: 32),
          Text("Meta Mensual",
              style: TextStyle(
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 16,
                  height: 1.5)),
          const SizedBox(height: 30),

          // Suggestion Chip
          GestureDetector(
            onTap: () {
              _budgetController.text = suggestedAmount.toStringAsFixed(2);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3))),
              child: Text(
                  "Usar sugerido: $_selectedCurrency ${suggestedAmount.toStringAsFixed(0)}",
                  style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 20),

          _buildMoneyInputBig(_budgetController, Colors.orange),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildRoundedTextField(
      String label, TextEditingController controller, IconData icon) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
          color: theme.cardColor, // Lighter slate
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: TextField(
        controller: controller,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: theme.hintColor),
          prefixIcon: Icon(icon, color: theme.primaryColor),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildGlassAccountCard(String title, TextEditingController controller,
      IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.6), // Glass look
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Theme(
        data: ThemeData(
            primaryColor: color,
            textSelectionTheme: TextSelectionThemeData(
                cursorColor: color, selectionColor: color.withOpacity(0.3))),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
              labelText: title,
              labelStyle: TextStyle(color: color.withOpacity(0.8)),
              prefixIcon: Icon(icon, color: color),
              // Moved to Prefix for S/ 200 format
              prefixText: "$_selectedCurrency ",
              prefixStyle: const TextStyle(color: Colors.white70, fontSize: 16),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: color.withOpacity(0.5), width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
              fillColor: Colors.transparent,
              filled: true),
        ),
      ),
    );
  }

  Widget _buildMoneyInputBig(TextEditingController controller, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
            color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixText: _selectedCurrency,
          prefixStyle: TextStyle(color: color, fontSize: 32),
          hintText: "0.00",
          hintStyle: TextStyle(color: Colors.grey[700]),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
