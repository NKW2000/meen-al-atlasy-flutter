/// بيراقب حالة اللعبة وبيشغّل الصوت/الاهتزاز عند كل حدث: كشف جواب، خطأ،
/// ونهاية جولة. منشغّلها بشاشة المضيف وبشاشات اللاعبين حتى يسمع الكل.
///
/// منفّذ عن `feedback/GameCues.kt` بالمشروع الأصلي (Kotlin). قواعد
/// المقارنة مفصولة بدالة نقية [cuesFor] حتى تنختبر بدون واجهة.
library;

import 'package:flutter/widgets.dart';
import 'dart:async';

import '../game/models.dart';
import 'game_feedback.dart';

int _revealedCount(GameState? state) =>
    state?.currentQuestion?.answers.where((a) => a.revealed).length ?? 0;

/// شو لازم ينسمع بين لقطتين — نفس ترتيب `when` بالكوتلن: أول قاعدة
/// بتنطبق بس (قائمة بعنصر واحد أو فاضية).
///
/// [forHost] بتشغّل صوت البزر لما لاعب يدوس «بجاوب» — بيتشغّل على جهاز
/// المضيف بس (هو مكبّر صوت الغرفة)، مش على ١٨ تلفون بنفس الوقت.
List<Cue> cuesFor(GameState? previous, GameState next, {bool forHost = false}) {
  if (previous == null) return const [];
  // لاعب دوس «بجاوب»: العدّاد وقف وفي حدا مسجّل ضاغط. صوت البزر عند
  // المضيف هو الإشارة إنه في حدا عم يجاوب ولازم يحكم.
  if (forHost &&
      next.clockPaused &&
      !previous.clockPaused &&
      next.buzzedPlayerId != null) {
    return const [Cue.buzz];
  }
  final award = next.lastAward;
  // السرقة: نجحت = صوت سرقة خاص، فشلت = غلط.
  if (previous.phase == RoundPhase.steal && award != null && award != previous.lastAward) {
    return award.stolen ? const [Cue.stealWin] : const [Cue.wrong];
  }
  // نهاية الجولة بتكشف اللوح كله، فبنعلن الفوز مش كل خانة.
  if (award != null && award != previous.lastAward) return const [Cue.win];
  // خلص الوقت لحاله (كان باقي ثانية والساعة ماشية) — صوت انتهاء الوقت
  // بدل صوت الخطأ العادي.
  final penalised = next.strikes > previous.strikes || next.wrongTicks > previous.wrongTicks;
  if (penalised && previous.answerSecondsLeft == 1 && !previous.clockPaused) {
    return const [Cue.timeUp];
  }
  if (next.strikes > previous.strikes) return [strikeCue(next.strikes)];
  // غلط بالمواجهة ما بياخد X، بس لازم ينسمع.
  if (next.wrongTicks > previous.wrongTicks) return const [Cue.wrong];
  if (_revealedCount(next) > _revealedCount(previous)) return const [Cue.reveal];
  // انتقالات المراحل.
  if (next.phase != previous.phase) {
    switch (next.phase) {
      case RoundPhase.steal:
        return const [Cue.stealOpen];
      case RoundPhase.playOrPass:
        return const [Cue.choicePrompt];
      case RoundPhase.play:
        return previous.phase == RoundPhase.playOrPass ? const [Cue.choiceMade] : const [];
      case RoundPhase.gameOver:
        return const [Cue.gameOver];
      default:
        break;
    }
  }
  // اللوبي: حدا انضم أو راح.
  if (!next.matchStarted) {
    if (next.players.length > previous.players.length) return const [Cue.join];
    if (next.players.length < previous.players.length) return const [Cue.leave];
  }
  return const [];
}

class GameCues extends StatefulWidget {
  final GameState? state;
  final Widget child;

  /// شاشة المضيف — شوف [cuesFor].
  final bool forHost;

  const GameCues({
    super.key,
    required this.state,
    required this.child,
    this.forHost = false,
  });

  @override
  State<GameCues> createState() => _GameCuesState();
}

class _GameCuesState extends State<GameCues> {
  /// اللقطة اللي قارنّا معها آخر مرة — بتبلّش من أول حالة، فما في صوت
  /// عند الدخول عالشاشة.
  late GameState? _last = widget.state;

