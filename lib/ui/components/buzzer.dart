/// زر الجواب — دائرة كرتونية بحد أسود سميك وظل صلب تحتها. بتطفو (bob) لما
/// تكون مفتوحة، وبتنزل على ظلها لحظة الضغط، وبيهتزّ الجهاز.
///
/// منفّذ عن `components/Buzzer.kt` بالمشروع الأصلي (Kotlin) — الاسم هون
/// `BuzzerButton` نفسه، والملف `buzzer.dart` زي ما طلبته المهمة.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class BuzzerButton extends StatefulWidget {
  final String label;
  final String? subLabel;
  final bool enabled;
  final Color accent;
  final VoidCallback onClick;
  final double size;

  const BuzzerButton({
    super.key,
    required this.label,
    this.subLabel,
    required this.enabled,
    required this.accent,
    required this.onClick,
    this.size = 230,
  });

  @override
  State<BuzzerButton> createState() => _BuzzerButtonState();
}

class _BuzzerButtonState extends State<BuzzerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.enabled) _bob.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant BuzzerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _bob.repeat(reverse: true);
      } else {
        _bob.animateTo(0, duration: const Duration(milliseconds: 1800));
      }
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    if (value && widget.enabled) {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    const shadowDepth = 12.0;
    final isLight = _isLight(widget.accent);

    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        final lift = _bob.value * 6;
        final drop = _pressed && widget.enabled ? shadowDepth : 0.0;

        return SizedBox(
          width: widget.size + shadowDepth,
          height: widget.size + shadowDepth,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // الظل الصلب تحت الزر.
              Transform.translate(
                offset: Offset(0, shadowDepth - lift),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: const BoxDecoration(
                    color: FeudColors.ink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, -lift + drop),
                child: Transform.scale(
                  scale: _pressed && widget.enabled ? 0.97 : 1,
                  child: GestureDetector(
                    onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
                    onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
                    onTapCancel: widget.enabled ? () => _setPressed(false) : null,
                    onTap: widget.enabled ? widget.onClick : null,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: FeudColors.ink, width: 7),
                        gradient: RadialGradient(
                          center: const Alignment(-0.36, -0.56),
                          colors: [_lighten(widget.accent), widget.accent],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: FeudText.displaySmall(context).copyWith(
                                color: isLight ? FeudColors.ink : Colors.white,
                              ),
                            ),
                            if (widget.subLabel != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.subLabel!,
                                textAlign: TextAlign.center,
                                style: FeudText.labelMedium(context).copyWith(
                                  color: isLight
                                      ? FeudColors.ink.withValues(alpha: 0.7)
                                      : Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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

Color _lighten(Color color, [double amount = 0.25]) {
  final r = (color.r + (1 - color.r) * amount).clamp(0.0, 1.0);
  final g = (color.g + (1 - color.g) * amount).clamp(0.0, 1.0);
  final b = (color.b + (1 - color.b) * amount).clamp(0.0, 1.0);
  return Color.from(alpha: color.a, red: r, green: g, blue: b);
}

bool _isLight(Color color) =>
    (color.r * 0.299 + color.g * 0.587 + color.b * 0.114) > 0.6;
