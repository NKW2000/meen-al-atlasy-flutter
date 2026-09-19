/// الصوت والاهتزاز مع بعض. لعبة بتنلعب بغرفة فيها ناس، فالتنبيه لازم
/// يوصل بالأذن وبالإيد مش بس بالعين.
///
/// منفّذ عن `feedback/GameFeedback.kt` بالمشروع الأصلي (Kotlin): بدل
/// `SoundPool` مشغّل `audioplayers` واحد لكل تنبيه بوضع الاستجابة السريعة،
/// وبدل `VibrationEffect.createWaveform` نبضات `HapticFeedback` متتالية
/// بنفس التوقيت (فلاتر ما بتعرّض أنماط اهتزاز مخصّصة بدون إضافات).
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// نوع التنبيه — كل واحد له صوت ونمط اهتزاز.
///
/// الأصوات كلها أصلية أو CC0 (شوف `tools/sfx/`): أحداث اللعبة، وكل حركة
/// بالشاشات (بداية الجولة، «استعدوا»، عدّ النقاط، التاج، الألعاب النارية…).
enum Cue {
  // أحداث اللعبة
  reveal, strike1, strike2, strike3, wrong, win, buzz, clock,
  timeUp, stealOpen, stealWin, choicePrompt, choiceMade, faceOffOpen,
  // الحركات والشاشات
  intro, roundStart, versus, scoreCount, crown, banner, gameOver, fireworks,
  // اللوبي والواجهة
  tap, join, leave, connected, kicked, teamSwitch, error,
}

/// صوت الخطأ حسب رقمه: الأول، التاني، التالت.
Cue strikeCue(int number) => switch (number) {
      1 => Cue.strike1,
      2 => Cue.strike2,
      _ => Cue.strike3,
    };

/// ملف كل تنبيه — `sfx_<اسم التنبيه>.mp3` من `tools/sfx/build.js`.
final Map<Cue, String> _files = {
  for (final cue in Cue.values) cue: 'sounds/sfx_${cue.name}.mp3',
};

/// نمط مميّز لكل حدث — الغلط ضربتين، الفوز ثلاث نبضات. نفس
/// `longArrayOf(off, on, off, on…)` بالكوتلن: بالملي ثانية، بتبلّش بسكوت.
const Map<Cue, List<int>> _patterns = {
  Cue.reveal: [0, 28],
  Cue.buzz: [0, 18],
  Cue.strike1: [0, 60],
  Cue.strike2: [0, 60, 70, 60],
  Cue.strike3: [0, 70, 70, 70, 70, 140],
  Cue.wrong: [0, 130],
  Cue.win: [0, 45, 60, 45, 60, 110],
  Cue.timeUp: [0, 120],
  Cue.stealOpen: [0, 40, 60, 40],
  Cue.stealWin: [0, 45, 60, 45, 60, 110],
  Cue.versus: [0, 90],
  Cue.crown: [0, 40],
  Cue.gameOver: [0, 60, 60, 60, 60, 140],
  Cue.kicked: [0, 100],
};

/// مشغّل صوت واحد. مجرّد عن `audioplayers` لسبب واحد: ترتيب
/// «حمّل بعدين شغّل» هو أصل باگ صوت الساعة، ولازم ينختبر بدون منصة صوت.
abstract class CueAudio {
  /// بيحمّل الملف ويجهّز المشغّل. **لازم تنستنى** قبل [restart].
  Future<void> load(String asset);

  /// بيرجّع الصوت لأوله ويشغّله.
  Future<void> restart();

  Future<void> stop();

  Future<void> dispose();
}

/// المشغّل الحقيقي فوق `audioplayers`.
class _AudioPlayersCue implements CueAudio {
  final AudioPlayer _player = AudioPlayer();
  final bool lowLatency;

  _AudioPlayersCue({required this.lowLatency});

  /// كل الإعدادات هون وبانتظار — `setPlayerMode`/`setSource` كلهم
  /// غير متزامنين، وتشغيل قبل ما يخلصوا بيفشل بالسكوت.
  @override
  Future<void> load(String asset) async {
    await _player.setPlayerMode(lowLatency ? PlayerMode.lowLatency : PlayerMode.mediaPlayer);
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(AssetSource(asset));
  }

