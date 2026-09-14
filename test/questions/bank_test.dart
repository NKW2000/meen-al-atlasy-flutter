import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/questions/bank.dart';
import 'package:meen_al_atlasy/questions/bank_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ported from data-questions/src/test/kotlin/.../QuestionBankTest.kt
  group('QuestionBank.load (bundled bank)', () {
    test(
      'load parses starter questions with answers sorted by points descending',
      () async {
        final questions = await QuestionBank.load();
        expect(questions, isNotEmpty);
        final first = questions.first;
        expect(first.id, 'q001');
        final points = first.answers.map((a) => a.points).toList();
        final sortedDescending = [...points]..sort((a, b) => b.compareTo(a));
        expect(points, sortedDescending);
      },
    );

    test('every question is well formed', () async {
      final questions = await QuestionBank.load();
      expect(
        questions.length,
        greaterThanOrEqualTo(500),
        reason: 'لازم يكون في ٥٠٠ سؤال عالأقل',
      );
      expect(
        questions.map((q) => q.id).toSet().length,
        questions.length,
        reason: 'في معرّفات مكررة',
      );
      expect(
        questions.map((q) => q.text).toSet().length,
        questions.length,
        reason: 'في أسئلة مكررة النص',
      );
      for (final question in questions) {
        expect(
          question.text.trim().isNotEmpty,
          isTrue,
          reason: 'سؤال بدون نص: ${question.id}',
        );
        expect(
          question.category.trim().isNotEmpty,
          isTrue,
          reason: 'سؤال بدون تصنيف: ${question.id}',
        );
        expect(
          question.answers.length >= 4 && question.answers.length <= 8,
          isTrue,
          reason: 'سؤال مش بين ٤ و٨ أجوبة: ${question.id}',
        );
        expect(
          question.answers.map((a) => a.text).toSet().length,
          question.answers.length,
          reason: 'أجوبة مكررة بالسؤال: ${question.id}',
        );
        expect(question.isRead, isFalse, reason: 'سؤال مرفق مقروء مسبقاً: ${question.id}');
        expect(
          question.answers.every((a) => a.text.trim().isNotEmpty && a.points > 0),
          isTrue,
          reason: 'أجوبة بدون نص أو بنقاط غير موجبة: ${question.id}',
        );
        expect(
          question.answers.any((a) => a.revealed),
          isFalse,
          reason: 'ما في جواب مكشوف مسبقاً: ${question.id}',
        );
      }
    });
  });

  group('QuestionBank.randomRound', () {
    test('randomRound returns the requested number of distinct questions', () async {
      final source = await QuestionBank.load();
      final round = QuestionBank.randomRound(8, source, random: Random(42));
      expect(round.length, 8);
      expect(round.map((q) => q.id).toSet().length, 8);
    });

    test('randomRound is deterministic for a given seed', () async {
      final source = await QuestionBank.load();
      final a = QuestionBank.randomRound(5, source, random: Random(7))
          .map((q) => q.id)
          .toList();
      final b = QuestionBank.randomRound(5, source, random: Random(7))
          .map((q) => q.id)
          .toList();
      expect(a, b);
    });

    test('randomRound never asks for more questions than the bank holds', () async {
      final all = await QuestionBank.load();
      expect(QuestionBank.randomRound(all.length + 100, all).length, all.length);
    });
  });

  group('QuestionBank.randomGame', () {
    test('randomGame draws a question per round without repeating one', () async {
      final source = await QuestionBank.load();
      final rounds = QuestionBank.randomGame(6, source, random: Random(11));
      expect(rounds.length, 6);
      expect(rounds.map((q) => q.id).toSet().length, 6);
    });

    test('randomGame is deterministic for a given seed', () async {
      final source = await QuestionBank.load();
      final first = QuestionBank.randomGame(4, source, random: Random(3))
          .map((q) => q.id)
          .toList();
      final second = QuestionBank.randomGame(4, source, random: Random(3))
          .map((q) => q.id)
          .toList();
      expect(first, second);
    });
  });

  // Ported from data-questions/src/test/kotlin/.../BankImportTest.kt
  group('QuestionBank.parse (bank import)', () {
    BankFailure failureOf(String json) {
      final result = QuestionBank.parse(json);
      expect(result, isA<BankFailure>(), reason: 'توقعنا رفض الملف');
      return result as BankFailure;
    }

    test('a valid bank is parsed and its answers sorted by points', () {
      final result = QuestionBank.parse('''
      [
        {
          "text": "سؤال",
          "category": "أكل",
          "answers": [
            {"text": "ب", "points": 20},
            {"text": "أ", "points": 55},
            {"text": "ج", "points": 10}
          ]
        }
      ]
      ''');

      expect(result, isA<BankSuccess>());
      final question = (result as BankSuccess).questions.single;
      expect(question.category, 'أكل');
      expect(question.answers.map((a) => a.text).toList(), ['أ', 'ب', 'ج']);
      expect(question.answers.map((a) => a.points).toList(), [55, 20, 10]);
    });

    test('tied points keep their original order (stable sort)', () {
      final result = QuestionBank.parse('''
      [
        {
          "text": "سؤال",
          "answers": [
            {"text": "أول ٣٠", "points": 30},
            {"text": "٢٠", "points": 20},
            {"text": "تاني ٣٠", "points": 30}
          ]
        }
      ]
      ''');

      final question = (result as BankSuccess).questions.single;
      // نفس القيمة (٣٠) لجوابين — لازم يضلوا بترتيبهم الأصلي بالملف.
      expect(
        question.answers.map((a) => a.text).toList(),
        ['أول ٣٠', 'تاني ٣٠', '٢٠'],
      );
    });

    test('id and category are optional', () {
      final result = QuestionBank.parse(
        '[{"text": "سؤال", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}]',
      );

      final question = (result as BankSuccess).questions.single;
      expect(question.id, 'q1');
      expect(question.category, 'عام');
    });

    test('isreaded (bundled bank spelling) and isRead both mark a question read', () {
      const answers = '[{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]';
      final result = QuestionBank.parse(
        '[{"text": "١", "isreaded": true, "answers": $answers},'
        ' {"text": "٢", "isRead": true, "answers": $answers},'
        ' {"text": "٣", "isreaded": false, "answers": $answers}]',
      );

      final read = (result as BankSuccess).questions.map((q) => q.isRead).toList();
      expect(read, [true, true, false]);
      expect(failureOf('[{"text": "١", "isreaded": "yes", "answers": $answers}]').message, contains('isreaded'));
    });

    test('broken json is refused with a readable reason', () {
      expect(failureOf('{ليس JSON').message, contains('JSON'));
    });

    test('an empty bank is refused', () {
      expect(failureOf('[]').message, contains('فاضي'));
    });

    test('a question with a single answer is refused', () {
      final message = failureOf(
        '[{"text": "سؤال", "answers": [{"text": "أ", "points": 10}]}]',
      ).message;
      expect(message.contains('١') || message.contains('1'), isTrue);
    });

    test('a question without text is refused', () {
      final message = failureOf(
        '[{"text": "  ", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}]',
      ).message;
      expect(message, contains('بدون نص'));
    });

    test('an answer worth nothing is refused', () {
      final message = failureOf(
        '[{"text": "سؤال", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 0}]}]',
      ).message;
      expect(message, contains('صفر'));
    });

    test('too many answers are refused', () {
      final answers = List.generate(
        QuestionBank.maxAnswers + 1,
        (i) => '{"text": "جواب ${i + 1}", "points": ${i + 1}}',
      ).join(',');
      final message =
          failureOf('[{"text": "سؤال", "answers": [$answers]}]').message;
      expect(message, contains('أكتر'));
    });

    test('a game draws its rounds from the imported bank without repeats', () {
      final questions = List.generate(12, (i) {
        final index = i + 1;
        final result = QuestionBank.parse(
          '[{"text": "سؤال $index", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}]',
        ) as BankSuccess;
        return result.questions.single.copyWith(id: 'q$index');
      });

      final rounds = QuestionBank.randomGame(4, questions);

      expect(rounds.length, 4);
      final ids = rounds.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('BankStore', () {
    late Directory dir;
    late BankStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('bank_store_test');
      store = BankStore(dir);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('questions() falls back to the bundled bank when nothing is imported', () async {
      final bundled = await QuestionBank.load();
      final questions = await store.questions();
      expect(questions.map((q) => q.id).toList(), bundled.map((q) => q.id).toList());
    });

    test('questions() returns the imported bank once one is valid', () async {
      const validJson =
          '[{"text": "سؤال", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}]';
      final result = await store.importBank(validJson, 'بنكي');
      expect(result, isA<BankSuccess>());

      final questions = await store.questions();
      expect(questions.length, 1);
      expect(questions.single.text, 'سؤال');
    });

    test('questions() falls back to the bundled bank when the imported file is invalid', () async {
      // اكتب ملف بنك فاسد مباشرة (بدون استيراد) لمحاكاة ملف تعطّل بعد الحفظ.
      final bankFile = File('${dir.path}/host_bank.json');
      await bankFile.writeAsString('[]');

      final bundled = await QuestionBank.load();
      final questions = await store.questions();
      expect(questions.map((q) => q.id).toList(), bundled.map((q) => q.id).toList());
    });

    test('importBank rejects an invalid file and leaves no trace', () async {
      final result = await store.importBank('[]', 'بنك فاضي');
      expect(result, isA<BankFailure>());
      expect(await store.bankName(), isNull);
      expect(await store.bankQuestionCount(), 0);
    });

    test('importBank remembers the display name and question count', () async {
      const validJson = '''
      [
        {"text": "سؤال ١", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]},
        {"text": "سؤال ٢", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}
      ]
      ''';
      await store.importBank(validJson, 'بنك الأصدقاء');

      expect(await store.bankName(), 'بنك الأصدقاء');
      expect(await store.bankQuestionCount(), 2);
    });

    test(
      'a failed import leaves the previously imported bank in place',
      () async {
        const firstJson =
            '[{"text": "سؤال ١", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}, '
            '{"text": "سؤال ٢", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}]';
        final firstResult = await store.importBank(firstJson, 'A');
        expect(firstResult, isA<BankSuccess>());

        final secondResult = await store.importBank('[]', 'B');
        expect(secondResult, isA<BankFailure>());

        expect(await store.bankName(), 'A');
        expect(await store.bankQuestionCount(), 2);
        final questions = await store.questions();
        expect(questions.length, 2);
        expect(questions.map((q) => q.text).toList(), ['سؤال ١', 'سؤال ٢']);
      },
    );

    test('readQuestionIds starts out empty', () async {
      expect(await store.readQuestionIds(), isEmpty);
    });

    test('readQuestionIds tolerates a corrupt read_ids.json', () async {
      final readIdsFile = File('${dir.path}/read_ids.json');
      await readIdsFile.writeAsString('{not valid json');

      expect(await store.readQuestionIds(), isEmpty);

      // markQuestionRead should still work despite the corrupt file.
      final bank = [
        const Question(id: 'q1', text: 'س1', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
        const Question(id: 'q2', text: 'س2', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
      ];
      await store.markQuestionRead('q1', bank: bank);
      expect(await store.readQuestionIds(), {'q1'});
    });

    test('bankName/bankQuestionCount tolerate a corrupt bank_meta.json', () async {
      const validJson =
          '[{"text": "سؤال", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}]';
      await store.importBank(validJson, 'بنكي');

      final metaFile = File('${dir.path}/bank_meta.json');
      await metaFile.writeAsString('{not valid json');

      expect(await store.bankName(), isNull);
      expect(await store.bankQuestionCount(), 0);
    });

    test('markQuestionRead adds the id to the read set', () async {
      final bank = [
        const Question(id: 'q1', text: 'س1', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
        const Question(id: 'q2', text: 'س2', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
      ];

      await store.markQuestionRead('q1', bank: bank);
      expect(await store.readQuestionIds(), {'q1'});
    });

    test('markQuestionRead resets to empty once every question in the bank is read', () async {
      final bank = [
        const Question(id: 'q1', text: 'س1', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
        const Question(
          id: 'q2',
          text: 'س2',
          category: 'عام',
          isRead: true,
          answers: [Answer(text: 'أ', points: 10), Answer(text: 'ب', points: 5)],
        ),
      ];

      // q2 already isRead=true; marking q1 read completes the set.
      await store.markQuestionRead('q1', bank: bank);
      expect(await store.readQuestionIds(), isEmpty);
    });

    test('clearReadQuestions empties the read set', () async {
      final bank = [
        const Question(id: 'q1', text: 'س1', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
        const Question(id: 'q2', text: 'س2', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
      ];
      await store.markQuestionRead('q1', bank: bank);
      await store.clearReadQuestions();
      expect(await store.readQuestionIds(), isEmpty);
    });

    test('importing a new bank clears the read ids', () async {
      final bank = [
        const Question(id: 'q1', text: 'س1', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
        const Question(id: 'q2', text: 'س2', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
      ];
      await store.markQuestionRead('q1', bank: bank);
      expect(await store.readQuestionIds(), isNotEmpty);

      const validJson =
          '[{"text": "سؤال جديد", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}]';
      await store.importBank(validJson, 'بنك جديد');
      expect(await store.readQuestionIds(), isEmpty);
    });

    test('clearBank removes the imported bank, its name/count, and the read ids', () async {
      const validJson =
          '[{"text": "سؤال", "answers": [{"text": "أ", "points": 10}, {"text": "ب", "points": 5}]}]';
      await store.importBank(validJson, 'بنكي');
      await store.markQuestionRead('q1', bank: [
        const Question(id: 'q1', text: 'س', category: 'عام', answers: [
          Answer(text: 'أ', points: 10),
          Answer(text: 'ب', points: 5),
        ]),
      ]);

      await store.clearBank();

      expect(await store.bankName(), isNull);
      expect(await store.bankQuestionCount(), 0);
      expect(await store.readQuestionIds(), isEmpty);
      final bundled = await QuestionBank.load();
      final questions = await store.questions();
      expect(questions.map((q) => q.id).toList(), bundled.map((q) => q.id).toList());
    });
  });
}
