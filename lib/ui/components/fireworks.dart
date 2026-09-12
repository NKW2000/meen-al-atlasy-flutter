/// ألعاب نارية بنفس مفردات التصميم: قصاصات مربّعة ودائرية بألوان اللعبة،
/// كل وحدة بحدّ حبر سميك — مش نقط ملوّنة ناعمة.
///
/// كل انفجار بيطلع من نقطة، بيتمدّد، وبيهبط شوي بالجاذبية قبل ما يختفي،
/// وبعدين بيعيد من جديد بتوقيت مختلف حتى ما يصيروا كلهم مع بعض.
///
/// منفّذ عن `components/Fireworks.kt` بالمشروع الأصلي (Kotlin).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/show_motion.dart' show bang;
import '../theme.dart';

class _Burst {
  final double x;
  final double y;
  final double delay;
  final double radius;
  final int seed;

  const _Burst({
    required this.x,
    required this.y,
    required this.delay,
    required this.radius,
    required this.seed,
  });
}

const List<Color> _palette = [
  FeudColors.gold,
  FeudColors.pink,
  FeudColors.teal,
  FeudColors.lime,
  FeudColors.team1,
  FeudColors.team2,
];

class Fireworks extends StatefulWidget {
  final int bursts;
  final int sparksPerBurst;
  final Duration cycle;

  const Fireworks({
    super.key,
    this.bursts = 5,
    this.sparksPerBurst = 22,
    this.cycle = const Duration(milliseconds: 2600),
  });

  @override
  State<Fireworks> createState() => _FireworksState();
}

class _FireworksState extends State<Fireworks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Burst> _shots;

  @override
  void initState() {
    super.initState();
    final random = math.Random(7);
    _shots = List.generate(widget.bursts, (index) {
      return _Burst(
        x: 0.14 + random.nextDouble() * 0.72,
        y: 0.16 + random.nextDouble() * 0.5,
        delay: index / widget.bursts,
        radius: 0.16 + random.nextDouble() * 0.16,
        seed: index * 31 + 7,
      );
    });
    _controller = AnimationController(vsync: this, duration: widget.cycle)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _FireworksPainter(
          clock: _controller.value,
          shots: _shots,
          sparks: widget.sparksPerBurst,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _FireworksPainter extends CustomPainter {
  final double clock;
  final List<_Burst> shots;
  final int sparks;

  const _FireworksPainter({
    required this.clock,
    required this.shots,
    required this.sparks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final burst in shots) {
      // كل انفجار عنده وقته الخاص ضمن الدورة.
      final life = (clock + burst.delay) % 1.0;
      if (life > 0.75) continue;
      _drawBurst(canvas, size, burst, life / 0.75);
    }
  }

  void _drawBurst(Canvas canvas, Size size, _Burst burst, double life) {
    final origin = Offset(size.width * burst.x, size.height * burst.y);
    final minDimension = math.min(size.width, size.height);
    final spread = burst.radius * minDimension * bang(life);
    final fade = (1 - life * life).clamp(0.0, 1.0);
    final gravity = size.height * 0.16 * life * life;

    for (var index = 0; index < sparks; index++) {
      final angle =
          (index / sparks) * math.pi * 2 + burst.seed * 0.37;
      final distance =
          spread * (0.62 + _fraction(burst.seed + index) * 0.38);
      final point = Offset(
        origin.dx + math.cos(angle) * distance,
        origin.dy + math.sin(angle) * distance + gravity,
      );
      final side = minDimension * (0.012 + _fraction(burst.seed * 3 + index) * 0.012);
      final color = _palette[(burst.seed + index) % _palette.length]
          .withValues(alpha: fade);
      final ink = FeudColors.ink.withValues(alpha: fade);
      final square = (burst.seed + index) % 3 != 0;

      if (square) {
        canvas.save();
        canvas.translate(point.dx, point.dy);
        canvas.rotate((life * 260 + index * 12) * math.pi / 180);
        canvas.translate(-point.dx, -point.dy);
        canvas.drawRect(
          Rect.fromCenter(center: point, width: side + 4, height: side + 4),
          Paint()..color = ink,
        );
        canvas.drawRect(
          Rect.fromCenter(center: point, width: side, height: side),
          Paint()..color = color,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(point, side / 2 + 2, Paint()..color = ink);
        canvas.drawCircle(point, side / 2, Paint()..color = color);
      }
    }

    // ومضة صغيرة بمركز الانفجار أول ما يفرقع.
    final flash = (1 - life * 4).clamp(0.0, double.infinity);
    if (flash > 0) {
      canvas.drawCircle(
        origin,
        minDimension * 0.05 * flash,
        Paint()..color = Colors.white.withValues(alpha: flash * 0.5),
      );
    }
  }

  double _fraction(int seed) {
    final value = math.sin(seed * 12.9898) * 43758.547;
    return value - value.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) =>
      oldDelegate.clock != clock;
}
