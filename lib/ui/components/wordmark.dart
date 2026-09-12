/// الوردمارك الكامل زي ملف التصميم: بلاطة ذهبية فيها «؟» فيروزية بظل حبر،
/// وجنبها لوحة الاسم مايلة، وتحتها شارتين.
///
/// منفّذ عن `components/Wordmark.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'buttons.dart';
import 'stage.dart';

class Wordmark extends StatefulWidget {
  final double tileSize;
  final int nameSize;
  final bool showTags;

  const Wordmark({
    super.key,
    this.tileSize = 104,
    this.nameSize = 44,
    this.showTags = true,
  });

  @override
  State<Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<Wordmark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _wobble;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);
    _wobble = Tween<double>(begin: -2.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _wobble,
          builder: (context, child) =>
              QuestionTile(size: widget.tileSize, rotation: _wobble.value),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -2 * 3.1415926535 / 180,
              child: CartoonSurface(
                color: FeudColors.gold,
                borderWidth: 6,
                corner: 20,
                shadow: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                  child: Text(
                    'مين الأطليسي',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: displayFontFamily,
                      fontWeight: FontWeight.w800,
                      fontSize: widget.nameSize.toDouble(),
                      height: 1.15,
                      color: FeudColors.ink,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showTags) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Pill(
                    text: 'لعبة عائلية',
                    color: FeudColors.pink,
                    textColor: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Pill(text: 'بدون إنترنت', color: FeudColors.lime),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// بلاطة العلامة — «؟» فيروزية وظلها حبر مزاح، نفس أيقونة التطبيق.
class QuestionTile extends StatelessWidget {
  final double size;
  final double rotation;

  const QuestionTile({super.key, this.size = 104, this.rotation = 0});

  @override
  Widget build(BuildContext context) {
    final glyph = TextStyle(
      fontFamily: displayFontFamily,
      fontWeight: FontWeight.w800,
      fontSize: size * 0.62,
      height: 1,
    );

    return Transform.rotate(
      angle: rotation * 3.1415926535 / 180,
      child: CartoonSurface(
        color: FeudColors.gold,
        borderWidth: 6,
        corner: size * 0.27,
        shadow: 8,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // الظل الصلب للعلامة.
              Transform.translate(
                offset: const Offset(-4, 4),
                child: Text('؟', textAlign: TextAlign.center, style: glyph.copyWith(color: FeudColors.ink)),
              ),
              Text('؟', textAlign: TextAlign.center, style: glyph.copyWith(color: FeudColors.teal)),
            ],
          ),
        ),
      ),
    );
  }
}
