/// نقطة دخول ويب للموقع بس: الشاشات الحقيقية من التطبيق (لوح المضيف،
/// بداية الجولة، النتيجة بين الجولات — شاشات معرض الديمو ٧ و٩ و١١) بتشتغل
/// جوّا إطار موبايل على صفحة التعريف، بحركاتها الأصلية على ٦٠ فريم/ث.
///
/// `?screen=07|09|11` بتعرض شاشة وحدة بتعيد حركتها على طول؛ بدون
/// المعامل (أو `?screen=all`) بتلفّ على التلاتة. ما فيها شبكة ولا صوت ولا
/// أي `dart:io` — حتى تنبني للويب:
///   flutter build web -t lib/site_showcase.dart --base-href /app/ -o site/app
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'demo/demo_data.dart';
import 'game/models.dart';
import 'ui/host/host_board_screen.dart';
import 'ui/show/round_opening.dart';
import 'ui/show/scoreboard_screen.dart';
import 'ui/theme.dart';

void main() {
  final screen = Uri.base.queryParameters['screen'] ?? 'all';
  runApp(feudApp(Showcase(screen: screen)));
}

/// بيلفّ على الشاشات المطلوبة بانتقال المسارات نفسه (سحبة + تلاشي).
class Showcase extends StatefulWidget {
  final String screen;

  const Showcase({super.key, required this.screen});

  @override
  State<Showcase> createState() => _ShowcaseState();
}

class _ShowcaseState extends State<Showcase> {
  static const _all = ['07', '09', '11'];

  late final List<String> _ids = _all.contains(widget.screen) ? [widget.screen] : _all;
  int _cursor = 0;

  /// عدّاد بيزيد كل دورة حتى تعيد الشاشة حركتها من أولها (مفتاح جديد).
  int _run = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// كم بتاخد كل شاشة قبل ما تنعاد أو تنتقل للي بعدها.
  Duration _length(String id) => switch (id) {
        '07' => const Duration(milliseconds: 5200), // ٣ خانات بتنكشف + وقفة
        '09' => const Duration(milliseconds: 3600),
        _ => const Duration(milliseconds: 4400),
      };

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_length(_ids[_cursor]), () {
      if (!mounted) return;
      setState(() {
        _cursor = (_cursor + 1) % _ids.length;
        _run++;
      });
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _ids[_cursor];
    final Widget screen = switch (id) {
      '07' => _BoardReveal(key: ValueKey('07-$_run')),
      '09' => RoundIntroScreen(key: ValueKey('09-$_run'), round: 3, multiplier: 2),
      _ => ScoreboardScreen(
          key: ValueKey('11-$_run'),
          state: demoState(phase: RoundPhase.scoreboard, revealed: 6),
          onContinue: () {},
        ),
    };

    // نفس انتقال المسارات بالتطبيق: سحبة قصيرة + تلاشي.
    return Scaffold(
      backgroundColor: FeudColors.deepNavy,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 340),
        switchInCurve: Curves.fastOutSlowIn,
        switchOutCurve: Curves.fastOutSlowIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.25, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        child: KeyedSubtree(key: ValueKey('$id-$_run'), child: screen),
      ),
    );
  }
}

/// لوح المضيف بمرحلة اللعب وخاناته بتنكشف وحدة ورا التانية بحركتها
/// الحقيقية — نفس ما بيصير لما يحكم المضيف «صح».
class _BoardReveal extends StatefulWidget {
  const _BoardReveal({super.key});

  @override
  State<_BoardReveal> createState() => _BoardRevealState();
}

class _BoardRevealState extends State<_BoardReveal> {
  int _revealed = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (!mounted) return;
      if (_revealed < 4) setState(() => _revealed++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HostGameBoardScreen(
        state: demoState(revealed: _revealed),
        onCorrect: (_) {},
        onWrong: () {},
        onNextRound: () {},
      );
}
