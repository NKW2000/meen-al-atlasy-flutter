import 'models.dart';

const Object _unset = Object();

/// إعدادات المضيف — بتتحفظ على جهازه وبتتطبّق على كل لعبة جديدة.
/// [bankName] بيضل null إذا المضيف عم يستعمل البنك المرفق مع التطبيق.
class GameSettings {
  final int rounds;
  final List<int> multipliers;
  final int strikesToSteal;

  /// كم ثانية عند اللاعب ليجاوب قبل ما ينحسب عليه خطأ.
  final int answerSeconds;

  /// كم ثانية لقرار «نلعب أو نمرّر».
  final int choiceSeconds;
  final Map<TeamId, String> teamNames;

  /// اسم الغرفة اللي بيشوفه اللاعبين لما يدوّروا على لعبة.
  final String roomName;

  /// أقل وأكثر عدد أجوبة بالسؤال — فلتر على البنك.
  final int minAnswers;
  final int maxAnswers;
  final String? bankName;
  final int bankQuestionCount;

  const GameSettings({
    this.rounds = defaultRounds,
    this.multipliers = defaultMultipliers,
    this.strikesToSteal = defaultStrikes,
    this.answerSeconds = defaultAnswerSeconds,
    this.choiceSeconds = defaultChoiceSeconds,
    this.teamNames = defaultTeamNames,
    this.roomName = defaultRoomName,
    this.minAnswers = defaultMinAnswers,
    this.maxAnswers = maxAnswersBound,
    this.bankName,
    this.bankQuestionCount = 0,
  });

  static const int minRounds = 1;
  static const int maxRounds = 8;
  static const int defaultRounds = 4;
  static const int minStrikes = 1;
  static const int maxStrikes = 5;
  static const int defaultStrikes = 3;
  static const List<int> defaultMultipliers = [1, 1, 2, 3];
  static const int minAnswerSeconds = 5;
  static const int maxAnswerSeconds = 60;
  static const int defaultAnswerSeconds = 10;
  static const int minChoiceSeconds = 3;
  static const int maxChoiceSeconds = 30;
  static const int defaultChoiceSeconds = 5;
  static const int maxTeamName = 18;
  static const String defaultRoomName = 'غرفة مين الأطليسي';

  /// نفس حدود بنك الأسئلة — والحدود الفعلية بتجي من البنك نفسه.
  ///
  /// اسم Kotlin الأصلي `MIN_ANSWERS`. انسمّى هون `minAnswersBound` لأنو
  /// Dart ما بيسمح بستاتيك وinstance member عندهم نفس الاسم بنفس الصنف،
  /// وفي حقل instance اسمه `minAnswers` أصلاً.
  static const int minAnswersBound = 4;

  /// ثمانية — نفس عدد خانات اللوح.
  ///
  /// اسم Kotlin الأصلي `MAX_ANSWERS` (نفس القيمة مستعملة كقيمة افتراضية
  /// لحقل [maxAnswers] وكحد أعلى بـ[clamped]). انسمّى هون `maxAnswersBound`
  /// لنفس سبب [minAnswersBound].
  static const int maxAnswersBound = 8;
  /// ٤ حتى يدخل البنك المرفق كله (٤–٨ أجوبة) بدون ما يلزم المضيف يغيّر الفلتر.
  static const int defaultMinAnswers = 4;
  static const Map<TeamId, String> defaultTeamNames = {
    TeamId.team1: 'الفريق الأخضر',
    TeamId.team2: 'الفريق الأزرق',
  };

  /// مضاعف كل جولة — إذا المضاعفات أقل من عدد الجولات منكرر الأخير.
  List<int> multipliersForRounds() => List.generate(rounds, (index) {
        if (index < multipliers.length) return multipliers[index];
        return multipliers.isNotEmpty ? multipliers.last : 1;
      });

  /// عدد الأسئلة اللي لازمة للعبة وحدة — سؤال لكل جولة.
  int questionsNeeded() => rounds;

