/// قطع شاشات الإعدادات: بطاقة، عدّاد زائد/ناقص، وشريحة مضاعف الجولة.
///
/// منفّذ عن `components/SettingsPieces.kt` بالمشروع الأصلي (Kotlin).
///
/// ملاحظة: Flutter عندها widget جاهز اسمه `Stepper` (لمعالج خطوات)،
/// فمنخفيه من `material.dart` حتى نقدر نستعمل نفس اسم الكوتلن هون.
library;

import 'package:flutter/material.dart' hide Stepper;

import '../arabic_numerals.dart';
import '../theme.dart';
import 'stage.dart';

class SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const SettingsCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CartoonSurface(
        color: FeudColors.stageAlt,
        corner: FeudShape.block,
        shadow: 6,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: FeudText.titleMedium(context).copyWith(color: FeudColors.gold)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChange;

  const Stepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FeudText.bodyMedium(context).copyWith(color: FeudColors.text),
          ),
        ),
        const SizedBox(width: 10),
        _StepperButton(
          text: '−',
          enabled: value > min,
          onClick: () => onChange((value - step).clamp(min, max)),
        ),
        SizedBox(
          width: 46,
          child: Text(
            value.ar(),
            textAlign: TextAlign.center,
            style: FeudText.titleLarge(context).copyWith(color: FeudColors.gold),
          ),
        ),
        _StepperButton(
          text: '+',
          enabled: value < max,
          onClick: () => onChange((value + step).clamp(min, max)),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onClick;

  const _StepperButton({
    required this.text,
    required this.enabled,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return CartoonSurface(
      color: enabled ? FeudColors.gold : FeudColors.panelDark,
      borderWidth: 3,
      corner: FeudShape.block,
      shadow: 4,
      onClick: onClick,
      enabled: enabled,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: Text(
            text,
            style: FeudText.titleLarge(context).copyWith(
              color: enabled ? FeudColors.ink : FeudColors.outlineSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class MultiplierChip extends StatelessWidget {
  final int round;
  final int multiplier;
  final VoidCallback onClick;

  const MultiplierChip({
    super.key,
    required this.round,
    required this.multiplier,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (multiplier) {
      1 => FeudColors.stage,
      2 => FeudColors.teal,
      3 => FeudColors.lime,
      _ => FeudColors.pink,
    };

    return CartoonSurface(
      color: color,
      borderWidth: 3,
      corner: FeudShape.block,
      shadow: 4,
      onClick: onClick,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'جولة ${round.ar()}',
              style: FeudText.labelSmall(context).copyWith(
                color: multiplier == 1 ? FeudColors.textMuted : FeudColors.ink,
              ),
            ),
            Text(
              '×${multiplier.ar()}',
              style: FeudText.titleMedium(context).copyWith(
                color: multiplier == 1 ? FeudColors.text : FeudColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
