/// نماذج اللعبة الأساسية — منفذة بـ Dart خالص (بدون أي اعتماد على Flutter)
/// عن نفس core-game/GameModels.kt بالمشروع الأصلي (Kotlin).
library;

/// خانة سؤال واحدة.
class Answer {
  final String text;
  final int points;
  final bool revealed;

  const Answer({
    required this.text,
    required this.points,
    this.revealed = false,
  });

  Answer copyWith({String? text, int? points, bool? revealed}) => Answer(
        text: text ?? this.text,
        points: points ?? this.points,
        revealed: revealed ?? this.revealed,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'points': points,
        'revealed': revealed,
      };

  factory Answer.fromJson(Map<String, dynamic> json) => Answer(
        text: json['text'] as String,
        points: json['points'] as int,
        revealed: json['revealed'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Answer &&
          other.text == text &&
          other.points == points &&
          other.revealed == revealed);

  @override
  int get hashCode => Object.hash(text, points, revealed);
}

/// سؤال بلوحه.
class Question {
  final String id;
  final String text;
  final List<Answer> answers;
  final String category;

  /// انقرأ قبل هيك؟ الأسئلة المقروءة ما بترجع إلا لما يخلصوا كلهن.
  final bool isRead;

  const Question({
    required this.id,
    required this.text,
    required this.answers,
    required this.category,
    this.isRead = false,
  });

  Question copyWith({
    String? id,
    String? text,
    List<Answer>? answers,
    String? category,
    bool? isRead,
  }) =>
      Question(
        id: id ?? this.id,
        text: text ?? this.text,
        answers: answers ?? this.answers,
        category: category ?? this.category,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'answers': answers.map((a) => a.toJson()).toList(),
        'category': category,
        'isRead': isRead,
      };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        text: json['text'] as String,
        answers: (json['answers'] as List<dynamic>)
            .map((e) => Answer.fromJson(e as Map<String, dynamic>))
            .toList(),
        category: json['category'] as String,
        isRead: json['isRead'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Question &&
          other.id == id &&
          other.text == text &&
          listEq(other.answers, answers) &&
          other.category == category &&
          other.isRead == isRead);

  @override
  int get hashCode =>
      Object.hash(id, text, Object.hashAll(answers), category, isRead);
}

enum TeamId { team1, team2 }

extension TeamIdX on TeamId {
  TeamId get other => this == TeamId.team1 ? TeamId.team2 : TeamId.team1;

  String get wire => this == TeamId.team1 ? 'TEAM_1' : 'TEAM_2';

  static TeamId fromWire(String wire) =>
      wire == 'TEAM_1' ? TeamId.team1 : TeamId.team2;
}

class TeamState {
  final TeamId id;
  final String name;
  final int score;
  final bool connected;

  const TeamState({
    required this.id,
    required this.name,
    this.score = 0,
    this.connected = false,
  });

  TeamState copyWith({TeamId? id, String? name, int? score, bool? connected}) =>
      TeamState(
        id: id ?? this.id,
        name: name ?? this.name,
        score: score ?? this.score,
        connected: connected ?? this.connected,
      );

  Map<String, dynamic> toJson() => {
        'id': id.wire,
        'name': name,
        'score': score,
        'connected': connected,
      };

  factory TeamState.fromJson(Map<String, dynamic> json) => TeamState(
        id: TeamIdX.fromWire(json['id'] as String),
        name: json['name'] as String,
        score: json['score'] as int? ?? 0,
        connected: json['connected'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeamState &&
          other.id == id &&
          other.name == name &&
          other.score == score &&
          other.connected == connected);

  @override
  int get hashCode => Object.hash(id, name, score, connected);
}

/// لاعب واحد = جهاز واحد.
///
/// [seat] هو رقمه بالفريق (١، ٢، ٣...) وبياخدو لما ينضم وبيضل إله. الرقم
/// هو أساس المواجهة: صاحب الرقم ١ بفريق بيواجه صاحب الرقم ١ بالفريق
/// التاني، والرقم ٢ مع الرقم ٢، وهكذا.
class Player {
  final String id;
  final String name;
  final TeamId teamId;
  final int seat;
  final bool connected;

  const Player({
    required this.id,
    required this.name,
    required this.teamId,
    required this.seat,
    this.connected = true,
  });

