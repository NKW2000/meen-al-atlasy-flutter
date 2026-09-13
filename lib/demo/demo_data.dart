/// حالة لعبة مزيّفة لمعرض الشاشات — نفس شكل الحالة الحقيقية، بس بدون
/// شبكة ولا محرّك. كل شاشة بالمعرض بتاخد نسخة منها بالمرحلة اللي بدها ياها.
///
/// منفّذ عن `demo/DemoData.kt` بالمشروع الأصلي (Kotlin).
library;

import '../game/models.dart';

const List<Player> demoPlayers = [
  Player(id: 'a1', name: 'عبد الرحمن', teamId: TeamId.team1, seat: 1),
  Player(id: 'a2', name: 'هناء', teamId: TeamId.team1, seat: 2),
  Player(id: 'a3', name: 'زيد', teamId: TeamId.team1, seat: 3),
  Player(id: 'b1', name: 'ليلى', teamId: TeamId.team2, seat: 1),
  Player(id: 'b2', name: 'سامر', teamId: TeamId.team2, seat: 2),
];

const List<(String, int)> _demoAnswers = [
  ('يشيّكوا الموبايل', 40),
  ('يشربوا قهوة', 28),
  ('يغسلوا وجّهم', 16),
  ('يصلّوا', 9),
  ('يفتحوا الشباك', 5),
  ('يرجعوا يناموا', 2),
  ('يفتحوا التلفزيون', 2),
];

GameState demoState({
  RoundPhase phase = RoundPhase.play,
  int revealed = 1,
  bool matchStarted = true,
  bool gameOver = false,
  int strikes = 2,
  // اللاعب ما بيشوف نص السؤال ولا الأجوبة المخفية — نفس `maskedForPlayers`.
  bool maskQuestion = false,
}) {
  final answers = [
    for (final (index, (text, points)) in _demoAnswers.indexed)
      Answer(
        text: index < revealed || !maskQuestion ? text : '',
        points: index < revealed || !maskQuestion ? points : 0,
        revealed: index < revealed,
      ),
  ];

  return GameState(
    questions: [
      Question(
        id: 'demo',
        text: maskQuestion ? '' : 'اذكر شي بيعمله الناس أول ما يصحوا من النوم',
        answers: answers,
        category: 'عام',
      ),
    ],
    players: demoPlayers,
    teams: const {
      TeamId.team1: TeamState(id: TeamId.team1, name: 'نمور الشام', score: 140, connected: true),
      TeamId.team2: TeamState(id: TeamId.team2, name: 'صقور البحر', score: 95, connected: true),
    },
    phase: phase,
    controllingTeam: TeamId.team1,
    faceOffTeam: TeamId.team1,
    faceOffWinner: TeamId.team1,
    turnPlayerId: switch (phase) {
      RoundPhase.play || RoundPhase.steal => 'a2',
      _ => null,
    },
    buzzState: phase == RoundPhase.faceOff ? BuzzState.open : BuzzState.closed,
    pot: 40,
    strikes: strikes,
    answerSecondsLeft: phase == RoundPhase.play ? 7 : 0,
    choiceSecondsLeft: phase == RoundPhase.playOrPass ? 4 : 0,
    roundWinner: TeamId.team1,
    matchStarted: matchStarted,
    gameOver: gameOver,
  );
}
