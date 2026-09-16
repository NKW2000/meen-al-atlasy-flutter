/// بيحفظ بنك أسئلة المضيف وسجل القراءة على القرص — نسخة عن نصف بنك
/// الأسئلة بـ`SettingsRepository` الأصلي (Kotlin): استيراد/حذف البنك،
/// وتتبّع الأسئلة المقروءة. باقي `SettingsRepository` (الإعدادات نفسها،
/// الفلتر، وحالة اللعبة الجديدة) بمهمّة تانية.
///
/// ما بيعرف وين يحفظ ملفاته — المستدعي هو اللي بيمرر مجلد التخزين
/// (`getApplicationSupportDirectory()` بالتطبيق الحقيقي).
///
/// **سجل القراءة والتحديثات:** الملف بمجلد بيانات التطبيق، فبيضل موجود
/// بعد تحديث التطبيق (بينمسح بس مع إزالة التطبيق أو «حذف البيانات»).
/// وبينحفظ فيه **المعرّف والبصمة** لكل سؤال انقرأ ([questionFingerprint]):
/// بالمعرّف لحاله كانت الأسئلة ترجع تنسأل بعد تحديث بدّل معرّفات البنك.
/// وللتنزيل من جديد أو جهاز تاني في [exportBank] — ملف JSON بنفس شكل
/// الاستيراد مع `isreaded` معبّى.
library;

import 'dart:convert';
import 'dart:io';

import '../game/models.dart';
import 'bank.dart';

/// سجل القراءة: معرّفات الأسئلة وبصماتها.
typedef ReadState = ({Set<String> ids, Set<String> texts});

const ReadState _emptyRead = (ids: <String>{}, texts: <String>{});

class BankStore {
  final Directory _dir;

  BankStore(this._dir);

  File get _bankFile => File('${_dir.path}/host_bank.json');
  File get _readIdsFile => File('${_dir.path}/read_ids.json');
  File get _metaFile => File('${_dir.path}/bank_meta.json');

  /// أسئلة اللعبة: بنك المضيف إذا مستورد وصالح، وإلا البنك المرفق.
  Future<List<Question>> questions() async {
    if (!await _bankFile.exists()) return QuestionBank.load();
    final text = await _bankFile.readAsString();
    final result = QuestionBank.parse(text);
    return switch (result) {
      BankSuccess(:final questions) => questions,
      BankFailure() => await QuestionBank.load(),
    };
  }

  /// الأسئلة اللي انقرأت قبل — ما بترجع لحد ما يخلص البنك.
  ///
  /// ملف تالف أو بشكل غير متوقع بيتعامل معه متل لو كان غير موجود (فاضي) —
  /// نفس تصرّف `SharedPreferences` الافتراضي بالنسخة الأصلية.
  Future<Set<String>> readQuestionIds() async => (await _readState()).ids;

  /// بصمات الأسئلة المقروءة — شوف [questionFingerprint].
  Future<Set<String>> readQuestionFingerprints() async => (await _readState()).texts;

  /// المضيف شاف السؤال — منسجّله حتى ما يتكرر باللعبة الجاية. [bank] هو
  /// أسئلة اللعبة الحالية (بعد فلتر المضيف) — منها منعرف إذا خلصت كلها،
  /// ومنها منجيب نص السؤال حتى نسجّل بصمته.
  Future<void> markQuestionRead(String id, {required List<Question> bank}) async {
    final read = await _readState();
    final ids = {...read.ids, id};
    final texts = {...read.texts};
    for (final q in bank) {
      if (q.id == id) {
        texts.add(questionFingerprint(q.text));
        break;
      }
    }
    // خلصت كل الأسئلة؟ منبلّش دورة قراءة جديدة نظيفة.
    final allRead = bank.isNotEmpty &&
        bank.every((q) =>
            q.isRead || ids.contains(q.id) || texts.contains(questionFingerprint(q.text)));
    await _writeReadState(allRead ? _emptyRead : (ids: ids, texts: texts));
  }

