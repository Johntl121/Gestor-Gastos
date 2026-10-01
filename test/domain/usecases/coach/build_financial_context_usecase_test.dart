import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/domain/usecases/coach/build_financial_context_usecase.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:gestor_gastos/domain/entities/account_entity.dart';
import 'package:gestor_gastos/data/models/goal_model.dart';
import 'package:gestor_gastos/data/models/subscription.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/domain/repositories/subscription_repository.dart';
import 'package:gestor_gastos/data/datasources/goal_local_data_source.dart';

class MockPreferences extends Mock implements PreferencesLocalDataSource {}
class MockSubscriptionRepository extends Mock implements SubscriptionRepository {}
class MockGoalDataSource extends Mock implements GoalLocalDataSource {}

void main() {
  late BuildFinancialContextUseCase usecase;
  late MockPreferences mockPrefs;
  late MockSubscriptionRepository mockSubRepo;
  late MockGoalDataSource mockGoalDS;

  setUp(() {
    mockPrefs = MockPreferences();
    mockSubRepo = MockSubscriptionRepository();
    mockGoalDS = MockGoalDataSource();
    usecase = BuildFinancialContextUseCase(
      preferencesLocalDataSource: mockPrefs,
      subscriptionRepository: mockSubRepo,
      goalLocalDataSource: mockGoalDS,
    );
  });

  test('should build financial context string correctly with multicurrency conversion', () async {
    when(() => mockPrefs.getBudgetLimit()).thenReturn(1000.0);
    when(() => mockSubRepo.getSubscriptions()).thenAnswer((_) async => Right([
          Subscription(id: '1', name: 'Netflix', amount: 15.0, accountToCharge: 1, categoryId: 1, paymentDate: DateTime(2023,1,10), isPaid: false, frequency: ExpenseFrequency.monthly)
        ]));
    when(() => mockGoalDS.getGoals()).thenAnswer((_) async => [
          GoalModel(id: '1', name: 'Vacaciones', targetAmount: 500.0, currentAmount: 100.0, accountId: 2, iconCode: 0, colorValue: 0)
        ]);

    final transactions = <TransactionEntity>[
      TransactionEntity(id: 1, accountId: 1, categoryId: 1, amount: -50.0, date: DateTime.now(), type: TransactionType.expense, description: 'Comida'),
      TransactionEntity(id: 2, accountId: 2, categoryId: 2, amount: 200.0, date: DateTime.now(), type: TransactionType.income, description: 'Sueldo'),
    ];

    final accounts = <AccountEntity>[
      const AccountEntity(id: 1, name: 'Main', initialBalance: 0, currentBalance: 0, currencySymbol: 'USD', iconCode: 0, colorValue: 0),
      const AccountEntity(id: 2, name: 'Savings', initialBalance: 0, currentBalance: 0, currencySymbol: 'EUR', iconCode: 0, colorValue: 0),
    ];

    final params = BuildFinancialContextParams(
      currentPeriodTransactions: transactions,
      topCategories: [],
      currencySymbol: 'USD',
      accounts: accounts,
      currencyConvert: (amount, from, to) {
        if (from == 'EUR' && to == 'USD') return amount * 1.1; // 1 EUR = 1.1 USD
        return amount;
      },
    );

    final result = await usecase(params);

    expect(result.isRight(), true);
    final contextString = result.getOrElse(() => '');

    expect(contextString, contains('DATOS DEL USUARIO:'));
    expect(contextString, contains('Moneda Principal: USD'));
    expect(contextString, contains('Total Ingresos: \$ 220.00')); // 200 EUR * 1.1 = 220 USD
    expect(contextString, contains('Total Gastos: \$ -50.00'));
    expect(contextString, contains('Presupuesto Mensual: \$ 1000.00'));
    expect(contextString, contains('Netflix: \$ 15.00'));
    expect(contextString, contains('Vacaciones: \$ 110.00 / \$ 550.00')); // 100 EUR = 110 USD, 500 EUR = 550 USD
  });
}
