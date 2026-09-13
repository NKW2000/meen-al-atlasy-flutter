/// بيراقب حالة اللعبة وبيشغّل الصوت/الاهتزاز عند كل حدث: كشف جواب، خطأ،
/// ونهاية جولة. منشغّلها بشاشة المضيف وبشاشات اللاعبين حتى يسمع الكل.
///
/// منفّذ عن `feedback/GameCues.kt` بالمشروع الأصلي (Kotlin). قواعد
/// المقارنة مفصولة بدالة نقية [cuesFor] حتى تنختبر بدون واجهة.
library;

import 'package:flutter/widgets.dart';

import '../game/models.dart';
import 'game_feedback.dart';

int _revealedCount(GameState? state) =>
    state?.currentQuestion?.answers.where((a) => a.revealed).length ?? 0;

/// شو لازم ينسمع بين لقطتين — نفس ترتيب `when` بالكوتلن: أول قاعدة
/// بتنطبق بس (قائمة بعنصر واحد أو فاضية).
List<Cue> cuesFor(GameState? previous, GameState next) {
  if (previous == null) return const [];
  final award = next.lastAward;
  // نهاية الجولة بتكشف اللوح كله، فبنعلن الفوز مش كل خانة.
  if (award != null && award != previous.lastAward) return const [Cue.win];
  if (next.strikes > previous.strikes) return [strikeCue(next.strikes)];
  // غلط بالمواجهة ما بياخد X، بس لازم ينسمع.
  if (next.wrongTicks > previous.wrongTicks) return const [Cue.wrong];
  if (_revealedCount(next) > _revealedCount(previous)) return const [Cue.reveal];
  return const [];
}

class GameCues extends StatefulWidget {
  final GameState? state;
  final Widget child;

  const GameCues({super.key, required this.state, required this.child});

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
      for (final cue in cuesFor(_last, next)) {
        feedback.play(cue);
      }
    }
    _last = next;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// دقّات الساعة بآخر [from] ثواني من وقت الجواب. بتبلّش مرة وحدة لما يوصل
/// العدّاد لخمسة، وبتسكت إذا انحكم على الجواب قبل ما يخلص الوقت.
class CountdownCues extends StatefulWidget {
  final int seconds;
  final int from;
  final Widget child;

  const CountdownCues({super.key, required this.seconds, this.from = 5, required this.child});

  @override
  State<CountdownCues> createState() => _CountdownCuesState();
}

class _CountdownCuesState extends State<CountdownCues> {
  int? _stream;

  bool _inWindow(int seconds) => seconds >= 1 && seconds <= widget.from;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(CountdownCues oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) _sync();
  }

  void _sync() {
    if (!mounted) return;
    final feedback = GameFeedbackScope.maybeOf(context);
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
    if (stream != null) GameFeedbackScope.maybeOf(context)?.stopStream(stream);
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
