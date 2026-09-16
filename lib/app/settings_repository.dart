/// بيحفظ إعدادات المضيف وبنك أسئلته على الجهاز. نفس `SettingsRepository.kt`
/// بالمشروع الأصلي (Kotlin)، بفارقين: هون `SharedPreferences` بدل
/// `SharedPreferences` الأندرويدية (بس نفس المفاتيح بالضبط)، وبنك الأسئلة
/// بمكوّن منفصل [BankStore] (Task 5) بدل ملفات مباشرة — هاد الصنف بيركّبه
/// ويضيفله نصف الإعدادات (`load`/`save`/الفلتر/حالة اللعبة الجديدة)، وبيلفّ
/// طرق البنك (`importBank`/`clearBank`) اللي كانت بـ`SettingsViewModel.kt`
/// (حكم المتحكمات ٤).
///
/// ما بيعرف وين يخزّن ملفات البنك — المستدعي هو اللي بيمرر مجلد التخزين
/// (`getApplicationSupportDirectory()` بالتطبيق الحقيقي)، ونسخة
/// `SharedPreferences` (حتى تقدر الاختبارات تستعمل
/// `SharedPreferences.setMockInitialValues({})`).
///
/// **لقطة متزامنة (قرار مراجعة الخيار ب):** [HostController.newGame] و
/// أخواتها لازم تكون دوال **متزامنة** (`GameState Function()`, نفس
/// `HostViewModel.kt` بالضبط)، بينما قراءة `SharedPreferences`/ملفات
/// البنك بـDart غير متزامنة (بعكس Kotlin). الحل: هاد الصنف بيحتفظ بنسخة
/// بالذاكرة من الإعدادات والبنك وسجل القراءة، بتتحدّث بآخر كل دالة كتابة
/// (`save`/`importBank`/`clearBank`/`markQuestionRead`/`clearReadQuestions`)
/// وبتتعبّى أول مرة بـ[warmUp] (تنستنى مرة وحدة عند الإقلاع). فوقها
/// [current]/[roomName]/[newGameStateSync]/[freshQuestionSync] بيرجّعوا
/// آخر نسخة محفوظة فوراً بدون انتظار. [newGameState] (النسخة غير
/// المتزامنة) ضلّت متل ما هي — قراءة حيّة من التخزين بكل نداء.
library;

import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';
import '../game/settings.dart';
import '../questions/bank.dart';
import '../questions/bank_store.dart';

class SettingsRepository {
  final SharedPreferences _prefs;
  final BankStore _bankStore;

  SettingsRepository(this._prefs, Directory bankDirectory)
      : _bankStore = BankStore(bankDirectory);

  GameSettings _cachedSettings = const GameSettings();
  List<Question> _cachedBank = const [];
  Set<String> _cachedReadIds = const {};
  Set<String> _cachedReadTexts = const {};

  static const _keyRounds = 'rounds';
  static const _keyMultipliers = 'multipliers';
  static const _keyStrikes = 'strikes';
  static const _keyAnswerSeconds = 'answer_seconds';
  static const _keyChoiceSeconds = 'choice_seconds';
  static const _keyRoomName = 'room_name';
  static const _keyMinAnswers = 'min_answers';
  static const _keyMaxAnswers = 'max_answers';
  static const _keyTeam1 = 'team_1_name';
  static const _keyTeam2 = 'team_2_name';

  /// فلتر الأجوبة صار ٤–٨ (كان ٥–٨ افتراضياً). أول مرة بعد التحديث منرجّع
  /// القيم المحفوظة للافتراضي الجديد حتى يبلّش المضيف من ٤.
  static const _keyAnswersFilterV2 = 'answers_filter_v2';

  /// بتنفّذ مرة وحدة بس (قبل أي قراءة أو كتابة) — بعدها الفلتر بيتحفظ عادي.
  Future<void> _migrateAnswersFilter() async {
    if (_prefs.getBool(_keyAnswersFilterV2) ?? false) return;
    await _prefs.remove(_keyMinAnswers);
    await _prefs.remove(_keyMaxAnswers);
    await _prefs.setBool(_keyAnswersFilterV2, true);
  }

