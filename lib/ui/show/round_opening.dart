/// افتتاحية الجولة — نفس مشهدَي التصميم بملف `مين الأطليسي - Play & Pass`:
/// أول شي «بداية الجولة» (اسم الجولة والمضاعف)، وبعدها «استعدوا» (اللاعبين
/// اللي عالمنصة بقطع مايل و«ضد» بالنص). بتنعرض عند المضيف وعند كل لاعب.
///
/// ما بتنتخطّى: اللمسة بتنبلع وما بتوصل لشي تحتها — وإلا اللاعب بيتخطّاها
/// وبيضغط الزر قبل ما يخلص المشهد عند الباقيين.
///
/// منفّذ عن `RoundOpeningScreen.kt` بالمشروع الأصلي (Kotlin).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../feedback/game_feedback.dart';

import '../../game/models.dart';
import '../arabic_numerals.dart';
import '../components/stage.dart';
import '../motion/show_motion.dart';
import '../theme.dart';

const double _introSeconds = 1.9;
const double _versusSeconds = 2.0;

/// توقيت «استعدوا»: الكروت، الرجّة، وشارة «ضد».
const double _cardAt = 0.06;
const double _cardTime = 0.44;
const double _shakeAt = 0.44;
const double _badgeAt = 0.5;

const List<String> _ordinals = [
  'الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة',
  'السادسة', 'السابعة', 'الثامنة', 'التاسعة', 'العاشرة',
];
const List<String> _multiplierWords = ['فردية', 'مزدوجة', 'ثلاثية', 'رباعية', 'خماسية'];

String roundOrdinal(int round) =>
    round >= 1 && round <= _ordinals.length ? _ordinals[round - 1] : round.ar();

String multiplierWord(int multiplier) =>
    multiplier >= 1 && multiplier <= _multiplierWords.length
        ? _multiplierWords[multiplier - 1]
        : '×${multiplier.ar()}';

/// الافتتاحية فوق اللوح — نفس الحالة بتوصل للمضيف وللاعبين، فكل جهاز
/// بيشغّل المشهد لحاله أول ما تبلّش جولة جديدة بالمواجهة، فبيطلعوا مع
/// بعض بفرق الشبكة بس. بتنعرض مرة وحدة لكل جولة على كل جهاز.
class RoundOpeningOverlay extends StatefulWidget {
  final GameState? state;

  const RoundOpeningOverlay({super.key, required this.state});

  @override
  State<RoundOpeningOverlay> createState() => _RoundOpeningOverlayState();
}

class _RoundOpeningOverlayState extends State<RoundOpeningOverlay> {
  /// `remember { mutableIntStateOf(-1) }` — بيعيش طول عمر المسار.
  int _openedRound = -1;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state == null || !state.matchStarted || state.gameOver) {
      return const SizedBox.shrink();
    }
    final roundIndex = state.currentQuestionIndex;
    if (state.phase != RoundPhase.faceOff || _openedRound == roundIndex) {
      return const SizedBox.shrink();
    }

    return RoundOpening(
      round: roundIndex + 1,
      multiplier: state.multiplier,
      playerA: state.podiumPlayer(TeamId.team1)?.name,
      playerB: state.podiumPlayer(TeamId.team2)?.name,
      teamAName: state.teams[TeamId.team1]?.name ?? '',
      teamBName: state.teams[TeamId.team2]?.name ?? '',
      onDone: () => setState(() => _openedRound = roundIndex),
    );
  }
}

class RoundOpening extends StatefulWidget {
  final int round;
  final int multiplier;
  final String? playerA;
  final String? playerB;
  final String teamAName;
  final String teamBName;
  final VoidCallback onDone;

  const RoundOpening({
    super.key,
    required this.round,
    required this.multiplier,
    required this.playerA,
    required this.playerB,
    required this.teamAName,
    required this.teamBName,
    required this.onDone,
  });

  @override
  State<RoundOpening> createState() => _RoundOpeningState();
}

class _RoundOpeningState extends State<RoundOpening> {
  int _stage = 0;
  Timer? _timer;

