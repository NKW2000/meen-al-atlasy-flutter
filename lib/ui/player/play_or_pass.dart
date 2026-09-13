/// قرار الفائز بالمواجهة — زرين كبار، بدون أي إشي تاني بالشاشة.
///
/// منفّذ عن `PlayOrPassScreen` + `Band` بـ`PlayerScreen.kt` بالمشروع
/// الأصلي (Kotlin).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../theme.dart';

/// ألوان شاشة «العب / تمرير» زي ما هي بملف التصميم.
const Color _passPlayBase = FeudColors.canvas;
const Color _passColor = FeudColors.pink;
const Color _playColor = FeudColors.team1;
const Color _playInk = FeudColors.team1Ink;
const Color _timerColor = FeudColors.gold;
const double _trackHeight = 16;
const Duration _doorMillis = Duration(milliseconds: 640);
const Curve _doorEasing = Cubic(0.2, 0.85, 0.25, 1);

class PlayOrPassScreen extends StatefulWidget {
  final GameState state;
  final TeamId? teamId;
  final void Function(bool play) onChoose;

  const PlayOrPassScreen({
    super.key,
    required this.state,
    required this.teamId,
    required this.onChoose,
  });

  @override
  State<PlayOrPassScreen> createState() => _PlayOrPassScreenState();
}

class _PlayOrPassScreenState extends State<PlayOrPassScreen> with TickerProviderStateMixin {
  // ثلاث مراحل زي التصميم: برّا الكادر، داخل ومستقر، ومفتوح بعد الاختيار.
  bool _opened = false;
  bool _entered = false;
  Timer? _enterTimer;

  /// شريط الوقت: بينفضى بسرعة ثابتة من الوقت نفسه، مش من دقّات المضيف —
  /// الدقّة اللي بتوصل عالشبكة متأخرة أو بدري ما بتوقّفه ولا بتنطّطه، بس
  /// إذا بعد كتير عن وقت المضيف منرجّعه على وقته.
  late final AnimationController _progress = AnimationController(vsync: this, value: 1);

  int get _total => widget.state.choiceLimitSeconds < 1 ? 1 : widget.state.choiceLimitSeconds;

  @override
  void initState() {
    super.initState();
    _enterTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _entered = true);
    });
    _syncProgress();
  }

  @override
  void didUpdateWidget(PlayOrPassScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.choiceSecondsLeft != widget.state.choiceSecondsLeft ||
        oldWidget.state.choiceLimitSeconds != widget.state.choiceLimitSeconds) {
      _syncProgress();
    }
  }

  void _syncProgress() {
    final total = _total;
    final left = widget.state.choiceSecondsLeft;
    final hostAt = (left / total).clamp(0.0, 1.0);
    final drift = (_progress.value - hostAt).abs() * total;
    // عدّاد جديد (رجع الوقت لفوق) أو فرق أكتر من ثانية ونص: منقفز لوقت المضيف.
    if (hostAt > _progress.value + 0.02 || drift > 1.5) _progress.value = hostAt;
    if (left <= 0) {
      _progress.stop();
      _progress.value = 0;
      return;
    }
    // من وين ما كنا لصفر، بسرعة (١ / الوقت الكلي) بالثانية — بدون وقفات.
    final remainingMillis = (_progress.value * total * 1000).round();
    _progress.animateTo(
      0,
      duration: Duration(milliseconds: remainingMillis < 1 ? 1 : remainingMillis),
      curve: Curves.linear,
    );
  }

  void _choose(bool play) {
    if (_opened) return;
    setState(() => _opened = true);
    widget.onChoose(play);
  }

  @override
  void dispose() {
    _enterTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final away = _entered && !_opened;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bandHeight = (constraints.maxHeight - _trackHeight) / 2;
        // بالطولي الشريط بيصير عالي كتير — منحدّ الخط بعرض الشاشة.
        final labelSize = bandHeight * 0.3 < width * 0.2 ? bandHeight * 0.3 : width * 0.2;

        // «تمرير» و«العب» بيدخلوا من الجهتين بفارق بسيط. `offset(x)` بالكوتلن
        // بياخد اتجاه الواجهة بعين الاعتبار (RTL: الموجب لليسار)، فمنقلب
        // الإشارة هون لنفس النتيجة.
        final passOffset = away ? 0.0 : -width;
        final playOffset = away ? 0.0 : width;

        return Container(
          color: _passPlayBase,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ورا البابين خلفية سادة بس (طلب المستخدم) — بدون نصوص.

              // شريط «تمرير» الأحمر فوق.
              AnimatedPositioned(
                duration: _doorMillis,
                curve: _doorEasing,
                top: 0,
                left: passOffset,
                width: width,
                height: bandHeight,
                child: _Band(
                  label: 'مرّر',
                  background: _passColor,
                  labelColor: FeudColors.cream,
                  fontSize: labelSize,
                  onClick: () => _choose(false),
                ),
              ),

              // شريط الوقت ملزوق بالأحمر.
              AnimatedPositioned(
                duration: _doorMillis,
                curve: _doorEasing,
                top: bandHeight,
                left: passOffset,
                width: width,
                height: _trackHeight,
                child: ColoredBox(
                  color: _passPlayBase,
                  // بينفضى من اليمين للشمال: الباقي ملزوق بالطرف الشمالي.
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => FractionallySizedBox(
                        widthFactor: _progress.value.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: const ColoredBox(color: _timerColor),
                      ),
                    ),
                  ),
                ),
              ),

              // شريط «العب» الأخضر تحت — بيتأخر ١١٠ملل عن الأحمر.
              _Delayed(
                delay: const Duration(milliseconds: 110),
                child: AnimatedPositioned(
                  duration: _doorMillis,
                  curve: _doorEasing,
                  bottom: 0,
                  left: playOffset,
                  width: width,
                  height: bandHeight,
                  child: _Band(
                    label: 'العب',
                    background: _playColor,
                    labelColor: _playInk,
                    fontSize: labelSize,
                    onClick: () => _choose(true),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// شريط ملوّن كامل العرض — مستطيل صافي بدون قصّات، زي التصميم.
class _Band extends StatelessWidget {
  final String label;
  final Color background;
  final Color labelColor;
  final double fontSize;
  final VoidCallback onClick;

  const _Band({
    required this.label,
    required this.background,
    required this.labelColor,
    required this.fontSize,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClick,
      child: Container(
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: FeudText.displayLarge(context).copyWith(
            color: labelColor,
            fontSize: fontSize,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// بيأخّر تمرير تحديثات [child] بـ[delay] — بديل `delayMillis` بالكوتلن:
/// الشريط التاني بيلحق الأول بفارق بسيط.
class _Delayed extends StatefulWidget {
  final Duration delay;
  final Widget child;

  const _Delayed({required this.delay, required this.child});

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  late Widget _shown = widget.child;
  Timer? _timer;

  @override
  void didUpdateWidget(_Delayed oldWidget) {
    super.didUpdateWidget(oldWidget);
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _shown = widget.child);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _shown;
}
