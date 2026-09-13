/// لوحة المضيف — بس هون بينحكم صح/غلط، وبس من هون بتتغير الحالة.
/// الكشف بيصير بالضغط على خانة الجواب نفسها.
///
/// الترتيب: الوقت عالجنب، السؤال بلوح كريمي، الأجوبة ثمان خانات دايماً
/// (عمود بالطولي وعمودين بالعرضي)، وتحت زر الغلط. ما في زر «صح»: المضيف
/// بيدوس على خانة الجواب نفسها فبتنقلب خضرا. النقاط ما بتبيّن هون —
/// بتبيّن بشاشة النتيجة بين الجولات.
///
/// منفّذ عن `HostGameBoardScreen.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../arabic_numerals.dart';
import '../components/answer_slot.dart';
import '../components/seat_badge.dart';
import '../components/stage.dart';
import '../components/strikes.dart';
import '../motion/show_motion.dart';
import '../responsive.dart';
import '../theme.dart';

/// عدد خانات اللوح — أكتر عدد أجوبة بالسؤال.
const int boardSlots = 8;

/// قواعد اللوح على [GameState] — نفس الدوال الخاصة بالكوتلن، عامة هون
/// حتى يشاركها لوح اللاعب والاختبارات.
extension HostBoardState on GameState {
  /// المضيف بيقدر يحكم بس لما يكون في لاعب مستنّي حكم.
  bool canJudge() => switch (phase) {
        // إذا ما ضل حدا يقدر يضغط (كلهم انقطعوا) المضيف بيكمّل بإيده.
        RoundPhase.faceOff => buzzedTeam() != null || armedPlayerIds().isEmpty,
        RoundPhase.faceOffSecond || RoundPhase.play || RoundPhase.steal => true,
        // بعد نهاية الجولة الخانات بتضل تنضغط حتى يكشف الباقي وحدة وحدة.
        RoundPhase.roundEnd => true,
        _ => false,
      };

  /// ما بينتقل للجولة الجاية إلا لما يكشف كل اللوح.
  bool boardFullyRevealed() => currentQuestion?.answers.every((a) => a.revealed) ?? true;

  String nextButtonLabel() => isLastRound ? 'إنهاء اللعبة' : 'الجولة الجاية';

  /// اللاعب اللي عليه الدور هلق — لاعب الدور باللعب، اللي ضغط بالمواجهة،
  /// أو لاعب المنصة تبع الخصم بالمواجهة التانية. `null` لما ما في حدا محدّد
  /// (المواجهة قبل الضغطة، قرار العب/تمرير، بين الجولات).
  Player? whoseTurn() {
    final byId = player(turnPlayerId ?? buzzedPlayerId);
    if (byId != null) return byId;
    if (phase == RoundPhase.faceOffSecond && faceOffTeam != null) {
      return podiumPlayer(faceOffTeam!);
    }
    return null;
  }

  /// تبديل السؤال مسموح قبل ما تبلّش الجولة فعلياً — يعني بالمواجهة وبدون كشف.
  bool canChangeQuestion() =>
      (phase == RoundPhase.faceOff || phase == RoundPhase.faceOffSecond) &&
      (currentQuestion?.answers.every((a) => !a.revealed) ?? false);
}

void _noop() {}

class HostGameBoardScreen extends StatelessWidget {
  final GameState state;
  final void Function(int index) onCorrect;
  final VoidCallback onWrong;
  final VoidCallback onNextRound;
  final VoidCallback onChangeQuestion;

  const HostGameBoardScreen({
    super.key,
    required this.state,
    required this.onCorrect,
    required this.onWrong,
    required this.onNextRound,
    this.onChangeQuestion = _noop,
  });

  @override
  Widget build(BuildContext context) {
    final canJudge = state.canJudge();
    final revealedAll = state.boardFullyRevealed();
    final seconds = state.answerSecondsLeft > state.choiceSecondsLeft
        ? state.answerSecondsLeft
        : state.choiceSecondsLeft;
    final portrait = isPortrait(context);

    final questionCard = BlockSkin(
      color: FeudColors.cream,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Center(
          child: Text(
            state.currentQuestion?.text ?? '—',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: FeudText.titleLarge(context).copyWith(color: FeudColors.ink),
          ),
        ),
      ),
    );

