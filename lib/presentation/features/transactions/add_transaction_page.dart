import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Domain Entities
import '../../../domain/entities/transaction_entity.dart';
import '../../../domain/entities/account_entity.dart';

// Providers
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/ui_provider.dart';
import '../../../core/constants/app_categories.dart';

class AddTransactionPage extends StatefulWidget {
  final TransactionEntity? transactionToEdit;
  final TransactionEntity? draftTransaction;

  const AddTransactionPage(
      {super.key, this.transactionToEdit, this.draftTransaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // State variables
  TransactionType _transactionType = TransactionType.expense;
  TransactionEntity? _editingTransaction;

  // Image Attachment
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Account Selection
  int? _selectedSourceAccountId;
  int? _selectedDestAccountId;

  // Category
  int _selectedCategoryId = 3; // Default Shopping

  // Dynamic Currency
  String _activeCurrencySymbol = 'S/';
  bool _hasCurrencyMismatch = false;
  String _mismatchSourceSymbol = '';
  String _mismatchDestSymbol = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (widget.transactionToEdit != null) {
      _editingTransaction = widget.transactionToEdit!;
      _transactionType = _editingTransaction!.amount < 0
          ? TransactionType.expense
          : (_editingTransaction!.type == TransactionType.transfer
              ? TransactionType.transfer
              : TransactionType.income);

      if (_editingTransaction!.type == TransactionType.transfer ||
          _editingTransaction!.description
              .toLowerCase()
              .contains('transferencia')) {
        _transactionType = TransactionType.transfer;
      }

      _amountController.text = _editingTransaction!.amount.abs().toString();
      _selectedCategoryId = _editingTransaction!.categoryId;
      _selectedSourceAccountId = _editingTransaction!.accountId;
      _selectedDestAccountId = _editingTransaction!.destinationAccountId;
      _noteController.text = _editingTransaction!.note ?? '';

      // Load Image
      if (_editingTransaction!.imagePath != null) {
        final file = File(_editingTransaction!.imagePath!);
        if (file.existsSync()) {
          setState(() {
            _selectedImage = file;
          });
        }
      }
    } else if (widget.draftTransaction != null) {
      final t = widget.draftTransaction!;
      _transactionType = t.type;
      _amountController.text = t.amount.abs().toString();
      _selectedCategoryId = t.categoryId;
      _selectedSourceAccountId = t.accountId;
      _selectedDestAccountId = t.destinationAccountId;
      _noteController.text = t.note ?? '';
    } else {
      if (walletProvider.accounts.isNotEmpty) {
        setState(() {
          _selectedSourceAccountId = walletProvider.accounts.first.id;
          if (walletProvider.accounts.length > 1) {
            _selectedDestAccountId = walletProvider.accounts[1].id;
          }
        });
      }
    }

    _updateCurrencySymbol(walletProvider);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 50, // Optimize size
      );

      if (pickedFile != null) {
        // Save permanently
        final directory = await getApplicationDocumentsDirectory();
        final String fileName = path.basename(pickedFile.path);
        final String savedPath = path.join(directory.path, fileName);

        // Copy to app docs
        final File savedFile = await File(pickedFile.path).copy(savedPath);

        setState(() {
          _selectedImage = savedFile;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _updateCurrencySymbol(WalletProvider provider) {
    if (_selectedSourceAccountId != null) {
      try {
        final account = provider.accounts.firstWhere(
            (a) => a.id == _selectedSourceAccountId,
            orElse: () => provider.accounts.first);
        setState(() {
          _activeCurrencySymbol = account.currencySymbol;
        });
      } catch (e) {
        // Fallback if no accounts
      }
    }

    if (_transactionType == TransactionType.transfer &&
        _selectedDestAccountId != null &&
        _selectedSourceAccountId != null) {
      try {
        final source = provider.accounts
            .firstWhere((a) => a.id == _selectedSourceAccountId);
        final dest =
            provider.accounts.firstWhere((a) => a.id == _selectedDestAccountId);

        if (source.currencySymbol != dest.currencySymbol) {
          setState(() {
            _hasCurrencyMismatch = true;
            _mismatchSourceSymbol = source.currencySymbol;
            _mismatchDestSymbol = dest.currencySymbol;
          });
        } else {
          setState(() {
            _hasCurrencyMismatch = false;
          });
        }
      } catch (e) {
        // Accounts might not exist
      }
    } else {
      setState(() {
        _hasCurrencyMismatch = false;
      });
    }
  }

  Color get _activeColor {
    switch (_transactionType) {
      case TransactionType.expense:
        return Colors.redAccent;
      case TransactionType.transfer:
        return const Color(0xFF64B5F6); // Soft Blue
      case TransactionType.income:
        return Colors.green; // Emerald Green
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text;
    if (amountText.isEmpty) return;

    double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    // Validation for Transfer
    if (_transactionType == TransactionType.transfer &&
        _selectedSourceAccountId == _selectedDestAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cuenta de origen y destino no pueden ser iguales')),
      );
      return;
    }

    // Block Currency Mismatch
    if (_hasCurrencyMismatch) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No es posible transferir entre monedas diferentes.")));
      return;
    }

    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    final note = _noteController.text.trim();

    try {
      if (_transactionType == TransactionType.transfer) {
        // Handle Transfer Logic
        if (_selectedSourceAccountId != null &&
            _selectedDestAccountId != null) {
          await transactionProvider.addTransfer(
            amount: amount,
            sourceAccountId: _selectedSourceAccountId!,
            destinationAccountId: _selectedDestAccountId!,
            note: note.isNotEmpty ? note : null,
          );
        }
      } else {
        // Handle Expense/Income logic
        if (_transactionType == TransactionType.expense) {
          amount = amount * -1;
        }

        // Ensure Account ID is valid
        if (_selectedSourceAccountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Selecciona una cuenta")));
          return;
        }

        final activeMap = _transactionType == TransactionType.income
            ? AppCategories.incomeCategories
            : AppCategories.expenseCategories;
        final catName =
            activeMap[_selectedCategoryId]?['name'] ?? 'Transacción';

        if (widget.transactionToEdit != null) {
          // Update Mode
          final updatedTransaction = TransactionEntity(
            id: widget.transactionToEdit!.id,
            accountId: _selectedSourceAccountId!,
            categoryId: _selectedCategoryId,
            amount: amount,
            date: widget.transactionToEdit!.date,
            description: catName,
            note: note.isNotEmpty ? note : null,
            type: _transactionType, // Explicit type update
            imagePath: _selectedImage?.path,
          );
          await transactionProvider.updateTransaction(updatedTransaction);
        } else {
          // Add Mode
          final transaction = TransactionEntity(
            accountId: _selectedSourceAccountId!,
            categoryId: _selectedCategoryId,
            amount: amount,
            date: DateTime.now(),
            description: catName,
            note: note.isNotEmpty ? note : null,
            type: _transactionType, // Explicit type
            imagePath: _selectedImage?.path,
          );
          await transactionProvider.addTransaction(transaction);
        }
      }

      // Refresh Wallet Data to reflect balance changes
      await walletProvider.loadWalletData();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Uses UiProvider for Theme
    final uiProvider = Provider.of<UiProvider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);

    final isDarkMode = uiProvider.isDarkMode;

    // Theme Colors
    final backgroundColor =
        isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF5F7FA);
    final surfaceColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final categoryInactiveBg =
        isDarkMode ? const Color(0xFF1F2937) : Colors.grey[100]!;

    // Bottom Area
    final bottomAreaColor = backgroundColor;
    final inputFillColor =
        isDarkMode ? const Color(0xFF1F2937) : Colors.grey[100]!;
    final bottomBorderColor = isDarkMode ? Colors.white10 : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            widget.transactionToEdit != null ? 'Editar' : 'Nueva Transacción',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),

                  // 1. TOGGLE TYPE (Top)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(25),
                      border: isDarkMode
                          ? null
                          : Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        _buildTypeTab(
                            "Gasto", TransactionType.expense, isDarkMode),
                        _buildTypeTab("Transferencia", TransactionType.transfer,
                            isDarkMode),
                        _buildTypeTab(
                            "Ingreso", TransactionType.income, isDarkMode),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. AMOUNT HERO
                  _buildHeroInput(_activeCurrencySymbol, isDarkMode),

                  const SizedBox(height: 20),

                  // 3. SOURCE / DEST (If Transfer)
                  if (_transactionType == TransactionType.transfer) ...[
                    // Origin
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("DESDE (ORIGEN)",
                          style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 12),
                    _buildAccountSelector(walletProvider.accounts,
                        isSource: true, isDarkMode: isDarkMode),

                    const SizedBox(height: 24),

                    // Destination
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("HACIA (DESTINO)",
                          style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 12),
                    _buildAccountSelector(walletProvider.accounts,
                        isSource: false, isDarkMode: isDarkMode),

                    if (_hasCurrencyMismatch)
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    Colors.redAccent.withValues(alpha: 0.3))),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  "No es posible transferir entre monedas diferentes ($_mismatchSourceSymbol vs $_mismatchDestSymbol).\nPor favor, registra un Gasto y un Ingreso por separado.",
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 12)))
                        ]),
                      )
                  ] else ...[
                    // STANDARD EXPENSE/INCOME
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("CUENTA",
                          style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 12),
                    _buildAccountSelector(walletProvider.accounts,
                        isSource: true, isDarkMode: isDarkMode),
                    const SizedBox(height: 30),

                    // 4. CATEGORY GRID
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("CATEGORÍA",
                          style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 16),

                    // Determine which map to show
                    Builder(builder: (context) {
                      final activeMap =
                          _transactionType == TransactionType.income
                              ? AppCategories.incomeCategories
                              : AppCategories.expenseCategories;
                      final keys = activeMap.keys.toList();

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5, // Cleaner Grid
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.70,
                        ),
                        itemCount: keys.length,
                        itemBuilder: (context, index) {
                          final catId = keys[index];
                          // Pass the map to the item builder so it looks up correctly
                          return _buildCategoryItem(
                              catId, categoryInactiveBg, isDarkMode, activeMap);
                        },
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildStickyBottomArea(context, isDarkMode, bottomAreaColor,
              inputFillColor, bottomBorderColor)
        ],
      ),
    );
  }

  Widget _buildTypeTab(String text, TransactionType type, bool isDarkMode) {
    final isSelected = _transactionType == type;
    final inactiveTextColor = isDarkMode ? Colors.grey : Colors.grey[600];

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTypeChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : inactiveTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  void _onTypeChanged(TransactionType type) {
    if (_transactionType != type) {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      setState(() {
        _transactionType = type;
        if (type == TransactionType.income) {
          _selectedCategoryId = AppCategories.incomeCategories.keys.first;
        } else {
          _selectedCategoryId = AppCategories.expenseCategories.keys.first;
        }
        _updateCurrencySymbol(walletProvider);
      });
    }
  }

  Widget _buildHeroInput(String currency, bool isDarkMode,
      {TextEditingController? controller}) {
    final ctrl = controller ?? _amountController;
    // Usamos el color activo para el texto también para que combine con el cursor
    final amountColor = isDarkMode ? Colors.white : _activeColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          currency,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _activeColor, // Símbolo en color activo
          ),
        ),
        const SizedBox(width: 12),
        IntrinsicWidth(
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
            cursorColor: _activeColor, // Color dinámico según tipo
            cursorHeight: 40.0, // Altura ajustada a fuente
            cursorWidth: 3.0,
            cursorRadius: const Radius.circular(2.0),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  fontSize: 40),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            autofocus: true,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector(List<AccountEntity> accounts,
      {required bool isSource, required bool isDarkMode}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: accounts.map((account) {
          return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _buildAccountChip(account,
                  isSource: isSource, isDarkMode: isDarkMode));
        }).toList(),
      ),
    );
  }

  Widget _buildAccountChip(AccountEntity account,
      {required bool isSource, required bool isDarkMode}) {
    final selectedId =
        isSource ? _selectedSourceAccountId : _selectedDestAccountId;
    final isSelected = selectedId == account.id;
    final inactiveTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[800];
    final inactiveBorderColor =
        isDarkMode ? Colors.transparent : Colors.grey[400]!;
    final inactiveBgColor =
        isDarkMode ? const Color(0xFF1F2937) : Colors.grey[100]!;

    // Use account color
    final Color chipColor = Color(account.colorValue);
    const Color contentColor = Colors
        .white; // Or evaluate contrast: ThemeData.estimateBrightnessForColor(chipColor) == Brightness.dark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSource) {
            _selectedSourceAccountId = account.id;
          } else {
            _selectedDestAccountId = account.id;
          }
          final provider = Provider.of<WalletProvider>(context, listen: false);
          _updateCurrencySymbol(provider);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : inactiveBgColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: inactiveBorderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(account.displayIcon,
                size: 18, color: isSelected ? contentColor : inactiveTextColor),
            const SizedBox(width: 8),
            Text(
              account.name,
              style: TextStyle(
                  color: isSelected ? contentColor : inactiveTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(int id, Color inactiveBgColor, bool isDarkMode,
      Map<int, Map<String, dynamic>> activeMap) {
    final isSelected = _selectedCategoryId == id;
    final catData = activeMap[id]!;
    final color = _activeColor;
    final inactiveIconColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isSelected ? color.withValues(alpha: 0.2) : inactiveBgColor,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: color, width: 2) : null,
            ),
            child: Icon(
              catData['icon'] as IconData,
              color: isSelected ? color : inactiveIconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            catData['name'] as String,
            style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  Widget _buildStickyBottomArea(BuildContext context, bool isDarkMode,
      Color bgColor, Color inputFillColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 20),
      decoration: BoxDecoration(
          color: bgColor, border: Border(top: BorderSide(color: borderColor))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimalist Note Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
                color: inputFillColor, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _noteController,
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                icon: const Icon(Icons.edit_note, color: Colors.grey),
                hintText: "Nota (Opcional)",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: InputBorder.none,
                isCollapsed: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Attachment UI
          Row(
            children: [
              if (_selectedImage != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    )
                  ],
                ),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: inputFillColor,
                  foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                icon: const Icon(Icons.image_outlined, size: 20),
                label: const Text("Foto"),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _activeColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                  elevation: 5,
                  shadowColor: _activeColor.withValues(alpha: 0.5),
                ),
                child: const Text("Guardar",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
