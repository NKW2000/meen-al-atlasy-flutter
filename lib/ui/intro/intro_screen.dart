/// المقدمة المتحركة — نفس السيناريو والتوقيت اللي بملف التصميم
/// (`intro-bumper.jsx` + مشاهد `OM_SCENES`)، أربع ثواني بالوضع الأفقي:
///
/// | المشهد | المدة | شو بيصير |
/// |---|---|---|
/// | Flash | ٠٫٥٥ | أرضية ذهبية، ذرات حبرية، وشعاع بيمسح الكادر |
/// | Clash | ٠٫٨٥ | لوح أخضر ولوح أزرق بيتصادموا، موجة صدمة، و«؟» بتنط |
/// | Build | ١٫٤٥ | «؟» بتصير شارة، واللوح البنفسجي والاسم بينطبقوا |
/// | Win | ١٫١٥ | بريق ذهبي، انفجار قصاصات، أجنحة الفريقين، وارتدادة القفلة |
///
/// وبالوضع الطولي مقدمة خاصة (`IntroPortraitScreen.kt`) — نفس السيناريو
/// بس بتصادم عمودي واسم بسطرين، ٧٫٦ ثانية.
///
/// الوقت `t` بالثواني، وكل حركة مربوطة فيه زي المحرّك بالتصميم. أي لمسة
/// بتخطّي المقدمة.
///
/// منفّذ عن `IntroScreen.kt` و`IntroPortraitScreen.kt` بالمشروع الأصلي
/// (Kotlin) — بنفس الأسماء والمفاتيح بالضبط.
///
/// ملاحظة RTL: `Modifier.offset(x = ...)` بكوتلن بياخد اتجاه الواجهة
/// بعين الاعتبار (والتطبيق RTL)، بعكس `Transform.translate` بفلاتر
/// (دايماً بكسلات خام) — فمنقلب إشارة أي إزاحة أفقية جاية من `.offset()`
/// (نفس قرار `stage.dart`/`brand_logo.dart`). إزاحات الرسم الخام
/// (`drawBehind`/`Canvas`) ما بتنقلب، لأنها مش اتجاهية أصلاً بكوتلن.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../components/brand_logo.dart';
import '../responsive.dart';
import '../theme.dart';

/// نفس منحنيات التصميم: خروج سريع، ارتداد، ودخول متسارع.
double _ease(double t) {
  final p = 1 - t;
  return 1 - p * p * p * p;
}

double _easeIn(double t) => t * t;

double _easeBack(double t) {
  const c = 1.70158;
  final p = t - 1;
  return p * p * ((c + 1) * p + c) + 1;
}

/// قيمة متحرّكة بين [from] و[to] خلال [start]..[end] بالثواني.
double _span(
  double t,
  double from,
  double to,
  double start,
  double end, [
  double Function(double p) curve = _ease,
]) {
  if (t <= start) return from;
  if (t >= end) return to;
  final p = ((t - start) / (end - start)).clamp(0.0, 1.0);
  return from + (to - from) * curve(p);
}

double _rnd(int index, double salt) {
  final v = math.sin(index * salt) * 43758.547;
  return v - v.floorToDouble();
}

/// نفس ملاحظة BrandWordmark: Modifier.offset(x=...) بكوتلن اتجاهي
/// (والتطبيق RTL)، وTransform.translate بفلاتر مش اتجاهي — فمنقلب
/// الإشارة حتى نطابق نفس الحركة المرئية.
double _rtlX(double x) => -x;

double _deg(double degrees) => degrees * math.pi / 180;

class _Speck {
  final double x, y, size, depth;
  const _Speck(this.x, this.y, this.size, this.depth);
}

class _Spark {
  final double angle, radius, size;
  final Color color;
  final bool square;
  const _Spark({
    required this.angle,
    required this.radius,
    required this.size,
    required this.color,
    required this.square,
  });
}

List<_Speck> _buildSpecks(int count) => List.generate(
      count,
      (i) => _Speck(
        _rnd(i + 1, 12.9898),
        _rnd(i + 1, 78.233),
        1.5 + _rnd(i + 1, 45.164) * 3.5,
        _rnd(i + 1, 94.673),
      ),
    );