  @override
  void didUpdateWidget(GameCues oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.state;
    if (next == null) return;
    final feedback = GameFeedbackScope.maybeOf(context);
    if (feedback != null) {
      for (final cue in cuesFor(_last, next, forHost: widget.forHost)) {
        feedback.play(cue);
      }
    }
    _last = next;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// تنبيهات على مواقيت مشهد متحرّك: [cues] بتربط ثانية من بداية المشهد
/// بتنبيه، وكل واحد بيتشغّل مرة وحدة أول ما يمرق وقته. [sceneKey] جديد =
/// مشهد جديد (بتعاد الحسبة). [t] هو وقت المشهد من `ShowScene`.
class TimedCues extends StatefulWidget {
  final double t;
  final Object? sceneKey;
  final Map<double, Cue> cues;
  final Widget child;

  const TimedCues({
    super.key,
    required this.t,
    required this.cues,
    this.sceneKey,
    required this.child,
  });

  @override
  State<TimedCues> createState() => _TimedCuesState();
}

class _TimedCuesState extends State<TimedCues> {
  final Set<double> _fired = {};

  @override
  void didUpdateWidget(TimedCues oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sceneKey != widget.sceneKey || widget.t < oldWidget.t) _fired.clear();
    final feedback = GameFeedbackScope.maybeOf(context);
    if (feedback == null) return;
    for (final entry in widget.cues.entries) {
      if (widget.t >= entry.key && !_fired.contains(entry.key)) {
        _fired.add(entry.key);
        feedback.play(entry.value);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// تنبيه واحد أول ما يتركّب الويدجت — لافتتاحية أو شاشة بتبلّش بصوت.
class CueOnMount extends StatefulWidget {
  final Cue cue;
  final Widget child;

  const CueOnMount({super.key, required this.cue, required this.child});

  @override
  State<CueOnMount> createState() => _CueOnMountState();
}

class _CueOnMountState extends State<CueOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameFeedbackScope.maybeOf(context)?.play(widget.cue);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// دقّات الساعة بآخر [from] ثواني من وقت الجواب. بتبلّش مرة وحدة لما يوصل
/// العدّاد لخمسة، وبتسكت إذا انحكم على الجواب قبل ما يخلص الوقت — أو إذا
/// وقف العدّاد ([paused]: اللاعب دوس «بجاوب»). بدون [paused] كانت الدقّات
/// تكمّل والعدّاد واقف على ٣، فبيحس اللاعب إنه الوقت لسا ماشي.
class CountdownCues extends StatefulWidget {
  final int seconds;
  final int from;
  final bool paused;
  final Widget child;

  const CountdownCues({
    super.key,
    required this.seconds,
    this.from = 5,
    this.paused = false,
    required this.child,
  });

  @override
  State<CountdownCues> createState() => _CountdownCuesState();
}

class _CountdownCuesState extends State<CountdownCues> {
  int? _stream;

  /// محفوظ من `didChangeDependencies` — البحث عن أسلاف الويدجت وقت
  /// `dispose` ممنوع، وكان يرمي بالإصدار أول ما تتسكّر الشاشة والساعة عم تدق.
  GameFeedback? _feedback;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feedback = GameFeedbackScope.maybeOf(context);
  }

  bool _inWindow(int seconds) => !widget.paused && seconds >= 1 && seconds <= widget.from;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(CountdownCues oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds || oldWidget.paused != widget.paused) _sync();
  }

  void _sync() {
    if (!mounted) return;
    final feedback = _feedback ??= GameFeedbackScope.maybeOf(context);
    if (feedback == null) return;
    if (_inWindow(widget.seconds)) {
      _stream ??= feedback.startClock();
    } else {
      final stream = _stream;
      if (stream != null) {
        feedback.stopStream(stream);
        _stream = null;
      }
    }
  }

  @override
  void dispose() {
    final stream = _stream;
    if (stream != null) _feedback?.stopStream(stream);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// صوت البزر — بس بالمواجهة، لأنه هناك السرعة هي اللعبة. بمرحلة اللعب
/// اللمسة مجرد إشارة للمضيف إنك عم تجاوب، فما بدها صوت. الصح والغلط
/// بيجوا من [GameCues] مرة وحدة، حتى ما ينعاد الصوت مرتين.
class PlayerMarkCues extends StatefulWidget {
  final PlayerMark mark;
  final bool faceOff;
  final Widget child;

  const PlayerMarkCues({
    super.key,
    required this.mark,
    required this.faceOff,
    required this.child,
  });

  @override
  State<PlayerMarkCues> createState() => _PlayerMarkCuesState();
}

class _PlayerMarkCuesState extends State<PlayerMarkCues> {
  late PlayerMark _last = widget.mark;

  @override
  void didUpdateWidget(PlayerMarkCues oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mark != _last) {
      if (widget.mark == PlayerMark.buzzed && widget.faceOff) {
        GameFeedbackScope.maybeOf(context)?.play(Cue.buzz);
      }
      _last = widget.mark;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// فرقعات الألعاب النارية: بتتكرّر مع كل دورة (٢٫٦ ث) طول ما الشاشة
/// مفتوحة، بحدّ أقصى [cycles] مرات حتى ما تصير ضجيج.
class FireworksCues extends StatefulWidget {
  final Widget child;
  final Duration cycle;
  final int cycles;

  const FireworksCues({
    super.key,
    required this.child,
    this.cycle = const Duration(milliseconds: 2600),
    this.cycles = 4,
  });

  @override
  State<FireworksCues> createState() => _FireworksCuesState();
}

class _FireworksCuesState extends State<FireworksCues> {
  Timer? _timer;
  int _played = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fire());
  }

  void _fire() {
    if (!mounted || _played >= widget.cycles) return;
    _played++;
    GameFeedbackScope.maybeOf(context)?.play(Cue.fireworks);
    _timer = Timer(widget.cycle, _fire);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
