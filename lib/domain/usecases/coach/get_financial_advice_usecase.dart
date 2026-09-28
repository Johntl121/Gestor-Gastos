import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../core/services/gemini_client.dart';
import '../../repositories/coach_cache_repository.dart';
import 'build_financial_context_usecase.dart';

class GetFinancialAdviceParams {
  final String periodType; // 'weekly' or 'monthly'
  final BuildFinancialContextParams contextParams;

  GetFinancialAdviceParams({
    required this.periodType,
    required this.contextParams,
  });
}

class GetFinancialAdviceUseCase {
  final BuildFinancialContextUseCase buildContextUseCase;
  final CoachCacheRepository cacheRepository;
  final GeminiClient geminiClient;

  GetFinancialAdviceUseCase({
    required this.buildContextUseCase,
    required this.cacheRepository,
    required this.geminiClient,
  });

  Future<Either<Failure, String>> call(GetFinancialAdviceParams params) async {
    try {
      final contextResult = await buildContextUseCase(params.contextParams);
      return await contextResult.fold(
        (failure) async => Left(failure),
        (contextData) async {
          final advice = await geminiClient.obtenerConsejo(
            contextData: contextData,
            periodType: params.periodType,
            isNewUser: false,
          );
          
          if (params.periodType == 'weekly') {
             await cacheRepository.saveWeeklyAdvice(advice);
          } else {
             await cacheRepository.saveMonthlyAdvice(advice);
          }

          return Right(advice);
        }
      );
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
