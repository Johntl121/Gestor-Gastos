import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/coach_cache_repository.dart';

class CoachCacheRepositoryImpl implements CoachCacheRepository {
  static const String _keyWeeklyAdvice = 'weekly_advice_content';
  static const String _keyMonthlyAdvice = 'monthly_advice_content';
  static const String _keyLastWeekly = 'last_weekly_analysis_date';
  static const String _keyLastMonthly = 'last_monthly_analysis_date';

  @override
  Future<String?> getWeeklyAdvice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWeeklyAdvice);
  }

  @override
  Future<String?> getMonthlyAdvice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMonthlyAdvice);
  }

  @override
  Future<DateTime?> getLastWeeklyAnalysisDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastWeekly);
    if (str != null) return DateTime.parse(str);
    return null;
  }

  @override
  Future<DateTime?> getLastMonthlyAnalysisDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastMonthly);
    if (str != null) return DateTime.parse(str);
    return null;
  }

  @override
  Future<void> saveWeeklyAdvice(String advice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWeeklyAdvice, advice);
    await prefs.setString(_keyLastWeekly, DateTime.now().toIso8601String());
  }

  @override
  Future<void> saveMonthlyAdvice(String advice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMonthlyAdvice, advice);
    await prefs.setString(_keyLastMonthly, DateTime.now().toIso8601String());
  }

  @override
  Future<void> resetCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastWeekly);
    await prefs.remove(_keyLastMonthly);
  }
}