  Player copyWith({
    String? id,
    String? name,
    TeamId? teamId,
    int? seat,
    bool? connected,
  }) =>
      Player(
        id: id ?? this.id,
        name: name ?? this.name,
        teamId: teamId ?? this.teamId,
        seat: seat ?? this.seat,
        connected: connected ?? this.connected,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teamId': teamId.wire,
        'seat': seat,
        'connected': connected,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        teamId: TeamIdX.fromWire(json['teamId'] as String),
        seat: json['seat'] as int,
        connected: json['connected'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Player &&
          other.id == id &&
          other.name == name &&
          other.teamId == teamId &&
          other.seat == seat &&
          other.connected == connected);

  @override
  int get hashCode => Object.hash(id, name, teamId, seat, connected);
}

/// حالة شاشة اللاعب — منها بيتحدد لون الجهاز كله:
/// وميض أبيض/أسود لما يكون دوره، أزرق لما يضغط، أخضر إذا صحّ، أحمر إذا غلط
/// (وبيضل أحمر لحد ما يرجع دوره).
enum PlayerMark { idle, armed, buzzed, correct, wrong }

enum RoundPhase {
  /// الزر مفتوح للاعبَي المنصة (واحد من كل فريق).
  faceOff,

  /// لاعب المنصة من الفريق التاني بياخد فرصته.
  faceOffSecond,

  /// الفريق اللي فاز بالمواجهة بيختار: يلعب اللوح أو يمرّرو للفريق
  /// التاني. الاختيار بيصير من جهاز لاعب المنصة نفسه.
  playOrPass,

  /// الفريق اللي معه اللوح بيلعب، لاعب ورا لاعب بالدور.
  play,

  /// محاولة وحدة للفريق المقابل يسرق فيها نقاط الجولة.
  steal,

  roundEnd,

  /// نتيجة الفريقين بتظهر عند الكل قبل ما تبلّش الجولة الجاية.
  scoreboard,

  gameOver,
}

extension RoundPhaseX on RoundPhase {
  String get wire {
    switch (this) {
      case RoundPhase.faceOff:
        return 'FACE_OFF';
      case RoundPhase.faceOffSecond:
        return 'FACE_OFF_SECOND';
      case RoundPhase.playOrPass:
        return 'PLAY_OR_PASS';
      case RoundPhase.play:
        return 'PLAY';
      case RoundPhase.steal:
        return 'STEAL';
      case RoundPhase.roundEnd:
        return 'ROUND_END';
      case RoundPhase.scoreboard:
        return 'SCOREBOARD';
      case RoundPhase.gameOver:
        return 'GAME_OVER';
    }
  }

  static RoundPhase fromWire(String wire) {
    switch (wire) {
      case 'FACE_OFF':
        return RoundPhase.faceOff;
      case 'FACE_OFF_SECOND':
        return RoundPhase.faceOffSecond;
      case 'PLAY_OR_PASS':
        return RoundPhase.playOrPass;
      case 'PLAY':
        return RoundPhase.play;
      case 'STEAL':
        return RoundPhase.steal;
      case 'ROUND_END':
        return RoundPhase.roundEnd;
      case 'SCOREBOARD':
        return RoundPhase.scoreboard;
      case 'GAME_OVER':
        return RoundPhase.gameOver;
      default:
        throw ArgumentError('Unknown RoundPhase wire value: $wire');
    }
  }
}

enum BuzzState { open, lockedTeam1, lockedTeam2, closed }

extension BuzzStateX on BuzzState {
  String get wire {
    switch (this) {
      case BuzzState.open:
        return 'OPEN';
      case BuzzState.lockedTeam1:
        return 'LOCKED_TEAM_1';
      case BuzzState.lockedTeam2:
        return 'LOCKED_TEAM_2';
      case BuzzState.closed:
        return 'CLOSED';
    }
  }

  static BuzzState fromWire(String wire) {
    switch (wire) {
      case 'OPEN':
        return BuzzState.open;
      case 'LOCKED_TEAM_1':
        return BuzzState.lockedTeam1;
      case 'LOCKED_TEAM_2':
        return BuzzState.lockedTeam2;
      case 'CLOSED':
        return BuzzState.closed;
      default:
        throw ArgumentError('Unknown BuzzState wire value: $wire');
    }
  }
}

class Award {
  final TeamId teamId;
  final int points;
  final bool stolen;