  /// بنك جديد = دورة قراءة جديدة.
  Future<void> clearReadQuestions() async {
    if (await _readIdsFile.exists()) await _readIdsFile.delete();
  }

  /// بيتأكد من ملف اختاره المضيف، وبيحفظه. بيرجّع رسالة الخطأ إذا الملف
  /// مش صالح — وبهاي الحالة البنك القديم بيضل شغّال.
  ///
  /// البنك الجديد بيبلّش دورة قراءة نظيفة، بس الأسئلة اللي جوّا الملف
  /// و`isreaded` تبعها `true` بتضل محسوبة مقروءة — هيك بيرجع المضيف نسخة
  /// حفظها بـ[exportBank] وما تتكرر عليه أسئلة سألها قبل التحديث.
  Future<BankResult> importBank(String text, String displayName) async {
    final result = QuestionBank.parse(text);
    if (result is BankSuccess) {
      await _bankFile.writeAsString(text);
      await clearReadQuestions();
      await _writeMeta(displayName, result.questions.length);
    }
    return result;
  }

  /// رجوع للبنك المرفق مع التطبيق.
  Future<void> clearBank() async {
    await clearReadQuestions();
    if (await _bankFile.exists()) await _bankFile.delete();
    if (await _metaFile.exists()) await _metaFile.delete();
  }

  /// البنك الحالي كملف JSON بنفس شكل الاستيراد، و`isreaded` معبّى من سجل
  /// القراءة. المضيف بيحفظه قبل ما ينزّل نسخة جديدة أو يغيّر جهاز،
  /// وبيستورده بعدها — فما تتكرر عليه الأسئلة اللي سألها.
  Future<String> exportBank() async {
    final all = await questions();
    final read = await _readState();
    final payload = [
      for (final q in all)
        {
          'id': q.id,
          'text': q.text,
          'isreaded': q.isRead ||
              read.ids.contains(q.id) ||
              read.texts.contains(questionFingerprint(q.text)),
          'answers': [
            for (final a in q.answers) {'text': a.text, 'points': a.points},
          ],
        },
    ];
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<String?> bankName() async {
    if (!await _bankFile.exists()) return null;
    final meta = await _readMeta();
    final name = meta?['name'];
    return name is String ? name : null;
  }

  Future<int> bankQuestionCount() async {
    final meta = await _readMeta();
    final count = meta?['count'];
    return count is int ? count : 0;
  }

  /// سجل القراءة من القرص. الشكل الحالي كائن (`{"v":2,...}`)، والشكل
  /// القديم لستة معرّفات — منقبل الاتنين حتى ما يضيع سجل مضيف محدّث.
  Future<ReadState> _readState() async {
    if (!await _readIdsFile.exists()) return _emptyRead;
    try {
      final decoded = jsonDecode(await _readIdsFile.readAsString());
      if (decoded is List) {
        // الشكل القديم: معرّفات بس، بدون بصمات.
        return (ids: decoded.whereType<String>().toSet(), texts: <String>{});
      }
      if (decoded is Map<String, dynamic>) {
        final ids = decoded['ids'];
        final texts = decoded['texts'];
        return (
          ids: ids is List ? ids.whereType<String>().toSet() : <String>{},
          texts: texts is List ? texts.whereType<String>().toSet() : <String>{},
        );
      }
      return _emptyRead;
    } catch (_) {
      return _emptyRead;
    }
  }

  Future<void> _writeReadState(ReadState state) async {
    await _readIdsFile.writeAsString(jsonEncode({
      'v': 2,
      'ids': state.ids.toList(),
      'texts': state.texts.toList(),
    }));
  }

  /// ملف تالف أو بشكل غير متوقع بيرجع `null` — يعني بدون اسم/عدد، نفس
  /// تصرّف `SharedPreferences` الافتراضي بالنسخة الأصلية.
  Future<Map<String, dynamic>?> _readMeta() async {
    if (!await _metaFile.exists()) return null;
    try {
      final decoded = jsonDecode(await _metaFile.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMeta(String name, int count) async {
    await _metaFile.writeAsString(jsonEncode({'name': name, 'count': count}));
  }
}