    final Widget judgeBar;
    if (state.phase == RoundPhase.roundEnd) {
      judgeBar = FlatButton(
        text: revealedAll ? state.nextButtonLabel() : 'اكشف الباقي',
        color: FeudColors.lime,
        textColor: FeudColors.ink,
        shadow: FeudColors.limeShadow,
        enabled: revealedAll,
        onClick: onNextRound,
      );
    } else if (state.faceOffFailed && state.canChangeQuestion()) {
      // الاتنين غلطوا: نفس الزر بمكانه بينقلب «بدّل السؤال».
      judgeBar = FlatButton(
        text: 'بدّل السؤال ⟳',
        color: FeudColors.gold,
        textColor: FeudColors.ink,
        shadow: FeudColors.goldShadow,
        onClick: onChangeQuestion,
      );
    } else {
      judgeBar = FlatButton(
        text: 'غلط ✕',
        color: FeudColors.pink,
        textColor: Colors.white,
        shadow: FeudColors.strikeShadow,
        enabled: canJudge,
        onClick: onWrong,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        StageBackground(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          // الوقت والأخطاء بالزاويتين الفوقانيتين بمستوى النوتش نفسه (بدون
          // هامش من فوق) — النوتش بالنص والزاويتين فاضيتين، فمنستغلّهن.
          // الباقي جوّا المنطقة الآمنة.
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PortraitBoardHeader(
                  seconds: seconds,
                  strikes: state.strikes,
                  total: state.strikesToSteal,
                ),
                const SizedBox(height: 10),
                // السؤال بسطر لحاله تحتهن بالوضعين؛ بالعرضي الأجوبة
                // بتتوزّع على عمودين لأن العرض بيسمح.
                questionCard,
                const SizedBox(height: 10),
                Expanded(
                  child: AnswerBoardColumns(
                    answers: state.currentQuestion?.answers ?? const [],
                    columns: portrait ? 1 : 2,
                    enabled: canJudge,
                    onCorrect: onCorrect,
                  ),
                ),
                const SizedBox(height: 10),
                // مين عليه الدور هلق — المضيف بدّه يعرف على مين بيحكم.
                HostTurnChip(state: state),
                const SizedBox(height: 10),
                judgeBar,
              ],
            ),
          ),
        ),
        StrikeFlash(strikes: state.strikes),
      ],
    );
  }
}

/// ثمان خانات دايماً — أكتر عدد أجوبة بالسؤال ثمانية — موزّعة على
/// [columns] عمود. نفس الشبكة عند المضيف (بتنضغط) وعند اللاعب (بتتفرّج).
/// «اكشف الباقي» بيكشف كذا خانة مرة وحدة — بتتقلب وحدة ورا التانية.
class AnswerBoardColumns extends StatefulWidget {
  final List<Answer> answers;
  final int columns;
  final bool enabled;

  /// اللاعب ما بيشوف نص الجواب ولا نقاطه قبل ما يكشفه المضيف.
  final bool revealHiddenText;
  final void Function(int index)? onCorrect;

  const AnswerBoardColumns({
    super.key,
    required this.answers,
    required this.columns,
    required this.enabled,
    this.revealHiddenText = true,
    this.onCorrect,
  });

  @override
  State<AnswerBoardColumns> createState() => _AnswerBoardColumnsState();
}

/// `rememberRevealDelays` بالكوتلن: بيتذكّر آخر مجموعة مكشوفة وبيحسب
/// تأخير كل خانة انكشفت هلق.
class _AnswerBoardColumnsState extends State<AnswerBoardColumns> {
  Set<int>? _revealed;
  Map<int, double> _delays = const {};

  Map<int, double> _revealDelays() {
    final revealed = {
      for (final (i, a) in widget.answers.indexed)
        if (a.revealed) i,
    };
    if (_revealed == null || !_setEq(revealed, _revealed!)) {
      _delays = revealDelays(_revealed, revealed);
      _revealed = revealed;
    }
    return _delays;
  }

  static bool _setEq(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);

