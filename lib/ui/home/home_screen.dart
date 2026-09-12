/// الشاشة الرئيسية: العلامة على لوح غامق زي كرت «شاشة البداية» بملف
/// التصميم، وجنبها تلات أزرار كبار — كل زر معه سطر بيقول شو بيصير لما
/// تدوسه. الأزرار بتاخد كل الارتفاع فما بتضل الشاشة فاضية.
///
/// منفّذ عن `HomeScreen.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../components/brand_logo.dart';
import '../components/stage.dart';
import '../responsive.dart';
import '../theme.dart';

/// قياس واحد لكل أزرار الرئيسية — نفس الارتفاع والحدّ والزوايا والظل.
const double _cardHeight = 104;
const double _cardGap = 12;
const double _cardCorner = 22;
const double _cardBorder = 5.0;
const double _cardShadow = 7.0;

class HomeScreen extends StatefulWidget {
  final VoidCallback onHostClick;
  final VoidCallback onJoinClick;
  final VoidCallback onSettingsClick;

  const HomeScreen({
    super.key,
    required this.onHostClick,
    required this.onJoinClick,
    this.onSettingsClick = _noop,
  });

  static void _noop() {}

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _tilt;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))
      ..repeat(reverse: true);
    _tilt = Tween<double>(begin: -1.6, end: 1.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isPortrait(context)) {
      return _PortraitHome(
        onHostClick: widget.onHostClick,
        onJoinClick: widget.onJoinClick,
        onSettingsClick: widget.onSettingsClick,
      );
    }

    return StageBackground(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: _tilt,
                builder: (context, _) => Transform.rotate(
                  angle: _tilt.value * 0.35 * 3.1415926535 / 180,
                  child: _BrandPlate(),
                ),
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 320,
              child: Column(
                children: [
                  Expanded(
                    child: _HomeAction(
                      title: 'استضافة لعبة',
                      subtitle: 'افتح غرفة وخلّي اللاعبين يفوتوا',
                      color: FeudColors.lime,
                      onClick: widget.onHostClick,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _HomeAction(
                      title: 'انضمام كلاعب',
                      subtitle: 'اكتب اسمك واختار غرفة',
                      color: FeudColors.teal,
                      onClick: widget.onJoinClick,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _HomeAction(
                      title: 'الإعدادات',
                      subtitle: 'استورد بنك أسئلتك',
                      color: FeudColors.gold,
                      onClick: widget.onSettingsClick,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// الرئيسية بالوضع الطولي — مطابقة لكرت التصميم.
class _PortraitHome extends StatelessWidget {
  final VoidCallback onHostClick;
  final VoidCallback onJoinClick;
  final VoidCallback onSettingsClick;

  const _PortraitHome({
    required this.onHostClick,
    required this.onJoinClick,
    required this.onSettingsClick,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [FeudColors.stageAlt, FeudColors.stage, FeudColors.panelDark],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(
            children: [
              // شريط الألوان فوق.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in FeudBrushes.stripes) ...[
                    Container(
                      width: 46,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(FeudShape.pill),
                      ),
                    ),
                  ],
                ],
              ),
              const Expanded(
                child: Center(
                  child: BrandLogo(em: 46, tagline: 'لعبة عائلية · فريقين · جهاز لكل لاعب'),
                ),
              ),
              // زر الاستضافة الكبير.
              SizedBox(
                width: double.infinity,
                height: _cardHeight,
                child: CartoonSurface(
                  color: FeudColors.lime,
                  borderWidth: _cardBorder,
                  corner: _cardCorner,
                  shadow: _cardShadow,
                  onClick: onHostClick,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'استضافة لعبة',
                                maxLines: 1,
                                style: FeudText.titleLarge(context).copyWith(color: FeudColors.ink),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'افتح غرفة وخلّي اللاعبين يفوتوا',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FeudText.bodyMedium(context)
                                    .copyWith(color: FeudColors.ink.withValues(alpha: 0.72)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(color: FeudColors.ink, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(
                            '‹',
                            style: FeudText.titleLarge(context).copyWith(color: FeudColors.lime),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _cardGap),
              _SmallHomeCard(
                title: 'انضمام كلاعب',
                subtitle: 'اكتب اسمك واختار غرفة',
                color: FeudColors.teal,
                onClick: onJoinClick,
              ),
              const SizedBox(height: _cardGap),
              _SmallHomeCard(
                title: 'الإعدادات',
                subtitle: 'استورد بنك أسئلتك',
                color: FeudColors.gold,
                onClick: onSettingsClick,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// كرت صغير بعنوان وسطر — الاتنين تحت زر الاستضافة، بنفس قياس الكبير.
class _SmallHomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onClick;

  const _SmallHomeCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _cardHeight,
      child: CartoonSurface(
        color: color,
        borderWidth: _cardBorder,
        corner: _cardCorner,
        shadow: _cardShadow,
        onClick: onClick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FeudText.titleLarge(context).copyWith(color: FeudColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FeudText.bodyMedium(context).copyWith(color: FeudColors.ink.withValues(alpha: 0.72)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// لوح العلامة — نفس الكرت بالوضعين، بس ارتفاعه بيتغيّر.
class _BrandPlate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CartoonSurface(
      color: FeudColors.canvas,
      borderWidth: 5,
      corner: FeudShape.block,
      shadow: 9,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandLogo(em: 38),
            const SizedBox(height: 16),
            Text(
              'لعبة عائلية · فريقين · جهاز لكل لاعب',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: FeudText.labelLarge(context).copyWith(color: FeudColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر رئيسي بعنوان وسطر شرح — بياخد ارتفاعه من العمود.
class _HomeAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onClick;

  const _HomeAction({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CartoonSurface(
        color: color,
        borderWidth: _cardBorder,
        corner: _cardCorner,
        shadow: _cardShadow,
        onClick: onClick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                style: FeudText.titleLarge(context).copyWith(color: FeudColors.ink),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FeudText.bodyMedium(context).copyWith(color: FeudColors.ink.withValues(alpha: 0.72)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
