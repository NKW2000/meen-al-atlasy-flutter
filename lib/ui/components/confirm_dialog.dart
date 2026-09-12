/// سؤال تأكيد بستايل اللعبة. بيغطي الشاشة كلها وبيبلع اللمسات، فما بتنضغط
/// اللعبة اللي تحته بالغلط.
///
/// منفّذ عن `components/ConfirmDialog.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'buttons.dart';
import 'stage.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String dismissText;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;
  final Color confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.dismissText,
    required this.onConfirm,
    required this.onDismiss,
    this.confirmColor = FeudColors.pink,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: FeudColors.ink.withValues(alpha: 0.82),
        alignment: Alignment.center,
        child: SizedBox(
          width: 600,
          child: CartoonSurface(
            color: FeudColors.stageAlt,
            corner: 22,
            shadow: 9,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FeudText.headlineSmall(context).copyWith(color: FeudColors.gold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: FeudText.bodyLarge(context).copyWith(color: FeudColors.textSoft),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: dismissText,
                          onClick: onDismiss,
                          accent: FeudColors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          text: confirmText,
                          onClick: onConfirm,
                          color: confirmColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
