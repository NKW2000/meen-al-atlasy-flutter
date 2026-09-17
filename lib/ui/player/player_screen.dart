/// جهاز اللاعب. شاشتين بس:
///
/// 1. **الزر** — لما يكون دورك بالمواجهة، الشاشة كلها زر واحد بيومض. ما في
///    ولا عنصر تاني، فما بتغلط بالضغط حتى لو ما بتتطلع عالجهاز.
/// 2. **اللوح** — بعد ما تضغط (أو لما يجي دورك باللعب) بيبيّن السؤال
///    والخانات الفاضية، وبتنكشف وحدة وحدة مع حكم المضيف.
///
/// اللون بيضل هو الرسالة: أزرق ضغطت، أخضر صح، أحمر غلط.
///
/// منفّذ عن `PlayerScreen` بـ`PlayerScreen.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../../network/player_client.dart';
import '../components/strikes.dart';
import 'buzzer.dart';
import 'play_or_pass.dart';
import 'player_board.dart';
import 'player_lobby.dart';

void _noChoose(bool _) {}
void _noChangeTeam(TeamId _) {}

class PlayerScreen extends StatelessWidget {
  final GameState? state;
  final String? playerId;
  final TeamId? teamId;
  final PlayerMark mark;
  final ConnectionStatus status;
  final VoidCallback onBuzz;
  final void Function(bool play) onChoose;
  final void Function(TeamId team) onChangeTeam;

  const PlayerScreen({
    super.key,
    required this.state,
    required this.playerId,
    required this.teamId,
    required this.mark,
    required this.status,
    required this.onBuzz,
    this.onChoose = _noChoose,
    this.onChangeTeam = _noChangeTeam,
  });

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    final connected = status == ConnectionStatus.connected;

    // قبل ما يبلّش المضيف (وكمان بعد ما يرجّع اللوبي): اللاعب بيشوف رقمه
    // وفريقه وبيقدر يبدّل.
    if (connected && state != null && !state.matchStarted && !state.gameOver) {
      return PlayerLobbyScreen(
        state: state,
        playerId: playerId,
        teamId: teamId,
        onChangeTeam: onChangeTeam,
      );
    }

    // الفائز بالمواجهة بيقرر من جهازه: نلعب أو نمرّر.
    if (connected &&
        state?.phase == RoundPhase.playOrPass &&
        playerId != null &&
        state!.armedPlayerIds().contains(playerId)) {
      return PlayOrPassScreen(state: state, teamId: teamId, onChoose: onChoose);
    }

    final faceOffBuzzer =
        connected && mark == PlayerMark.armed && state?.phase == RoundPhase.faceOff;

    if (faceOffBuzzer) return FullScreenBuzzer(onBuzz: onBuzz);

    // زر «بجاوب»: بس لصاحب الدور، وبس بمرحلة فيها جواب (اللعب، السرقة،
    // والمواجهة التانية). بيوقف العدّاد لحد ما يحكم المضيف.
    final canAnswer = connected &&
        playerId != null &&
        state != null &&
        !state.gameOver &&
        const {
          RoundPhase.play,
          RoundPhase.steal,
          RoundPhase.faceOffSecond,
        }.contains(state.phase) &&
        state.armedPlayerIds().contains(playerId);
    // ضغط أصلاً (أو المضيف واقف العدّاد) — الزر بيصير «عم تجاوب».
    final answering = canAnswer && (mark == PlayerMark.buzzed || state.clockPaused);

    return Stack(
      fit: StackFit.expand,
      children: [
        PlayerBoard(
          state: state,
          playerId: playerId,
          teamId: teamId,
          mark: mark,
          status: status,
          onAnswer: canAnswer && !answering ? onBuzz : null,
          answering: answering,
        ),
        // نفس حركة الخطأ اللي بتطلع عند المضيف — بتطلع عند الكل،
        // وكمان لما يخلص الوقت بدون جواب.
        StrikeFlash(strikes: state?.strikes ?? 0),
      ],
    );
  }
}
