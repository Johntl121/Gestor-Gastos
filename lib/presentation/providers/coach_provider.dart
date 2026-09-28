import 'package:flutter/material.dart';
import '../../domain/repositories/coach_cache_repository.dart';
import '../../domain/usecases/coach/get_financial_advice_usecase.dart';

class CoachProvider extends ChangeNotifier {
  final CoachCacheRepository cacheRepository;
  final GetFinancialAdviceUseCase getFinancialAdvice;

  CoachProvider({
    required this.cacheRepository,
    required this.getFinancialAdvice,
  }) {
    _loadCache();
  }

  bool _isAdviceLoading = false;
  String? _weeklyAdvice;
  String? _monthlyAdvice;
  DateTime? _lastWeeklyAnalysis;
  DateTime? _lastMonthlyAnalysis;

  bool get isAdviceLoading => _isAdviceLoading;
  String? get weeklyAdvice => _weeklyAdvice;
  String? get monthlyAdvice => _monthlyAdvice;

  String? currentAdvice(String mode) =>
      mode == 'weekly' ? _weeklyAdvice : _monthlyAdvice;

  Future<void> _loadCache() async {
    _weeklyAdvice = await cacheRepository.getWeeklyAdvice();
    _monthlyAdvice = await cacheRepository.getMonthlyAdvice();
    _lastWeeklyAnalysis = await cacheRepository.getLastWeeklyAnalysisDate();
    _lastMonthlyAnalysis = await cacheRepository.getLastMonthlyAnalysisDate();
    notifyListeners();
  }

  bool canRequestAnalysis(String type) {
    final now = DateTime.now();
    if (type == 'weekly') {
      if (_lastWeeklyAnalysis == null) return true;
      return now.difference(_lastWeeklyAnalysis!) >= const Duration(days: 7);
    } else {
      if (_lastMonthlyAnalysis == null) return true;
      return now.difference(_lastMonthlyAnalysis!) >= const Duration(days: 30);
    }
  }

  int getDaysUntilAvailable(String type) {
    if (canRequestAnalysis(type)) return 0;
    final now = DateTime.now();
    if (type == 'weekly' && _lastWeeklyAnalysis != null) {
      return 7 - now.difference(_lastWeeklyAnalysis!).inDays;
    }
    if (type == 'monthly' && _lastMonthlyAnalysis != null) {
      return 30 - now.difference(_lastMonthlyAnalysis!).inDays;
    }
    return 0;
  }

  Future<void> requestAdvice(String type, GetFinancialAdviceParams params) async {
    if (!canRequestAnalysis(type)) return;

    _isAdviceLoading = true;
    notifyListeners();

    final result = await getFinancialAdvice(params);

    result.fold(
      (fail) {
        final errorMessage = "Error al contactar al coach. Inténtalo más tarde.\nDetalle: ${fail.message}";
        if (type == 'weekly') {
           _weeklyAdvice = errorMessage;
        } else {
           _monthlyAdvice = errorMessage;
        }
      },
      (advice) {
        if (type == 'weekly') {
          _weeklyAdvice = advice;
          _lastWeeklyAnalysis = DateTime.now();
        } else {
          _monthlyAdvice = advice;
          _lastMonthlyAnalysis = DateTime.now();
        }
      }
    );

    _isAdviceLoading = false;
    notifyListeners();
  }

  Future<void> resetCoachCooldown() async {
    await cacheRepository.resetCooldown();
    _lastWeeklyAnalysis = null;
    _lastMonthlyAnalysis = null;
    notifyListeners();
  }
}
