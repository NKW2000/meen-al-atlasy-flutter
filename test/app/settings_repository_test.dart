/// اختبارات [SettingsRepository] — نفس مفاتيح ومنطق `SettingsRepository.kt`
/// بالمشروع الأصلي، بس فوق `SharedPreferences` (حكم المتحكمات ٤) وبنك
/// أسئلة عبر [BankStore] (Task 5) بدل ملفات أندرويد مباشرة.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/app/settings_repository.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/game/settings.dart';
import 'package:meen_al_atlasy/questions/bank.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _bankJson(List<(String, List<(String, int)>)> questions) => jsonEncode([
      for (final (text, answers) in questions)
        {
          'text': text,
          'answers': [
            for (final (aText, points) in answers) {'text': aText, 'points': points},
          ],
        },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('settings_repo_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<SettingsRepository> repo() async =>
      SettingsRepository(await SharedPreferences.getInstance(), tempDir);

  test('load returns defaults when nothing was saved before', () async {
    final settings = await (await repo()).load();
    expect(settings.rounds, equals(GameSettings.defaultRounds));
    expect(settings.multipliers, equals(GameSettings.defaultMultipliers));
    expect(settings.strikesToSteal, equals(GameSettings.defaultStrikes));
    expect(settings.answerSeconds, equals(GameSettings.defaultAnswerSeconds));
    expect(settings.choiceSeconds, equals(GameSettings.defaultChoiceSeconds));
    expect(settings.roomName, equals(GameSettings.defaultRoomName));
    expect(settings.bankName, isNull);
    expect(settings.bankQuestionCount, equals(0));
  });

  test('save then load round-trips every field', () async {
    final r = await repo();
    final settings = const GameSettings(
      rounds: 6,
      multipliers: [1, 2, 3],
      strikesToSteal: 2,
      answerSeconds: 15,
      choiceSeconds: 8,
      roomName: 'غرفتي',
      minAnswers: 3,
      maxAnswers: 6,
      teamNames: {TeamId.team1: 'أ', TeamId.team2: 'ب'},
    );

    await r.save(settings);
    final loaded = await r.load();

    expect(loaded.rounds, equals(6));
    expect(loaded.multipliers, equals([1, 2, 3]));
    expect(loaded.strikesToSteal, equals(2));
    expect(loaded.answerSeconds, equals(15));
    expect(loaded.choiceSeconds, equals(8));
    expect(loaded.roomName, equals('غرفتي'));
    expect(loaded.minAnswers, equals(3));
    expect(loaded.maxAnswers, equals(6));
    expect(loaded.teamName(TeamId.team1), equals('أ'));
    expect(loaded.teamName(TeamId.team2), equals('ب'));
  });

  test('save clamps out-of-range values before persisting', () async {
    final r = await repo();
    await r.save(const GameSettings(rounds: 99, strikesToSteal: 0));
    final loaded = await r.load();
    expect(loaded.rounds, equals(GameSettings.maxRounds));
    expect(loaded.strikesToSteal, equals(GameSettings.minStrikes));
  });

  test('questions() falls back to the bundled bank until a bank is imported',
      () async {
    final r = await repo();
    final bundled = await r.questions();
    expect(bundled, isNotEmpty);

    final result = await r.importBank(
      _bankJson([
        ('سؤال مستورد', [('أ', 10), ('ب', 20)]),
      ]),
      'بنكي',
    );
    expect(result, isA<BankSuccess>());

    final imported = await r.questions();
    expect(imported, hasLength(1));
    expect(imported.single.text, equals('سؤال مستورد'));
  });

  test('load reflects the imported bank name and count', () async {
    final r = await repo();
    await r.importBank(
      _bankJson([
        ('س١', [('أ', 10), ('ب', 20)]),
        ('س٢', [('ج', 5), ('د', 5)]),
      ]),
      'بنك خاص',
    );

    final settings = await r.load();
    expect(settings.bankName, equals('بنك خاص'));
    expect(settings.bankQuestionCount, equals(2));
  });

  test('answerBounds reflects the actual answer counts in the current bank',
      () async {
    final r = await repo();
    await r.importBank(
      _bankJson([
        ('س١', [('أ', 10), ('ب', 20)]), // جوابين
        ('س٢', [('ج', 5), ('د', 5), ('ه', 5), ('و', 5)]), // أربعة أجوبة
      ]),
      'بنك',
    );

    final (low, high) = await r.answerBounds();
    expect(low, equals(2));
    expect(high, equals(4));
  });

  test('filteredQuestions keeps only questions within the min/max answers',
      () async {
    final r = await repo();
    await r.importBank(
      _bankJson([
        ('قليل', [('أ', 10), ('ب', 20)]), // جوابين
        ('كتير', [('ج', 5), ('د', 5), ('ه', 5), ('و', 5)]), // أربعة أجوبة
      ]),
      'بنك',
    );
    await r.save((await r.load()).copyWith(minAnswers: 3, maxAnswers: 4));

    final filtered = await r.filteredQuestions();
    expect(filtered, hasLength(1));
    expect(filtered.single.text, equals('كتير'));

    expect(await r.matchingCount(await r.load()), equals(1));
  });

  test('markQuestionRead tracks read ids and clearBank forgets them',
      () async {
    final r = await repo();
    // بنكين سؤالين حتى ما تكتمل دورة القراءة بأول تسجيل (وترجع فاضية).
    await r.importBank(
      _bankJson([
        ('س١', [('أ', 10), ('ب', 20)]),
        ('س٢', [('ج', 5), ('د', 5)]),
      ]),
      'بنك',
    );
    expect(await r.readQuestionIds(), isEmpty);

    await r.markQuestionRead('q1');
    expect(await r.readQuestionIds(), equals({'q1'}));

    await r.clearBank();
    expect(await r.readQuestionIds(), isEmpty);
    expect((await r.load()).bankName, isNull);
  });

  test('newGameState draws rounds worth of questions from the filtered bank',
      () async {
    final r = await repo();
    await r.importBank(
      _bankJson([
        for (var i = 1; i <= 4; i++) ('سؤال $i', [('أ', 10), ('ب', 20)]),
      ]),
      'بنك',
    );
    await r.save((await r.load()).copyWith(rounds: 3));

    final state = await r.newGameState();
    expect(state.questions, hasLength(3));
    expect(state.teams[TeamId.team1], isNotNull);
    expect(state.teams[TeamId.team2], isNotNull);
    expect(state.multipliers, hasLength(3));
  });

  group('sync snapshot (review controller ruling, option B)', () {
    test('warmUp before any write yields the defaults', () async {
      final r = await repo();
      await r.warmUp();

      expect(r.current.rounds, equals(GameSettings.defaultRounds));
      expect(r.roomName, equals(GameSettings.defaultRoomName));
      expect(r.newGameStateSync().questions, isNotEmpty);
    });

    test('newGameStateSync reflects the latest save without an intervening '
        'load()', () async {
      final r = await repo();
      await r.warmUp();

      await r.save((await r.load()).copyWith(rounds: 3));

      // ملاحظة: ما منستدعي load() هون — save() بحدّث اللقطة بنفسه.
      expect(r.current.rounds, equals(3));
      expect(r.newGameStateSync().questions, hasLength(3));
    });

    test('newGameStateSync draws from an imported bank after it is saved',
        () async {
      final r = await repo();
      await r.warmUp();
      await r.importBank(
        _bankJson([
          for (var i = 1; i <= 4; i++) ('سؤال $i', [('أ', 10), ('ب', 20)]),
        ]),
        'بنك',
      );
      await r.save((await r.load()).copyWith(rounds: 2));

      final state = r.newGameStateSync();
      expect(state.questions, hasLength(2));
      expect(state.questions.every((q) => q.text.startsWith('سؤال')), isTrue);
    });

    test('freshQuestionSync returns one unread question from the filtered '
        'bank, and reflects markQuestionRead once refreshed', () async {
      final r = await repo();
      await r.importBank(
        _bankJson([
          ('س١', [('أ', 10), ('ب', 20)]),
          ('س٢', [('ج', 5), ('د', 5)]),
        ]),
        'بنك',
      );
      await r.warmUp();

      final first = r.freshQuestionSync();
      expect(first, isNotNull);
      expect(['س١', 'س٢'], contains(first!.text));

      await r.markQuestionRead(first.id);
      // بعد ما انقرأ، السؤال التاني بس هو "البديل ما انقرأ" — منكرر
      // النداء كذا مرة حتى نتأكد إنه ما بيرجّع نفس السؤال المقروء.
      for (var i = 0; i < 5; i++) {
        expect(r.freshQuestionSync()!.id, isNot(equals(first.id)));
      }
    });
  });
}
