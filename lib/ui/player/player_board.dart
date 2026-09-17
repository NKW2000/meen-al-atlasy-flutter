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

/// بمراحل اللعب في زر «بجاوب» جنب بلوك الدور (طلب المستخدم): اللاعب
/// اللي عليه الدور بيدوسه فيوقف العدّاد، بيحكي جوابه بصوته، والمضيف بيحكم
/// صح أو غلط. بدونه كان العدّاد بيكمّل وهو عم يحكي وبينحسب عليه غلط.
/// الزر الكبير بالمواجهة (سباق الضغط) بيضل بشاشته لحاله.
class PlayerBoard extends StatelessWidget {
  final GameState? state;
  final String? playerId;
  final TeamId? teamId;
  final PlayerMark mark;
  final ConnectionStatus status;

  /// «بجاوب» — بيطلع بس لما يكون الدور على صاحب الجهاز. `null` يعني ما
  /// في زر (دور حدا تاني، أو مرحلة ما فيها جواب).
  final VoidCallback? onAnswer;

  /// دوس الزر أصلاً والعدّاد واقف — الزر بيصير «عم تجاوب» ومطفّي.
  final bool answering;

  const PlayerBoard({
    super.key,
    required this.state,
    required this.playerId,
    required this.teamId,
    required this.mark,
    required this.status,
    this.onAnswer,
    this.answering = false,
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
                // بلوك الدور بنفس ارتفاع خانات الأجوبة بالضبط. نقاط الفرق
                // مش هون — بتبيّن بشاشة النتيجة بين الجولات.
                footer: TurnBlock(
                  state: state,
                  playerId: playerId,
                  teamId: teamId,
                  mark: mark,
                  status: status,
                  onAnswer: onAnswer,
                  answering: answering,
                ),
              ),
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

  /// شوف [PlayerBoard.onAnswer].
  final VoidCallback? onAnswer;
  final bool answering;

  const TurnBlock({
    super.key,
    required this.state,
    required this.playerId,
    required this.teamId,
    required this.mark,
    required this.status,
    this.onAnswer,
    this.answering = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    // مين عليه الدور فعلاً: لاعب الدور باللعب، اللي ضغط بالمواجهة، أو لاعب
    // المنصة تبع الخصم بالمواجهة التانية. بدون رجوع لصاحب الجهاز — هيك
    // كان الكل بيشوف «دورك» بعد ما يغلط الأول.
    final current = state?.whoseTurn();
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
              // زر الجواب جنب البلوك: بيوقف العدّاد حتى يسمعك المضيف ويحكم.
              if (onAnswer != null || answering) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 122,
                  child: FlatButton(
                    text: answering ? 'عم تجاوب' : 'بجاوب',
                    color: answering ? FeudColors.gold : FeudColors.lime,
                    textColor: FeudColors.ink,
                    shadow: FeudColors.ink,
                    enabled: !answering && onAnswer != null,
                    onClick: onAnswer ?? () {},
                  ),
                ),
              ],
            ] else
              Expanded(
                child: Text(
                  _idleLine(state, status),
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

/// سطر البلوك لما ما في لاعب عالدور.
String _idleLine(GameState? state, ConnectionStatus status) {
  if (status != ConnectionStatus.connected) return connectionLabel(status);
  if (state == null) return 'بانتظار المضيف';
  return switch (state.phase) {
    RoundPhase.faceOff => 'المواجهة — أول ضغطة بتجاوب',
    RoundPhase.playOrPass => 'الفائز بالمواجهة عم يقرر',
    RoundPhase.roundEnd => 'انتهت الجولة',
    _ => 'بانتظار المضيف',
  };
}

String connectionLabel(ConnectionStatus status) => switch (status) {
  ConnectionStatus.idle => 'غير متصل',
  ConnectionStatus.connecting => 'جاري البحث عن المضيف...',
  ConnectionStatus.connected => 'متصل',
  // الانقطاع المش مقصود بيتبعه رجوع تلقائي (PlayerController) — فمنقول
  // للاعب إنه عم نرجّعه، مش بس إنه انقطع.
  ConnectionStatus.disconnected => 'انقطع الاتصال — عم نرجّعك',
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