  const Award({
    required this.teamId,
    required this.points,
    this.stolen = false,
  });

  Award copyWith({TeamId? teamId, int? points, bool? stolen}) => Award(
        teamId: teamId ?? this.teamId,
        points: points ?? this.points,
        stolen: stolen ?? this.stolen,
      );

  Map<String, dynamic> toJson() => {
        'teamId': teamId.wire,
        'points': points,
        'stolen': stolen,
      };

  factory Award.fromJson(Map<String, dynamic> json) => Award(
        teamId: TeamIdX.fromWire(json['teamId'] as String),
        points: json['points'] as int,
        stolen: json['stolen'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Award &&
          other.teamId == teamId &&
          other.points == points &&
          other.stolen == stolen);

  @override
  int get hashCode => Object.hash(teamId, points, stolen);
}

/// ثواني قرار «نلعب أو نمرّر».
const int choiceSeconds = 5;

/// الوقت الافتراضي للجواب.
const int defaultAnswerSeconds = 10;

const Object _unset = Object();

class GameState {
  final List<Question> questions;
  final int currentQuestionIndex;
  final Map<TeamId, TeamState> teams;
  final List<Player> players;
  final RoundPhase phase;
  final BuzzState buzzState;
  final int pot;
  final int strikes;
  final TeamId? controllingTeam;
  final TeamId? faceOffTeam;
  final TeamId? faceOffLeader;
  final int faceOffLeaderPoints;

  /// الفريق اللي كسب المواجهة وبيختار يلعب أو يمرّر.
  final TeamId? faceOffWinner;

  /// اللاعب اللي ضاغط حالياً (أزرق عند الكل).
  final String? buzzedPlayerId;

  /// اللاعب اللي دوره يجاوب بمرحلة اللعب أو السرقة.
  final String? turnPlayerId;

  /// الرقم اللي عليه الدور بالمواجهة — بيزيد كل جولة.
  final int faceOffSeat;

  /// مؤشر الدور داخل الفريق بمرحلة اللعب.
  final Map<TeamId, int> turnIndex;

  /// لاعبين جاوبوا غلط — بيضلوا حمر لحد ما يرجع دورهم.
  final Set<String> wrongPlayers;

  /// عدّاد كل جواب غلط بالجولة — منه بيجي صوت الغلط عند الكل.
  final int wrongTicks;

  /// الاتنين غلطوا بالمواجهة — المضيف لازم يبدّل السؤال.
  final bool faceOffFailed;

  /// لاعبين جاوبوا صح — بيضلوا خضر لحد ما يرجع دورهم.
  final Set<String> correctPlayers;

  final TeamId? roundWinner;
  final Award? lastAward;
  final List<int> multipliers;

  /// عدد الأخطاء اللي بتفتح السرقة — ٣ زي البرنامج.
  final int strikesToSteal;

  /// كم ثانية للاعب يجاوب قبل ما ينحسب عليه خطأ.
  final int answerLimitSeconds;

  /// كم ثانية للفائز بالمواجهة ليقرّر: يلعب أو يمرّر.
  final int choiceLimitSeconds;

  /// الوقت الباقي للجواب — صفر يعني ما في عدّاد شغّال.
  final int answerSecondsLeft;

  /// اللاعب ضغط عالشاشة ليجاوب — العدّاد بيوقف لحد ما يحكم المضيف،
  /// حتى ما ينحسب عليه خطأ لأن المضيف ما لحق يدوس.
  final bool clockPaused;

  /// الوقت الباقي لقرار «نلعب أو نمرّر».
  final int choiceSecondsLeft;

  /// صارت اللعبة تمشي — قبلها اللاعب بيقدر يبدّل فريقه.
  final bool matchStarted;

  final bool gameOver;

  const GameState({
    required this.questions,
    this.currentQuestionIndex = 0,
    required this.teams,
    this.players = const [],
    this.phase = RoundPhase.faceOff,
    this.buzzState = BuzzState.open,
    this.pot = 0,
    this.strikes = 0,
    this.controllingTeam,
    this.faceOffTeam,
    this.faceOffLeader,
    this.faceOffLeaderPoints = 0,
    this.faceOffWinner,
    this.buzzedPlayerId,
    this.turnPlayerId,
    this.faceOffSeat = 1,
    this.turnIndex = const {},
    this.wrongPlayers = const {},
    this.wrongTicks = 0,
    this.faceOffFailed = false,
    this.correctPlayers = const {},
    this.roundWinner,
    this.lastAward,
    this.multipliers = const [1, 1, 2, 3],
    this.strikesToSteal = 3,
    this.answerLimitSeconds = defaultAnswerSeconds,
    this.choiceLimitSeconds = choiceSeconds,
    this.answerSecondsLeft = 0,
    this.clockPaused = false,
    this.choiceSecondsLeft = 0,
    this.matchStarted = false,
    this.gameOver = false,
  });