  Future<GameSettings> load() async {
    await _migrateAnswersFilter();
    final multipliers = _prefs
            .getString(_keyMultipliers)
            ?.split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList() ??
        const <int>[];
    final bankName = await _bankStore.bankName();
    final bankQuestionCount = await _bankStore.bankQuestionCount();
    return GameSettings(
      rounds: _prefs.getInt(_keyRounds) ?? GameSettings.defaultRounds,
      multipliers:
          multipliers.isNotEmpty ? multipliers : GameSettings.defaultMultipliers,
      strikesToSteal: _prefs.getInt(_keyStrikes) ?? GameSettings.defaultStrikes,
      answerSeconds:
          _prefs.getInt(_keyAnswerSeconds) ?? GameSettings.defaultAnswerSeconds,
      choiceSeconds:
          _prefs.getInt(_keyChoiceSeconds) ?? GameSettings.defaultChoiceSeconds,
      roomName: _prefs.getString(_keyRoomName) ?? '',
      minAnswers: _prefs.getInt(_keyMinAnswers) ?? GameSettings.defaultMinAnswers,
      maxAnswers: _prefs.getInt(_keyMaxAnswers) ?? GameSettings.maxAnswersBound,
      teamNames: {
        TeamId.team1: _prefs.getString(_keyTeam1) ?? '',
        TeamId.team2: _prefs.getString(_keyTeam2) ?? '',
      },
      bankName: bankName,
      bankQuestionCount: bankQuestionCount,
    ).clamped();
  }

  Future<void> save(GameSettings settings) async {
    await _migrateAnswersFilter();
    final safe = settings.clamped();
    await _prefs.setInt(_keyRounds, safe.rounds);
    await _prefs.setString(_keyMultipliers, safe.multipliers.join(','));
    await _prefs.setInt(_keyStrikes, safe.strikesToSteal);
    await _prefs.setInt(_keyAnswerSeconds, safe.answerSeconds);
    await _prefs.setInt(_keyChoiceSeconds, safe.choiceSeconds);
    await _prefs.setString(_keyRoomName, safe.roomName);
    await _prefs.setInt(_keyMinAnswers, safe.minAnswers);
    await _prefs.setInt(_keyMaxAnswers, safe.maxAnswers);
    await _prefs.setString(_keyTeam1, safe.teamName(TeamId.team1));
    await _prefs.setString(_keyTeam2, safe.teamName(TeamId.team2));
    await _refreshCache();
  }

  /// بيعبّي اللقطة المتزامنة (إعدادات + بنك + سجل قراءة) أول مرة. لازم
  /// تنستنى قبل أي استعمال لـ[current]/[roomName]/[newGameStateSync]/
  /// [freshQuestionSync] — المستدعي (`main.dart` لاحقاً) بينادي هاي مرة
  /// وحدة عند الإقلاع، قبل ما يبني [HostController].
  Future<void> warmUp() => _refreshCache();

  Future<void> _refreshCache() async {
    _cachedSettings = await load();
    _cachedBank = await questions();
    _cachedReadIds = await readQuestionIds();
    _cachedReadTexts = await readQuestionFingerprints();
  }

  /// أسئلة اللعبة: بنك المضيف إذا مستورد، وإلا البنك المرفق.
  Future<List<Question>> questions() => _bankStore.questions();

  /// حدود عدد الأجوبة الموجودة فعلياً بالبنك (أقل، أكثر) — منها بتتبنى
  /// خطوات الفلتر.
  Future<(int low, int high)> answerBounds() async {
    final sizes = (await questions()).map((q) => q.answers.length).toList();
    final low = (sizes.isEmpty
            ? GameSettings.minAnswersBound
            : sizes.reduce((a, b) => a < b ? a : b))
        .clamp(GameSettings.minAnswersBound, GameSettings.maxAnswersBound)
        .toInt();
    final high = (sizes.isEmpty
            ? GameSettings.maxAnswersBound
            : sizes.reduce((a, b) => a > b ? a : b))
        .clamp(low, GameSettings.maxAnswersBound)
        .toInt();
    return (low, high);
  }

  /// أسئلة البنك بعد فلتر عدد الأجوبة.
  Future<List<Question>> filteredQuestions([GameSettings? settings]) async {
    final s = settings ?? await load();
    final all = await questions();
    return all
        .where((q) =>
            q.answers.length >= s.minAnswers && q.answers.length <= s.maxAnswers)
        .toList();
  }

  /// كم سؤال بيطابق الفلتر الحالي.
  Future<int> matchingCount(GameSettings settings) async =>
      (await filteredQuestions(settings)).length;

  /// الأسئلة اللي انقرأت قبل — ما بترجع لحد ما يخلص البنك.
  Future<Set<String>> readQuestionIds() => _bankStore.readQuestionIds();

  /// بصمات الأسئلة المقروءة — بتخلّي القراءة تنجو من تحديث بدّل المعرّفات.
  Future<Set<String>> readQuestionFingerprints() =>
      _bankStore.readQuestionFingerprints();

