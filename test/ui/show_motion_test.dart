// اختبارات أدوات حركة مشاهد البرنامج — نفس اختبارات RevealMotionTest.kt
// بالإضافة لاختبارات bang/keys/thump من ملف المهمة.
import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/ui/motion/show_motion.dart';

void main() {
  group('bang', () {
    test('bang(0) == 0', () {
      expect(bang(0), 0);
    });

    test('bang(1) == 1', () {
      expect(bang(1), 1);
    });
  });

  group('keys', () {
    test('before delay returns first stop', () {
      final value = keys(0, 1, 1, const [(0.0, 5.0), (1.0, 10.0)]);
      expect(value, 5.0);
    });

    test('after duration returns last stop', () {
      final value = keys(5, 0, 1, const [(0.0, 5.0), (1.0, 10.0)]);
      expect(value, 10.0);
    });
  });

  group('thump', () {
    test('peaks at 1.22 (the 0.52 keyframe) before settling at 1', () {
      // نفس مفاتيح Kotlin: (0, 0), (0.52, 1.22), (0.76, 0.94), (1, 1).
      // القمة 1.22 بتصير لما الوقت المنحني (بعد bang) يوصل ٠٫٥٢ من
      // duration=0.46 — قبل الثانية ٠٫٢٤ لأنه bang بيسرّع البداية.
      var peak = double.negativeInfinity;
      for (var t = 0.0; t <= 0.5; t += 0.0005) {
        final value = thump(t, 0);
        if (value > peak) peak = value;
      }
      expect(peak, closeTo(1.22, 1e-2));
    });

    test('settles at 1 once the duration has elapsed', () {
      expect(thump(0.46, 0), 1.0);
      expect(thump(10, 0), 1.0);
    });

    test('pinned value at the true peak time (t≈0.0998, not the naive 0.24)', () {
      expect(thump(0.0998, 0), closeTo(1.22, 1e-2));
    });
  });

  group('revealDelays (ported from RevealMotionTest.kt)', () {
    test('single new reveal gets no delay', () {
      final delays = revealDelays({0}, {0, 3});
      expect(delays, {3: 0.0});
    });

    test('several reveals in one update are staggered in board order', () {
      final delays = revealDelays({1}, {1, 5, 2, 7}, step: 0.12);
      expect(delays[2], closeTo(0.0, 1e-6));
      expect(delays[5], closeTo(0.12, 1e-6));
      expect(delays[7], closeTo(0.24, 1e-6));
      expect(delays.keys.toSet(), {2, 5, 7});
    });

    test('slots that were already revealed keep no delay', () {
      final delays = revealDelays({0, 1}, {0, 1});
      expect(delays, <int, double>{});
    });

    test('a fresh board with reveals already in it is not staggered', () {
      // لاعب انضم بنص الجولة: كل شي مكشوف بيبين فوراً بدون طابور.
      final delays = revealDelays(null, {0, 2});
      expect(delays, <int, double>{});
    });
  });
}
