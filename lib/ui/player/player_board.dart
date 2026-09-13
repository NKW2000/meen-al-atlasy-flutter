/// لوح اللاعب: نفس لوح المضيف بالضبط — بس بدون السؤال وبدون زر الغلط —
/// بخلفية ثابتة بلون المسرح. تحت بلوك واحد بيقول مين عم يلعب برقمه، وشو
/// المطلوب منّك (وحالتك: ضغطت/صح/غلط).
///
/// منفّذ عن `PlayerBoard` + `TurnBlock` + `statusLine` بـ`PlayerScreen.kt`
/// بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/models.dart';
import '../../feedback/game_feedback.dart';
import '../../network/player_client.dart';
import '../components/seat_badge.dart';
import '../components/stage.dart';
import '../components/strikes.dart';
import '../host/host_board_screen.dart';
import '../responsive.dart';
import '../theme.dart';

class PlayerBoard extends StatefulWidget {
  final GameState? state;
  final String? playerId;
  final TeamId? teamId;
  final PlayerMark mark;
  final ConnectionStatus status;
  final VoidCallback onBuzz;

  const PlayerBoard({
    super.key,
    required this.state,
    required this.playerId,
    required this.teamId,
    required this.mark,
    required this.status,
    required this.onBuzz,
  });

  @override
  State<PlayerBoard> createState() => _PlayerBoardState();
}