  @override
  Future<void> restart() async {
    await _player.stop();
    await _player.resume();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

CueAudio _defaultAudio({required bool lowLatency}) => _AudioPlayersCue(lowLatency: lowLatency);

typedef CueAudioFactory = CueAudio Function({required bool lowLatency});

class GameFeedback {
  final Map<Cue, CueAudio> _players = {};

  /// تحميل كل مشغّل — `play` بتنستناه قبل ما تشغّل، فما في تشغيل على
  /// مشغّل ملفه لسا ما وصل.
  final Map<Cue, Future<void>> _loading = {};

  /// مجاري الساعة الشغّالة — `startClock()` بيرجّع رقم حتى نقدر نسكّتها.
  final Map<int, CueAudio> _streams = {};
  int _nextStream = 1;
  bool _released = false;

  final CueAudioFactory _newAudio;

  /// [configureSession] بتنطفّي بالاختبارات — ما في منصة صوت هناك.
  GameFeedback({
    this._newAudio = _defaultAudio,
    bool configureSession = true,
  }) {
    if (configureSession) _configureSession();
    for (final entry in _files.entries) {
      final audio = _newAudio(lowLatency: true);
      _players[entry.key] = audio;
      _loading[entry.key] = audio.load(entry.value).catchError((_) {});
    }
  }

  void _configureSession() {
    try {
      AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient, options: const {}),
        ),
      );
    } catch (_) {
      // جهاز بدون مشغّل صوت — الصوت بيسكت وباقي اللعبة بتكمّل.
    }
  }

  /// صوت الخطأ حسب رقمه.
  Future<void> playStrike(int number) => play(strikeCue(number));

  Future<void> play(Cue cue) async {
    if (_released) return;
    final player = _players[cue];
    if (player != null) {
      try {
        // بينتهي فوراً بعد الإقلاع، وبيحمي أول تنبيه لو صار بسرعة.
        await _loading[cue];
        if (_released) return;
        await player.restart();
      } catch (_) {
        // بدون صوت أحسن من انهيار اللعبة (جهاز بدون مشغّل مثلاً).
      }
    }
    unawaited(_vibrate(cue));
  }

  /// دقّات آخر خمس ثواني. بترجّع رقم المجرى حتى نقدر نسكّتها إذا اللاعب
  /// جاوب قبل ما يخلص الوقت.
  int startClock() {
    final id = _nextStream++;
    if (_released) return id;
    // ملف الساعة ٥ ثواني — مشغّل عادي، مش لقطة `lowLatency` (SoundPool).
    final audio = _newAudio(lowLatency: false);
    _streams[id] = audio;
    unawaited(_startStream(id, audio));
    return id;
  }

  /// حمّل بعدين شغّل. إذا انسكّرت المجرى بهالأثناء (اللاعب جاوب قبل ما
  /// يخلص التحميل) ما منشغّل إشي.
  Future<void> _startStream(int id, CueAudio audio) async {
    try {
      await audio.load(_files[Cue.clock]!);
      if (_released || !identical(_streams[id], audio)) return;
      await audio.restart();
    } catch (_) {
      // بدون دقّات أحسن من انهيار.
    }
  }

  /// بيسكّت كل دقّات الساعة الشغّالة فوراً — اللاعب دوس «بجاوب» وما بدنا
  /// نستنى الحالة ترجع من المضيف حتى يسكت الصوت.
  Future<void> stopClocks() async {
    for (final id in _streams.keys.toList()) {
      await stopStream(id);
    }
  }

  Future<void> stopStream(int streamId) async {
    final player = _streams.remove(streamId);
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    await player.dispose();
  }

  Future<void> _vibrate(Cue cue) async {
    final timings = _patterns[cue];
    if (timings == null) return; // صوت بس — بدون اهتزاز.
    // كل زوج (سكوت، نبضة): منستنى السكوت ومنضرب نبضة بقوّة تناسب طولها.
    for (var i = 0; i + 1 < timings.length; i += 2) {
      if (timings[i] > 0) await Future.delayed(Duration(milliseconds: timings[i]));
      final on = timings[i + 1];
      if (on <= 0) continue;
      if (on >= 100) {
        unawaited(HapticFeedback.heavyImpact());
      } else if (on >= 50) {
        unawaited(HapticFeedback.mediumImpact());
      } else {
        unawaited(HapticFeedback.lightImpact());
      }
      await Future.delayed(Duration(milliseconds: on));
    }
  }

  Future<void> release() async {
    _released = true;
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    for (final player in _streams.values) {
      await player.dispose();
    }
    _streams.clear();
  }
}

/// بيوفّر نسخة وحدة للتطبيق كله — نفس `LocalGameFeedback` +
/// `ProvideGameFeedback` بالكوتلن. بدون [GameFeedback] (الاختبارات مثلاً)
/// التنبيهات بتسكت.
class GameFeedbackScope extends InheritedWidget {
  final GameFeedback? feedback;

  const GameFeedbackScope({super.key, required this.feedback, required super.child});

  static GameFeedback? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameFeedbackScope>()?.feedback;

  @override
  bool updateShouldNotify(GameFeedbackScope oldWidget) => feedback != oldWidget.feedback;
}
