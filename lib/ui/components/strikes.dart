/// الخطوط الثلاثة، علامة X مفردة، وX الكبير اللي بينزل لحظة الخطأ.
///
/// منفّذ عن `components/Strikes.kt` بالمشروع الأصلي (Kotlin).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/models.dart';
import '../theme.dart';

extension TeamColorX on TeamId {
  Color color() =>
      this == TeamId.team1 ? FeudColors.team1 : FeudColors.team2;

  Color inkColor() =>
      this == TeamId.team1 ? FeudColors.team1Ink : FeudColors.team2Ink;
}

/// الخطوط الثلاثة — مربعات مدوّرة، الممتلئة وردية بظل صلب.
class StrikeRow extends StatelessWidget {
  final int strikes;
  final double size;
  final int total;

  const StrikeRow({
    super.key,
    required this.strikes,
    this.size = 38,
    this.total = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < total; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          _StrikeBox(filled: index < strikes, size: size),
        ],
      ],
    );
  }
}

class _StrikeBox extends StatelessWidget {
  final bool filled;
  final double size;

  const _StrikeBox({required this.filled, required this.size});

  @override
  Widget build(BuildContext context) {
    // الضربة بتنزل بحركة slam: بتكبر وبترتد لمكانها.
    return AnimatedScale(
      scale: filled ? 1 : 0.94,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? FeudColors.pink : FeudColors.ink.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: FeudColors.ink, width: 4),
        ),
        child: Text(
          '✕',
          style: FeudText.titleMedium(context).copyWith(
            color: filled ? Colors.white : const Color(0xFF5C4A8C),
          ),
        ),
      ),
    );
  }
}

/// علامة X مفردة — بتستعمل بشاشات تانية.
class StrikeMark extends StatelessWidget {
  final Color color;
  final double size;

  const StrikeMark({super.key, required this.color, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: FeudColors.ink, width: 4),
      ),
      child: Text(
        '✕',
        style: FeudText.titleMedium(context).copyWith(color: Colors.white),
      ),
    );
  }
}

/// X كبير بينزل على كل الشاشة لحظة الخطأ — أوضح إشي بغرفة مليانة ناس.
class StrikeFlash extends StatefulWidget {
  final int strikes;

  const StrikeFlash({super.key, required this.strikes});

  @override
  State<StrikeFlash> createState() => _StrikeFlashState();
}

class _StrikeFlashState extends State<StrikeFlash>
    with SingleTickerProviderStateMixin {
  late int _lastSeen = widget.strikes;
  bool _visible = false;
  Timer? _hideTimer;
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale =
      Tween<double>(begin: 2.4, end: 1).animate(_enter);

  @override
  void didUpdateWidget(covariant StrikeFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.strikes > _lastSeen) {
      _show();
    }
    _lastSeen = widget.strikes;
  }

  void _show() {
    _hideTimer?.cancel();
    setState(() => _visible = true);
    _enter.forward(from: 0);
    _hideTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: Duration(milliseconds: _visible ? 120 : 200),
        child: AnimatedBuilder(
          animation: _enter,
          builder: (context, child) => Transform.scale(
            scale: _visible ? _scale.value : 1,
            child: child,
          ),
          child: Center(
            child: Text(
              '✕',
              style: FeudText.displayLarge(context)
                  .copyWith(color: FeudColors.pink, fontSize: 220),
            ),
          ),
        ),
      ),
    );
  }
}
