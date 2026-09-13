/// معرض الديمو: كل شاشة بتنبني بالوضعين بدون استثناءات، والتنقّل بيلف.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meen_al_atlasy/app/settings_repository.dart';
import 'package:meen_al_atlasy/demo/demo_gallery.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

Future<SettingsRepository> _repo(WidgetTester tester, String name) async {
  SharedPreferences.setMockInitialValues({});
  final dir = Directory.systemTemp.createTempSync(name);
  addTearDown(() => dir.deleteSync(recursive: true));
  return (await tester.runAsync(() async {
    final repo = SettingsRepository(await SharedPreferences.getInstance(), dir);
    await repo.warmUp();
    return repo;
  }))!;
}

Future<void> _walk(WidgetTester tester, SettingsRepository repo, Size physical) async {
  tester.view.physicalSize = physical;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(feudApp(DemoGallery(settingsRepository: repo)));
  await tester.pump();
  expect(find.textContaining('1/'), findsOneWidget);

  final total = int.parse(
    RegExp(r'1/(\d+)').firstMatch(tester.widget<Text>(find.textContaining('1/')).data!)!.group(1)!,
  );
  expect(total, greaterThanOrEqualTo(19));

  for (var i = 1; i <= total; i++) {
    // كل شاشة بتاخد كم فريم حتى تبلّش حركاتها.
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull, reason: 'screen $i');
    expect(find.textContaining('$i/$total'), findsOneWidget);
    await tester.tap(find.text('›'));
    await tester.pump();
  }
  // لفّينا كل الشاشات ورجعنا لأولها.
  expect(find.textContaining('1/$total'), findsOneWidget);
}

/// اختبارات فلاتر بترسم النص بخط Ahem (كل حرف مربّع بعرض em كامل)، فأي
/// عنوان عربي بيطلع ضعف عرضه الحقيقي وبيعمل overflow وهمي. منحمّل خطوط
/// اللعبة نفسها حتى يقيس المعرض اللي بيشوفه الجهاز فعلاً.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('every demo screen renders in landscape', (tester) async {
    final repo = await _repo(tester, 'demo_gallery_land');
    await _walk(tester, repo, const Size(1600, 800));
  });

  testWidgets('every demo screen renders in portrait', (tester) async {
    final repo = await _repo(tester, 'demo_gallery_port');
    await _walk(tester, repo, const Size(800, 1600));
  });
}
