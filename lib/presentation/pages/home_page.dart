import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/account_entity.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/budget_mood_widget.dart';
import 'add_transaction_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AccountEnumType _selectedType = AccountEnumType.cash;

  @override
  void initState() {
    super.initState();
    // Cargar datos al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 1. Carita (Budget Mood) y Resumen Superior
          const BudgetMoodWidget(),

          const SizedBox(height: 20),

          // 2. Switch Efectivo / Digital
          SegmentedButton<AccountEnumType>(
            segments: const [
              ButtonSegment<AccountEnumType>(
                value: AccountEnumType.cash,
                label: Text('Efectivo'),
                icon: Icon(Icons.money),
              ),
              ButtonSegment<AccountEnumType>(
                value: AccountEnumType.digital,
                label: Text('Digital'),
                icon: Icon(Icons.credit_card),
              ),
            ],
            selected: <AccountEnumType>{_selectedType},
            onSelectionChanged: (Set<AccountEnumType> newSelection) {
              setState(() {
                _selectedType = newSelection.first;
              });
            },
          ),

          const SizedBox(height: 20),

          // Muestra el saldo específico del tipo seleccionado
          Consumer<DashboardProvider>(
            builder: (context, provider, child) {
              final balance = _selectedType == AccountEnumType.cash
                  ? provider.balanceBreakdown?.cash
                  : provider.balanceBreakdown?.digital;

              return Text(
                "Disponible: S/ ${balance?.toStringAsFixed(2) ?? '0.00'}",
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              );
            },
          ),

          const SizedBox(height: 10),
          const Divider(),

          // 3. Lista de Transacciones (Placeholder por ahora, ya que no tenemos un UseCase de "GetTransactions" aún)
          // Asumo que el usuario quiere filtrar transacciones por el tipo seleccionado,
          // pero el prompt actual solo pedía mostrar la lista. Para MVP pondré un placeholder visual.
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text(
                    "No hay movimientos recientes en ${_selectedType == AccountEnumType.cash ? 'Efectivo' : 'Digital'}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
