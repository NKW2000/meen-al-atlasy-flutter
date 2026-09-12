/// الأساس البصري لكل الشاشات: خلفية بنفسجية بنقط، وشريط ألوان متحرك فوق.
/// السطح الكرتوني: حد أسود سميك + ظل صلب مزاح (مش elevation).
///
/// منفّذ عن `components/Stage.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../theme.dart';

/// الأساس البصري لكل الشاشات: خلفية بنفسجية بنقط.
class StageBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry contentPadding;

  const StageBackground({
    super.key,
    required this.child,
    this.contentPadding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: FeudBrushes.stage,
      ),
      child: CustomPaint(
        painter: const _DotGridPainter(),
        child: Padding(padding: contentPadding, child: child),
      ),
    );
  }
}

/// نقط خفيفة عالخلفية — نفس تكستشر التصميم.
class _DotGridPainter extends CustomPainter {
  static const Color _color = Color(0x12FFFFFF); // White @ alpha 0.07
  static const double _spacing = 15;

  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _color;
    const radius = 1.2;
    for (var y = 0.0; y < size.height; y += _spacing) {
      for (var x = 0.0; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

/// جلد البلوك الموحّد: ظل حبري مزاح، خلفية، وحدّ حبر — نفس أسلوب
/// [CartoonSurface] حتى يطلع كل شي بالتطبيق بنفس اللغة البصرية.
BoxDecoration blockSkin(
  Color color, {
  double border = 4,
  double shadow = 6,
  double corner = FeudShape.block,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(corner),
    border: Border.all(color: FeudColors.ink, width: border),
  );
}

/// يرسم الظل المزاح خلف [child] بنفس منطق [blockSkin] — لأنه CSS/Compose
/// بيرسم الظل والخلفية بنفس الطبقة، وبفلَتر بسيط ما منقدر نعمل هيك
/// بـ[BoxDecoration] وحده (bottom-left offset shadow بدون blur).
class BlockSkin extends StatelessWidget {
  final Widget child;
  final Color color;
  final double border;
  final double shadow;
  final double corner;

  const BlockSkin({
    super.key,
    required this.child,
    required this.color,
    this.border = 4,
    this.shadow = 6,
    this.corner = FeudShape.block,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OffsetShadowPainter(
        shadowColor: FeudColors.ink,
        corner: corner,
        dx: -shadow,
        dy: shadow,
      ),
      child: Container(
        decoration: blockSkin(color, border: border, shadow: shadow, corner: corner),
        child: child,
      ),
    );
  }
}

class _OffsetShadowPainter extends CustomPainter {
  final Color shadowColor;
  final double corner;
  final double dx;
  final double dy;

  const _OffsetShadowPainter({
    required this.shadowColor,
    required this.corner,
    required this.dx,
    required this.dy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(dx, dy, size.width, size.height),
      Radius.circular(corner),
    );
    canvas.drawRRect(rrect, Paint()..color = shadowColor);
  }

  @override
  bool shouldRepaint(covariant _OffsetShadowPainter oldDelegate) =>
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.corner != corner ||
      oldDelegate.dx != dx ||
      oldDelegate.dy != dy;
}

/// ظل مسطّح تحت العنصر بالضبط (`box-shadow: 0 Ypx 0 color`) — هيك ظلال
/// كروت التصميم بالوضع الطولي، مش الظل المزاح تبع الوضع الأفقي.
class FlatShadow extends StatelessWidget {
  final Widget child;
  final double offset;
  final Color color;
  final double corner;

  const FlatShadow({
    super.key,
    required this.child,
    required this.offset,
    required this.color,
    required this.corner,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OffsetShadowPainter(
        shadowColor: color,
        corner: corner,
        dx: 0,
        dy: offset,
      ),
      child: child,
    );
  }
}

/// السطح الكرتوني: حد أسود سميك + ظل صلب مزاح (مش elevation). الضغط
/// بينزّل السطح على ظله — نفس إحساس الأزرار بالتصميم.
class CartoonSurface extends StatefulWidget {
  final Color color;
  final double borderWidth;
  final double corner;
  final double shadow;
  final VoidCallback? onClick;
  final bool enabled;
  final Widget child;

  const CartoonSurface({
    super.key,
    this.color = FeudColors.stageAlt,
    this.borderWidth = 5,
    this.corner = FeudShape.block,
    this.shadow = 6,
    this.onClick,
    this.enabled = true,
    required this.child,
  });

  @override
  State<CartoonSurface> createState() => _CartoonSurfaceState();
}

class _CartoonSurfaceState extends State<CartoonSurface> {
  bool _pressed = false;

  bool get _clickable => widget.onClick != null && widget.enabled;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final drop = _pressed && _clickable ? widget.shadow : 0.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(widget.corner),
      side: BorderSide(color: FeudColors.ink, width: widget.borderWidth),
    );

    Widget surface = CustomPaint(
      painter: _OffsetShadowPainter(
        shadowColor: FeudColors.ink,
        corner: widget.corner,
        dx: -widget.shadow,
        dy: widget.shadow,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(color: widget.color, shape: shape),
        child: widget.child,
      ),
    );

    surface = Transform.translate(
      offset: Offset(-drop, drop),
      child: surface,
    );

    if (widget.onClick == null) return surface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTap: widget.enabled ? widget.onClick : null,
      child: surface,
    );
  }
}

/// لوح كريمي — بيستعمل للسؤال وللبطاقات الفاتحة.
class GoldPanel extends StatelessWidget {
  final Color accent;
  final Widget child;

  const GoldPanel({super.key, this.accent = FeudColors.cream, required this.child});

  @override
  Widget build(BuildContext context) => CartoonSurface(
        color: accent,
        corner: 22,
        shadow: 8,
        child: child,
      );
}

class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 4,
        decoration: BoxDecoration(
          color: FeudColors.ink,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
