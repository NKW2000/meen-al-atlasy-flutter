/// لوح اللاعب: نفس لوح المضيف بالضبط — بس بدون السؤال وبدون زر الغلط —
/// بخلفية ثابتة بلون المسرح. تحت بلوك واحد بيقول مين عم يلعب برقمه، وشو
/// المطلوب منّك (وحالتك: ضغطت/صح/غلط).
///
/// منفّذ عن `PlayerBoard` + `TurnBlock` + `statusLine` بـ`PlayerScreen.kt`
/// بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../../network/player_client.dart';
import '../components/seat_badge.dart';
import '../components/stage.dart';
import '../components/strikes.dart';
import '../host/host_board_screen.dart';
import '../responsive.dart';
import '../theme.dart';

/// بمراحل اللعب ما في كبسة (طلب المستخدم): اللاعب بيحكي جوابه والمضيف
/// بيحكم، والعدّاد بيمشي وما بيوقف — إذا ما لحق يجاوب بينحسب عليه غلط.
/// الزر الكبير بالمواجهة (سباق الضغط) بيضل بشاشته.
class PlayerBoard extends StatelessWidget {
  final GameState? state;
  final String? playerId;
  final TeamId? teamId;
  final PlayerMark mark;
  final ConnectionStatus status;

  const PlayerBoard({
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
    final seconds = state == null
        ? 0
        : (state.answerSecondsLeft > state.choiceSecondsLeft
            ? state.answerSecondsLeft
            : state.choiceSecondsLeft);

    return Container(
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
            TurnBlock(
              state: state,
              playerId: playerId,
              teamId: teamId,
              mark: mark,
              status: status,
            ),
          ],
        ),
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
