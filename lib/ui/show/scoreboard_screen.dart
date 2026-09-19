/// النتيجة بين الجولات — نفس مشهد «نهاية الجولة» بملف التصميم
/// (`مين الأطليسي - Play & Pass`): العنوان بيهبط، اللوحان بيطلعان من تحت،
/// الأرقام بتعدّ لفوق مع أعمدتها، وبعدين تاج ذهبي للمتقدّم ولافتة بتكنس.
/// بتظهر عند المضيف وعند كل اللاعبين — بس المضيف عنده زر الجولة الجاية.
///
/// منفّذ عن `ScoreboardScreen.kt` بالمشروع الأصلي (Kotlin).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../feedback/game_cues.dart';
import '../../feedback/game_feedback.dart';

import '../../game/models.dart';
import '../arabic_numerals.dart';
import '../components/buttons.dart';
import '../components/stage.dart';
import '../components/strikes.dart';
import '../motion/show_motion.dart';
import '../responsive.dart';
import '../theme.dart';

const double countStart = 0.5;
const double countTime = 0.9;
const double crownAt = 1.5;
const double bannerAt = 1.56;

class ScoreboardScreen extends StatelessWidget {
  final GameState state;

  /// المضيف بس — عنده زر الجولة الجاية.
  final VoidCallback? onContinue;

  const ScoreboardScreen({super.key, required this.state, this.onContinue});

