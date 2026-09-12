/// رقم اللاعب بمربّع — نفس الرقم عند الخصم.
///
/// منفّذ عن `SeatBadge` بـ`HostSetupScreen.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../arabic_numerals.dart';
import '../theme.dart';

class SeatBadge extends StatelessWidget {
  final int seat;

  /// لاعب منقطع — المربّع بيبهت بدل ما يضل ذهبي.
  final bool dim;
  final double size;

  const SeatBadge({super.key, required this.seat, this.dim = false, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dim ? FeudColors.textMuted : FeudColors.gold,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: FeudColors.ink, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(seat.ar(), style: FeudText.labelMedium(context).copyWith(color: FeudColors.ink)),
    );
  }
}
