/// اختبار ترتيب «حمّل بعدين شغّل» بـ[GameFeedback].
///
/// الباگ اللي كان: [GameFeedback.startClock] كان يبني مشغّل جديد، يبعت
/// `setSource` **بدون انتظار**، وبنفس اللحظة ينادي `resume()` — فالملف لسا
/// ما تحمّل والتشغيل بيفشل بالسكوت (الخطأ كان منمسوك ومرمي). باقي
/// الأصوات كانت تشتغل لأن مشغّلاتها بتتبنى عند إقلاع التطبيق وبتكون
/// محمّلة قبل أول استعمال بزمن طويل — فدقّات آخر خمس ثواني بس كانت تسكت.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/feedback/game_feedback.dart';

/// مشغّل وهمي بيسجّل الترتيب، وبيخلّينا نأخّر التحميل متل جهاز حقيقي.
class FakeCueAudio implements CueAudio {
  final List<String> calls;
  final bool lowLatency;
  final Completer<void> loaded = Completer<void>();
  String? asset;
  bool disposed = false;

  FakeCueAudio(this.calls, {required this.lowLatency});

  /// التحميل ما بيخلص لحد ما الاختبار يقول — هيك منشوف شو صار بالنتيجة.
  void finishLoading() {
    if (!loaded.isCompleted) loaded.complete();
  }

  @override
  Future<void> load(String asset) {
    this.asset = asset;
    calls.add('load $asset');
    return loaded.future;
  }

  @override
  Future<void> restart() async => calls.add('restart');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
  }
}

void main() {
  // الاهتزاز بيمرق على قناة منصة — لازم ربط الاختبار يكون جاهز.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late List<FakeCueAudio> made;

  GameFeedback build() {
    calls = [];
    made = [];
    return GameFeedback(
      configureSession: false,
      newAudio: ({required bool lowLatency}) {
        final audio = FakeCueAudio(calls, lowLatency: lowLatency);
        made.add(audio);
        return audio;
      },
    );
  }

  /// آخر مشغّل انبنى — تبع الساعة بعد [GameFeedback.startClock].
  FakeCueAudio last() => made.last;

  void finishAllLoading() {
    for (final audio in made) {
      audio.finishLoading();
    }
  }

  test('the clock waits for the file to load before it plays', () async {
    final feedback = build();
    calls.clear();

    feedback.startClock();
    await pumpEventQueue();

    // لسا عم يحمّل — ممنوع يكون حاول يشغّل.
    expect(calls, ['load sounds/sfx_clock.mp3']);

    last().finishLoading();
    await pumpEventQueue();

    expect(calls, ['load sounds/sfx_clock.mp3', 'restart']);
  });

  test('a clock stopped while still loading never makes a sound', () async {
    final feedback = build();
    calls.clear();

    final id = feedback.startClock();
    await pumpEventQueue();
    await feedback.stopStream(id);

    last().finishLoading();
    await pumpEventQueue();

    expect(calls, isNot(contains('restart')));
    expect(last().disposed, isTrue);
  });

  test('the clock is a normal player, not a low-latency clip', () async {
    final feedback = build();
    feedback.startClock();
    await pumpEventQueue();

    // ملف الساعة ٥ ثواني — وضع الاستجابة السريعة (SoundPool) لللقطات القصيرة.
    expect(last().lowLatency, isFalse);
    expect(last().asset, 'sounds/sfx_clock.mp3');
  });

  test('a cue waits for its own load before playing', () async {
    final feedback = build();
    // مشغّلات التنبيهات بتتبنى مع الصنف — كلها عم تحمّل هلق.
    expect(calls.where((c) => c.startsWith('load')), isNotEmpty);
    calls.clear();

    final playing = feedback.play(Cue.reveal);
    await pumpEventQueue();
    expect(calls, isEmpty); // لسا عم يحمّل

    finishAllLoading();
    await playing;

    expect(calls, contains('restart'));
  });

  test('every cue has a file and a player of its own', () {
    final feedback = build();
    // ٨ تنبيهات — وكل واحد انبناله مشغّل وانطلب ملفه.
    expect(made, hasLength(Cue.values.length));
    expect(
      calls.where((c) => c.startsWith('load')).toSet(),
      hasLength(Cue.values.length), // ملف لكل تنبيه
    );
    expect(feedback, isNotNull);
  });
}
