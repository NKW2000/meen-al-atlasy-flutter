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

void main() {
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

