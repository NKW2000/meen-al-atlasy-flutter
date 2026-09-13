/// رأس الشاشة: نتيجة الفريقين على الجناحين، والجولة والأخطاء بالنص.
///
/// منفّذ عن `components/ScoreHeader.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../arabic_numerals.dart';
import '../theme.dart';
import 'buttons.dart';
import 'stage.dart';
import 'strikes.dart';

/// رأس الشاشة: نتيجة الفريقين على الجناحين، والجولة والأخطاء بالنص.
class ScoreHeader extends StatelessWidget {
  final GameState state;

  const ScoreHeader({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 210,
          child: _TeamScoreCard(state: state, teamId: TeamId.team1),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'جولة ${(state.currentQuestionIndex + 1).ar()} من ${state.questions.length.ar()}'
                  '${state.multiplier > 1 ? ' · ×${state.multiplier.ar()}' : ''}',
                  textAlign: TextAlign.center,
                  style: FeudText.labelLarge(context).copyWith(color: FeudColors.gold),
                ),
                if (state.phase == RoundPhase.play || state.phase == RoundPhase.steal) ...[
                  const SizedBox(height: 6),
                  StrikeRow(strikes: state.strikes, size: 34),
                ],
                if (state.pot > 0) ...[
                  const SizedBox(height: 6),
                  Pill(text: 'نقاط الجولة ${state.pot.ar()}', color: FeudColors.gold),
                ],
              ],
            ),
          ),
        ),
        SizedBox(
          width: 210,
          child: _TeamScoreCard(state: state, teamId: TeamId.team2),
        ),
      ],
    );
  }
}

class _TeamScoreCard extends StatelessWidget {
  final GameState state;
  final TeamId teamId;

  const _TeamScoreCard({required this.state, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final team = state.teams[teamId];
    if (team == null) return const SizedBox.shrink();
    final active = state.activeTeam == teamId;

    return AnimatedScale(
      // النتيجة بتنبض لما تزيد.
      scale: active ? 1.03 : 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: CartoonSurface(
        color: team.connected ? teamId.color() : teamId.color().withValues(alpha: 0.45),
        corner: 20,
        shadow: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FeudText.titleMedium(context).copyWith(color: teamId.inkColor()),
                    ),
                    if (active)
                      Text(
                        'دورهم',
                        style: FeudText.labelSmall(context)
                            .copyWith(color: teamId.inkColor().withValues(alpha: 0.75)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: team.score, end: team.score),
                duration: const Duration(milliseconds: 320),
                builder: (context, value, _) => Text(
                  value.ar(),
                  style: FeudText.headlineMedium(context).copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة نتيجة مصغّرة — لشاشات اللاعبين.
class MiniScore extends StatelessWidget {
  final GameState state;
  final TeamId teamId;

  const MiniScore({super.key, required this.state, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final team = state.teams[teamId];
    if (team == null) return const SizedBox.shrink();

    return CartoonSurface(
      color: teamId.color(),
      borderWidth: 4,
      corner: 14,
      shadow: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FeudText.titleSmall(context).copyWith(color: teamId.inkColor()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                team.score.ar(),
                style: FeudText.titleMedium(context).copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
