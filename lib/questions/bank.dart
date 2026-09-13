/// بنك الأسئلة. في بنك مرفق مع التطبيق، والمضيف بيقدر يستورد بنكه الخاص
/// من ملف JSON بنفس الشكل.
///
/// نفس `QuestionBank.kt` بالمشروع الأصلي (Kotlin).
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../game/models.dart';

/// نتيجة قراءة ملف بنك أسئلة من المضيف.
sealed class BankResult {}

class BankSuccess extends BankResult {
  final List<Question> questions;

  BankSuccess(this.questions);
}

/// [message] عربي وجاهز للعرض للمضيف.
class BankFailure extends BankResult {
  final String message;

  BankFailure(this.message);
}

class QuestionBank {
  static const String _asset = 'assets/questions/starter_questions.json';

  /// أقل وأكثر عدد أجوبة مسموح فيه بالسؤال الواحد.
  static const int minAnswers = 2;
  static const int maxAnswers = 9;

  static List<Question>? _bundled;

  QuestionBank._();

  /// البنك المرفق مع التطبيق — بيتحمّل مرة وحدة وبينحفظ بالذاكرة.
  static Future<List<Question>> load() async {
    final cached = _bundled;
    if (cached != null) return cached;

    final text = await rootBundle.loadString(_asset);
    final result = parse(text);
    if (result is BankFailure) {
      throw StateError('bundled bank invalid: ${result.message}');
    }
    final questions = (result as BankSuccess).questions;
    _bundled = questions;
    return questions;
  }

