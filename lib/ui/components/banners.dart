/// شريط السؤال، شريط الحالة، وإعلان النقاط بنهاية الجولة.
///
/// منفّذ عن `components/Banners.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../arabic_numerals.dart';
import '../theme.dart';
import 'stage.dart';
import 'strikes.dart' show TeamColorX;

/// بطاقة السؤال — لوح كريمي زي شاشة البرنامج. عرضها بقد نصّها (مع سقف
/// حتى ما تتمدّد على كل الشاشة بالأسئلة الطويلة)، فبتنتوسّط تماماً جوّا
/// المساحة اللي بتنعطى لها.
class QuestionCard extends StatelessWidget {
  final int round;
  final int totalRounds;
  final String question;

  const QuestionCard({
    super.key,
    required this.round,
    required this.totalRounds,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    return GoldPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Text(
          question,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FeudText.headlineSmall(context).copyWith(color: FeudColors.ink),
        ),
      ),
    );
  }
}

/// شريط الحالة تحت السؤال — بياخد لون الفريق اللي عليه الدور.
class StatusBanner extends StatelessWidget {
  final String text;
  final Color accent;
  final bool filled;

  const StatusBanner({
    super.key,
    required this.text,
    required this.accent,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CartoonSurface(
        color: filled ? accent : FeudColors.ink.withValues(alpha: 0.45),
        borderWidth: 4,
        corner: FeudShape.block,
        shadow: 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: FeudText.titleSmall(context).copyWith(
              color: filled ? FeudColors.ink : FeudColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// إعلان نقاط نهاية الجولة — بينط بضربة.
class AwardBanner extends StatelessWidget {
  final GameState state;

  const AwardBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final award = state.lastAward;
    if (award == null || !state.roundOver) return const SizedBox.shrink();

    final teamName = state.teams[award.teamId]?.name ?? '';
    final text = award.stolen
        ? 'سرقة! $teamName +${award.points.ar()}'
        : '$teamName +${award.points.ar()}';

    return SizedBox(
      width: double.infinity,
      child: CartoonSurface(
        color: award.stolen ? FeudColors.pink : FeudColors.gold,
        borderWidth: 4,
        corner: FeudShape.block,
        shadow: 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: FeudText.titleMedium(context).copyWith(
              color: award.stolen ? Colors.white : FeudColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

Color accentFor(TeamId? teamId) => teamId?.color() ?? FeudColors.gold;

/// فراغ صغير بين عناصر الشاشة.
class BannerSpacer extends StatelessWidget {
  const BannerSpacer({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}
