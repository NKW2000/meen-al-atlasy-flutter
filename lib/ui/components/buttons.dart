/// زر أساسي وثانوي وشارة مدوّرة — بترتكز كلها على [CartoonSurface].
///
/// منفّذ عن أزرار `components/Stage.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'stage.dart';

/// زر أساسي — ذهبي كرتوني.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onClick;
  final bool enabled;
  final Color color;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onClick,
    this.enabled = true,
    this.color = FeudColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return CartoonSurface(
      color: enabled ? color : FeudColors.panelDark,
      corner: 18,
      shadow: 6,
      onClick: onClick,
      enabled: enabled,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: FeudText.titleLarge(context).copyWith(
            color: enabled ? FeudColors.ink : FeudColors.outlineSoft,
          ),
        ),
      ),
    );
  }
}

/// زر ثانوي — بلون مخصص (فيروزي افتراضياً).
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onClick;
  final bool enabled;
  final Color accent;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onClick,
    this.enabled = true,
    this.accent = FeudColors.teal,
  });

  @override
  Widget build(BuildContext context) => PrimaryButton(
        text: text,
        onClick: onClick,
        enabled: enabled,
        color: accent,
      );
}

/// شارة صغيرة مدوّرة.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const Pill({
    super.key,
    required this.text,
    required this.color,
    this.textColor = FeudColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(FeudShape.pill),
        border: Border.all(color: FeudColors.ink, width: 3),
      ),
      child: Text(
        text,
        style: FeudText.labelLarge(context).copyWith(color: textColor),
      ),
    );
  }
}
