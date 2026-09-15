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
/// الستريكات تلاتة، وكل وحدة إلها صوتها زي البرنامج.
enum Cue { reveal, strike1, strike2, strike3, wrong, win, buzz, clock }

/// صوت الخطأ حسب رقمه: الأول، التاني، التالت.
Cue strikeCue(int number) => switch (number) {
      1 => Cue.strike1,
      2 => Cue.strike2,
      _ => Cue.strike3,
    };

const Map<Cue, String> _files = {
  Cue.reveal: 'sounds/sfx_reveal.mp3',
  Cue.strike1: 'sounds/sfx_strike1.mp3',
  Cue.strike2: 'sounds/sfx_strike2.mp3',
  Cue.strike3: 'sounds/sfx_strike3.mp3',
  Cue.wrong: 'sounds/sfx_wrong.mp3',
  Cue.win: 'sounds/sfx_reveal.mp3', // نفس صوت الكشف (بطلب المستخدم)
  Cue.buzz: 'sounds/sfx_press.mp3',
  Cue.clock: 'sounds/sfx_clock.mp3',
};

/// نمط مميّز لكل حدث — الغلط ضربتين، الفوز ثلاث نبضات. نفس
/// `longArrayOf(off, on, off, on…)` بالكوتلن: بالملي ثانية، بتبلّش بسكوت.
const Map<Cue, List<int>> _patterns = {
  Cue.reveal: [0, 28],
  Cue.buzz: [0, 18],
  Cue.clock: [0, 0],
  Cue.strike1: [0, 60],
  Cue.strike2: [0, 60, 70, 60],
  Cue.strike3: [0, 70, 70, 70, 70, 140],
  Cue.wrong: [0, 130],
  Cue.win: [0, 45, 60, 45, 60, 110],
};

class GameFeedback {
  final Map<Cue, AudioPlayer> _players = {};

  /// مجاري الساعة الشغّالة — `startClock()` بيرجّع رقم حتى نقدر نسكّتها.
  final Map<int, AudioPlayer> _streams = {};
  int _nextStream = 1;
  bool _released = false;

  GameFeedback() {
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
    for (final entry in _files.entries) {
      _players[entry.key] = _newPlayer(entry.value);
    }
  }

  AudioPlayer _newPlayer(String asset) {
    final player = AudioPlayer()
      ..setPlayerMode(PlayerMode.lowLatency)
      ..setReleaseMode(ReleaseMode.stop);
    unawaited(player.setSource(AssetSource(asset)).catchError((_) {}));
    return player;
  }

  /// صوت الخطأ حسب رقمه.
  Future<void> playStrike(int number) => play(strikeCue(number));

  Future<void> play(Cue cue) async {
    if (_released) return;
    final player = _players[cue];
    if (player != null) {
      try {
        await player.stop();
        await player.resume();
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
    final player = _newPlayer(_files[Cue.clock]!);
    _streams[id] = player;
    unawaited(player.resume().catchError((_) {}));
    return id;
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
    final timings = _patterns[cue]!;
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
