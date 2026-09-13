/// أدوات حركة مشاهد البرنامج — نفس منحنيات ملف التصميم
/// (`مين الأطليسي - Play & Pass.dc.html`): كل حركة عبارة عن مفاتيح
/// (keyframes) على وقت بالثواني، ومنحنى [bang] هو
/// `cubic-bezier(.2,.9,.2,1)` تبع التصميم.
///
/// منفّذ عن `ShowMotion.kt` بالمشروع الأصلي (Kotlin) — بنفس الأسماء
/// والمفاتيح بالضبط.
library;

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme.dart';

/// منحنى الضربة تبع التصميم — سريع بالبداية وبيهدى بالآخر.
double bang(double p) {
  // تقريب `cubic-bezier(.2,.9,.2,1)` بمنحنى أُسّي — نفس الإحساس.
  final t = p.clamp(0.0, 1.0);
  return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
}

/// قيمة بين مفاتيح: [stops] لازم تكون مرتّبة بنسبة الوقت `0..1`.
/// [t] بالثواني، الحركة بتبلّش بعد [delay] وبتاخد [duration].
double keys(
  double t,
  double delay,
  double duration,
  List<(double, double)> stops, {
  double Function(double) curve = bang,
}) {
  if (stops.isEmpty) return 0;
  final raw = (t - delay) / duration;
  if (raw <= 0) return stops.first.$2;
  if (raw >= 1) return stops.last.$2;
  final p = curve(raw);
  var previous = stops.first;
  for (final stop in stops) {
    if (p <= stop.$1) {
      final span = stop.$1 - previous.$1;
      if (!(span > 0)) return stop.$2;
      final local = (p - previous.$1) / span;
      return previous.$2 + (stop.$2 - previous.$2) * local;
    }
    previous = stop;
  }
  return stops.last.$2;
}

/// `dcThump` — بتطلع من صفر، بتتخطّى، وبتستقر.
double thump(double t, double delay, [double duration = 0.46]) => keys(
      t,
      delay,
      duration,
      const [(0.0, 0.0), (0.52, 1.22), (0.76, 0.94), (1.0, 1.0)],
    );

/// `dcDrop` — بتنزل من فوق وبترتد. بترجّع الإزاحة كنسبة من الارتفاع.
double drop(double t, double delay, [double duration = 0.62]) => keys(
      t,
      delay,
      duration,
      const [
        (0.0, -1.6),
        (0.46, 0.08),
        (0.68, -0.05),
        (0.86, 0.02),
        (1.0, 0.0),
      ],
    );

/// `dcWipe` — لافتة بتكنس من الجهة. بترجّع الإزاحة كنسبة من العرض.
double wipe(double t, double delay, [double duration = 0.62]) => keys(
      t,
      delay,
      duration,
      const [
        (0.0, 1.12),
        (0.54, -0.06),
        (0.72, 0.03),
        (0.88, -0.015),
        (1.0, 0.0),
      ],
    );

/// `dcRise` — لوح بيطلع من تحت. إزاحة كنسبة من الارتفاع.
double rise(double t, double delay, [double duration = 0.66]) => keys(
      t,
      delay,
      duration,
      const [(0.0, 1.18), (0.62, -0.04), (0.82, 0.02), (1.0, 0.0)],
    );

/// `dcSlam` — بتنزل من كبير لصغير مع لفّة. بترجّع القياس.
double slamScale(double t, double delay, [double duration = 0.7]) => keys(
      t,
      delay,
      duration,
      const [
        (0.0, 3.1),
        (0.44, 0.74),
        (0.58, 1.18),
        (0.72, 0.92),
        (0.86, 1.05),
        (1.0, 1.0),
      ],
    );

double slamRotation(double t, double delay, [double duration = 0.7]) => keys(
      t,
      delay,
      duration,
      const [
        (0.0, -16.0),
        (0.44, 4.0),
        (0.58, -3.0),
        (0.72, 2.0),
        (0.86, -1.0),
        (1.0, 0.0),
      ],
    );

/// بداية الظهور: شفافية الحركات اللي بتبلّش مخفية.
double appear(double t, double delay, [double over = 0.12]) =>
    ((t - delay) / over).clamp(0.0, 1.0);

/// `dcRing` — حلقة صدمة بتتوسّع وبتختفي.
class ShockRing {
  final double scale;
  final double alpha;
  final double width;

  const ShockRing(this.scale, this.alpha, this.width);
}

ShockRing shockRing(double t, double delay, [double duration = 0.76]) {
  final raw = (t - delay) / duration;
  if (raw <= 0 || raw >= 1) return const ShockRing(1, 0, 2);
  final scale = keys(t, delay, duration, const [(0.0, 0.18), (1.0, 2.1)]);
  final alpha = keys(
    t,
    delay,
    duration,
    const [(0.0, 0.0), (0.06, 1.0), (0.55, 0.55), (1.0, 0.0)],
    curve: (p) => p,
  );
  final width = keys(t, delay, duration, const [(0.0, 28.0), (1.0, 2.0)]);
  return ShockRing(scale, alpha, width);
}

