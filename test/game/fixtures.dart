import 'package:meen_al_atlasy/game/engine.dart';
import 'package:meen_al_atlasy/game/events.dart';
import 'package:meen_al_atlasy/game/models.dart';

/// لوح من ٤ أجوبة — نفس السؤال بكل الاختبارات حتى تضل الأرقام متوقعة.
Question board([String id = 'q1']) => Question(
      id: id,
      text: 'سؤال $id',
      category: 'عام',
      answers: [
        Answer(text: 'الأول', points: 40),
        Answer(text: 'التاني', points: 30),
        Answer(text: 'التالت', points: 20),
        Answer(text: 'الرابع', points: 10),
      ],
    );

/// ٣ لاعبين لكل فريق: a1,a2,a3 و b1,b2,b3.
List<Player> defaultPlayers([int perTeam = 3]) => [
      for (var i = 1; i <= perTeam; i++)
        Player(id: 'a$i', name: 'لاعب أ$i', teamId: TeamId.team1, seat: i),
      for (var i = 1; i <= perTeam; i++)
        Player(id: 'b$i', name: 'لاعب ب$i', teamId: TeamId.team2, seat: i),
    ];

GameState freshState({
  List<Question>? questions,
  List<int>? multipliers,
  List<Player>? players,
}) =>
    GameState(
      questions: questions ?? [board('q1'), board('q2')],
      multipliers: multipliers ?? [1, 2],
      players: players ?? defaultPlayers(),
      teams: {
        TeamId.team1: TeamState(id: TeamId.team1, name: 'فريق ١', connected: true),
        TeamId.team2: TeamState(id: TeamId.team2, name: 'فريق ٢', connected: true),
      },
    );

extension GameStateScore on GameState {
  int score(TeamId team) => teams[team]!.score;
}

extension EngineHelpers on GameEngine {
  GameState buzz(String playerId) => apply(Buzz(playerId, 0));

  /// بيضغط لاعب المنصة الحالي لهاد الفريق.
  GameState buzzPodium(TeamId team) => buzz(state.podiumPlayer(team)!.id);

  GameState correct(int index) => apply(JudgeCorrect(index));

  GameState wrong() => apply(const JudgeWrong());

  GameState choosePlay() => apply(const ChooseControl(true));

  GameState choosePass() => apply(const ChooseControl(false));

  /// بتوصل اللعبة لمرحلة اللعب مع [team] ماسك اللوح وجواب رقم ١ مكشوف.
  GameState giveControlTo(TeamId team) {
    buzzPodium(team);
    correct(0);
    return choosePlay();
  }
}