  GameSettings clamped() {
    final clampedMinAnswers =
        minAnswers.clamp(minAnswersBound, maxAnswersBound).toInt();
    final trimmedRoom = roomName.trim();
    final cappedRoom = trimmedRoom.length > maxTeamName
        ? trimmedRoom.substring(0, maxTeamName)
        : trimmedRoom;
    return GameSettings(
      rounds: rounds.clamp(minRounds, maxRounds).toInt(),
      multipliers: multipliers.isEmpty
          ? defaultMultipliers
          : multipliers.map((m) => m.clamp(1, 9).toInt()).toList(),
      strikesToSteal: strikesToSteal.clamp(minStrikes, maxStrikes).toInt(),
      answerSeconds:
          answerSeconds.clamp(minAnswerSeconds, maxAnswerSeconds).toInt(),
      choiceSeconds:
          choiceSeconds.clamp(minChoiceSeconds, maxChoiceSeconds).toInt(),
      roomName: _isBlank(cappedRoom) ? defaultRoomName : cappedRoom,
      minAnswers: clampedMinAnswers,
      maxAnswers: maxAnswers.clamp(clampedMinAnswers, maxAnswersBound).toInt(),
      teamNames: {
        for (final id in TeamId.values) id: _clampedTeamName(teamNames[id], id),
      },
      bankName: bankName,
      bankQuestionCount: bankQuestionCount,
    );
  }

  String teamName(TeamId teamId) =>
      teamNames[teamId] ?? defaultTeamNames[teamId]!;

  GameSettings copyWith({
    int? rounds,
    List<int>? multipliers,
    int? strikesToSteal,
    int? answerSeconds,
    int? choiceSeconds,
    Map<TeamId, String>? teamNames,
    String? roomName,
    int? minAnswers,
    int? maxAnswers,
    Object? bankName = _unset,
    int? bankQuestionCount,
  }) =>
      GameSettings(
        rounds: rounds ?? this.rounds,
        multipliers: multipliers ?? this.multipliers,
        strikesToSteal: strikesToSteal ?? this.strikesToSteal,
        answerSeconds: answerSeconds ?? this.answerSeconds,
        choiceSeconds: choiceSeconds ?? this.choiceSeconds,
        teamNames: teamNames ?? this.teamNames,
        roomName: roomName ?? this.roomName,
        minAnswers: minAnswers ?? this.minAnswers,
        maxAnswers: maxAnswers ?? this.maxAnswers,
        bankName: identical(bankName, _unset) ? this.bankName : bankName as String?,
        bankQuestionCount: bankQuestionCount ?? this.bankQuestionCount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameSettings &&
          other.rounds == rounds &&
          listEq(other.multipliers, multipliers) &&
          other.strikesToSteal == strikesToSteal &&
          other.answerSeconds == answerSeconds &&
          other.choiceSeconds == choiceSeconds &&
          mapEq(other.teamNames, teamNames) &&
          other.roomName == roomName &&
          other.minAnswers == minAnswers &&
          other.maxAnswers == maxAnswers &&
          other.bankName == bankName &&
          other.bankQuestionCount == bankQuestionCount);

  @override
  int get hashCode => Object.hashAll([
        rounds,
        Object.hashAll(multipliers),
        strikesToSteal,
        answerSeconds,
        choiceSeconds,
        _mapHash(teamNames),
        roomName,
        minAnswers,
        maxAnswers,
        bankName,
        bankQuestionCount,
      ]);
}

int _mapHash(Map<Object?, Object?> map) =>
    map.entries.fold(0, (acc, e) => acc ^ Object.hash(e.key, e.value));

bool _isBlank(String s) => s.trim().isEmpty;

String _clampedTeamName(String? raw, TeamId id) {
  final trimmed = raw?.trim();
  if (trimmed == null) return GameSettings.defaultTeamNames[id]!;
  final capped = trimmed.length > GameSettings.maxTeamName
      ? trimmed.substring(0, GameSettings.maxTeamName)
      : trimmed;
  return _isBlank(capped) ? GameSettings.defaultTeamNames[id]! : capped;
}
