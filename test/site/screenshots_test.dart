/// بيولّد لقطات حقيقية من شاشات التطبيق للموقع — نفس الويدجتات ونفس
/// الخطوط، بدون جهاز: شاشات معرض الديمو ٧ (لوح المضيف — لعب)، ٩ (بداية
/// الجولة) و١١ (النتيجة بين الجولات)، بالطولي والعرضي.
///
/// بتنكتب على `site/screens/*.png` لما تشغّل:
///   flutter test test/site --dart-define=WRITE_SCREENSHOTS=true
/// بدون التعريف الاختبار بس بيتأكد إنه الشاشات بتنرسم.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meen_al_atlasy/demo/demo_data.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/ui/host/host_board_screen.dart';
import 'package:meen_al_atlasy/ui/show/round_opening.dart';
import 'package:meen_al_atlasy/ui/show/scoreboard_screen.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

const bool _write = bool.fromEnvironment('WRITE_SCREENSHOTS');

Future<void> _loadFonts() async {
  const fonts = {
    'BalooBhaijaan2': [
      'baloo_bhaijaan2_medium.ttf',
      'baloo_bhaijaan2_bold.ttf',
      'baloo_bhaijaan2_extrabold.ttf',
    ],
    'Tajawal': ['tajawal_medium.ttf', 'tajawal_bold.ttf', 'tajawal_extrabold.ttf'],
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

/// بيرسم [screen] بحجم [logical] (موبايل ٣٦٠×٧٨٠ أو بالعكس) بدقة ×٣،
/// بيقدّم الحركات [settle]، وبيحفظ PNG باسم [name].
Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget screen, {
  Size logical = const Size(360, 780),
  Duration settle = const Duration(seconds: 3),
}) async {
  const scale = 3.0;
  tester.view.physicalSize = logical * scale;
  tester.view.devicePixelRatio = scale;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  // Material زي Scaffold المسار بالتطبيق — بدونه النص بياخد تسطير أصفر.
  await tester.pumpWidget(
    feudApp(RepaintBoundary(key: key, child: Material(type: MaterialType.transparency, child: screen))),
  );
  await tester.pump();
  await tester.pump(settle);
  expect(tester.takeException(), isNull, reason: name);

  if (!_write) return;
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: scale);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final file = File('site/screens/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
}

/// بيرسم [screen] وبيلقط سلسلة فريمات من حركته: [frames] لقطة كل
/// [step]، بعد تقديم [lead] — تنعرض بالموقع كأنيميشن حقيقي من التطبيق.
/// بدقة ×١٫٥ (الإطار بالموقع ≤ ٣٠٠px) حتى تضل الملفات صغيرة.
Future<void> _sequence(
  WidgetTester tester,
  String name,
  Widget screen, {
  required int frames,
  Duration step = const Duration(milliseconds: 125),
  Duration lead = Duration.zero,
  Size logical = const Size(360, 780),
}) async {
  const scale = 1.5;
  tester.view.physicalSize = logical * scale;
  tester.view.devicePixelRatio = scale;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    feudApp(RepaintBoundary(key: key, child: Material(type: MaterialType.transparency, child: screen))),
  );
  await tester.pump();
  if (lead > Duration.zero) await tester.pump(lead);

  for (var i = 0; i < frames; i++) {
    if (i > 0) await tester.pump(step);
    expect(tester.takeException(), isNull, reason: '$name frame $i');
    if (!_write) continue;
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: scale);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    final file = File('site/screens/anim/$name/${i.toString().padLeft(2, '0')}.png')
      ..createSync(recursive: true);
    file.writeAsBytesSync(bytes!);
  }
}

void main() {
  sequenceTests();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  // ٧ — لوح المضيف بمرحلة اللعب (نفس حالة معرض الديمو).
  Widget hostBoard() => HostGameBoardScreen(
        state: demoState(),
        onCorrect: (_) {},
        onWrong: () {},
        onNextRound: () {},
      );
  // ٩ — بداية الجولة.
  Widget roundIntro() => const RoundIntroScreen(round: 3, multiplier: 2);
  // ١١ — النتيجة بين الجولات (عند المضيف).
  Widget scoreboard() => ScoreboardScreen(
        state: demoState(phase: RoundPhase.scoreboard, revealed: 6),
        onContinue: () {},
      );

  testWidgets('7 host board', (tester) async {
    await _shoot(tester, '07-host-board-portrait', hostBoard(), settle: const Duration(seconds: 2));
    await _shoot(tester, '07-host-board-landscape', hostBoard(),
        logical: const Size(780, 360), settle: const Duration(seconds: 2));
  });

  testWidgets('9 round intro', (tester) async {
    await _shoot(tester, '09-round-intro-portrait', roundIntro());
    await _shoot(tester, '09-round-intro-landscape', roundIntro(), logical: const Size(780, 360));
  });

  testWidgets('11 scoreboard', (tester) async {
    await _shoot(tester, '11-scoreboard-portrait', scoreboard());
    await _shoot(tester, '11-scoreboard-landscape', scoreboard(), logical: const Size(780, 360));
  });
}

// ---- سلاسل الفريمات للموقع (الواجهات «حيّة»).
void sequenceTests() {
  testWidgets('anim 09 round intro', (tester) async {
    // الافتتاحية: القرص بينط، الاسم بيهبط، اللافتة بتكنس — ٢٫٢ ثانية بـ ٨ فريم/ث.
    await _sequence(tester, '09', const RoundIntroScreen(round: 3, multiplier: 2), frames: 18);
  });

  testWidgets('anim 11 scoreboard', (tester) async {
    // العدّ من ٠٫٥ لـ ١٫٤ ث، التاج ١٫٥، اللافتة ١٫٥٦–٢٫٢.
    await _sequence(
      tester,
      '11',
      ScoreboardScreen(
        state: demoState(phase: RoundPhase.scoreboard, revealed: 6),
        onContinue: () {},
      ),
      frames: 20,
    );
  });

  testWidgets('anim 07 board reveal', (tester) async {
    // خانة بتنكشف: الحالة نفسها بشجرة وحدة، فالخانة بتقلب بحركتها الحقيقية.
    const scale = 1.5;
    tester.view.physicalSize = const Size(360, 780) * scale;
    tester.view.devicePixelRatio = scale;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    Widget board(int revealed) => feudApp(
          RepaintBoundary(
            key: key,
            child: Material(
              type: MaterialType.transparency,
              child: HostGameBoardScreen(
                state: demoState(revealed: revealed),
                onCorrect: (_) {},
                onWrong: () {},
                onNextRound: () {},
              ),
            ),
          ),
        );

    Future<void> shoot(int i) async {
      expect(tester.takeException(), isNull, reason: '07 frame $i');
      if (!_write) return;
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: scale);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('site/screens/anim/07/${i.toString().padLeft(2, '0')}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!);
    }

    await tester.pumpWidget(board(1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await shoot(0);
    // الخانة التانية بتنكشف — ٠٫٩ ثانية بـ ١٢ فريم/ث.
    await tester.pumpWidget(board(2));
    for (var i = 1; i <= 11; i++) {
      await tester.pump(const Duration(milliseconds: 83));
      await shoot(i);
    }
    await tester.pump(const Duration(seconds: 1));
    await shoot(12);
  });
}