  Question? get currentQuestion =>
      currentQuestionIndex >= 0 && currentQuestionIndex < questions.length
          ? questions[currentQuestionIndex]
          : null;

  int get multiplier {
    if (currentQuestionIndex >= 0 && currentQuestionIndex < multipliers.length) {
      return multipliers[currentQuestionIndex];
    }
    return multipliers.isNotEmpty ? multipliers.last : 1;
  }

  bool get roundOver => phase == RoundPhase.roundEnd;

  bool get isLastRound => currentQuestionIndex >= questions.length - 1;

  TeamId? get stealingTeam =>
      phase == RoundPhase.steal ? controllingTeam?.other : null;

  TeamId? get activeTeam {
    switch (phase) {
      case RoundPhase.faceOff:
      case RoundPhase.faceOffSecond:
        return faceOffTeam;
      case RoundPhase.playOrPass:
        return faceOffWinner;
      case RoundPhase.play:
        return controllingTeam;
      case RoundPhase.steal:
        return stealingTeam;
      default:
        return null;
    }
  }

  TeamId? get leadingTeam {
    final one = teams[TeamId.team1]?.score ?? 0;
    final two = teams[TeamId.team2]?.score ?? 0;
    if (one > two) return TeamId.team1;
    if (two > one) return TeamId.team2;
    return null;
  }

  List<Player> playersOf(TeamId teamId) =>
      players.where((p) => p.teamId == teamId).toList();

  Player? player(String? playerId) {
    for (final p in players) {
      if (p.id == playerId) return p;
    }
    return null;
  }

  /// أكبر رقم موجود بالفريقين — عليه بتلف المواجهة.
  int get maxSeat {
    if (players.isEmpty) return 1;
    var max = players.first.seat;
    for (final p in players.skip(1)) {
      if (p.seat > max) max = p.seat;
    }
    return max;
  }

  /// لاعب المنصة للفريق: صاحب الرقم [faceOffSeat]. إذا الفريق أقصر من
  /// الرقم، منلفّ عليه من الأول حتى يضل في مواجهة.
  Player? podiumPlayer(TeamId teamId) {
    final list = playersOf(teamId);
    if (list.isEmpty) return null;
    for (final p in list) {
      if (p.seat == faceOffSeat) return p;
    }
    return list[(faceOffSeat - 1) % list.length];
  }

  /// اللاعب اللي قدّامه بالفريق التاني — نفس الرقم.
  Player? opponentOf(Player player) {
    for (final p in playersOf(player.teamId.other)) {
      if (p.seat == player.seat) return p;
    }
    return null;
  }

  /// مين مسموح له يضغط هلق — عليهم بيومض الزر.
  Set<String> armedPlayerIds() {
    switch (phase) {
      case RoundPhase.faceOff:
        if (buzzState != BuzzState.open) return const {};
        final ids = <String>{};
        final p1 = podiumPlayer(TeamId.team1)?.id;
        final p2 = podiumPlayer(TeamId.team2)?.id;
        if (p1 != null) ids.add(p1);
        if (p2 != null) ids.add(p2);
        return ids;
      case RoundPhase.faceOffSecond:
        final id = faceOffTeam == null ? null : podiumPlayer(faceOffTeam!)?.id;
        return id == null ? const {} : {id};
      case RoundPhase.playOrPass:
        final id =
            faceOffWinner == null ? null : podiumPlayer(faceOffWinner!)?.id;
        return id == null ? const {} : {id};
      case RoundPhase.play:
      case RoundPhase.steal:
        return turnPlayerId == null ? const {} : {turnPlayerId!};
      default:
        return const {};
    }
  }

