/// علامة «مين الأطليسي» زي ما هي بملف التصميم (Brand Logo):
///
/// - **الشارة**: قرص ذهبي بحدّ حبر ٠٫٠٩٣em وظل صلب ٠٫٠٦٨×٠٫٠٨٧em، وجوّاته
///   «؟» كريمية بحجم ٠٫٦٢em محدودة بحبر ٠٫٠٥em ومايلة ٧ درجات.
/// - **الاسم**: تلات طبقات فوق بعض — طبقة مزاحة ٠٫٠٦٢×٠٫٠٨٨em (الظل)،
///   طبقة حدّ حبر ٠٫١٤٥em، وفوقهن التعبئة الذهبية.
/// - **الشريط**: ذهبي بعرض ٤٫٥em وارتفاع ٠٫١٥em بحدّ حبر.
///
/// كل المقاسات نسبة لـ [em] — نفس فكرة `font-size` بالتصميم.
///
/// منفّذ عن `components/BrandLogo.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../theme.dart';

const String _wordmark = 'مين الأطليسي';

class BrandLogo extends StatelessWidget {
  final double em;
  final String? tagline;
  final bool showBar;

  const BrandLogo({
    super.key,
    this.em = 64,
    this.tagline,
    this.showBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandBadge(em: em),
        SizedBox(height: em * 0.19),
        BrandWordmark(em: em),
        if (showBar) ...[
          SizedBox(height: em * 0.19),
          BrandBar(em: em),
        ],
        if (tagline != null) ...[
          SizedBox(height: em * 0.19),
          Text(
            tagline!,
            style: TextStyle(
              fontFamily: bodyFontFamily,
              fontWeight: FontWeight.w800,
              fontSize: em * 0.16,
              letterSpacing: em * 0.0096,
              color: FeudColors.cream,
            ),
          ),
        ],
      ],
    );
  }
}

/// نفس العلامة بس بصف واحد — الشارة جنب الاسم.
class BrandLogoRow extends StatelessWidget {
  final double em;

  const BrandLogoRow({super.key, this.em = 44});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BrandBadge(em: em),
        SizedBox(width: em * 0.36),
        BrandWordmark(em: em),
      ],
    );
  }
}

/// الشارة لحالها — بتستعمل بالمقدمة وبالأماكن الضيقة.
class BrandBadge extends StatelessWidget {
  final double em;

  const BrandBadge({super.key, required this.em});

  @override
  Widget build(BuildContext context) {
    final shadowX = em * 0.068;
    final shadowY = em * 0.087;

    return SizedBox(
      width: em,
      height: em,
      child: CustomPaint(
        painter: _BadgeShadowPainter(dx: shadowX, dy: shadowY),
        child: Container(
          decoration: BoxDecoration(
            color: FeudColors.gold,
            shape: BoxShape.circle,
            border: Border.all(color: FeudColors.ink, width: em * 0.093),
          ),
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, em * 0.02),
            child: Transform.rotate(
              angle: -7 * 3.1415926535 / 180,
              child: StrokedText(
                text: '؟',
                fontSize: em * 0.62,
                fill: FeudColors.cream,
                strokeWidth: em * 0.05,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeShadowPainter extends CustomPainter {
  final double dx;
  final double dy;

  const _BadgeShadowPainter({required this.dx, required this.dy});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2 + dx, size.height / 2 + dy),
      size.shortestSide / 2,
      Paint()..color = FeudColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _BadgeShadowPainter oldDelegate) =>
      oldDelegate.dx != dx || oldDelegate.dy != dy;
}

/// الاسم بطبقاته التلاتة.
class BrandWordmark extends StatelessWidget {
  final double em;

  const BrandWordmark({super.key, required this.em});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        // طبقة الظل — نفس الاسم مزاح ومحدود بالحبر.
        // Compose: `.offset(x = -em*0.062f, y = em*0.088f)` بياخد اتجاه
        // الواجهة بعين الاعتبار، فبـ RTL بتنزاح الطبقة تحت-يمين — منقلب
        // إشارة x هون حتى Transform.translate (مش اتجاهي) يعطي نفس النتيجة.
        Transform.translate(
          offset: Offset(em * 0.062, em * 0.088),
          child: StrokedText(
            text: _wordmark,
            fontSize: em,
            fill: FeudColors.ink,
            strokeWidth: em * 0.145,
          ),
        ),
        // طبقة الحدّ.
        StrokedText(
          text: _wordmark,
          fontSize: em,
          fill: FeudColors.ink,
          strokeWidth: em * 0.145,
        ),
        // التعبئة الذهبية فوق.
        Text(
          _wordmark,
          maxLines: 1,
          softWrap: false,
          style: _wordStyle(em).copyWith(color: FeudColors.gold),
        ),
      ],
    );
  }
}

/// سطر من الاسم بالحبر والظل — بينستعمل بالمقدمة الطولية بسطرين.
class BrandWordLine extends StatelessWidget {
  final String text;
  final double em;

  const BrandWordLine({super.key, required this.text, required this.em});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        // نفس ملاحظة BrandWordmark: منقلب إشارة x لتطابق RTL بالكوتلن.
        Transform.translate(
          offset: Offset(em * 0.062, em * 0.088),
          child: StrokedText(
            text: text,
            fontSize: em,
            fill: FeudColors.ink,
            strokeWidth: em * 0.145,
          ),
        ),
        StrokedText(
          text: text,
          fontSize: em,
          fill: FeudColors.gold,
          strokeWidth: em * 0.145,
        ),
      ],
    );
  }
}

class BrandBar extends StatelessWidget {
  final double em;

  const BrandBar({super.key, required this.em});

  @override
  Widget build(BuildContext context) {
    final shadowX = em * 0.058;
    final shadowY = em * 0.068;
    final corner = em * 0.1;

    return SizedBox(
      width: em * 4.5,
      height: em * 0.15,
      child: CustomPaint(
        painter: _BarShadowPainter(dx: -shadowX, dy: shadowY, corner: corner),
        child: Container(
          decoration: BoxDecoration(
            color: FeudColors.gold,
            borderRadius: BorderRadius.circular(corner),
            border: Border.all(color: FeudColors.ink, width: em * 0.048),
          ),
        ),
      ),
    );
  }
}

class _BarShadowPainter extends CustomPainter {
  final double dx;
  final double dy;
  final double corner;

  const _BarShadowPainter({
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
  bool shouldRepaint(covariant _BarShadowPainter oldDelegate) =>
      oldDelegate.dx != dx || oldDelegate.dy != dy || oldDelegate.corner != corner;
}

/// نص محدود بحبر: منرسمه مرتين — مرة حدّ ومرة تعبئة.
class StrokedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fill;
  final double strokeWidth;

  const StrokedText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.fill,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: _wordStyle(fontSize).copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = FeudColors.ink,
          ),
        ),
        Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: _wordStyle(fontSize).copyWith(color: fill),
        ),
      ],
    );
  }
}

TextStyle _wordStyle(double fontSize) => TextStyle(
      fontFamily: displayFontFamily,
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      height: 1.05,
    );
