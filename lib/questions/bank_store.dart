/// بيحفظ بنك أسئلة المضيف وسجل القراءة على القرص — نسخة عن نصف بنك
/// الأسئلة بـ`SettingsRepository` الأصلي (Kotlin): استيراد/حذف البنك،
/// وتتبّع الأسئلة المقروءة. باقي `SettingsRepository` (الإعدادات نفسها،
/// الفلتر، وحالة اللعبة الجديدة) بمهمّة تانية.
///
/// ما بيعرف وين يحفظ ملفاته — المستدعي هو اللي بيمرر مجلد التخزين
/// (`getApplicationSupportDirectory()` بالتطبيق الحقيقي).
library;

import 'dart:convert';
import 'dart:io';

import '../game/models.dart';
import 'bank.dart';

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
  Future<Set<String>> readQuestionIds() async {
    if (!await _readIdsFile.exists()) return <String>{};
    final decoded = jsonDecode(await _readIdsFile.readAsString());
    if (decoded is! List) return <String>{};
    return decoded.map((e) => e as String).toSet();
  }

  /// المضيف شاف السؤال — منسجّله حتى ما يتكرر باللعبة الجاية. [bank] هو
  /// أسئلة اللعبة الحالية (بعد فلتر المضيف) — منها منعرف إذا خلصت كلها.
  Future<void> markQuestionRead(String id, {required List<Question> bank}) async {
    final read = await readQuestionIds();
    final next = {...read, id};
    // خلصت كل الأسئلة؟ منبلّش دورة قراءة جديدة نظيفة.
    final allRead = bank.isNotEmpty && bank.every((q) => next.contains(q.id) || q.isRead);
    await _writeReadIds(allRead ? <String>{} : next);
  }

  /// بنك جديد = دورة قراءة جديدة.
  Future<void> clearReadQuestions() async {
    if (await _readIdsFile.exists()) await _readIdsFile.delete();
  }

  /// بيتأكد من ملف اختاره المضيف، وبيحفظه. بيرجّع رسالة الخطأ إذا الملف
  /// مش صالح — وبهاي الحالة البنك القديم بيضل شغّال.
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

  Future<String?> bankName() async {
    if (!await _bankFile.exists()) return null;
    final meta = await _readMeta();
    return meta?['name'] as String?;
  }

  Future<int> bankQuestionCount() async {
    final meta = await _readMeta();
    return meta?['count'] as int? ?? 0;
  }

  Future<void> _writeReadIds(Set<String> ids) async {
    await _readIdsFile.writeAsString(jsonEncode(ids.toList()));
  }

  Future<Map<String, dynamic>?> _readMeta() async {
    if (!await _metaFile.exists()) return null;
    final decoded = jsonDecode(await _metaFile.readAsString());
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> _writeMeta(String name, int count) async {
    await _metaFile.writeAsString(jsonEncode({'name': name, 'count': count}));
  }
}