List<_Spark> _buildSparks(int count, List<double> radiusRange) {
  const palette = [
    FeudColors.gold,
    FeudColors.teal,
    FeudColors.team1,
    FeudColors.pink,
    FeudColors.lime,
  ];
  return List.generate(count, (i) {
    return _Spark(
      angle: (i / count) * math.pi * 2 + _rnd(i + 3, 9.31) * 0.5,
      radius: radiusRange[0] + _rnd(i + 3, 31.7) * radiusRange[1],
      size: 7 + _rnd(i + 3, 52.1) * 13,
      color: palette[i % palette.length],
      square: _rnd(i + 3, 17.4) > 0.5,
    );
  });
}

/// ظل حبري مصمّت خلف مستطيل مدوّر — نفس `drawBehind { drawRoundRect(...) }`
/// بكوتلن: إزاحة بكسلات خام (مش اتجاهية).
class _RRectShadowPainter extends CustomPainter {
  final double dx, dy, corner;

  const _RRectShadowPainter({
    required this.dx,
    required this.dy,
    required this.corner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(dx, dy, size.width, size.height),
      Radius.circular(corner),
    );
    canvas.drawRRect(rrect, Paint()..color = FeudColors.ink);
  }

  @override
  bool shouldRepaint(covariant _RRectShadowPainter oldDelegate) =>
      oldDelegate.dx != dx || oldDelegate.dy != dy || oldDelegate.corner != corner;
}

/// لوح ملوّن بظل حبري مزاح وحدّ حبر — نفس بلوكات الفريقين بالتصميم.
Widget _shadowedBlock({
  required double width,
  required double height,
  required Color color,
  required double innerCorner,
  required double outerCorner,
  required double borderWidth,
  double shadowDx = 10,
  double shadowDy = 12,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: CustomPaint(
      painter: _RRectShadowPainter(dx: shadowDx, dy: shadowDy, corner: outerCorner),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(innerCorner),
          border: Border.all(color: FeudColors.ink, width: borderWidth),
        ),
      ),
    ),
  );
}

/// لوح ملوّن بدون ظل — نفس أجنحة مشهد الفوز.
Widget _plainBlock({
  required Color color,
  required double corner,
  required double borderWidth,
  double? width,
  double? height,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(corner),
      border: Border.all(color: FeudColors.ink, width: borderWidth),
    ),
  );
}

