/// اختبارات الشاشات الأربع تبع Task 8 (المقدمة، الرئيسية، إعدادات
/// البنك، إعدادات المضيف) — نصوص عربية أساسية موجودة، والمقدمة بتنادي
/// `onDone`، وتغيير الجولات بإعدادات المضيف بيتحفظ فعلياً.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meen_al_atlasy/app/settings_repository.dart';
import 'package:meen_al_atlasy/ui/arabic_numerals.dart';
import 'package:meen_al_atlasy/ui/home/home_screen.dart';
import 'package:meen_al_atlasy/ui/host/host_settings_screen.dart';
import 'package:meen_al_atlasy/ui/intro/intro_screen.dart';
import 'package:meen_al_atlasy/ui/settings/bank_settings_screen.dart';
import 'package:meen_al_atlasy/ui/theme.dart';

/// [SettingsRepository] بيعمل عمليات ملفات حقيقية (`dart:io`) — لازم
/// تنعمل جوّا [WidgetTester.runAsync] لأنه `testWidgets` بيشغّل جسم
/// الاختبار بمنطقة زمن وهمي (fake async)، وعمليات dart:io الحقيقية ما
/// بتخلص من غيرها (وبتوقف الاختبار للأبد لحد ما يطلع تايم آوت).
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IntroScreen', () {
    testWidgets('calls onDone once the landscape choreography finishes', (tester) async {
      var doneCalls = 0;
      await tester.pumpWidget(feudApp(IntroScreen(onDone: () => doneCalls++)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));

      expect(doneCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('tapping the screen skips straight to onDone', (tester) async {
      var doneCalls = 0;
      await tester.pumpWidget(feudApp(IntroScreen(onDone: () => doneCalls++)));
      await tester.pump();
      await tester.tap(find.byType(IntroScreen));
      await tester.pump();

      expect(doneCalls, 1);
    });
  });

  group('HomeScreen', () {
    testWidgets('shows the host and join actions', (tester) async {
      await tester.pumpWidget(feudApp(HomeScreen(onHostClick: () {}, onJoinClick: () {})));
      await tester.pump();

      expect(find.text('استضافة لعبة'), findsOneWidget);
      expect(find.text('انضمام كلاعب'), findsOneWidget);
    });

    testWidgets('onHostClick and onJoinClick fire on tap', (tester) async {
      var hosted = false;
      var joined = false;
      await tester.pumpWidget(feudApp(HomeScreen(
        onHostClick: () => hosted = true,
        onJoinClick: () => joined = true,
      )));
      await tester.pump();

      await tester.tap(find.text('استضافة لعبة'));
      await tester.tap(find.text('انضمام كلاعب'));
      await tester.pump();

      expect(hosted, isTrue);
      expect(joined, isTrue);
    });
  });

  group('BankSettingsScreen', () {
    testWidgets('shows the bundled bank message and the import button', (tester) async {
      final repo = await _repo(tester, 'bank_settings_test');
      await tester.pumpWidget(feudApp(BankSettingsScreen(settings: repo, onBack: () {})));
      await tester.pump();

      expect(find.text('الحالي: البنك المرفق مع التطبيق'), findsOneWidget);
      expect(find.text('استيراد ملف'), findsOneWidget);
    });

    testWidgets('onBack fires on tap', (tester) async {
      final repo = await _repo(tester, 'bank_settings_test2');
      var back = false;
      await tester.pumpWidget(feudApp(BankSettingsScreen(settings: repo, onBack: () => back = true)));
      await tester.pump();

      await tester.tap(find.text('رجوع'));
      await tester.pump();

      expect(back, isTrue);
    });
  });

  group('HostSettingsScreen', () {
    /// شاهد صغير على شكل `main.dart._HostSettingsRoute`: بيحفظ كل تغيير
    /// عالمستودع فوراً وبيعيد بناء نفسه باللقطة الجديدة. الحفظ (`dart:io`
    /// حقيقي) لازم يصير جوّا [WidgetTester.runAsync] — نفس سبب [_repo].
    ///
    /// `onTap` بالفلاتر مش دالة منستناها (`VoidCallback`)، فـ`tap()` بيرجع
    /// قبل ما يخلص الحفظ الحقيقي. [onSaveStarted] بيسلّم الاختبار الـ
    /// Future تبع الحفظ الجاري حتى يقدر يستناه فعلياً قبل ما يفحص النتيجة،
    /// بدل ما يتكل على `pumpAndSettle` توقيتياً.
    Widget harness(
      WidgetTester tester,
      SettingsRepository repo, {
      void Function(Future<void> pending)? onSaveStarted,
    }) {
      return StatefulBuilder(builder: (context, setState) {
        return HostSettingsScreen(
          settings: repo.current,
          onSettingsChange: (next) {
            final pending = tester.runAsync(() => repo.save(next)).then((_) {
              if (context.mounted) setState(() {});
            });
            onSaveStarted?.call(pending);
          },
          onBack: () {},
          onContinue: () {},
        );
      });
    }

    testWidgets('shows the continue-to-lobby button', (tester) async {
      final repo = await _repo(tester, 'host_settings_test');
      await tester.pumpWidget(feudApp(harness(tester, repo)));
      await tester.pump();

      expect(find.text('كمّل للوبي'), findsOneWidget);
    });

    testWidgets('tapping the rounds "+" increments the shown numeral and persists it', (tester) async {
      final repo = await _repo(tester, 'host_settings_test2');
      Future<void>? pendingSave;
      await tester.pumpWidget(feudApp(
        harness(tester, repo, onSaveStarted: (pending) => pendingSave = pending),
      ));
      await tester.pump();

      // منحصر البحث بصف «عدد الجولات» نفسه — القيمة ممكن تتطابق صدفة مع
      // صف تاني (متل «أقل عدد أجوبة» الافتراضي ٥) بعد ما تزيد.
      final roundsRow = find.ancestor(of: find.text('عدد الجولات'), matching: find.byType(Row)).first;
      final startRounds = repo.current.rounds;
      expect(find.descendant(of: roundsRow, matching: find.text(startRounds.ar())), findsOneWidget);

      await tester.tap(find.descendant(of: roundsRow, matching: find.text('+')));
      await pendingSave; // منستنى الحفظ الحقيقي يخلص فعلياً قبل ما نفحص.
      await tester.pump();

      expect(
        find.descendant(of: roundsRow, matching: find.text((startRounds + 1).ar())),
        findsOneWidget,
      );
      expect(repo.current.rounds, startRounds + 1);
    });
  });
}
