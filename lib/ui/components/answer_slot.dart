/// سطر جواب: رقم، نص، نقاط — بظل مسطّح زي التصميم. نفس السطر عند المضيف
/// وعند اللاعب، فالكشف بيتحرّك عند الاتنين متل بعض: الخانة بتنقلب على
/// محورها الأفقي من الكريمي للأخضر، بتهتز لما تحطّ، والنقاط بتنط بعدها.
/// [revealDelay] بيأخّر الانقلاب لما تنكشف كذا خانة بنفس اللحظة.
///
/// منفّذ عن `PortraitAnswerRow` + `SlotFace` + `RevealGate` + `flipAngle`
/// من `HostGameBoardScreen.kt` (أسطر ~٣٢٧–٥٢٠) بالمشروع الأصلي (Kotlin) —
/// هون بالاسم `AnswerSlotRow` زي ما طلبته المهمة.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../arabic_numerals.dart';
import '../motion/show_motion.dart';
import '../theme.dart';
import 'stage.dart' show BlockSkin;

/// زمن انقلاب الخانة لما تنكشف.
const double _flipTime = 0.5;

/// الهزّة لما يحطّ الوجه الأخضر، ونطّة النقاط بعدها بشوي.
const double _landAt = _flipTime * 0.35;
const double _pointsAt = _flipTime * 0.45;

/// وقت «خلصت الحركة» للخانة اللي بتبيّن مكشوفة بدون ما تتحرّك.
const double _settled = 1e6;

/// زاوية الانقلاب من ٠ لـ ١٨٠: النص الأول بيلف الوجه الكريمي لحد ما يصير
/// عالحرف، والتاني بيجيب الأخضر من الحرف لمكانه — بمنحنى `bang` نفسه،
/// فالكريمي بيختفي بسرعة والأخضر بيهدى وهو نازل.
double flipAngle(double t, double delay) =>
    180 * keys(t, delay, _flipTime, const [(0.0, 0.0), (1.0, 1.0)]);

class AnswerSlotRow extends StatefulWidget {
  final int position;
  final Answer? answer;
  final bool enabled;

  /// اللاعب ما بيشوف نص الجواب ولا نقاطه قبل ما يكشفه المضيف.
  final bool revealHiddenText;
  final double revealDelay;
  final VoidCallback? onClick;

  const AnswerSlotRow({
    super.key,
    required this.position,
    required this.answer,
    required this.enabled,
    this.revealHiddenText = true,
    this.revealDelay = 0,
    this.onClick,
  });

  @override
  State<AnswerSlotRow> createState() => _AnswerSlotRowState();
}