  /// حالة شاشة لاعب معيّن.
  PlayerMark markFor(String? playerId) {
    if (playerId == null) return PlayerMark.idle;
    if (playerId == buzzedPlayerId) return PlayerMark.buzzed;
    if (wrongPlayers.contains(playerId)) return PlayerMark.wrong;
    if (correctPlayers.contains(playerId)) return PlayerMark.correct;
    if (armedPlayerIds().contains(playerId)) return PlayerMark.armed;
    return PlayerMark.idle;
  }

  GameState copyWith({
    List<Question>? questions,
    int? currentQuestionIndex,
    Map<TeamId, TeamState>? teams,
    List<Player>? players,
    RoundPhase? phase,
    BuzzState? buzzState,
    int? pot,
    int? strikes,
    Object? controllingTeam = _unset,
    Object? faceOffTeam = _unset,
    Object? faceOffLeader = _unset,
    int? faceOffLeaderPoints,
    Object? faceOffWinner = _unset,
    Object? buzzedPlayerId = _unset,
    Object? turnPlayerId = _unset,
    int? faceOffSeat,
    Map<TeamId, int>? turnIndex,
    Set<String>? wrongPlayers,
    int? wrongTicks,
    bool? faceOffFailed,
    Set<String>? correctPlayers,
    Object? roundWinner = _unset,
    Object? lastAward = _unset,
    List<int>? multipliers,
    int? strikesToSteal,
    int? answerLimitSeconds,
    int? choiceLimitSeconds,
    int? answerSecondsLeft,
    bool? clockPaused,
    int? choiceSecondsLeft,
    bool? matchStarted,
    bool? gameOver,
  }) =>
      GameState(
        questions: questions ?? this.questions,
        currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
        teams: teams ?? this.teams,
        players: players ?? this.players,
        phase: phase ?? this.phase,
        buzzState: buzzState ?? this.buzzState,
        pot: pot ?? this.pot,
        strikes: strikes ?? this.strikes,
        controllingTeam: identical(controllingTeam, _unset)
            ? this.controllingTeam
            : controllingTeam as TeamId?,
        faceOffTeam: identical(faceOffTeam, _unset)
            ? this.faceOffTeam
            : faceOffTeam as TeamId?,
        faceOffLeader: identical(faceOffLeader, _unset)
            ? this.faceOffLeader
            : faceOffLeader as TeamId?,
        faceOffLeaderPoints: faceOffLeaderPoints ?? this.faceOffLeaderPoints,
        faceOffWinner: identical(faceOffWinner, _unset)
            ? this.faceOffWinner
            : faceOffWinner as TeamId?,
        buzzedPlayerId: identical(buzzedPlayerId, _unset)
            ? this.buzzedPlayerId
            : buzzedPlayerId as String?,
        turnPlayerId: identical(turnPlayerId, _unset)
            ? this.turnPlayerId
            : turnPlayerId as String?,
        faceOffSeat: faceOffSeat ?? this.faceOffSeat,
        turnIndex: turnIndex ?? this.turnIndex,
        wrongPlayers: wrongPlayers ?? this.wrongPlayers,
        wrongTicks: wrongTicks ?? this.wrongTicks,
        faceOffFailed: faceOffFailed ?? this.faceOffFailed,
        correctPlayers: correctPlayers ?? this.correctPlayers,
        roundWinner: identical(roundWinner, _unset)
            ? this.roundWinner
            : roundWinner as TeamId?,
        lastAward:
            identical(lastAward, _unset) ? this.lastAward : lastAward as Award?,
        multipliers: multipliers ?? this.multipliers,
        strikesToSteal: strikesToSteal ?? this.strikesToSteal,
        answerLimitSeconds: answerLimitSeconds ?? this.answerLimitSeconds,
        choiceLimitSeconds: choiceLimitSeconds ?? this.choiceLimitSeconds,
        answerSecondsLeft: answerSecondsLeft ?? this.answerSecondsLeft,
        clockPaused: clockPaused ?? this.clockPaused,
        choiceSecondsLeft: choiceSecondsLeft ?? this.choiceSecondsLeft,
        matchStarted: matchStarted ?? this.matchStarted,
        gameOver: gameOver ?? this.gameOver,
      );