/// اللوح البنفسجي: ظل حبري مزاح خلف مستطيل كريمي بحدّ حبر.
Widget _plateBox({
  required double width,
  required double height,
  required double innerCorner,
  required Widget child,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: CustomPaint(
      painter: const _RRectShadowPainter(dx: 14, dy: 17, corner: 34),
      child: Container(
        decoration: BoxDecoration(
          color: FeudColors.canvas,
          borderRadius: BorderRadius.circular(innerCorner),
          border: Border.all(color: FeudColors.ink, width: 6),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    ),
  );
}

/// ذرات حبرية طايفة على الأرضية الذهبية.
class _DustPainter extends CustomPainter {
  final List<_Speck> specks;
  final double t;
  final double dustAlpha;
  final double speed;

  const _DustPainter({
    required this.specks,
    required this.t,
    required this.dustAlpha,
    this.speed = 1.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in specks) {
      final y = (s.y * size.height + math.sin(t * speed + s.depth * 9) * 22) %
          size.height;
      paint.color = FeudColors.ink.withValues(alpha: dustAlpha * (0.1 + s.depth * 0.22));
      canvas.drawCircle(Offset(s.x * size.width, y), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.dustAlpha != dustAlpha;
}

/// انفجار القصاصات بمشهد الفوز — دوائر ومربّعات نص محدودة بحبر.
class _BurstPainter extends CustomPainter {
  final List<_Spark> sparks;
  final double burst;
  final double burstAlpha;
  final double yScale;

  const _BurstPainter({
    required this.sparks,
    required this.burst,
    required this.burstAlpha,
    this.yScale = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2 - 20);
    final alpha = burstAlpha.clamp(0.0, 1.0);
    final inkPaint = Paint()..color = FeudColors.ink.withValues(alpha: alpha);
    for (final s in sparks) {
      final point = Offset(
        origin.dx + math.cos(s.angle) * s.radius * burst,
        origin.dy + math.sin(s.angle) * s.radius * burst * yScale,
      );
      final colorPaint = Paint()..color = s.color.withValues(alpha: alpha);
      if (s.square) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: point, width: s.size + 6, height: s.size + 6),
            const Radius.circular(3),
          ),
          inkPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: point, width: s.size, height: s.size),
            const Radius.circular(3),
          ),
          colorPaint,
        );
      } else {
        canvas.drawCircle(point, s.size / 2 + 3, inkPaint);
        canvas.drawCircle(point, s.size / 2, colorPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.burst != burst || oldDelegate.burstAlpha != burstAlpha;
}

/// المقدمة: بتختار الوضع الأفقي أو الطولي بحسب اتجاه الشاشة — نفس
/// `IntroScreen.kt` (اللي بيوجّه فوراً على `IntroPortraitScreen` بالطولي).
class IntroScreen extends StatelessWidget {
  final VoidCallback onDone;

  const IntroScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    if (isPortrait(context)) return _IntroPortrait(onDone: onDone);
    return _IntroLandscape(onDone: onDone);
  }
}

/// ساعة بتدور من صفر — بتنادي [onDone] مرة وحدة أول ما توصل [total]
/// وبعدها بترجع تلف من جديد (زي `OM_PLAYBACK: loop` بالتصميم).
class _LoopClock extends StatefulWidget {
  final double total;
  final VoidCallback onDone;
  final Widget Function(BuildContext context, double t) builder;

  const _LoopClock({
    required this.total,
    required this.onDone,
    required this.builder,
  });

  @override
  State<_LoopClock> createState() => _LoopClockState();
}

class _LoopClockState extends State<_LoopClock> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _cycleStart;
  bool _announced = false;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _cycleStart ??= elapsed;
    var seconds =
        (elapsed - _cycleStart!).inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds >= widget.total) {
      if (!_announced) {
        _announced = true;
        widget.onDone();
      }
      _cycleStart = elapsed;
      seconds = 0;
    }
    if (mounted) setState(() => _t = seconds);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _t);
}

// ============================================================== الأفقي

class _IntroLandscape extends StatefulWidget {
  final VoidCallback onDone;

  const _IntroLandscape({required this.onDone});

  @override
  State<_IntroLandscape> createState() => _IntroLandscapeState();
}

class _IntroLandscapeState extends State<_IntroLandscape> {
  static const _flash = 0.0;
  static const _clash = 0.55;
  static const _build = 1.40;
  static const _win = 2.85;
  static const _total = 4.0;
  static const _impact = _clash + 0.32;

