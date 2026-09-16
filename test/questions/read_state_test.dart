/// سجل القراءة وتحديثات التطبيق: السؤال اللي انسأل ما بيرجع ينسأل — ولا
/// بعد تحديث بدّل معرّفات البنك، ولا بعد تنزيل التطبيق من جديد (بملف
/// [BankStore.exportBank] وإعادة استيراده).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/questions/bank.dart';
import 'package:meen_al_atlasy/questions/bank_store.dart';

/// بنك صغير بنفس شكل ملفات المضيف.
String _bankJson(List<(String id, String text)> items) => jsonEncode([
      for (final (id, text) in items)
        {
          'id': id,
          'text': text,
          'isreaded': false,
          'answers': [
            {'text': 'أ', 'points': 60},
            {'text': 'ب', 'points': 40},
          ],
        },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('questionFingerprint', () {
    test('the same question with different diacritics or punctuation matches', () {
      expect(
        questionFingerprint('اذكر شي بيعملوه الناس أول ما يصحوا؟'),
        questionFingerprint('اذكر شي بيعملوه النَّاس اول ما يصحوا'),
      );
    });

    test('two different questions do not match', () {
      expect(
        questionFingerprint('اذكر فاكهة صيفية'),
        isNot(questionFingerprint('اذكر فاكهة شتوية')),
      );
    });

    test('extra spaces and tatweel do not matter', () {
      expect(
        questionFingerprint('اذكر   شي   حلو'),
        questionFingerprint('اذكر شي حلـــو'),
      );
    });
  });

  group('BankStore read state', () {
    late Directory dir;
    late BankStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('read_state_test');
      store = BankStore(dir);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('a question stays read after an update renumbers the bank', () async {
      // النسخة القديمة: ٣ أسئلة، المضيف سأل التاني.
      await store.importBank(
        _bankJson([('q1', 'اذكر فاكهة'), ('q2', 'اذكر خضرة'), ('q3', 'اذكر حلويات')]),
        'قديم',
      );
      final old = await store.questions();
      await store.markQuestionRead('q2', bank: old);

      // النسخة الجديدة: نفس الأسئلة بمعرّفات تانية (زي ما صار بتحديث البنك).
      await File('${dir.path}/host_bank.json').writeAsString(
        _bankJson([('n7', 'اذكر فاكهة'), ('n8', 'اذكر خضرة'), ('n9', 'اذكر حلويات')]),
      );

      final fresh = await store.questions();
      final picked = QuestionBank.randomGame(
        2,
        fresh,
        readIds: await store.readQuestionIds(),
        readTexts: await store.readQuestionFingerprints(),
      );

      // «اذكر خضرة» انسألت قبل التحديث — ما بتنسأل تاني وإن تغيّر معرّفها.
      expect(picked.map((q) => q.text), isNot(contains('اذكر خضرة')));
      expect(picked, hasLength(2));
    });

    test('the old read-ids file format (a plain list) is still honoured', () async {
      await File('${dir.path}/read_ids.json').writeAsString('["q1","q2"]');

      expect(await store.readQuestionIds(), {'q1', 'q2'});
      expect(await store.readQuestionFingerprints(), isEmpty);
    });

    test('a corrupt read-ids file reads as empty', () async {
      await File('${dir.path}/read_ids.json').writeAsString('{ليس');

      expect(await store.readQuestionIds(), isEmpty);
      expect(await store.readQuestionFingerprints(), isEmpty);
    });

    test('exportBank writes isreaded true for what was asked', () async {
      await store.importBank(
        _bankJson([('q1', 'اذكر فاكهة'), ('q2', 'اذكر خضرة')]),
        'بنكي',
      );
      await store.markQuestionRead('q1', bank: await store.questions());

      final exported = jsonDecode(await store.exportBank()) as List;
      final byId = {for (final q in exported) q['id'] as String: q};

      expect(byId['q1']!['isreaded'], isTrue);
      expect(byId['q2']!['isreaded'], isFalse);
      // نفس شكل الاستيراد بالضبط — فبيرجع ينقرا.
      expect(QuestionBank.parse(jsonEncode(exported)), isA<BankSuccess>());
    });

    test('re-importing an export keeps the asked questions out of the next game',
        () async {
      await store.importBank(
        _bankJson([('q1', 'اذكر فاكهة'), ('q2', 'اذكر خضرة'), ('q3', 'اذكر حلويات')]),
        'بنكي',
      );
      await store.markQuestionRead('q1', bank: await store.questions());
      final backup = await store.exportBank();

      // «نزّل التطبيق من جديد»: مخزن فاضي تماماً، وبعدها استورد النسخة.
      final freshDir = await Directory.systemTemp.createTemp('read_state_fresh');
      addTearDown(() async {
        if (await freshDir.exists()) await freshDir.delete(recursive: true);
      });
      final freshStore = BankStore(freshDir);
      expect(await freshStore.readQuestionIds(), isEmpty);

      final result = await freshStore.importBank(backup, 'نسخة محفوظة');
      expect(result, isA<BankSuccess>());

      final picked = QuestionBank.randomGame(2, await freshStore.questions());
      expect(picked.map((q) => q.text), isNot(contains('اذكر فاكهة')));
      expect(picked, hasLength(2));
    });

    test('reading the last question starts a clean cycle', () async {
      await store.importBank(_bankJson([('q1', 'اذكر فاكهة'), ('q2', 'اذكر خضرة')]), 'بنكي');
      final bank = await store.questions();

      await store.markQuestionRead('q1', bank: bank);
      expect(await store.readQuestionIds(), {'q1'});

      await store.markQuestionRead('q2', bank: bank);
      expect(await store.readQuestionIds(), isEmpty);
      expect(await store.readQuestionFingerprints(), isEmpty);
    });
  });
}
