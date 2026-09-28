import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/domain/repositories/coach_cache_repository.dart';
import 'package:gestor_gastos/domain/usecases/coach/get_financial_advice_usecase.dart';
import 'package:gestor_gastos/domain/usecases/coach/build_financial_context_usecase.dart';
import 'package:gestor_gastos/presentation/providers/coach_provider.dart';

class MockCacheRepo extends Mock implements CoachCacheRepository {}
class MockGetAdvice extends Mock implements GetFinancialAdviceUseCase {}
class FakeGetAdviceParams extends Fake implements GetFinancialAdviceParams {}

void main() {
  late CoachProvider provider;
  late MockCacheRepo mockCacheRepo;
  late MockGetAdvice mockGetAdvice;

  setUpAll(() {
    registerFallbackValue(FakeGetAdviceParams());
  });

  setUp(() {
    mockCacheRepo = MockCacheRepo();
    mockGetAdvice = MockGetAdvice();
    
    when(() => mockCacheRepo.getWeeklyAdvice()).thenAnswer((_) async => null);
    when(() => mockCacheRepo.getMonthlyAdvice()).thenAnswer((_) async => null);
    when(() => mockCacheRepo.getLastWeeklyAnalysisDate()).thenAnswer((_) async => null);
    when(() => mockCacheRepo.getLastMonthlyAnalysisDate()).thenAnswer((_) async => null);

    provider = CoachProvider(
      cacheRepository: mockCacheRepo,
      getFinancialAdvice: mockGetAdvice,
    );
  });

  test('should load cache on init', () async {
    // Wait for the async init to finish
    await Future.delayed(const Duration(milliseconds: 100));

    verify(() => mockCacheRepo.getWeeklyAdvice()).called(1);
    verify(() => mockCacheRepo.getMonthlyAdvice()).called(1);
  });

  test('should update state and save advice when requestAdvice succeeds', () async {
    final params = GetFinancialAdviceParams(periodType: 'weekly', contextParams: BuildFinancialContextParams(currentPeriodTransactions: [], topCategories: [], currencySymbol: 'USD', accounts: [], currencyConvert: (a,b,c) => a));
    
    when(() => mockGetAdvice.call(any())).thenAnswer((_) async => const Right('Great advice!'));

    await provider.requestAdvice('weekly', params);

    expect(provider.isAdviceLoading, false);
    expect(provider.weeklyAdvice, 'Great advice!');
  });

  test('should set error message when requestAdvice fails', () async {
    final params = GetFinancialAdviceParams(periodType: 'weekly', contextParams: BuildFinancialContextParams(currentPeriodTransactions: [], topCategories: [], currencySymbol: 'USD', accounts: [], currencyConvert: (a,b,c) => a));
    
    when(() => mockGetAdvice.call(any())).thenAnswer((_) async => const Left(DatabaseFailure('Error')));

    await provider.requestAdvice('weekly', params);

    expect(provider.isAdviceLoading, false);
    expect(provider.weeklyAdvice, contains('Error al contactar al coach'));
  });
}