  /// البنك الحالي كملف JSON مع `isreaded` — للحفظ قبل تحديث/تنزيل من جديد.
  Future<String> exportBank() => _bankStore.exportBank();

  /// المضيف شاف السؤال — منسجّله حتى ما يتكرر باللعبة الجاية.
  Future<void> markQuestionRead(String id) async {
    final filtered = await filteredQuestions();
    final bank = filtered.isNotEmpty ? filtered : await questions();
    await _bankStore.markQuestionRead(id, bank: bank);
    await _refreshCache();
  }

  /// بنك جديد = دورة قراءة جديدة.
  Future<void> clearReadQuestions() async {
    await _bankStore.clearReadQuestions();
    await _refreshCache();
  }

  /// حالة بداية للعبة جديدة: أسئلة ما انقرأت وإعدادات المضيف الحالية.
  Future<GameState> newGameState() async {
    final settings = await load();
    final filtered = await filteredQuestions(settings);
    final source = filtered.isNotEmpty ? filtered : await questions();
    final readIds = await readQuestionIds();
    final readTexts = await readQuestionFingerprints();
    return GameState(
      questions: QuestionBank.randomGame(
        settings.rounds,
        source,
        readIds: readIds,
        readTexts: readTexts,
      ),
      multipliers: settings.multipliersForRounds(),
      strikesToSteal: settings.strikesToSteal,
      answerLimitSeconds: settings.answerSeconds,
      choiceLimitSeconds: settings.choiceSeconds,
      teams: {
        for (final id in TeamId.values) id: TeamState(id: id, name: settings.teamName(id)),
      },
    );
  }

  /// بيتأكد من ملف اختاره المضيف، وبيحفظه. بيرجّع رسالة الخطأ إذا الملف
  /// مش صالح — وبهاي الحالة البنك القديم بيضل شغّال.
  Future<BankResult> importBank(String text, String displayName) async {
    final result = await _bankStore.importBank(text, displayName);
    await _refreshCache();
    return result;
  }

  /// رجوع للبنك المرفق مع التطبيق.
  Future<void> clearBank() async {
    await _bankStore.clearBank();
    await _refreshCache();
  }

  // ========================================================================
  // اللقطة المتزامنة — فوق آخر نسخة عبّاها [warmUp] أو أي دالة كتابة.
  // ========================================================================

  /// آخر إعدادات معروفة — بدون انتظار (حكم قرار المراجعة، الخيار ب).
  GameSettings get current => _cachedSettings;

  /// اسم الغرفة الحالي — بدون انتظار.
  String get roomName => _cachedSettings.roomName;

  List<Question> _filteredFromCache(GameSettings settings) => _cachedBank
      .where((q) =>
          q.answers.length >= settings.minAnswers &&
          q.answers.length <= settings.maxAnswers)
      .toList();

  /// نفس [newGameState] بس متزامنة، فوق آخر لقطة محفوظة — تقدر تنستعمل
  /// مباشرة كـ`HostController.newGame`.
  GameState newGameStateSync() {
    final settings = _cachedSettings;
    final filtered = _filteredFromCache(settings);
    final source = filtered.isNotEmpty ? filtered : _cachedBank;
    return GameState(
      questions: QuestionBank.randomGame(
        settings.rounds,
        source,
        readIds: _cachedReadIds,
        readTexts: _cachedReadTexts,
      ),
      multipliers: settings.multipliersForRounds(),
      strikesToSteal: settings.strikesToSteal,
      answerLimitSeconds: settings.answerSeconds,
      choiceLimitSeconds: settings.choiceSeconds,
      teams: {
        for (final id in TeamId.values) id: TeamState(id: id, name: settings.teamName(id)),
      },
    );
  }

  /// سؤال بديل ما انقرأ — نفس منطق `freshQuestion` بـ`FeudNavGraph.kt`
  /// (سطر ٤٠٠-٤٠٧): سؤال وحيد من بنك مفلتر بإعدادات المضيف الحالية، ما
  /// انقرأ قبل — أو `null` إذا ما في. تقدر تنستعمل مباشرة كـ
  /// `HostController.freshQuestion`.
  Question? freshQuestionSync() {
    final filtered = _filteredFromCache(_cachedSettings);
    final source = filtered.isNotEmpty ? filtered : _cachedBank;
    final picked = QuestionBank.randomGame(
      1,
      source,
      readIds: _cachedReadIds,
      readTexts: _cachedReadTexts,
    );
    return picked.isEmpty ? null : picked.first;
  }
}
