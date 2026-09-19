import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gestor_gastos/domain/entities/goal_entity.dart';
import 'package:gestor_gastos/domain/repositories/goal_operations_repository.dart';
import 'package:gestor_gastos/domain/usecases/goal_operations_usecases.dart';
import 'package:gestor_gastos/presentation/providers/goal_provider.dart';

class MockDepositToGoalUseCase extends Mock implements DepositToGoalUseCase {}
class MockPurchaseGoalUseCase extends Mock implements PurchaseGoalUseCase {}
class MockDeleteGoalAtomicUseCase extends Mock implements DeleteGoalAtomicUseCase {}
class MockGoalOperationsRepository extends Mock implements GoalOperationsRepository {}

class FakeGoalEntity extends Fake implements GoalEntity {}

void main() {
  late MockDepositToGoalUseCase mockDepositToGoalUseCase;
  late MockPurchaseGoalUseCase mockPurchaseGoalUseCase;
  late MockDeleteGoalAtomicUseCase mockDeleteGoalAtomicUseCase;
  late MockGoalOperationsRepository mockGoalOperationsRepository;
  late GoalProvider provider;

  setUpAll(() {
    registerFallbackValue(FakeGoalEntity());
  });

  setUp(() {
    mockDepositToGoalUseCase = MockDepositToGoalUseCase();
    mockPurchaseGoalUseCase = MockPurchaseGoalUseCase();
    mockDeleteGoalAtomicUseCase = MockDeleteGoalAtomicUseCase();
    mockGoalOperationsRepository = MockGoalOperationsRepository();

    provider = GoalProvider(
      depositToGoalUseCase: mockDepositToGoalUseCase,
      purchaseGoalUseCase: mockPurchaseGoalUseCase,
      deleteGoalAtomicUseCase: mockDeleteGoalAtomicUseCase,
      goalOperationsRepository: mockGoalOperationsRepository,
    );
  });

  test('loadGoals calls getGoals from repository and populates goals list', () async {
    final goals = [
      GoalEntity(id: '1', name: 'Meta 1', targetAmount: 100, currentAmount: 0, iconCode: 0, colorValue: 0),
    ];
    when(() => mockGoalOperationsRepository.getGoals()).thenAnswer((_) async => Right(goals));

    await provider.loadGoals();

    verify(() => mockGoalOperationsRepository.getGoals()).called(1);
    expect(provider.goals.length, 1);
    expect(provider.goals.first.name, 'Meta 1');
  });

  test('addGoal adds goal to state and calls saveGoal on repository', () async {
    when(() => mockGoalOperationsRepository.getGoals()).thenAnswer((_) async => const Right([]));
    when(() => mockGoalOperationsRepository.saveGoal(any())).thenAnswer((_) async => const Right(null));

    await provider.loadGoals();
    expect(provider.goals.isEmpty, isTrue);

    provider.addGoal('New Goal', 500, 123, 0xff0000, iconName: 'icon_name');

    expect(provider.goals.length, 1);
    expect(provider.goals.first.name, 'New Goal');
    await Future.delayed(Duration.zero);
    verify(() => mockGoalOperationsRepository.saveGoal(any())).called(1);
  });

  test('updateGoal updates goal in state and calls saveGoal on repository', () async {
    final goal = GoalEntity(id: '1', name: 'Meta 1', targetAmount: 100, currentAmount: 0, iconCode: 0, colorValue: 0);
    when(() => mockGoalOperationsRepository.getGoals()).thenAnswer((_) async => Right([goal]));
    when(() => mockGoalOperationsRepository.saveGoal(any())).thenAnswer((_) async => const Right(null));

    await provider.loadGoals();

    final updatedGoal = goal.copyWith(name: 'Meta Modificada');
    provider.updateGoal(updatedGoal);

    expect(provider.goals.first.name, 'Meta Modificada');
    await Future.delayed(Duration.zero);
    verify(() => mockGoalOperationsRepository.saveGoal(any())).called(1);
  });

  test('reorderGoals reorders state and saves goals', () async {
    final goal1 = GoalEntity(id: '1', name: 'Meta 1', targetAmount: 100, currentAmount: 0, iconCode: 0, colorValue: 0, orderIndex: 0);
    final goal2 = GoalEntity(id: '2', name: 'Meta 2', targetAmount: 200, currentAmount: 0, iconCode: 0, colorValue: 0, orderIndex: 1);
    when(() => mockGoalOperationsRepository.getGoals()).thenAnswer((_) async => Right([goal1, goal2]));
    when(() => mockGoalOperationsRepository.saveGoal(any())).thenAnswer((_) async => const Right(null));

    await provider.loadGoals();

    provider.reorderGoals(0, 2);

    expect(provider.goals.first.id, '2');
    expect(provider.goals.last.id, '1');
    expect(provider.goals.first.orderIndex, 0);
    expect(provider.goals.last.orderIndex, 1);
    verify(() => mockGoalOperationsRepository.saveGoal(any())).called(2);
  });
}