class _AnswerSlotRowState extends State<AnswerSlotRow>
    with SingleTickerProviderStateMixin {
  /// بيتذكّر إذا شفنا الخانة مخفية قبل — بس هيك الكشف بيتحرّك.
  late bool _seenHidden = !_revealed;
  bool _animating = false;

  /// ساعة واحدة طول عمر الصف — SingleTickerProviderStateMixin بيرفض
  /// نطلب منه Ticker تاني، فمنعملها مرة وحدة أول ما تنكشف الخانة (مش من
  /// أول ما يتركّب الصف حتى ما نطلب Ticker إذا الخانة ما انكشفت أبداً)،
  /// وبعدين منعيد تشغيلها (restart) كل ما تنكشف من جديد بدل ما نعمل ساعة
  /// جديدة كل مرة. سقف الساعة [ShowClock.cap] لازم ينحدّث قبل كل إعادة
  /// تشغيل لأنه [revealDelay] ممكن يختلف بين دورة كشف وتانية.
  ShowClock? _clock;

  bool get _revealed => widget.answer?.revealed ?? false;

  double get _cap => widget.revealDelay + _flipTime + 0.6;

  @override
  void initState() {
    super.initState();
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant AnswerSlotRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClock();
  }

  void _syncClock() {
    if (!_revealed) _seenHidden = true;
    final animate = _revealed && _seenHidden;
    if (animate == _animating) return;
    _animating = animate;
    if (animate) {
      final clock = _clock;
      if (clock == null) {
        _clock = ShowClock(this, cap: _cap);
      } else {
        clock.cap = _cap;
        clock.restart();
      }
    }
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  double _now() {
    if (_animating) return _clock?.value ?? 0;
    if (_revealed) return _settled;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(FeudShape.block);
    final answer = widget.answer;

    if (answer == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: FeudColors.panelDark,
          borderRadius: shape,
          border: Border.all(color: FeudColors.stageAlt, width: 3),
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: _SlotFace(
            position: widget.position,
            text: null,
            textColor: FeudColors.textFaint,
            points: null,
            pointsColor: FeudColors.textFaint,
            numberColor: FeudColors.stageAlt,
            numberInk: FeudColors.textFaint,
          ),
        ),
      );
    }

    if (_animating) {
      // _clock مضمون غير null هون: ما بنخلّي _animating=true إلا بعد ما
      // ننشئ الساعة بـ _syncClock().
      return ListenableBuilder(
        listenable: _clock!,
        builder: (context, _) => _buildFaces(context, answer, shape),
      );
    }
    return _buildFaces(context, answer, shape);
  }

  /// بيبني الوجهين لخانة عندها جواب — بيتنفّذ كل فريم لما تكون الحركة
  /// شغّالة (جوّا [ListenableBuilder]) عشان يقرأ وقت الساعة أول لحظة رسم.
  Widget _buildFaces(BuildContext context, Answer answer, BorderRadius shape) {
    final t = _now();
    final angle = flipAngle(t, widget.revealDelay);
    final showText = _revealed || widget.revealHiddenText;

    final land = keys(
      t,
      widget.revealDelay + _landAt,
      0.4,
      const [(0.0, 1.0), (0.45, 1.06), (0.75, 0.98), (1.0, 1.0)],
    );
    final pop = thump(t, widget.revealDelay + _pointsAt, 0.4);

    // الوجه الأخضر — بيجي من الحرف لمكانه بعد ما يختفي الكريمي.
    final greenVisible = angle >= 90;
    final greenFace = Visibility(
      visible: greenVisible,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX((angle - 180) * math.pi / 180)
          ..scaleByDouble(land, land, 1, 1),
        child: ClipRRect(
          borderRadius: shape,
          child: BlockSkin(
            color: FeudColors.team1,
            border: 3,
            shadow: 4,
            corner: FeudShape.block,
            child: _SlotFace(
              position: widget.position,
              text: answer.text,
              textColor: FeudColors.team1Ink,
              points: answer.points.ar(),
              pointsColor: FeudColors.team1Ink,
              numberColor: FeudColors.gold,
              numberInk: FeudColors.ink,
              pointsScale: pop,
            ),
          ),
        ),
      ),
    );

    // الوجه الكريمي — فوق، لأنه هو اللي بينضغط عند المضيف.
    final creamVisible = angle < 90;
    final creamFace = Visibility(
      visible: creamVisible,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(angle * math.pi / 180),
        child: ClipRRect(
          borderRadius: shape,
          child: BlockSkin(
            color: FeudColors.cream,
            border: 3,
            shadow: 4,
            corner: FeudShape.block,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: (!_revealed && widget.enabled) ? widget.onClick : null,
              child: showText
                  ? _SlotFace(
                      position: widget.position,
                      text: answer.text,
                      textColor: FeudColors.ink,
                      points: answer.points.ar(),
                      pointsColor: FeudColors.ink,
                      numberColor: FeudColors.gold,
                      numberInk: FeudColors.ink,
                    )
                  // عند اللاعب الخانة المخفية رقم بنصّها وبس — زي لوح
                  // «فاميلي فيود» الحقيقي.
                  : _HiddenFace(position: widget.position),
            ),
          ),
        ),
      ),
    );

    // الوجهين بياخدوا قياس الخانة كلها — `matchParentSize()` بالكوتلن؛
    // بدون هيك الوجه الأخضر بياخد حجم محتواه بس وبيطلع أصغر من الكريمي.
    return Stack(
      fit: StackFit.expand,
      children: [
        greenFace,
        creamFace,
      ],
    );
  }
}

/// وجه واحد من الخانة: رقم، نص، ونقاط. [text] = null يعني خانة فاضية.
class _SlotFace extends StatelessWidget {
  final int position;
  final String? text;
  final Color textColor;
  final String? points;
  final Color pointsColor;
  final Color numberColor;
  final Color numberInk;
  final double pointsScale;

  const _SlotFace({
    required this.position,
    required this.text,
    required this.textColor,
    required this.points,
    required this.pointsColor,
    required this.numberColor,
    required this.numberInk,
    this.pointsScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: numberColor, shape: BoxShape.circle),
            child: Text(
              position.ar(),
              style: FeudText.labelLarge(context).copyWith(color: numberInk),
            ),
          ),
          const SizedBox(width: 10),
          if (text != null) ...[
            Expanded(
              child: Text(
                text!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FeudText.titleMedium(context).copyWith(color: textColor),
              ),
            ),
            if (points != null)
              Transform.scale(
                scale: pointsScale,
                child: Text(
                  points!,
                  style: FeudText.titleMedium(context).copyWith(color: pointsColor),
                ),
              ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

/// الوجه المخفي عند اللاعب: رقم الخانة بشارة ذهبية بنصّ البلوك، بدون نص
/// ولا نقاط — زي لوح «فاميلي فيود» الحقيقي.
class _HiddenFace extends StatelessWidget {
  final int position;

  const _HiddenFace({required this.position});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FeudColors.gold,
          shape: BoxShape.circle,
          border: Border.all(color: FeudColors.ink, width: 2),
        ),
        child: Text(
          position.ar(),
          style: FeudText.titleMedium(context).copyWith(color: FeudColors.ink),
        ),
      ),
    );
  }
}
