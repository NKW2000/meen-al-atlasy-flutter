/// شريط السؤال، شريط الحالة، وإعلان النقاط بنهاية الجولة.
///
/// منفّذ عن `components/Banners.kt` بالمشروع الأصلي (Kotlin).
library;

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../arabic_numerals.dart';
import '../theme.dart';
import 'stage.dart';
import 'strikes.dart' show TeamColorX;

/// بطاقة السؤال — لوح كريمي زي شاشة البرنامج. عرضها بقد نصّها (مع سقف
/// حتى ما تتمدّد على كل الشاشة بالأسئلة الطويلة)، فبتنتوسّط تماماً جوّا
/// المساحة اللي بتنعطى لها.
class QuestionCard extends StatelessWidget {
  final int round;
  final int totalRounds;
  final String question;

  const QuestionCard({
    super.key,
    required this.round,
    required this.totalRounds,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    return GoldPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Text(
          question,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FeudText.headlineSmall(context).copyWith(color: FeudColors.ink),
        ),
      ),
    );
  }
}

/// شريط الحالة تحت السؤال — بياخد لون الفريق اللي عليه الدور.
class StatusBanner extends StatelessWidget {
  final String text;
  final Color accent;
  final bool filled;

  const StatusBanner({
    super.key,
    required this.text,
    required this.accent,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CartoonSurface(
        color: filled ? accent : FeudColors.ink.withValues(alpha: 0.45),
        borderWidth: 4,
        corner: FeudShape.block,
        shadow: 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: FeudText.titleSmall(context).copyWith(
              color: filled ? FeudColors.ink : FeudColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// إعلان نقاط نهاية الجولة — بينط بضربة: `scaleIn(1.6f, 280ms) +
/// fadeIn(180ms)` لما يظهر، و`fadeOut(160ms)` لما يختفي — زي
/// `AnimatedVisibility` بالكوتلن بالحرف.
class AwardBanner extends StatefulWidget {
  final GameState state;

  const AwardBanner({super.key, required this.state});

  @override
  State<AwardBanner> createState() => _AwardBannerState();
}

class _AwardBannerState extends State<AwardBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.6, end: 1)
      .animate(CurvedAnimation(parent: _enter, curve: Curves.fastOutSlowIn));
  late bool _wasVisible = _visible;

  bool get _visible =>
      widget.state.lastAward != null && widget.state.roundOver;

  @override
  void initState() {
    super.initState();
    // إذا الصف تركّب وهو أصلاً ظاهر (مثلاً بعد hot restart)، ما في داعي
    // لضربة الدخول — منثبّته على القياس النهائي فوراً.
    if (_visible) _enter.value = 1;
  }

  @override
  void didUpdateWidget(covariant AwardBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_visible && !_wasVisible) {
      _enter.forward(from: 0);
    }
    _wasVisible = _visible;
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final award = widget.state.lastAward;
    if (award == null) return const SizedBox.shrink();

    final teamName = widget.state.teams[award.teamId]?.name ?? '';
    final text = award.stolen
        ? 'سرقة! $teamName +${award.points.ar()}'
        : '$teamName +${award.points.ar()}';

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: Duration(milliseconds: _visible ? 180 : 160),
      curve: Curves.fastOutSlowIn,
      child: AnimatedBuilder(
        animation: _enter,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          width: double.infinity,
          child: CartoonSurface(
            color: award.stolen ? FeudColors.pink : FeudColors.gold,
            borderWidth: 4,
            corner: FeudShape.block,
            shadow: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: FeudText.titleMedium(context).copyWith(
                  color: award.stolen ? Colors.white : FeudColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color accentFor(TeamId? teamId) => teamId?.color() ?? FeudColors.gold;

/// فراغ صغير بين عناصر الشاشة.
class BannerSpacer extends StatelessWidget {
  const BannerSpacer({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}