  @override
  Widget build(BuildContext context) {
    final roundNumber = state.currentQuestionIndex + 1;
    final award = state.lastAward;
    final scores = {
      for (final id in TeamId.values) id: state.teams[id]?.score ?? 0,
    };
    final top = math.max(1, scores.values.reduce(math.max));
    final TeamId? leader = scores[TeamId.team1] == scores[TeamId.team2]
        ? null
        : (scores[TeamId.team1]! > scores[TeamId.team2]!
              ? TeamId.team1
              : TeamId.team2);
    final short = shortSide(context);
    final portrait = isPortrait(context);

    return ShowScene(
      sceneKey: roundNumber,
      cap: 4,
      builder: (context, t) {
        final counted = ((t - countStart) / countTime).clamp(0.0, 1.0);
        return TimedCues(
          t: t,
          sceneKey: roundNumber,
          cues: {
            countStart: Cue.scoreCount,
            if (leader != null) crownAt: Cue.crown,
            if (leader != null) bannerAt: Cue.banner,
          },
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                const SpinningRays(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DropTitle(
                          text:
                              'نتيجة الجولة ${roundNumber.ar()}/${state.questions.length.ar()}',
                          t: t,
                        ),
                        if (award != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            award.stolen
                                ? 'سرقة! ${state.teams[award.teamId]?.name ?? ''} أخد ${award.points.ar()}'
                                : '${state.teams[award.teamId]?.name ?? ''} أخد ${award.points.ar()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FeudText.titleMedium(context).copyWith(
                              color: award.stolen
                                  ? FeudColors.pink
                                  : FeudColors.lime,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Expanded(
                          child: TeamPanels(
                            state: state,
                            scores: scores,
                            top: top,
                            crowned: leader,
                            counted: counted,
                            t: t,
                            portrait: portrait,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // لافتة «مين بالمقدمة» بتكنس عرض الشاشة زي التصميم.
                        LeadBanner(
                          text: leader == null
                              ? 'تعادل'
                              : '${state.teams[leader]?.name ?? ''} بالمقدمة',
                          width: constraints.maxWidth,
                          height: (short * 0.14).clamp(48.0, 74.0),
                          offsetFraction: wipe(t, bannerAt),
                        ),
                        const SizedBox(height: 10),
                        if (onContinue != null)
                          PrimaryButton(
                            text: state.isLastRound
                                ? 'النتيجة النهائية'
                                : 'الجولة الجاية',
                            onClick: onContinue!,
                          )
                        else
                          Text(
                            'بانتظار المضيف يبلّش الجولة الجاية',
                            style: FeudText.titleSmall(context)
                                .copyWith(color: FeudColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// عنوان بيهبط بضربة من فوق — `drop` + `appear`.
class DropTitle extends StatelessWidget {
  final String text;
  final double t;

  const DropTitle({super.key, required this.text, required this.t});

  @override
  Widget build(BuildContext context) {
    final style = FeudText.headlineSmall(context)
        .copyWith(color: FeudColors.gold);
    final lineHeight = style.fontSize! * (style.height ?? 1.2);
    return Opacity(
      opacity: appear(t, 0.04, 0.08),
      child: Transform.translate(
        offset: Offset(0, drop(t, 0.04) * lineHeight),
        child: Text(text, style: style),
      ),
    );
  }
}

/// اللوحان — فوق بعض بالطولي (كل واحد سطر واحد بالاسم والرقم) وجنب بعض
/// بالعرضي. مشترك بين نتيجة الجولة والنتيجة النهائية.
class TeamPanels extends StatelessWidget {
  final GameState state;
  final Map<TeamId, int> scores;
  final int top;
  final TeamId? crowned;
  final double counted;
  final double t;
  final bool portrait;

  const TeamPanels({
    super.key,
    required this.state,
    required this.scores,
    required this.top,
    required this.crowned,
    required this.counted,
    required this.t,
    required this.portrait,
  });

  @override
  Widget build(BuildContext context) {
    final panels = [
      for (final (index, teamId) in TeamId.values.indexed)
        TeamPanel(
          name: state.teams[teamId]?.name ?? '',
          score: scores[teamId]!,
          shown: (scores[teamId]! * counted).toInt(),
          share: (scores[teamId]! / top) * counted,
          crowned: crowned == teamId,
          teamId: teamId,
          t: t,
          delay: index == 0 ? 0.2 : 0.32,
          wide: portrait,
        ),
    ];
    if (portrait) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: panels[0]),
          const SizedBox(height: 14),
          Expanded(child: panels[1]),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: panels[0]),
        const SizedBox(width: 14),
        Expanded(child: panels[1]),
      ],
    );
  }
}

/// لوح فريق: بيطلع من تحت، رقمه بيعدّ، وعموده بيكبر معه.
class TeamPanel extends StatelessWidget {
  final String name;
  final int score;
  final int shown;
  final double share;
  final bool crowned;
  final TeamId teamId;
  final double t;
  final double delay;

  /// بالطولي اللوح بيصير عريض: الاسم والرقم بسطر واحد.
  final bool wide;

  const TeamPanel({
    super.key,
    required this.name,
    required this.score,
    required this.shown,
    required this.share,
    required this.crowned,
    required this.teamId,
    required this.t,
    required this.delay,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = teamId == TeamId.team1
        ? teamId.inkColor()
        : FeudColors.cream;
    final shownText = math.min(shown, score).ar();

    return LayoutBuilder(
      builder: (context, constraints) {
        // الرقم بياخد قياسه من أصغر بُعد باللوح — حتى ما ينفجر بالطولي.
        final basis = math.min(constraints.maxHeight, constraints.maxWidth);
        final scoreSize = wide ? basis * 0.26 : basis * 0.34;
        final scoreStyle = FeudText.displayLarge(context)
            .copyWith(color: scoreColor, fontSize: scoreSize, height: 1.06);

        // بالطولي المتقدّم بيضوي بإطار ذهبي بينبض — زي التصميم.
        final glow = math.max(0.0, (t - crownAt) * 1.4);
        final pulse = 0.6 + 0.4 * math.sin(glow * 4.5);
        final glowAlpha = t > crownAt ? 0.55 + 0.45 * pulse : 0.0;

        return Opacity(
          opacity: appear(t, delay, 0.1),
          child: Transform.translate(
            offset: Offset(0, rise(t, delay) * constraints.maxHeight),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FeudShape.block),
              child: Container(
                color: teamId.color(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (crowned && wide)
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              FeudShape.block,
                            ),
                            border: Border.all(
                              color: FeudColors.gold.withValues(
                                alpha: glowAlpha.clamp(0, 1),
                              ),
                              width: 5,
                            ),
                          ),
                        ),
                      ),
                    if (crowned && !wide)
                      // تاج المتقدّم: شريط ذهبي بينط فوق اللوح.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Transform.scale(
                          scaleY: thump(t, crownAt),
                          child: Container(height: 12, color: FeudColors.gold),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (wide)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: FeudText.titleLarge(context)
                                        .copyWith(color: teamId.inkColor()),
                                  ),
                                ),
                                Text(shownText, maxLines: 1, style: scoreStyle),
                              ],
                            )
                          else ...[
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: FeudText.titleMedium(context)
                                  .copyWith(color: teamId.inkColor()),
                            ),
                            Text(shownText, maxLines: 1, style: scoreStyle),
                          ],
                          const SizedBox(height: 10),
                          FractionallySizedBox(
                            widthFactor: wide ? 1 : 0.64,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 14,
                                color: FeudColors.ink.withValues(alpha: 0.28),
                                alignment: AlignmentDirectional.centerStart,
                                child: FractionallySizedBox(
                                  widthFactor: share.clamp(0.0, 1.0),
                                  heightFactor: 1,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: FeudColors.ink,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(999),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// لافتة ذهبية بتكنس عرض الشاشة وبتقول مين بالمقدمة.
class LeadBanner extends StatelessWidget {
  final String text;
  final double width;
  final double height;
  final double offsetFraction;

  const LeadBanner({
    super.key,
    required this.text,
    required this.width,
    required this.height,
    required this.offsetFraction,
  });

  @override
  Widget build(BuildContext context) {
    // `offset(x)` بالكوتلن بياخد اتجاه الواجهة بعين الاعتبار (RTL: لليسار).
    return Transform.translate(
      offset: Offset(-width * offsetFraction, 0),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: BlockSkin(
          color: FeudColors.gold,
          child: Center(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FeudText.displayLarge(context).copyWith(
                color: FeudColors.ink,
                fontSize: height * 0.45,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
