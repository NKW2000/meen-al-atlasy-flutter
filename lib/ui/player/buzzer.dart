/// الشاشة كلها زر. الخلفية ثابتة (بنفسجي المسرح) وبس الزر بينبض وحواليه
/// حلقة بتتوسّع — مشدود للعين بدون وميض أبيض/أسود بيوجعها.
///
/// منفّذ عن `FullScreenBuzzer` بـ`PlayerScreen.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../responsive.dart';
import '../theme.dart';

/// قطر زر البزّ.
const double buzzerSize = 190;

class FullScreenBuzzer extends StatefulWidget {
  final VoidCallback onBuzz;

  const FullScreenBuzzer({super.key, required this.onBuzz});

  @override
  State<FullScreenBuzzer> createState() => _FullScreenBuzzerState();
}

class _FullScreenBuzzerState extends State<FullScreenBuzzer> with TickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..repeat(reverse: true);
  late final Animation<double> _pulse = Tween<double>(begin: 0.97, end: 1.05)
      .chain(CurveTween(curve: Curves.fastOutSlowIn))
      .animate(_pulseController);
  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  static const double _shadow = 10;

  @override
  void dispose() {
    _pulseController.dispose();
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = isPortrait(context) ? shortSide(context) * 0.70 : buzzerSize;
    final ringSize = buttonSize * 1.27;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.heavyImpact();
        widget.onBuzz();
      },
      child: Container(
        color: FeudColors.stage,
        alignment: Alignment.center,
        // الزر وحلقته: الحلقة متمركزة على الزر نفسه — الظل تحته بالنص
        // وما بيدخل بحساب حجمه.
        child: Stack(
          alignment: Alignment.center,
          children: [
            // حلقتين بتتوسّعوا وراء بعض — نفس التصميم (١٤٠٠ms وفارق نصّها).
            AnimatedBuilder(
              animation: _halo,
              builder: (context, _) => CustomPaint(
                size: Size.square(ringSize),
                painter: _HaloPainter(phase: _halo.value),
              ),
            ),
            ScaleTransition(
              scale: _pulse,
              child: CustomPaint(
                painter: const _ButtonShadowPainter(offset: _shadow),
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: FeudColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: FeudColors.ink, width: 6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'اضغط!',
                    textAlign: TextAlign.center,
                    style: FeudText.displayMedium(context).copyWith(color: FeudColors.ink),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  final double phase;

  const _HaloPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final p in [phase, (phase + 0.5) % 1]) {
      canvas.drawCircle(
        center,
        (size.shortestSide / 2) * (0.62 + p * 0.38),
        Paint()
          ..color = FeudColors.gold.withValues(alpha: (1 - p) * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
    }
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.phase != phase;
}

/// ظل صلب تحت الزر بالضبط، مش على جنب.
class _ButtonShadowPainter extends CustomPainter {
  final double offset;

  const _ButtonShadowPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2 + offset),
      size.shortestSide / 2,
      Paint()..color = FeudColors.ink,
    );
  }

  @override
  bool shouldRepaint(_ButtonShadowPainter old) => old.offset != offset;
}
