import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/main.dart';

void main() {
  group('Relock Grace Period', () {
    const gracePeriod = Duration(seconds: 60);

    test('30s background -> no relock', () {
      final bgAt = DateTime(2025, 1, 1, 10, 0, 0);
      final resumeAt = bgAt.add(const Duration(seconds: 30));
      
      final shouldLock = shouldLockApp(
        backgroundedAt: bgAt,
        resumedAt: resumeAt,
        gracePeriod: gracePeriod,
      );
      
      expect(shouldLock, isFalse);
    });

    test('59s -> no relock', () {
      final bgAt = DateTime(2025, 1, 1, 10, 0, 0);
      final resumeAt = bgAt.add(const Duration(seconds: 59));
      
      final shouldLock = shouldLockApp(
        backgroundedAt: bgAt,
        resumedAt: resumeAt,
        gracePeriod: gracePeriod,
      );
      
      expect(shouldLock, isFalse);
    });

    test('60s exactos -> relock', () {
      final bgAt = DateTime(2025, 1, 1, 10, 0, 0);
      final resumeAt = bgAt.add(const Duration(seconds: 60));
      
      final shouldLock = shouldLockApp(
        backgroundedAt: bgAt,
        resumedAt: resumeAt,
        gracePeriod: gracePeriod,
      );
      
      expect(shouldLock, isTrue);
    });

    test('61s -> relock', () {
      final bgAt = DateTime(2025, 1, 1, 10, 0, 0);
      final resumeAt = bgAt.add(const Duration(seconds: 61));
      
      final shouldLock = shouldLockApp(
        backgroundedAt: bgAt,
        resumedAt: resumeAt,
        gracePeriod: gracePeriod,
      );
      
      expect(shouldLock, isTrue);
    });

    test('dos períodos de 40s separados -> no se acumulan', () {
      final bgAt1 = DateTime(2025, 1, 1, 10, 0, 0);
      final resumeAt1 = bgAt1.add(const Duration(seconds: 40));
      
      final shouldLock1 = shouldLockApp(
        backgroundedAt: bgAt1,
        resumedAt: resumeAt1,
        gracePeriod: gracePeriod,
      );
      expect(shouldLock1, isFalse);

      final bgAt2 = resumeAt1.add(const Duration(seconds: 10));
      final resumeAt2 = bgAt2.add(const Duration(seconds: 40));
      
      final shouldLock2 = shouldLockApp(
        backgroundedAt: bgAt2,
        resumedAt: resumeAt2,
        gracePeriod: gracePeriod,
      );
      expect(shouldLock2, isFalse);
    });

    test('paused en t0, paused nuevamente en t0+40s, resumed en t0+70s -> relock', () {
      DateTime? backgroundedAt;
      void simulatePaused(DateTime time) {
        backgroundedAt ??= time;
      }

      // t0
      simulatePaused(DateTime(2025, 1, 1, 10, 0, 0));

      // t0+40s
      simulatePaused(DateTime(2025, 1, 1, 10, 0, 40));

      // t0+70s
      final resumedAt = DateTime(2025, 1, 1, 10, 1, 10);

      final lock = shouldLockApp(
        backgroundedAt: backgroundedAt,
        resumedAt: resumedAt,
        gracePeriod: const Duration(seconds: 60),
      );

      expect(lock, isTrue);
    });

    test('paused cuando _isLocked == true -> no inicia _backgroundedAt', () {
      DateTime? backgroundedAt;

      void simulateLifecyclePaused(DateTime time, bool locked) {
        if (!locked) {
          backgroundedAt ??= time;
        }
      }

      simulateLifecyclePaused(DateTime(2025, 1, 1, 10, 0, 0), true);
      expect(backgroundedAt, isNull);
    });
  });
}