  @override
  Widget build(BuildContext context) {
    final answers = widget.answers;
    final slots = answers.length > boardSlots ? answers.length : boardSlots;
    final perColumn = (slots + widget.columns - 1) ~/ widget.columns;
    final delays = _revealDelays();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var column = 0; column < widget.columns; column++) ...[
          if (column > 0) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var row = 0; row < perColumn; row++) ...[
                  if (row > 0) const SizedBox(height: 10),
                  Expanded(
                    child: () {
                      final index = column * perColumn + row;
                      if (index >= slots) return const SizedBox.shrink();
                      return AnswerSlotRow(
                        position: index + 1,
                        answer: index < answers.length ? answers[index] : null,
                        enabled: widget.enabled,
                        revealHiddenText: widget.revealHiddenText,
                        revealDelay: delays[index] ?? 0,
                        onClick: widget.onCorrect == null ? null : () => widget.onCorrect!(index),
                      );
                    }(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// سطر الوقت والأخطاء: الوقت عاليمين والأخطاء عالشمال — نفس الشريط عند
/// المضيف وعند اللاعب — بالزاويتين الفوقانيتين، والنص بيناتهن فاضي (للنوتش).
class PortraitBoardHeader extends StatelessWidget {
  final int seconds;
  final int strikes;
  final int total;

  const PortraitBoardHeader({
    super.key,
    required this.seconds,
    required this.strikes,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: FeudColors.panelDark,
            borderRadius: BorderRadius.circular(FeudShape.block),
            border: Border.all(color: FeudColors.stageAlt, width: 3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                seconds > 0 ? seconds.ar() : '—',
                style: FeudText.headlineSmall(context).copyWith(color: FeudColors.gold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Spacer(),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < total; index++) ...[
              if (index > 0) const SizedBox(width: 7),
              _StrikeDot(lit: index < strikes),
            ],
          ],
        ),
      ],
    );
  }
}

class _StrikeDot extends StatelessWidget {
  final bool lit;

  const _StrikeDot({required this.lit});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: lit ? const _DropShadowPainter() : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: lit ? FeudColors.pink : FeudColors.stageAlt,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '✕',
          style: FeudText.titleMedium(context)
              .copyWith(color: lit ? Colors.white : FeudColors.outlineSoft),
        ),
      ),
    );
  }
}

/// ظل صلب تحت النقطة المضوية — `drawBehind { drawCircle(... +3.dp) }`.
class _DropShadowPainter extends CustomPainter {
  const _DropShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2 + 3),
      size.shortestSide / 2,
      Paint()..color = FeudColors.strikeShadow,
    );
  }

  @override
  bool shouldRepaint(_DropShadowPainter oldDelegate) => false;
}

/// زر مسطّح بظل تحته — شكل أزرار التصميم بالوضع الطولي.
class FlatButton extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final Color shadow;
  final bool enabled;
  final VoidCallback onClick;

  const FlatButton({
    super.key,
    required this.text,
    required this.color,
    required this.textColor,
    required this.shadow,
    this.enabled = true,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onClick : null,
      child: BlockSkin(
        color: enabled ? color : color.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              text,
              maxLines: 1,
              style: FeudText.titleLarge(context).copyWith(
                color: enabled ? textColor : textColor.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بلوك الدور عند المضيف: رقم واسم اللاعب اللي عليه الدور وفريقه — أو
/// «المواجهة: فلان ضد فلان» قبل ما يضغط حدا. نفس منطق بلوك اللاعب.
class HostTurnChip extends StatelessWidget {
  final GameState state;

  const HostTurnChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final current = state.whoseTurn();
    final team = current?.teamId ?? state.activeTeam;
    final color = team?.color() ?? FeudColors.panelDark;
    final ink = team == null ? FeudColors.textMuted : team.inkColor();

    final String label;
    if (current != null) {
      label = 'دور ${current.name} — ${state.teams[current.teamId]?.name ?? ''}';
    } else {
      final a = state.podiumPlayer(TeamId.team1)?.name;
      final b = state.podiumPlayer(TeamId.team2)?.name;
      label = switch (state.phase) {
        RoundPhase.faceOff when a != null && b != null => 'المواجهة: $a ضد $b — أول ضغطة بتجاوب',
        RoundPhase.faceOff => 'المواجهة — أول ضغطة بتجاوب',
        RoundPhase.playOrPass => '${state.teams[state.faceOffWinner]?.name ?? ''} عم يقرر: يلعب أو يمرّر',
        RoundPhase.roundEnd => 'انتهت الجولة — اكشف الباقي',
        _ => '—',
      };
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(FeudShape.block),
        border: Border.all(color: FeudColors.ink, width: 3),
      ),
      child: Row(
        children: [
          if (current != null) ...[
            SeatBadge(seat: current.seat, dim: !current.connected, size: 28),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FeudText.titleMedium(context).copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
