import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/core/usecases/usecase.dart';
import 'package:gestor_gastos/domain/entities/budget_mood.dart';
import 'package:gestor_gastos/presentation/providers/stats_provider.dart';
import 'package:gestor_gastos/presentation/providers/wallet_provider.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/data/datasources/goal_local_data_source.dart';
import 'package:gestor_gastos/domain/repositories/subscription_repository.dart';
import 'package:gestor_gastos/data/models/goal_model.dart';
import 'package:gestor_gastos/data/models/account_model.dart';
import 'package:gestor_gastos/core/services/currency_converter.dart';
import 'package:gestor_gastos/domain/usecases/get_budget_mood_usecase.dart';
import 'package:gestor_gastos/domain/usecases/get_transactions_by_date_range_usecase.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MockPreferences extends Mock implements PreferencesLocalDataSource {}
class MockGoals extends Mock implements GoalLocalDataSource {}
class MockSubscriptions extends Mock implements SubscriptionRepository {}
class MockWalletProvider extends Mock implements WalletProvider {}
class MockGetBudgetMoodUseCase extends Mock implements GetBudgetMoodUseCase {}
class MockGetTransactionsByDateRangeUseCase extends Mock implements GetTransactionsByDateRangeUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(NoParams());
    registerFallbackValue(DateRangeParams(start: DateTime.now(), end: DateTime.now()));
  });

  test('StatsProvider buildFinancialContextForAI converts goal amounts to preferred currency', () async {
    final prefs = MockPreferences();
    final goalsSrc = MockGoals();
    final subs = MockSubscriptions();
    final wallet = MockWalletProvider();
    final getMood = MockGetBudgetMoodUseCase();
    final getTxns = MockGetTransactionsByDateRangeUseCase();

    when(() => getMood.call(any())).thenAnswer((_) async => const Right(BudgetMood.neutral));
    when(() => getTxns.call(any())).thenAnswer((_) async => const Right([]));

    when(() => prefs.getCurrency()).thenReturn('S/');
    when(() => prefs.getBudgetLimit()).thenReturn(1000.0);
    when(() => subs.getSubscriptions()).thenAnswer((_) async => const Right([]));
    
    // Meta con cuenta USD
    when(() => goalsSrc.getGoals()).thenAnswer((_) async => [
          GoalModel(
            id: 'g1',
            name: 'Viaje',
            targetAmount: 100.0, // 100 USD
            currentAmount: 50.0, // 50 USD
            deadline: DateTime.now(),
            accountId: 2, // Vinculada a cuenta USD
            colorValue: 0,
            iconCode: 0,
          )
        ]);

    when(() => wallet.currencySymbol).thenReturn('S/');
    when(() => wallet.accounts).thenReturn([
      const AccountModel(
        id: 2,
        name: 'Ahorros USD',
        initialBalance: 0,
        isCash: false,
        colorValue: 0,
        iconCode: 0,
        includeInTotal: true,
        currencySymbol: '\$',
      )
    ]);
    
    // 1 USD = 3.75 PEN
    when(() => wallet.currencyConverter).thenReturn(
        CurrencyConverter(rates: {'S/': 1.0, '\$': 3.75}));

    final provider = StatsProvider(
      getBudgetMood: getMood,
      getTransactionsByDateRange: getTxns,
      preferencesLocalDataSource: prefs,
      goalLocalDataSource: goalsSrc,
      subscriptionRepository: subs,
    );
    provider.updateWalletProvider(wallet);

    final contextStr = await provider.buildFinancialContextForAI();
    
    // 50 USD -> 187.50 PEN, 100 USD -> 375.00 PEN
    expect(contextStr, contains('S/ 187.50 / S/ 375.00'));
  });
}
