abstract class CoachCacheRepository {
  Future<String?> getWeeklyAdvice();
  Future<String?> getMonthlyAdvice();
  Future<DateTime?> getLastWeeklyAnalysisDate();
  Future<DateTime?> getLastMonthlyAnalysisDate();

  Future<void> saveWeeklyAdvice(String advice);
  Future<void> saveMonthlyAdvice(String advice);
  Future<void> resetCooldown();
}
