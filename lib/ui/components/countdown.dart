/// عدّاد الثواني — بيصير أحمر بآخر ٣ ثواني.
///
/// منفّذ عن `components/Countdown.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../arabic_numerals.dart';
import '../theme.dart';
import 'stage.dart';

class Countdown extends StatelessWidget {
  final int seconds;
  final double size;

  const Countdown({super.key, required this.seconds, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final urgent = seconds >= 1 && seconds <= 3;
    final target = urgent ? FeudColors.pink : FeudColors.gold;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: target, end: target),
      duration: const Duration(milliseconds: 200),
      builder: (context, color, _) => CartoonSurface(
        color: color ?? FeudColors.gold,
        borderWidth: 4,
        corner: 14,
        shadow: 5,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              seconds.ar(),
              style: FeudText.headlineSmall(context).copyWith(color: FeudColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