  /// بيقرأ ملف بنك أسئلة ويتأكد منه. الشكل المتوقع:
  ///
  /// ```json
  /// [
  ///   {
  ///     "text": "اذكر شي بيعمله الناس أول ما يصحوا",
  ///     "category": "عام",
  ///     "answers": [
  ///       {"text": "يشيّكوا الموبايل", "points": 40},
  ///       {"text": "يشربوا قهوة", "points": 30}
  ///     ]
  ///   }
  /// ]
  /// ```
  ///
  /// `id` و`category` اختياريين. الأجوبة بتنرتب من الأعلى نقاط للأقل،
  /// لأن ترتيبها هو ترتيب اللوح وجواب رقم ١ بياخد اللوح بالمواجهة.
  static BankResult parse(String text) {
    List<dynamic> raw;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) {
        throw const FormatException('bank root must be a list of questions');
      }
      for (final item in decoded) {
        _validateRawQuestion(item);
      }
      raw = decoded;
    } catch (error) {
      final detail = error is FormatException ? error.message : error.toString();
      return BankFailure('الملف مش JSON صالح: $detail');
    }

    if (raw.isEmpty) return BankFailure('الملف فاضي — ما في ولا سؤال');

    final questions = <Question>[];
    for (var index = 0; index < raw.length; index++) {
      final position = index + 1;
      final item = raw[index] as Map;
      final text = item['text'] as String;
      if (text.trim().isEmpty) {
        return BankFailure('السؤال رقم $position بدون نص');
      }

      final answersRaw = item['answers'] as List;
      if (answersRaw.length < minAnswers) {
        return BankFailure(
          'السؤال رقم $position لازم يكون فيه $minAnswers أجوبة عالأقل',
        );
      }
      if (answersRaw.length > maxAnswers) {
        return BankFailure(
          'السؤال رقم $position فيه أجوبة أكتر من $maxAnswers',
        );
      }

      for (final answer in answersRaw) {
        final answerMap = answer as Map;
        final answerText = answerMap['text'] as String;
        final points = answerMap['points'] as int;
        if (answerText.trim().isEmpty) {
          return BankFailure('بالسؤال رقم $position في جواب بدون نص');
        }
        if (points <= 0) {
          return BankFailure(
            'بالسؤال رقم $position في جواب نقاطه صفر أو أقل',
          );
        }
      }

      final idRaw = item['id'] as String?;
      final categoryRaw = (item['category'] as String?)?.trim();
      final isRead = item['isRead'] as bool? ?? false;

      // ترتيب اللوح دايماً من الأعلى نقاط للأقل. بترتيب ثابت (stable) عند
      // تعادل النقاط — زي `sortedByDescending` بـKotlin — فبنقارن أولاً
      // بالنقاط تنازلياً وبعدين بالترتيب الأصلي بالملف تصاعدياً، بدل
      // الاعتماد على `List.sort` اللي مش مضمون إنه ثابت.
      final indexedAnswers = answersRaw.asMap().entries.map((entry) {
        final m = entry.value as Map;
        return (
          index: entry.key,
          answer: Answer(text: (m['text'] as String).trim(), points: m['points'] as int),
        );
      }).toList()
        ..sort((a, b) {
          final byPoints = b.answer.points.compareTo(a.answer.points);
          return byPoints != 0 ? byPoints : a.index.compareTo(b.index);
        });
      final answers = indexedAnswers.map((e) => e.answer).toList();

      questions.add(
        Question(
          id: (idRaw != null && idRaw.trim().isNotEmpty) ? idRaw : 'q$position',
          text: text.trim(),
          category: (categoryRaw == null || categoryRaw.isEmpty) ? 'عام' : categoryRaw,
          isRead: isRead,
          answers: answers,
        ),
      );
    }
    return BankSuccess(questions);
  }

  /// بيختار [count] سؤال عشوائي لجولة وحدة — بدون تكرار، ومو أكتر من
  /// عدد الأسئلة الموجودة بالبنك.
  static List<Question> randomRound(
    int count,
    List<Question> source, {
    Random? random,
  }) {
    final rnd = random ?? Random();
    final shuffled = List<Question>.from(source)..shuffle(rnd);
    final take = count < shuffled.length ? count : shuffled.length;
    return shuffled.take(take).toList();
  }

  /// أسئلة لعبة وحدة — بتاخد من الأسئلة **اللي ما انقرأت** أول شي
  /// ([readIds] هي المقروءة). إذا ما ضل كفاية غير مقروء، منرجع نستعمل
  /// البنك كله من جديد.
  static List<Question> randomGame(
    int rounds,
    List<Question> source, {
    Set<String> readIds = const {},
    Random? random,
  }) {
    final rnd = random ?? Random();
    final unread = source.where((q) => !q.isRead && !readIds.contains(q.id)).toList();
    final picked = (List<Question>.from(unread)..shuffle(rnd)).take(rounds).toList();
    if (picked.length == rounds) return picked;
    // خلصت الأسئلة: منبلّش دورة جديدة على البنك كله.
    final pickedIds = picked.map((q) => q.id).toSet();
    final rest = source.where((q) => !pickedIds.contains(q.id)).toList();
    final more = (List<Question>.from(rest)..shuffle(rnd)).take(rounds - picked.length).toList();
    return [...picked, ...more];
  }

  static void _validateRawQuestion(dynamic item) {
    if (item is! Map) {
      throw const FormatException('question must be an object');
    }
    if (item['text'] is! String) {
      throw const FormatException('question text must be a string');
    }
    final id = item['id'];
    if (id != null && id is! String) {
      throw const FormatException('question id must be a string');
    }
    final category = item['category'];
    if (category != null && category is! String) {
      throw const FormatException('question category must be a string');
    }
    final isRead = item['isRead'];
    if (isRead != null && isRead is! bool) {
      throw const FormatException('question isRead must be a boolean');
    }
    final answers = item['answers'];
    if (answers is! List) {
      throw const FormatException('question answers must be a list');
    }
    for (final answer in answers) {
      if (answer is! Map) {
        throw const FormatException('answer must be an object');
      }
      if (answer['text'] is! String) {
        throw const FormatException('answer text must be a string');
      }
      if (answer['points'] is! int) {
        throw const FormatException('answer points must be an integer');
      }
    }
  }
}
