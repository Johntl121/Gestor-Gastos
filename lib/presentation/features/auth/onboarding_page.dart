import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';

import '../../../../data/datasources/preferences_local_data_source.dart';
import '../../../../core/services/database_helper.dart';
import '../../../injection_container.dart' as sl;
import '../../../domain/entities/transaction_entity.dart';
import '../../../domain/entities/account_entity.dart';
import '../dashboard/main_page.dart'; // Correct relative for main_page if it's in dashboard
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'widgets/welcome_step.dart';
import '../../providers/ui_provider.dart';
import '../../../core/constants/app_onboarding_data.dart';
import '../../../core/constants/app_constants.dart';

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
  String _userProfile = ""; // Obligar a que escojan uno

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
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _budgetController.addListener(() => setState(() {}));
  }

  bool get _isCurrentStepValid {
    switch (_currentPage) {
      case 0:
        return _nameController.text.trim().isNotEmpty;
      case 1:
        return _userProfile.isNotEmpty;
      case 2:
        return true; // Siempre válido, si está vacío asume 0
      case 3:
        return _budgetController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

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
      if (!mounted) return;
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

    // Get providers
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final dataSource = sl.sl<PreferencesLocalDataSource>();
    final navigator = Navigator.of(context);

    try {
      // 0. RESET EVERYTHING (Ensures fresh start)
      await LocalDatabase().clearAllTables(); // 1. Limpiar datos viejos
      await dataSource.clearAllPreferences();
      await sl.sl<LocalDatabase>().clearAllTables(); // Wipe Prefs

      // 1. Save Currency
      await dataSource.saveCurrency(_selectedCurrency);
      walletProvider.setCurrency(_selectedCurrency);

      // 2. Save Name & Profile via UiProvider (to update app state instantly)
      final nameToSave = _nameController.text.trim().isEmpty
          ? "Usuario"
          : _nameController.text.trim();
      await uiProvider.setUserName(nameToSave);

      // Save Avatar First
      await uiProvider.setUserAvatar(_selectedAvatar);

      // Save Profile Image if picked (will override avatar visually)
      if (_profileImage != null) {
        await uiProvider.setProfileImagePath(_profileImage!.path);
      }

      // 3. Save Budget
      final budget = budgetValue; // Already validated above
      await dataSource.saveBudgetLimit(budget);
      walletProvider.setBudgetLimit(budget);

      // 4. Create Initial Accounts (Replacing Seed Data)
      // We create accounts with 0 balance and then add "Initial Balance" transactions.
      // This ensures the transaction history reflects the initial money and the balance is correct.
      final cash = double.tryParse(_cashController.text) ?? 0;
      final bank = double.tryParse(_bankController.text) ?? 0;
      final savings = double.tryParse(_savingsController.text) ?? 0;

      // Account 1: Efectivo
      final id1 = await walletProvider.createAccount(AccountEntity(
        id: 0, // Dynamic ID
        name: "Efectivo",
        initialBalance: 0, // Start with 0
        currentBalance: 0,
        iconCode: Icons.money.codePoint, // Billete
        colorValue: Colors.amber.toARGB32(),
        currencySymbol: _selectedCurrency,
        includeInTotal: true,
        isCash: true,
      ));

      // Account 2: Banco
      final id2 = await walletProvider.createAccount(AccountEntity(
        id: 0, // Dynamic ID
        name: "Banco",
        initialBalance: 0,
        currentBalance: 0,
        iconCode: Icons.account_balance.codePoint, // Banco
        colorValue: Colors.blueAccent.toARGB32(),
        currencySymbol: _selectedCurrency,
        includeInTotal: true,
        isCash: false,
      ));

      // Account 3: Ahorros
      final id3 = await walletProvider.createAccount(AccountEntity(
        id: 0, // Dynamic ID
        name: "Ahorros",
        initialBalance: 0,
        currentBalance: 0, // Initialize with same amount
        iconCode: Icons.savings.codePoint, // Chanchito
        colorValue: Colors.purpleAccent.toARGB32(),
        currencySymbol: _selectedCurrency,
        includeInTotal: true,
        isCash: false,
      ));

      // Add Initial Transactions for History
      // Helper to add initial transaction
      Future<void> addInitTx(double amount, int accountId, String desc) async {
        if (amount > 0) {
          final t = TransactionEntity(
              accountId: accountId,
              categoryId: AppConstants.otherIncomeId, // Otros / Saldo Inicial
              amount: amount,
              date: DateTime.now(),
              description: desc,
              note: "Saldo Inicial",
              type: TransactionType.income);

          await transactionProvider.addTransaction(t);
        }
      }

      await addInitTx(cash, id1, "Saldo Inicial Efectivo");
      await addInitTx(bank, id2, "Saldo Inicial Banco");
      await addInitTx(savings, id3, "Saldo Inicial Ahorros");

      // 5. Complete
      await dataSource.setFirstTime(false);

      // Refresh data just in case
      await walletProvider.loadWalletData();

      if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => const MainPage()),
        );
      }
    } catch (e) {
      debugPrint("Error in onboarding: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al configurar: $e")),
        );
        setState(() => _isProcessing = false);
      }
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
            // Theme Toggle Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Consumer<UiProvider>(
                  builder: (context, uiProvider, child) {
                    return IconButton(
                      icon: Icon(uiProvider.isDarkMode
                          ? Icons.light_mode
                          : Icons.dark_mode),
                      color: uiProvider.isDarkMode
                          ? Colors.yellow.shade700
                          : const Color(0xFF1E293B),
                      onPressed: () =>
                          uiProvider.toggleTheme(!uiProvider.isDarkMode),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
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
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
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
                  WelcomeStep(
                    nameController: _nameController,
                    selectedCurrency: _selectedCurrency,
                    onCurrencyChanged: (val) =>
                        setState(() => _selectedCurrency = val),
                    profileImage: _profileImage,
                    selectedAvatar: _selectedAvatar,
                    onAvatarTap: _showAvatarSelectionSheet,
                  ),
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
                    backgroundColor.withValues(alpha: 0),
                    backgroundColor.withValues(alpha: 0.8),
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
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isCurrentStepValid ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_isCurrentStepValid,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: LinearGradient(
                            colors: [cyanColor, blueColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cyanColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isProcessing
                              ? null
                              : (_currentPage == 3
                                  ? _finishOnboarding
                                  : _nextPage),
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                        ),
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

  // --- ELIMINATED STEP 1 ---

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
                  children: AppOnboardingData.avatars
                      .map((emoji) => GestureDetector(
                            onTap: () {
                              setState(() => _selectedAvatar = emoji);
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
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
    return AppOnboardingData.getBudgetSuggestionForCurrency(
        baseAmountPEN, _selectedCurrency);
  }

  // --- STEP 2: PROFILE SELECTOR ---

  Widget _buildProfileSelectorStep() {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            "¿Qué te describe mejor?",
            style: TextStyle(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Esto nos ayuda a personalizar la experiencia para ti.",
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
            physics: const NeverScrollableScrollPhysics(),
            children: AppOnboardingData.profiles.map((profile) {
              return _buildProfileCard(
                profile['title'] as String,
                profile['subtitle'] as String,
                profile['icon'] as IconData,
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildProfileCard(String title, String subtitle, IconData icon) {
    bool isSelected = _userProfile == title;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Unselected State Colors
    final unselectedBg =
        isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50;
    final unselectedBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _userProfile = title);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // For smoother animations, always use a gradient
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF00ACC1), // Cian oscuro
                    Color(0xFF0D47A1), // Azul medianoche
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [unselectedBg, unselectedBg],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: isSelected ? colorScheme.primary : unselectedBorder,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 42,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : (isDark ? Colors.white54 : Colors.black54),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 3: BALANCES ---

  Widget _buildBalancesStep() {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            "Saldo Actual",
            style: TextStyle(
              color: textColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "¿Cuánto dinero tienes ahora mismo?\n(Déjalo en blanco si es 0)",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),
          _AnimatedAccountInput(
            label: "Efectivo",
            controller: _cashController,
            icon: Icons.payments_rounded,
            brandColor: const Color(0xFFFFC107), // Amarillo/Oro
            currencySymbol: _selectedCurrency,
          ),
          const SizedBox(height: 20),
          _AnimatedAccountInput(
            label: "Banco",
            controller: _bankController,
            icon: Icons.account_balance_rounded,
            brandColor: const Color(0xFF2196F3), // Azul Brillante
            currencySymbol: _selectedCurrency,
          ),
          const SizedBox(height: 20),
          _AnimatedAccountInput(
            label: "Ahorros",
            controller: _savingsController,
            icon: Icons.savings_rounded,
            brandColor: const Color(0xFF9C27B0), // Morado/Magenta
            currencySymbol: _selectedCurrency,
          ),
        ],
      ),
    );
  }

  // --- STEP 4: BUDGET (With Smart Suggestions) ---

  Widget _buildBudgetStep() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final textColor = isDark ? Colors.white : Colors.black87;

    final suggestionsData =
        AppOnboardingData.getBudgetSuggestions(_userProfile);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            "Tu Meta Mensual",
            style: TextStyle(
              color: textColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "¿Cuánto es lo máximo que quieres gastar al mes?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 60),

          // GIANT MINIMALIST INPUT
          Column(
            children: [
              IntrinsicWidth(
                child: TextField(
                  controller: _budgetController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Text(
                        _selectedCurrency,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: colorScheme
                              .primary, // Color primario brillante (Cian)
                        ),
                      ),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: "0.00",
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: colorScheme.primary, width: 3),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                          width: 1),
                    ),
                    contentPadding: const EdgeInsets.only(bottom: 8),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              Text(
                "Sugerencias para un $_userProfile:",
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // STYLIZED ACTION CHIPS
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: suggestionsData.map((data) {
                  final amount = _getBudgetSuggestion(data['amount'] as double);
                  final desc = data['desc'] as String;

                  return ActionChip(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    backgroundColor: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : colorScheme.surfaceTint.withValues(alpha: 0.05),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$_selectedCurrency ${amount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _budgetController.text = amount.toStringAsFixed(0);
                    },
                  );
                }).toList(),
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- UI HELPERS ---
}

class _AnimatedAccountInput extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final Color brandColor;
  final String currencySymbol;

  const _AnimatedAccountInput({
    required this.label,
    required this.controller,
    required this.icon,
    required this.brandColor,
    required this.currencySymbol,
  });

  @override
  State<_AnimatedAccountInput> createState() => _AnimatedAccountInputState();
}

class _AnimatedAccountInputState extends State<_AnimatedAccountInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Theme-based colors
    final containerColor = isDark
        ? const Color(0xFF1E2435)
        : widget.brandColor.withValues(alpha: 0.1);

    final borderColor = _isFocused
        ? widget.brandColor
        : (isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.transparent);

    final borderWidth = _isFocused ? 2.0 : 1.0;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: _isFocused && isDark
            ? [
                BoxShadow(
                  color: widget.brandColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: TextStyle(
          fontSize: 20,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          prefixIcon: Icon(
            widget.icon,
            color: widget.brandColor,
          ),
          prefixText: '${widget.currencySymbol} ',
          prefixStyle: TextStyle(
            color: widget.brandColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          labelText: widget.label,
          labelStyle: TextStyle(
            color: _isFocused
                ? widget.brandColor
                : (isDark ? Colors.white54 : Colors.black87),
            fontWeight: FontWeight.w600,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