/// تأخير كشف كل خانة انكشفت بهالتحديث: لما تنكشف كذا خانة بنفس اللحظة
/// («اكشف الباقي») بتتقلب وحدة ورا التانية بترتيب اللوح، كل [step] ثانية.
/// الخانة اللي انكشفت لحالها ما بتستنى. [previous] = null يعني أول لوح
/// منشوفه (لاعب انضم بنص الجولة) — ما في طابور، كل شي بيبيّن فوراً.
Map<int, double> revealDelays(
  Set<int>? previous,
  Set<int> current, {
  double step = 0.12,
}) {
  if (previous == null) return const {};
  final fresh = current.difference(previous).toList()..sort();
  return {
    for (var order = 0; order < fresh.length; order++)
      fresh[order]: order * step,
  };
}

/// ساعة المشهد بالثواني — بتبلّش من صفر وبتوقف عند [cap]. بتتحرّك بـ
/// [Ticker] لازم نمرّرله [TickerProvider] (عادة `SingleTickerProviderStateMixin`
/// أو `TickerProviderStateMixin`).
class ShowClock extends ValueNotifier<double> {
  final TickerProvider vsync;
  // مش final: بعض المشاهد (متل AnswerSlotRow) بتغيّر سقف الساعة بين كل
  // دورة كشف وتانية (تبعاً لـ revealDelay الجديد) قبل ما تعيد التشغيل.
  double cap;
  // Ticker واحد بس طول عمر الساعة — TickerProviderStateMixin بيرفض ثاني
  // نداء لـ createTicker من نفس الـ State، فما منعيد إنشاءه، منوقّفه
  // ومنرجّع نشغّله (Ticker.start() بيصفّر الوقت المنقضي لحاله).
  late final Ticker _ticker = vsync.createTicker(_onTick);

  ShowClock(this.vsync, {this.cap = 12}) : super(0) {
    start();
  }

  /// بيبلّش (أو بيعيد بلش) الساعة من صفر.
  void start() {
    _ticker.stop();
    value = 0;
    _ticker.start();
  }

  /// نفس [start] — اسم أوضح لما نعيد التشغيل بعد تغيير مفتاح المشهد.
  void restart() => start();

  void _onTick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds >= cap) {
      value = cap;
      _ticker.stop();
      return;
    }
    value = seconds;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// ساعة مشهد جاهزة بواجهة `builder`: بتبلّش ساعتها وبتعيدها كل ما يتغيّر
/// [sceneKey]، وبتعيد بناء محتواها كل فريم. أغلب المشاهد بتستعمل هاي بدل
/// ما تدير [ShowClock] بنفسها.
class ShowScene extends StatefulWidget {
  final Object? sceneKey;
  final double cap;
  final Widget Function(BuildContext context, double t) builder;

  const ShowScene({
    super.key,
    this.sceneKey,
    this.cap = 12,
    required this.builder,
  });

  @override
  State<ShowScene> createState() => _ShowSceneState();
}

class _ShowSceneState extends State<ShowScene>
    with SingleTickerProviderStateMixin {
  late ShowClock _clock;

  @override
  void initState() {
    super.initState();
    _clock = ShowClock(this, cap: widget.cap);
  }

  @override
  void didUpdateWidget(covariant ShowScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sceneKey != widget.sceneKey) {
      _clock.restart();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _clock,
      builder: (context, _) => widget.builder(context, _clock.value),
    );
  }
}

/// خلفية الأشعة الدوّارة — نفس `repeating-conic-gradient` تبع التصميم.
class SpinningRays extends StatefulWidget {
  final Color dark;
  final Color light;
  final Duration period;

  const SpinningRays({
    super.key,
    this.dark = FeudColors.panelDark,
    this.light = FeudColors.stage,
    this.period = const Duration(milliseconds: 14000),
  });

  @override
  State<SpinningRays> createState() => _SpinningRaysState();
}

class _SpinningRaysState extends State<SpinningRays>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
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
        painter: _SpinningRaysPainter(
          angle: _controller.value * 2 * math.pi,
          dark: widget.dark,
          light: widget.light,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SpinningRaysPainter extends CustomPainter {
  final double angle;
  final Color dark;
  final Color light;

  const _SpinningRaysPainter({
    required this.angle,
    required this.dark,
    required this.light,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = dark);

    final center = Offset(size.width / 2, size.height / 2);
    // ١٢ شعاع بعرض ١٥ درجة — نفس تدرّج التصميم المخروطي.
    final radius = size.longestSide * 1.4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..color = light;
    const sweep = 15 * math.pi / 180;
    const step = 30 * math.pi / 180;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);
    for (var index = 0; index < 12; index++) {
      final start = index * step;
      canvas.drawArc(rect, start, sweep, true, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpinningRaysPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.dark != dark ||
      oldDelegate.light != light;
}
