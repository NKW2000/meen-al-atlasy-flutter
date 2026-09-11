/// أحداث اللعبة — منفذة بـ Dart خالص (بدون أي اعتماد على Flutter)
/// عن نفس core-game/GameEvent.kt بالمشروع الأصلي (Kotlin).
library;

import 'models.dart';

sealed class GameEvent {
  const GameEvent();
}

/// بزّة من جهاز لاعب — بتنقبل بس إذا هو المسموح له يضغط هلق.
class Buzz extends GameEvent {
  final String playerId;
  final int atMillis;

  const Buzz(this.playerId, this.atMillis);
}

/// المضيف حكم إنه الجواب صح وكشف الخانة رقم [answerIndex].
class JudgeCorrect extends GameEvent {
  final int answerIndex;

  const JudgeCorrect(this.answerIndex);
}

/// جواب غلط — بالمواجهة بينقل الدور، وباللعب بيزيد خطأ (X).
class JudgeWrong extends GameEvent {
  const JudgeWrong();
}

/// قرار الفريق اللي كسب المواجهة: يلعب اللوح ([play] = true) أو
/// يمرّرو للفريق التاني.
class ChooseControl extends GameEvent {
  final bool play;

  const ChooseControl(this.play);
}

/// الانتقال للجولة التالية (أو للجولة السريعة أو نهاية اللعبة).
class NextRound extends GameEvent {
  const NextRound();
}

class PlayerJoined extends GameEvent {
  final String playerId;
  final String name;
  final TeamId teamId;

  const PlayerJoined(this.playerId, this.name, this.teamId);
}

class PlayerLeft extends GameEvent {
  final String playerId;

  const PlayerLeft(this.playerId);
}

/// المضيف أو اللاعب نفسه بيغيّر فريقه قبل ما تبلّش اللعبة.
class PlayerMoved extends GameEvent {
  final String playerId;
  final TeamId teamId;

  const PlayerMoved(this.playerId, this.teamId);
}

/// المضيف بلّش اللعبة — بعدها ما بيضل حدا يغيّر فريقه.
class StartGame extends GameEvent {
  const StartGame();
}

/// المضيف بدّل سؤال الجولة الحالية بسؤال تاني.
class ReplaceQuestion extends GameEvent {
  final Question question;

  const ReplaceQuestion(this.question);
}

/// ثانية مرقت — بتنقص من وقت الجواب أو وقت القرار.
class Tick extends GameEvent {
  const Tick();
}

class EndGame extends GameEvent {
  const EndGame();
}