  /// بدون لاعبين عالمنصة ما في «استعدوا» — بنكتفي ببداية الجولة.
  bool get _hasVersus =>
      (widget.playerA?.trim().isNotEmpty ?? false) &&
      (widget.playerB?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    // بعد أول إطار — `GameFeedbackScope.maybeOf` بدها سياق مبني.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedule();
    });
  }

  @override
  void didUpdateWidget(RoundOpening oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `remember(round)` — جولة جديدة بترجّع المشهد لأوله.
    if (oldWidget.round != widget.round) {
      _stage = 0;
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    // صوت كل مشهد لحظة ما يبلّش: بداية الجولة (كرت بيطير وبيخبط)، وبعدها
    // «استعدوا» (صعود وضربة). فتح الزر بينسمع لما يخلص الافتتاح كله.
    GameFeedbackScope.maybeOf(context)?.play(_stage == 0 ? Cue.roundStart : Cue.versus);
    final wait = _stage == 0 ? _introSeconds : _versusSeconds;
    _timer = Timer(Duration(milliseconds: (wait * 1000).round()), () {
      if (!mounted) return;
      if (_stage == 0 && _hasVersus) {
        setState(() => _stage = 1);
        _schedule();
      } else {
        GameFeedbackScope.maybeOf(context)?.play(Cue.faceOffOpen);
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // بتاكل اللمسة بدون ما تعمل شي — حاجز، مش زر تخطّي.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: _stage == 0
          ? RoundIntroScreen(round: widget.round, multiplier: widget.multiplier)
          : VersusScreen(
              playerA: widget.playerA ?? '',
              playerB: widget.playerB ?? '',
              teamAName: widget.teamAName,
              teamBName: widget.teamBName,
            ),
    );
  }
}

/// «بداية الجولة»: قرص بينط، اسم الجولة بيهبط بضربة، ولافتة المضاعف بتكنس.
class RoundIntroScreen extends StatelessWidget {
  final int round;
  final int multiplier;

  const RoundIntroScreen({super.key, required this.round, required this.multiplier});

  @override
  Widget build(BuildContext context) {
    return ShowScene(
      sceneKey: round,
      cap: 6,
      builder: (context, t) => LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final tall = constraints.maxHeight;
          final portrait = tall > w;
          // القياس الأساسي من أقصر بُعد — هيك القرص بيضل دايرة كاملة جوّا
          // الكادر بالوضعين، وما بينقص منه ولا بيطلع بيضوي.
          final h = math.min(tall, w);
          final bannerHeight = portrait ? tall * 0.104 : h * 0.16;

          return Stack(
            fit: StackFit.expand,
            children: [
              const SpinningRays(),
              // قرص بنفسجي بينط ورا الاسم.
              Center(
                child: Transform.translate(
                  offset: Offset(0, portrait ? -tall * 0.02 : 0),
                  child: Transform.scale(
                    scale: thump(t, 0),
                    child: Container(
                      width: portrait ? w * 0.88 : h * 0.82,
                      height: portrait ? w * 0.88 : h * 0.82,
                      decoration: const BoxDecoration(
                        color: FeudColors.stageAlt,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, portrait ? -tall * 0.045 : -h * 0.055),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: appear(t, 0.12),
                        child: Transform.scale(
                          scale: thump(t, 0.12, 0.38),
                          child: Text(
                            'الجولة',
                            style: FeudText.headlineSmall(context)
                                .copyWith(color: FeudColors.cream),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: appear(t, 0.06, 0.1),
                        child: Transform.rotate(
                          angle: slamRotation(t, 0.06) * math.pi / 180,
                          child: Transform.scale(
                            scale: slamScale(t, 0.06),
                            child: Text(
                              roundOrdinal(round),
                              maxLines: 1,
                              style: FeudText.displayLarge(context).copyWith(
                                color: FeudColors.gold,
                                fontSize: portrait ? w * 0.22 : h * 0.20,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // لافتة المضاعف بتكنس من الجهة بعد ما يستقر الاسم.
              Positioned(
                top: portrait ? tall * 0.774 : tall * 0.76,
                left: 0,
                child: GoldBanner(
                  text: '${multiplierWord(multiplier)} ×${multiplier.ar()}',
                  width: w,
                  height: bannerHeight,
                  offsetFraction: wipe(t, 0.70),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// «استعدوا» — نفس شاشة التصميم بالوضعين: كرت لكل لاعب بينقذف لمكانه
/// وبينهم «ضد» مع حلقة صدمة.
class VersusScreen extends StatelessWidget {
  final String playerA;
  final String playerB;
  final String teamAName;
  final String teamBName;

  const VersusScreen({
    super.key,
    required this.playerA,
    required this.playerB,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  Widget build(BuildContext context) {
    return ShowScene(
      sceneKey: playerA + playerB,
      cap: 4,
      builder: (context, t) => LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final tall = constraints.maxHeight;
          final span = math.min(w, tall * 0.62);

          // رجّة الكادر بعد التصادم.
          double shake = 0;
          if (t >= _shakeAt && t <= _shakeAt + 0.24) {
            final p = (t - _shakeAt) / 0.24;
            shake = math.sin(p * 20) * (1 - p) * 8;
          }

          final ringSize = span * 0.5;
          final badge = span * 0.24;

          return Stack(
            fit: StackFit.expand,
            children: [
              const SpinningRays(),
              Transform.translate(
                offset: Offset(shake, -shake * 0.7),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.068, vertical: tall * 0.035),
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: tall * 0.02),
                          child: _VersusCard(
                            label: teamAName,
                            name: playerA,
                            color: FeudColors.team1,
                            ink: FeudColors.team1Ink,
                            nameColor: FeudColors.team1Ink,
                            fromY: -tall * 0.8,
                            fromRotation: -8,
                            nameSize: span * 0.17,
                            t: t,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: tall * 0.02),
                          child: _VersusCard(
                            label: teamBName,
                            name: playerB,
                            color: FeudColors.team2,
                            ink: FeudColors.team2Ink,
                            nameColor: FeudColors.cream,
                            fromY: tall * 0.8,
                            fromRotation: 8,
                            nameSize: span * 0.17,
                            t: t,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // حلقة الصدمة — بترسم لحالها كل فريم.
              Center(
                child: CustomPaint(
                  size: Size.square(ringSize * 2.2),
                  painter: _ShockRingPainter(
                    ring: shockRing(t, _badgeAt, 0.6),
                    radius: ringSize / 2,
                    strokeScale: span / 385,
                  ),
                ),
              ),
              // شارة «ضد».
              Center(
                child: Transform.scale(
                  scale: thump(t, _badgeAt, 0.36),
                  child: Container(
                    width: badge,
                    height: badge,
                    padding: EdgeInsets.all(badge * 0.076),
                    decoration: const BoxDecoration(
                      color: FeudColors.gold,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: FeudColors.ink,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'ضد',
                        style: FeudText.displayLarge(context).copyWith(
                          color: FeudColors.cream,
                          fontSize: badge * 0.37,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShockRingPainter extends CustomPainter {
  final ShockRing ring;
  final double radius;
  final double strokeScale;

  const _ShockRingPainter({
    required this.ring,
    required this.radius,
    required this.strokeScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (ring.alpha <= 0) return;
    final stroke = math.max(1.0, ring.width * strokeScale);
    canvas.drawCircle(
      size.center(Offset.zero),
      radius * ring.scale,
      Paint()
        ..color = FeudColors.gold.withValues(alpha: ring.alpha.clamp(0, 1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_ShockRingPainter old) =>
      old.ring.alpha != ring.alpha || old.ring.scale != ring.scale || old.radius != radius;
}

/// كرت لاعب بالمواجهة — بينقذف لمكانه بضربة مطاطية.
class _VersusCard extends StatelessWidget {
  final String label;
  final String name;
  final Color color;
  final Color ink;
  final Color nameColor;
  final double fromY;
  final double fromRotation;
  final double nameSize;
  final double t;

  const _VersusCard({
    required this.label,
    required this.name,
    required this.color,
    required this.ink,
    required this.nameColor,
    required this.fromY,
    required this.fromRotation,
    required this.nameSize,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final away = keys(t, _cardAt, _cardTime, const [(0.0, 1.0), (0.54, 0.0), (1.0, 0.0)]);
    final scaleX = keys(
      t, _cardAt, _cardTime,
      const [(0.0, 0.7), (0.54, 0.86), (0.7, 1.08), (0.86, 0.97), (1.0, 1.0)],
    );
    final scaleY = keys(
      t, _cardAt, _cardTime,
      const [(0.0, 0.7), (0.54, 1.14), (0.7, 0.94), (0.86, 1.04), (1.0, 1.0)],
    );

    return Opacity(
      opacity: appear(t, _cardAt, 0.12),
      child: Transform.translate(
        offset: Offset(0, fromY * away),
        child: Transform.rotate(
          angle: fromRotation * away * math.pi / 180,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
            child: BlockSkin(
              color: color,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FeudText.titleSmall(context)
                            .copyWith(color: ink.withValues(alpha: 0.75)),
                      ),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: FeudText.displayLarge(context).copyWith(
                          color: nameColor,
                          fontSize: nameSize,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// لافتة ذهبية بتكنس عرض الشاشة — نفس `dcWipe` بالتصميم.
class GoldBanner extends StatelessWidget {
  final String text;
  final double width;
  final double height;
  final double offsetFraction;

  const GoldBanner({
    super.key,
    required this.text,
    required this.width,
    required this.height,
    required this.offsetFraction,
  });

  @override
  Widget build(BuildContext context) {
    // `offset(x = width * fraction)` بالكوتلن بياخد اتجاه الواجهة بعين
    // الاعتبار — بـ RTL بيتحرّك لليسار؛ Transform.translate خام فمنقلب الإشارة.
    return Transform.translate(
      offset: Offset(-width * offsetFraction, 0),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: BlockSkin(
            color: FeudColors.gold,
            child: Center(
              child: Text(
                text,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: FeudText.displayLarge(context).copyWith(
                  color: FeudColors.ink,
                  fontSize: height * 0.52,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
