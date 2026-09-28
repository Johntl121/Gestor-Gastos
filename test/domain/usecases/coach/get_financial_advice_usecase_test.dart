import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/core/services/gemini_client.dart';
import 'package:gestor_gastos/domain/repositories/coach_cache_repository.dart';
import 'package:gestor_gastos/domain/usecases/coach/build_financial_context_usecase.dart';
import 'package:gestor_gastos/domain/usecases/coach/get_financial_advice_usecase.dart';

class MockBuildContext extends Mock implements BuildFinancialContextUseCase {}
class MockCacheRepo extends Mock implements CoachCacheRepository {}
class MockGemini extends Mock implements GeminiClient {}

class FakeBuildContextParams extends Fake implements BuildFinancialContextParams {}

void main() {
  late GetFinancialAdviceUseCase usecase;
  late MockBuildContext mockBuildContext;
  late MockCacheRepo mockCacheRepo;
  late MockGemini mockGemini;

  setUpAll(() {
    registerFallbackValue(FakeBuildContextParams());
  });

  setUp(() {
    mockBuildContext = MockBuildContext();
    mockCacheRepo = MockCacheRepo();
    mockGemini = MockGemini();
    usecase = GetFinancialAdviceUseCase(
      buildContextUseCase: mockBuildContext,
      cacheRepository: mockCacheRepo,
      geminiClient: mockGemini,
    );
  });

  test('should return advice and save to cache on success', () async {
    final params = GetFinancialAdviceParams(
      periodType: 'weekly',
      contextParams: FakeBuildContextParams(),
    );

    when(() => mockBuildContext.call(any())).thenAnswer((_) async => const Right('Context String'));
    when(() => mockGemini.obtenerConsejo(contextData: 'Context String', periodType: 'weekly', isNewUser: false))
        .thenAnswer((_) async => 'AI Advice');
    when(() => mockCacheRepo.saveWeeklyAdvice('AI Advice')).thenAnswer((_) async => {});

    final result = await usecase(params);

    expect(result, const Right('AI Advice'));
    verify(() => mockCacheRepo.saveWeeklyAdvice('AI Advice')).called(1);
  });

  test('should return failure if context building fails', () async {
    final params = GetFinancialAdviceParams(
      periodType: 'monthly',
      contextParams: FakeBuildContextParams(),
    );

    when(() => mockBuildContext.call(any())).thenAnswer((_) async => const Left(DatabaseFailure('DB Error')));

    final result = await usecase(params);

    expect(result, const Left(DatabaseFailure('DB Error')));
    verifyNever(() => mockGemini.obtenerConsejo(contextData: any(named: 'contextData'), periodType: any(named: 'periodType'), isNewUser: false));
  });

  test('should return failure if gemini fails', () async {
    final params = GetFinancialAdviceParams(
      periodType: 'weekly',
      contextParams: FakeBuildContextParams(),
    );

    when(() => mockBuildContext.call(any())).thenAnswer((_) async => const Right('Context String'));
    when(() => mockGemini.obtenerConsejo(contextData: 'Context String', periodType: 'weekly', isNewUser: false))
        .thenThrow(Exception('API Error'));

    final result = await usecase(params);

    expect(result.isLeft(), true);
    verifyNever(() => mockCacheRepo.saveWeeklyAdvice(any()));
  });
}
