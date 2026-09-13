/// بلوك الجولة وبلوك المعلومات الصغير.
///
/// منفّذ عن `components/InfoBlocks.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../arabic_numerals.dart';
import '../theme.dart';
import 'stage.dart';

/// بلوك الجولة — نفس الشكل عند المضيف وعند اللاعب.
class RoundBlock extends StatelessWidget {
  final int round;
  final int totalRounds;

  const RoundBlock({super.key, required this.round, required this.totalRounds});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: InfoBlock(
            label: 'الجولة',
            value: '${round.ar()}/${totalRounds.ar()}',
            accent: FeudColors.teal,
          ),
        ),
      ],
    );
  }
}

/// بلوك صغير: عنوان بلون مميّز وتحته القيمة.
class InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const InfoBlock({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return CartoonSurface(
      color: FeudColors.stageAlt,
      borderWidth: 3,
      corner: FeudShape.block,
      shadow: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              style: FeudText.labelSmall(context).copyWith(color: accent),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: FeudText.titleSmall(context).copyWith(color: FeudColors.cream),
            ),
          ],
        ),
      ),
    );
  }
}