class _PlayerBoardState extends State<PlayerBoard> with SingleTickerProviderStateMixin {
  /// إطار ذهبي بيخبى ونبضة ببلوك الدور لحظة الضغط — مع الصوت والاهتزاز، حتى يحس
  /// اللاعب إنه ضغطته وصلت قبل ما يرجع رد المضيف من الشبكة.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  void _signal() {
    HapticFeedback.heavyImpact();
    GameFeedbackScope.maybeOf(context)?.play(Cue.buzz);
    _flash.forward(from: 0);
    widget.onBuzz();
  }

  @override
  Widget build(BuildContext context) {
    // الخلفية ثابتة بلون المسرح (طلب المستخدم — بالكوتلن كانت تتلوّن حسب
    // الحالة): ضغط/صح/غلط بيبيّنوا ببلوك الدور تحت، مش بلون الشاشة كلها.
    // بمرحلة اللعب دورك بينبّه: أي لمسة بتقول للمضيف إنك عم تجاوب.
    final canSignal = widget.mark == PlayerMark.armed;
    final state = widget.state;
    final seconds = state == null
        ? 0
        : (state.answerSecondsLeft > state.choiceSecondsLeft
              ? state.answerSecondsLeft
              : state.choiceSecondsLeft);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canSignal ? _signal : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: FeudColors.stage,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            // الوقت والأخطاء بالزاويتين الفوقانيتين بمستوى النوتش — نفس المضيف.
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PortraitBoardHeader(
                    seconds: seconds,
                    strikes: state?.strikes ?? 0,
                    total: state?.strikesToSteal ?? 3,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: AnswerBoardColumns(
                      answers: state?.currentQuestion?.answers ?? const [],
                      columns: isPortrait(context) ? 1 : 2,
                      enabled: false,
                      revealHiddenText: false,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // نقاط الفرق مش هون — بتبيّن بشاشة النتيجة بين الجولات.
                  // نبضة صغيرة ببلوك الدور لحظة الضغط.
                  ScaleTransition(
                    scale: TweenSequence<double>([
                      TweenSequenceItem(tween: Tween(begin: 1, end: 1.06), weight: 35),
                      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1), weight: 65),
                    ]).animate(_flash),
                    child: TurnBlock(
                      state: state,
                      playerId: widget.playerId,
                      teamId: widget.teamId,
                      mark: widget.mark,
                      status: widget.status,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // إطار ذهبي رفيع حول الشاشة بيخبى بسرعة — بدون ما تضوي الشاشة
          // كلها (كانت ومضة كاملة وما عجبت).
          IgnorePointer(
            child: FadeTransition(
              opacity: Tween<double>(
                begin: 1,
                end: 0,
              ).chain(CurveTween(curve: Curves.easeOut)).animate(_flash),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: FeudColors.gold, width: 6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بلوك الدور: رقم اللاعب اللي عليه الدور واسمه، وتحته سطر الحالة.
class TurnBlock extends StatelessWidget {
  final GameState? state;
  final String? playerId;
  final TeamId? teamId;
  final PlayerMark mark;
  final ConnectionStatus status;

  const TurnBlock({
    super.key,
    required this.state,
    required this.playerId,
    required this.teamId,
    required this.mark,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    final me = state?.player(playerId);
    final current = state?.player(state.turnPlayerId ?? state.buzzedPlayerId) ?? me;
    final team = current?.teamId ?? teamId;
    final color = team?.color() ?? FeudColors.gold;
    final ink = team?.inkColor() ?? FeudColors.ink;

    return CartoonSurface(
      color: color,
      borderWidth: 3,
      corner: FeudShape.block,
      shadow: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // بس مين عليه الدور ورقمه (طلب المستخدم) — بدون سطر حالة. لما ما
        // في لاعب عالدور (قبل ما توصل حالة، أو انقطع الاتصال) بيبيّن حالة
        // الاتصال حتى ما يضل البلوك فاضي.
        child: Row(
          children: [
            if (current != null) ...[
              SeatBadge(seat: current.seat, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  current.id == playerId ? 'دورك' : 'دور ${current.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FeudText.titleMedium(context).copyWith(color: ink),
                ),
              ),
            ] else
              Expanded(
                child: Text(
                  status == ConnectionStatus.connected ? 'بانتظار المضيف' : connectionLabel(status),
                  maxLines: 1,
                  style: FeudText.titleMedium(context).copyWith(color: ink),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String connectionLabel(ConnectionStatus status) => switch (status) {
  ConnectionStatus.idle => 'غير متصل',
  ConnectionStatus.connecting => 'جاري البحث عن المضيف...',
  ConnectionStatus.connected => 'متصل',
  ConnectionStatus.disconnected => 'انقطع الاتصال',
};

String statusLine(PlayerMark mark, GameState? state, TeamId? teamId, ConnectionStatus status) {
  if (status != ConnectionStatus.connected) return connectionLabel(status);
  if (state == null) return 'بانتظار المضيف';
  if (state.gameOver) return 'انتهت اللعبة';

  switch (mark) {
    case PlayerMark.armed:
      return state.phase == RoundPhase.steal
          ? 'دوس عالشاشة لتجاوب — عندك جواب واحد بس'
          : 'دورك — دوس عالشاشة لتجاوب';
    case PlayerMark.buzzed:
      return 'ضغطت! المضيف عم يسمع جوابك';
    case PlayerMark.correct:
      return 'صح ✔ — الدور بينتقل لزميلك';
    case PlayerMark.wrong:
      return 'غلط ✘ — استنى لحد ما يخلّص زمايلك';
    case PlayerMark.idle:
      if (state.phase == RoundPhase.playOrPass) {
        final winner = state.faceOffWinner == null ? null : state.teams[state.faceOffWinner!];
        return '${winner?.name ?? ''} عم يقرر يلعب أو يمرّر';
      }
      if (state.phase == RoundPhase.roundEnd && state.roundWinner == teamId) {
        return 'الجولة إلنا!';
      }
      if (state.phase == RoundPhase.roundEnd) return 'انتهت الجولة';
      if (state.turnPlayerId != null) {
        final name = state.player(state.turnPlayerId)?.name;
        return name == null ? 'استنى دورك' : 'الدور على $name';
      }
      if (state.activeTeam == teamId) return 'دور فريقك';
      return 'استنى دورك';
  }
}