  late final List<_Speck> _specks = _buildSpecks(40);
  late final List<_Spark> _sparks = _buildSparks(26, const [190, 210]);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDone,
      child: ColoredBox(
        color: FeudColors.gold,
        child: _LoopClock(total: _total, onDone: widget.onDone, builder: _build_),
      ),
    );
  }

  Widget _build_(BuildContext context, double t) {
    final cam = 1 +
        _span(t, 0.06, 0, _flash, _clash) +
        _span(t, 0, 0.10, _clash + 0.18, _impact) +
        _span(t, 0, -0.02, _impact, _impact + 0.36) +
        _span(t, 0, -0.08, _build, _build + 0.55) +
        _span(t, 0, 0.035, _win + 0.55, _win + 0.70) +
        _span(t, 0, -0.035, _win + 0.70, _win + 1.05);

    final beam = _span(t, -0.35, 1.35, _flash, _clash + 0.3);
    final beamAlpha = _span(t, 0, 0.85, _flash, _flash + 0.22) +
        _span(t, 0, -0.85, _clash, _clash + 0.3);
    final dust = _span(t, 0, 1, _flash, _flash + 0.35);

    final teamIn = _span(t, 620, 0, _clash, _impact, _easeIn);
    final part = _span(t, 0, 820, _impact + 0.1, _build + 0.35, _easeIn);
    final teamAlpha = 1 + _span(t, 0, -1, _build + 0.05, _build + 0.30);
    final spin = _span(t, 0, 18, _impact + 0.1, _build + 0.35, _easeIn);
    final squash = _span(t, 0, 1, _impact, _impact + 0.08) +
        _span(t, 0, -1, _impact + 0.08, _impact + 0.30);
    final shock = _span(t, 0.2, 3.4, _impact, _impact + 0.4);
    final shockAlpha = _span(t, 1, 0, _impact + 0.04, _impact + 0.4);
    final markPop = _span(t, 0, 1, _impact + 0.04, _impact + 0.28, _easeBack);
    final markGone = _span(t, 1, 0, _build, _build + 0.16, _easeIn);

    final plate = _span(t, 0, 1, _build, _build + 0.36, _easeBack);
    final badge = _span(t, 0, 1, _build + 0.08, _build + 0.50, _easeBack);
    final badgeSpin = _span(t, -40, 0, _build + 0.08, _build + 0.56, _easeBack);
    final wordIn = _span(t, 460, 0, _build + 0.34, _build + 0.78, _easeBack);
    final wordAlpha = _span(t, 0, 1, _build + 0.34, _build + 0.44);
    final barGrow = _span(t, 0, 1, _build + 0.86, _build + 1.14);
    final logoSquash = _span(t, 0, 1, _build + 1.0, _build + 1.08) +
        _span(t, 0, -1, _build + 1.08, _build + 1.38);

    final burst = _span(t, 0, 1, _win + 0.06, _win + 0.85);
    final burstAlpha = _span(t, 1, 0, _win + 0.38, _win + 0.90);
    final wing = _span(t, 230, 0, _win + 0.04, _win + 0.42, _easeBack);
    final bob = math.sin(t * 5.2) * 4;
    final markScale = markPop * markGone;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      return Stack(children: [
        Positioned.fill(
          child: CustomPaint(painter: _DustPainter(specks: _specks, t: t, dustAlpha: dust)),
        ),
        Positioned.fill(
          child: Transform.scale(
            scale: cam,
            child: Stack(alignment: Alignment.center, children: [
              if (beamAlpha > 0.01)
                Transform.translate(
                  offset: Offset(_rtlX(w * beam - 80), -h),
                  child: Transform.rotate(
                    angle: _deg(14),
                    child: Opacity(
                      opacity: beamAlpha.clamp(0.0, 1.0),
                      child: Container(
                        width: 160,
                        height: h * 3,
                        color: FeudColors.cream.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              if (teamAlpha > 0.01) ...[
                _teamBlock(
                  color: FeudColors.team1,
                  offsetX: _rtlX(-(teamIn + part)),
                  rotationDeg: -spin,
                  squash: squash,
                  alpha: teamAlpha,
                ),
                _teamBlock(
                  color: FeudColors.team2,
                  offsetX: _rtlX(teamIn + part),
                  rotationDeg: spin,
                  squash: squash,
                  alpha: teamAlpha,
                ),
              ],
              if (shockAlpha > 0.01 && t > _impact)
                Transform.scale(
                  scale: shock,
                  child: Opacity(
                    opacity: shockAlpha.clamp(0.0, 1.0),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: FeudColors.cream, width: 10),
                      ),
                    ),
                  ),
                ),
              if (markScale > 0.01)
                Transform.scale(scale: markScale, child: const BrandBadge(em: 180)),
              if (t >= _win)
                Positioned.fill(
                  child: Stack(children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Transform.translate(
                        offset: Offset(_rtlX(-86 + wing), bob),
                        child: Transform.rotate(
                          angle: _deg(-6),
                          child: _plainBlock(
                            color: FeudColors.team1,
                            corner: 20,
                            borderWidth: 5,
                            width: 120,
                            height: 168,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Transform.translate(
                        offset: Offset(_rtlX(86 - wing), -bob),
                        child: Transform.rotate(
                          angle: _deg(6),
                          child: _plainBlock(
                            color: FeudColors.team2,
                            corner: 20,
                            borderWidth: 5,
                            width: 120,
                            height: 168,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              if (plate > 0.01)
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scaleByDouble(plate * (1 + logoSquash * 0.06), plate * (1 - logoSquash * 0.05), 1.0, 1.0),
                  child: _plateBox(
                    width: 560,
                    height: 260,
                    innerCorner: 28,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: badge,
                          child: Transform.rotate(
                            angle: _deg(badgeSpin),
                            child: const BrandBadge(em: 68),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Transform.translate(
                          offset: Offset(_rtlX(wordIn), 0),
                          child: Opacity(
                            opacity: wordAlpha.clamp(0.0, 1.0),
                            child: const BrandWordmark(em: 42),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Transform.scale(
                          scale: barGrow.clamp(0.0, 1.0),
                          child: const BrandBar(em: 42),
                        ),
                      ],
                    ),
                  ),
                ),
              if (burst > 0 && burstAlpha > 0.01)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BurstPainter(sparks: _sparks, burst: burst, burstAlpha: burstAlpha),
                  ),
                ),
            ]),
          ),
        ),
      ]);
    });
  }

  Widget _teamBlock({
    required Color color,
    required double offsetX,
    required double rotationDeg,
    required double squash,
    required double alpha,
  }) {
    return Transform.translate(
      offset: Offset(offsetX, 0),
      child: Transform.rotate(
        angle: _deg(rotationDeg),
        child: Opacity(
          opacity: alpha.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scaleByDouble(1 + squash * 0.28, 1 - squash * 0.22, 1.0, 1.0),
            child: _shadowedBlock(
              width: 172,
              height: 112,
              color: color,
              innerCorner: 24,
              outerCorner: 28,
              borderWidth: 5,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================== الطولي

class _IntroPortrait extends StatefulWidget {
  final VoidCallback onDone;

  const _IntroPortrait({required this.onDone});

  @override
  State<_IntroPortrait> createState() => _IntroPortraitState();
}

class _IntroPortraitState extends State<_IntroPortrait> {
  static const _flash = 0.0;
  static const _clash = 1.1;
  static const _build = 2.6;
  static const _win = 5.2;
  static const _total = 7.6;
  static const _impact = _clash + 0.62;

  late final List<_Speck> _dust = _buildSpecks(38);
  late final List<_Spark> _confetti = _buildConfetti(26);

  static List<_Spark> _buildConfetti(int count) {
    const palette = [
      FeudColors.gold,
      FeudColors.teal,
      FeudColors.team1,
      FeudColors.pink,
      FeudColors.lime,
    ];
    return List.generate(count, (i) {
      return _Spark(
        angle: (i / count) * math.pi * 2 + _rnd(i + 3, 9.31) * 0.5,
        radius: 0.315 + _rnd(i + 3, 31.7) * 0.426,
        size: 7 + _rnd(i + 3, 52.1) * 13,
        color: palette[i % palette.length],
        square: _rnd(i + 3, 17.4) > 0.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDone,
      child: ColoredBox(
        color: FeudColors.gold,
        child: _LoopClock(total: _total, onDone: widget.onDone, builder: _build_),
      ),
    );
  }

  Widget _build_(BuildContext context, double t) {
    final cam = 1 +
        _span(t, 0.06, 0, _flash, _clash) +
        _span(t, 0, 0.10, _clash + 0.3, _impact) +
        _span(t, 0, -0.02, _impact, _impact + 0.6) +
        _span(t, 0, -0.06, _build, _build + 0.9) +
        _span(t, 0, 0.035, _win + 0.9, _win + 1.15) +
        _span(t, 0, -0.035, _win + 1.15, _win + 1.75);

    final beam = _span(t, -0.35, 1.35, _flash, _clash + 0.55);
    final beamAlpha = _span(t, 0, 0.85, _flash, _flash + 0.4) +
        _span(t, 0, -0.85, _clash, _clash + 0.55);
    final dustAlpha = _span(t, 0, 1, _flash, _flash + 0.6);

    final teamTop = _span(t, -1.33, 0, _clash, _impact, _easeIn);
    final teamBottom = _span(t, 1.33, 0, _clash, _impact, _easeIn);
    final squash = _span(t, 0, 1, _impact, _impact + 0.14) +
        _span(t, 0, -1, _impact + 0.14, _impact + 0.55);
    final partTop = _span(t, 0, -1.67, _impact + 0.2, _build + 0.6, _easeIn);
    final partBottom = _span(t, 0, 1.67, _impact + 0.2, _build + 0.6, _easeIn);
    final teamAlpha = 1 + _span(t, 0, -1, _build + 0.1, _build + 0.5);
    final teamSpin = _span(t, 0, 14, _impact + 0.2, _build + 0.6, _easeIn);
    final shock = _span(t, 0.2, 3.4, _impact, _impact + 0.7);
    final shockAlpha = _span(t, 1, 0, _impact + 0.08, _impact + 0.7);
    final markPop = _span(t, 0, 1, _impact + 0.08, _impact + 0.5, _easeBack);
    final markGone = _span(t, 1, 0, _build, _build + 0.3, _easeIn);

    final plate = _span(t, 0, 1, _build, _build + 0.6, _easeBack);
    final badge = _span(t, 0, 1, _build + 0.15, _build + 0.85, _easeBack);
    final badgeSpin = _span(t, -40, 0, _build + 0.15, _build + 0.95, _easeBack);
    final line1 = _span(t, -0.48, 0, _build + 0.7, _build + 1.4, _easeBack);
    final line1Rot = _span(t, 10, 0, _build + 0.7, _build + 1.5, _easeBack);
    final line1Alpha = _span(t, 0, 1, _build + 0.7, _build + 0.9);
    final line2 = _span(t, 0.48, 0, _build + 1.1, _build + 1.85, _easeBack);
    final line2Rot = _span(t, -10, 0, _build + 1.1, _build + 1.95, _easeBack);
    final line2Alpha = _span(t, 0, 1, _build + 1.1, _build + 1.3);
    final barGrow = _span(t, 0, 1, _build + 1.7, _build + 2.1);
    final logoSquash = _span(t, 0, 1, _build + 1.9, _build + 2.05) +
        _span(t, 0, -1, _build + 2.05, _build + 2.6);

    final burst = _span(t, 0, 1, _win + 0.15, _win + 1.5);
    final burstAlpha = _span(t, 1, 0, _win + 0.7, _win + 1.6);
    final wingTop = _span(t, -1, 0, _win + 0.1, _win + 0.8, _easeBack);
    final wingBottom = _span(t, 1, 0, _win + 0.1, _win + 0.8, _easeBack);
    final tagAlpha = _span(t, 0, 1, _win + 0.45, _win + 0.9);
    final tagY = _span(t, 0.035, 0, _win + 0.45, _win + 1.0, _easeBack);
    final bob = math.sin(t * 3.2) * 4;
    final markScale = markPop * markGone;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      return Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _DustPainter(specks: _dust, t: t, dustAlpha: dustAlpha, speed: 1.1),
          ),
        ),
        Positioned.fill(
          child: Transform.scale(
            scale: cam,
            child: Stack(alignment: Alignment.center, children: [
              if (beamAlpha > 0.01)
                Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(0, h * beam - h * 0.157),
                    child: Transform.rotate(
                      angle: _deg(-12),
                      child: Opacity(
                        opacity: beamAlpha.clamp(0.0, 1.0),
                        child: Container(
                          width: w * 2,
                          height: h * 0.315,
                          color: FeudColors.cream.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              if (teamAlpha > 0.01) ...[
                _verticalTeamBlock(
                  color: FeudColors.team1,
                  width: w * 0.74,
                  height: h * 0.231,
                  offsetY: h * (teamTop + partTop) - h * 0.111,
                  rotationDeg: -teamSpin,
                  squash: squash,
                  alpha: teamAlpha,
                ),
                _verticalTeamBlock(
                  color: FeudColors.team2,
                  width: w * 0.74,
                  height: h * 0.231,
                  offsetY: h * (teamBottom + partBottom) + h * 0.111,
                  rotationDeg: teamSpin,
                  squash: squash,
                  alpha: teamAlpha,
                ),
              ],
              if (shockAlpha > 0.01 && t > _impact)
                Transform.scale(
                  scale: shock,
                  child: Opacity(
                    opacity: shockAlpha.clamp(0.0, 1.0),
                    child: Container(
                      width: w * 0.26,
                      height: w * 0.26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: FeudColors.cream, width: 12),
                      ),
                    ),
                  ),
                ),
              if (markScale > 0.01)
                Transform.scale(scale: markScale, child: BrandBadge(em: w * 0.5)),
              if (t >= _win)
                Positioned.fill(
                  child: Stack(children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Transform.translate(
                        offset: Offset(_rtlX(bob), -h * 0.111 + h * 0.185 * wingTop),
                        child: Transform.rotate(
                          angle: _deg(-3),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: w * 0.111),
                            child: _plainBlock(
                              color: FeudColors.team1,
                              corner: 26,
                              borderWidth: 7,
                              width: w - w * 0.222,
                              height: h * 0.185,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Transform.translate(
                        offset: Offset(_rtlX(-bob), h * 0.111 + h * 0.185 * wingBottom),
                        child: Transform.rotate(
                          angle: _deg(3),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: w * 0.111),
                            child: _plainBlock(
                              color: FeudColors.team2,
                              corner: 26,
                              borderWidth: 7,
                              width: w - w * 0.222,
                              height: h * 0.185,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              if (plate > 0.01)
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scaleByDouble(plate * (1 + logoSquash * 0.06), plate * (1 - logoSquash * 0.05), 1.0, 1.0),
                  child: _plateBox(
                    width: w * 0.815,
                    height: h * 0.574,
                    innerCorner: 38,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: badge,
                          child: Transform.rotate(
                            angle: _deg(badgeSpin),
                            child: BrandBadge(em: w * 0.274),
                          ),
                        ),
                        SizedBox(height: h * 0.024),
                        Transform.translate(
                          offset: Offset(0, h * line1),
                          child: Transform.rotate(
                            angle: _deg(line1Rot),
                            child: Opacity(
                              opacity: line1Alpha.clamp(0.0, 1.0),
                              child: BrandWordLine(text: 'مين', em: w * 0.178),
                            ),
                          ),
                        ),
                        SizedBox(height: h * 0.009),
                        Transform.translate(
                          offset: Offset(0, h * line2),
                          child: Transform.rotate(
                            angle: _deg(line2Rot),
                            child: Opacity(
                              opacity: line2Alpha.clamp(0.0, 1.0),
                              child: BrandWordLine(text: 'الأطليسي', em: w * 0.178),
                            ),
                          ),
                        ),
                        SizedBox(height: h * 0.024),
                        Transform.scale(
                          scale: barGrow.clamp(0.0, 1.0),
                          child: BrandBar(em: w * 0.135),
                        ),
                        if (tagAlpha > 0.01) ...[
                          SizedBox(height: h * 0.018),
                          Transform.translate(
                            offset: Offset(0, h * tagY),
                            child: Opacity(
                              opacity: tagAlpha.clamp(0.0, 1.0),
                              child: Text(
                                'لعبة عائلية · فريقين · جهاز لكل لاعب',
                                style: FeudText.labelLarge(context)
                                    .copyWith(color: FeudColors.cream),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (burst > 0 && burstAlpha > 0.01)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BurstPainter(
                      sparks: _confetti,
                      burst: burst * w,
                      burstAlpha: burstAlpha,
                      yScale: 1.6,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]);
    });
  }

  Widget _verticalTeamBlock({
    required Color color,
    required double width,
    required double height,
    required double offsetY,
    required double rotationDeg,
    required double squash,
    required double alpha,
  }) {
    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Transform.rotate(
        angle: _deg(rotationDeg),
        child: Opacity(
          opacity: alpha.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scaleByDouble(1 - squash * 0.22, 1 + squash * 0.28, 1.0, 1.0),
            child: _shadowedBlock(
              width: width,
              height: height,
              color: color,
              innerCorner: 30,
              outerCorner: 30,
              borderWidth: 7,
            ),
          ),
        ),
      ),
    );
  }
}