  Map<String, dynamic> toJson() => {
        'questions': questions.map((q) => q.toJson()).toList(),
        'currentQuestionIndex': currentQuestionIndex,
        'teams': {
          for (final entry in teams.entries) entry.key.wire: entry.value.toJson(),
        },
        'players': players.map((p) => p.toJson()).toList(),
        'phase': phase.wire,
        'buzzState': buzzState.wire,
        'pot': pot,
        'strikes': strikes,
        'controllingTeam': controllingTeam?.wire,
        'faceOffTeam': faceOffTeam?.wire,
        'faceOffLeader': faceOffLeader?.wire,
        'faceOffLeaderPoints': faceOffLeaderPoints,
        'faceOffWinner': faceOffWinner?.wire,
        'buzzedPlayerId': buzzedPlayerId,
        'turnPlayerId': turnPlayerId,
        'faceOffSeat': faceOffSeat,
        'turnIndex': {
          for (final entry in turnIndex.entries) entry.key.wire: entry.value,
        },
        'wrongPlayers': wrongPlayers.toList(),
        'wrongTicks': wrongTicks,
        'faceOffFailed': faceOffFailed,
        'correctPlayers': correctPlayers.toList(),
        'roundWinner': roundWinner?.wire,
        'lastAward': lastAward?.toJson(),
        'multipliers': multipliers,
        'strikesToSteal': strikesToSteal,
        'answerLimitSeconds': answerLimitSeconds,
        'choiceLimitSeconds': choiceLimitSeconds,
        'answerSecondsLeft': answerSecondsLeft,
        'clockPaused': clockPaused,
        'choiceSecondsLeft': choiceSecondsLeft,
        'matchStarted': matchStarted,
        'gameOver': gameOver,
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        questions: (json['questions'] as List<dynamic>)
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentQuestionIndex: json['currentQuestionIndex'] as int? ?? 0,
        teams: {
          for (final entry in (json['teams'] as Map<String, dynamic>).entries)
            TeamIdX.fromWire(entry.key):
                TeamState.fromJson(entry.value as Map<String, dynamic>),
        },
        players: (json['players'] as List<dynamic>?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        phase: json['phase'] == null
            ? RoundPhase.faceOff
            : RoundPhaseX.fromWire(json['phase'] as String),
        buzzState: json['buzzState'] == null
            ? BuzzState.open
            : BuzzStateX.fromWire(json['buzzState'] as String),
        pot: json['pot'] as int? ?? 0,
        strikes: json['strikes'] as int? ?? 0,
        controllingTeam: _teamIdOrNull(json['controllingTeam']),
        faceOffTeam: _teamIdOrNull(json['faceOffTeam']),
        faceOffLeader: _teamIdOrNull(json['faceOffLeader']),
        faceOffLeaderPoints: json['faceOffLeaderPoints'] as int? ?? 0,
        faceOffWinner: _teamIdOrNull(json['faceOffWinner']),
        buzzedPlayerId: json['buzzedPlayerId'] as String?,
        turnPlayerId: json['turnPlayerId'] as String?,
        faceOffSeat: json['faceOffSeat'] as int? ?? 1,
        turnIndex: json['turnIndex'] == null
            ? const {}
            : {
                for (final entry
                    in (json['turnIndex'] as Map<String, dynamic>).entries)
                  TeamIdX.fromWire(entry.key): entry.value as int,
              },
        wrongPlayers: _stringSet(json['wrongPlayers']),
        wrongTicks: json['wrongTicks'] as int? ?? 0,
        faceOffFailed: json['faceOffFailed'] as bool? ?? false,
        correctPlayers: _stringSet(json['correctPlayers']),
        roundWinner: _teamIdOrNull(json['roundWinner']),
        lastAward: json['lastAward'] == null
            ? null
            : Award.fromJson(json['lastAward'] as Map<String, dynamic>),
        multipliers: (json['multipliers'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [1, 1, 2, 3],
        strikesToSteal: json['strikesToSteal'] as int? ?? 3,
        answerLimitSeconds:
            json['answerLimitSeconds'] as int? ?? defaultAnswerSeconds,
        choiceLimitSeconds: json['choiceLimitSeconds'] as int? ?? choiceSeconds,
        answerSecondsLeft: json['answerSecondsLeft'] as int? ?? 0,
        clockPaused: json['clockPaused'] as bool? ?? false,
        choiceSecondsLeft: json['choiceSecondsLeft'] as int? ?? 0,
        matchStarted: json['matchStarted'] as bool? ?? false,
        gameOver: json['gameOver'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameState &&
        listEq(other.questions, questions) &&
        other.currentQuestionIndex == currentQuestionIndex &&
        mapEq(other.teams, teams) &&
        listEq(other.players, players) &&
        other.phase == phase &&
        other.buzzState == buzzState &&
        other.pot == pot &&
        other.strikes == strikes &&
        other.controllingTeam == controllingTeam &&
        other.faceOffTeam == faceOffTeam &&
        other.faceOffLeader == faceOffLeader &&
        other.faceOffLeaderPoints == faceOffLeaderPoints &&
        other.faceOffWinner == faceOffWinner &&
        other.buzzedPlayerId == buzzedPlayerId &&
        other.turnPlayerId == turnPlayerId &&
        other.faceOffSeat == faceOffSeat &&
        mapEq(other.turnIndex, turnIndex) &&
        setEq(other.wrongPlayers, wrongPlayers) &&
        other.wrongTicks == wrongTicks &&
        other.faceOffFailed == faceOffFailed &&
        setEq(other.correctPlayers, correctPlayers) &&
        other.roundWinner == roundWinner &&
        other.lastAward == lastAward &&
        listEq(other.multipliers, multipliers) &&
        other.strikesToSteal == strikesToSteal &&
        other.answerLimitSeconds == answerLimitSeconds &&
        other.choiceLimitSeconds == choiceLimitSeconds &&
        other.answerSecondsLeft == answerSecondsLeft &&
        other.clockPaused == clockPaused &&
        other.choiceSecondsLeft == choiceSecondsLeft &&
        other.matchStarted == matchStarted &&
        other.gameOver == gameOver;
  }

  @override
  int get hashCode => Object.hashAll([
        Object.hashAll(questions),
        currentQuestionIndex,
        _mapHash(teams),
        Object.hashAll(players),
        phase,
        buzzState,
        pot,
        strikes,
        controllingTeam,
        faceOffTeam,
        faceOffLeader,
        faceOffLeaderPoints,
        faceOffWinner,
        buzzedPlayerId,
        turnPlayerId,
        faceOffSeat,
        _mapHash(turnIndex),
        _setHash(wrongPlayers),
        wrongTicks,
        faceOffFailed,
        _setHash(correctPlayers),
        roundWinner,
        lastAward,
        Object.hashAll(multipliers),
        strikesToSteal,
        answerLimitSeconds,
        choiceLimitSeconds,
        answerSecondsLeft,
        clockPaused,
        choiceSecondsLeft,
        matchStarted,
        gameOver,
      ]);
}

TeamId? _teamIdOrNull(Object? value) =>
    value == null ? null : TeamIdX.fromWire(value as String);

Set<String> _stringSet(Object? value) => value == null
    ? const <String>{}
    : (value as List<dynamic>).map((e) => e as String).toSet();

TeamId? _buzzedTeam(BuzzState buzzState) {
  switch (buzzState) {
    case BuzzState.lockedTeam1:
      return TeamId.team1;
    case BuzzState.lockedTeam2:
      return TeamId.team2;
    default:
      return null;
  }
}

extension GameStateDerived on GameState {
  TeamId? buzzedTeam() => _buzzedTeam(buzzState);

  /// نسخة الحالة اللي بتنبعت لأجهزة اللاعبين: بدون نص السؤال وبدون نصوص
  /// الأجوبة المخفية. اللاعب بيسمع السؤال من المضيف، وبيشوف خانات مرقّمة بس.
  GameState maskedForPlayers() => copyWith(
        // نص السؤال ما بيوصل ولا جهاز لاعب — بيسمعوه من المضيف بس.
        questions: questions.map((q) => _maskQuestion(q, hideText: true)).toList(),
      );
}

Question _maskQuestion(Question question, {required bool hideText}) =>
    question.copyWith(
      text: hideText ? '' : question.text,
      // الأجوبة المخفية ما بتنبعت أبداً — اللوح بيعرض خانات فاضية.
      answers: question.answers
          .map((a) => a.revealed ? a : a.copyWith(text: ''))
          .toList(),
    );

bool listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

bool setEq<T>(Set<T> a, Set<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

int _mapHash(Map<Object?, Object?> map) =>
    map.entries.fold(0, (acc, e) => acc ^ Object.hash(e.key, e.value));

int _setHash(Set<Object?> set) => set.fold(0, (acc, e) => acc ^ e.hashCode);
