/// النتيجة النهائية — نفس لغة «نتيجة الجولة»: أشعة بتلف، اللوحان بيطلعان
/// من تحت وأرقامهم بتعدّ مع أعمدتها، الفائز بيضوي، ولافتة ذهبية بتكنس
/// باسمه، وفوق الكل قصاصات وألعاب نارية.
///
/// منفّذ عن `GameOverScreen.kt` بالمشروع الأصلي (Kotlin).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../components/buttons.dart';
import '../components/fireworks.dart';
import '../motion/show_motion.dart';
import '../responsive.dart';
import '../theme.dart';
import 'scoreboard_screen.dart';

class GameOverScreen extends StatelessWidget {
  final GameState state;
  final VoidCallback? onBackHome;
  final VoidCallback? onBackToLobby;

  const GameOverScreen({super.key, required this.state, this.onBackHome, this.onBackToLobby});

  @override
  Widget build(BuildContext context) {
    final winner = state.leadingTeam;
    final winnerName = winner == null ? null : state.teams[winner]?.name;
    final scores = {for (final id in TeamId.values) id: state.teams[id]?.score ?? 0};
    final top = math.max(1, scores.values.reduce(math.max));
    final portrait = isPortrait(context);
    final short = shortSide(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ShowScene(
          sceneKey: 'final',
          cap: 4,
          builder: (context, t) {
            final counted = ((t - 0.5) / 0.9).clamp(0.0, 1.0);
            return LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  const SpinningRays(),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          DropTitle(text: 'النتيجة النهائية', t: t),
                          const SizedBox(height: 12),
                          Expanded(
                            child: TeamPanels(
                              state: state,
                              scores: scores,
                              top: top,
                              crowned: winner,
                              counted: counted,
                              t: t,
                              portrait: portrait,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LeadBanner(
                            text: winnerName == null ? 'تعادل!' : 'فاز $winnerName',
                            width: constraints.maxWidth,
                            height: (short * 0.14).clamp(52.0, 84.0),
                            offsetFraction: wipe(t, 1.56),
                          ),
                          if (onBackHome != null || onBackToLobby != null) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                if (onBackToLobby != null)
                                  Expanded(
                                    child: PrimaryButton(
                                      text: 'رجوع للوبي',
                                      onClick: onBackToLobby!,
                                      color: FeudColors.lime,
                                    ),
                                  ),
                                if (onBackToLobby != null && onBackHome != null)
                                  const SizedBox(width: 12),
                                if (onBackHome != null)
                                  Expanded(
                                    child: PrimaryButton(
                                      text: 'الرئيسية',
                                      onClick: onBackHome!,
                                      color: FeudColors.teal,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const IgnorePointer(child: _Confetti()),
        // ألعاب نارية فوق القصاصات — نفس ألوان اللعبة وحدودها الحبرية.
        const IgnorePointer(child: Fireworks()),
      ],
    );
  }
}

/// كونفيتي بيوقع من فوق — ورق ملوّن بحدود سودا.
class _Confetti extends StatefulWidget {

  const _Confetti();

  static const int pieces = 14;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  static const _colors = [
    FeudColors.gold,
    FeudColors.pink,
    FeudColors.teal,
    FeudColors.lime,
    FeudColors.cream,
  ];

  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// نفس `infiniteRepeatable(tween(duration, delayMillis))`: تقدّم كل قصاصة
  /// من زمن مشترك — بتبلّش بعد تأخيرها وبتعيد الدورة بدون توقف.
  double _progress(int index, double seconds) {
    final duration = (2200 + (index % 5) * 350) / 1000;
    final delay = index * 160 / 1000;
    if (seconds < delay) return 0;
    return ((seconds - delay) % duration) / duration;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final seconds = _clock.value * 60;
        return Stack(
          children: [
            for (var index = 0; index < _Confetti.pieces; index++)
              Positioned(
                // `offset(x)` بالكوتلن بياخد الاتجاه بعين الاعتبار — RTL من اليمين.
                right: 14.0 + index * 62,
                top: -30 + _progress(index, seconds) * 460,
                child: Container(
                  width: 8.0 + (index % 3) * 4,
                  height: 12.0 + (index % 2) * 6,
                  decoration: BoxDecoration(
                    color: _colors[index % _colors.length],
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: FeudColors.ink, width: 2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
