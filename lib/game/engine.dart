/// محرك قواعد اللعبة — Dart خالص (بدون أي اعتماد على Flutter).
/// المضيف هو الوحيد اللي بيشغّل هالمحرك؛ أجهزة اللاعبين بس بتستقبل الحالة.
///
/// كل لاعب = جهاز. تسلسل الجولة زي البرنامج:
/// 1. **المواجهة**: لاعب المنصة من كل فريق بس بيقدر يضغط. أول ضغطة بتجاوب؛
///    الجواب رقم ١ بياخد اللوح فوراً، وإلا الفريق التاني بياخد فرصة يتفوّق.
/// 2. **اللعب**: الفريق اللي فاز بالمواجهة بيجاوب **لاعب ورا لاعب بالدور** —
///    اللي جاوب ما بيرجع دوره إلا لما يخلّص كل زمايله. كل غلط = X، وثلاث X
///    بتفتح فرصة السرقة.
/// 3. **السرقة**: لاعب المنصة من الفريق المقابل عنده محاولة وحدة.
/// 4. نقاط الجولة بتتضرب بمضاعف الجولة وبتروح لفريق واحد بس.
///
/// لاعب المنصة بيتغير كل جولة (`podiumSeat`) — زي ما بيتبدلوا عالمنصة
/// بالبرنامج.
library;

import 'events.dart';
import 'models.dart';

class GameEngine {
  GameState _state;

  GameEngine(GameState initial) : _state = initial;

  GameState get state => _state;

  static const int defaultStrikesToSteal = 3;

  /// لعبة جديدة من الصفر — بدون لاعبين ولا نقاط ولا جولات قديمة.
  void reset(GameState newState) {
    _state = newState;
  }

  GameState apply(GameEvent event) {
    _state = switch (event) {
      Buzz() => _handleBuzz(event),
      JudgeCorrect() => _handleCorrect(event.answerIndex),
      JudgeWrong() => _handleWrong(),
      ChooseControl() => _handleChoice(event.play),
      NextRound() => _handleNextRound(),
      PlayerJoined() => _handlePlayerJoined(event),
      PlayerLeft() => _handlePlayerLeft(event),
      PlayerMoved() => _handlePlayerMoved(event),
      StartGame() => _state.copyWith(matchStarted: true),
      ReplaceQuestion() => _handleReplaceQuestion(event.question),
      Tick() => _handleTick(),
      EndGame() => _state.copyWith(
          phase: RoundPhase.gameOver,
          gameOver: true,
          buzzState: BuzzState.closed,
          buzzedPlayerId: null,
          turnPlayerId: null,
        ),
    };
    // أي حدث غير الضغطة والثانية بيرجّع العدّاد يمشي.
    if (event is! Buzz && event is! Tick) {
      _state = _state.copyWith(clockPaused: false);
    }
    return _state;
  }

  // ------------------------------------------------------------------ الضغط

  GameState _handleBuzz(Buzz event) {
    final player = _state.player(event.playerId);
    if (player == null) return _state;
    if (!_state.armedPlayerIds().contains(event.playerId)) return _state;

    switch (_state.phase) {
      case RoundPhase.faceOff:
        if (_state.buzzState != BuzzState.open) return _state;
        final locked = switch (player.teamId) {
          TeamId.team1 => BuzzState.lockedTeam1,
          TeamId.team2 => BuzzState.lockedTeam2,
        };
        // الضغطة بتشغّل وقت الجواب (طلب المستخدم — بالأصل كانت توقفه):
        // اللاعب لازم يجاوب قبل ما يخلص، وإلا بينحسب غلط والدور للخصم.
        return _state.copyWith(
          buzzState: locked,
          faceOffTeam: player.teamId,
          buzzedPlayerId: player.id,
          answerSecondsLeft: _state.answerLimitSeconds,
          clockPaused: false,
        );

      // بمراحل اللعب الضغطة بتوضّح إنه اللاعب عم يجاوب هلق وبتوقف
      // العدّاد — الوقت ما بيكمّل وهو مستني حكم المضيف.
      case RoundPhase.faceOffSecond:
      case RoundPhase.play:
      case RoundPhase.steal:
        return _state.copyWith(
          buzzedPlayerId: player.id,
          clockPaused: true,
        );

      default:
        return _state;
    }
  }

  /// سؤال جديد لنفس الجولة — بيرجّع اللوح والأخطاء والمواجهة من الصفر.
  /// بينستعمل لما الاتنين يغلطوا والمضيف يقرر يبدّل السؤال.
  GameState _handleReplaceQuestion(Question question) {
    final questions = List<Question>.of(_state.questions);
    if (_state.currentQuestionIndex < 0 ||
        _state.currentQuestionIndex >= questions.length) {
      return _state;
    }
    questions[_state.currentQuestionIndex] = question;
    return _state.copyWith(
      questions: questions,
      phase: RoundPhase.faceOff,
      buzzState: BuzzState.open,
      buzzedPlayerId: null,
      turnPlayerId: null,
      faceOffTeam: null,
      faceOffWinner: null,
      faceOffLeader: null,
      faceOffLeaderPoints: 0,
      controllingTeam: null,
      faceOffFailed: false,
      strikes: 0,
      pot: 0,
      wrongPlayers: const {},
      correctPlayers: const {},
      answerSecondsLeft: 0,
      choiceSecondsLeft: 0,
      lastAward: null,
      roundWinner: null,
    );
  }

  // ------------------------------------------------------------- حكم المضيف

  /// اللاعب اللي المضيف عم يحكم على جوابه هلق.
  String? _answeringPlayerId() {
    switch (_state.phase) {
      case RoundPhase.faceOff:
        return _state.buzzedPlayerId;
      case RoundPhase.faceOffSecond:
        return _state.buzzedPlayerId ??
            (_state.faceOffTeam == null
                ? null
                : _state.podiumPlayer(_state.faceOffTeam!)?.id);
      case RoundPhase.play:
      case RoundPhase.steal:
        return _state.turnPlayerId;
      default:
        return null;
    }
  }

  /// بعد المواجهة: الفائز بيلعب اللوح أو بيمرّرو للفريق التاني.
  GameState _handleChoice(bool play) {
    if (_state.phase != RoundPhase.playOrPass) return _state;
    final winner = _state.faceOffWinner;
    if (winner == null) return _state;
    return _state.startPlay(play ? winner : winner.other);
  }

  GameState _handleCorrect(int answerIndex) {
    final question = _state.currentQuestion;
    if (question == null) return _state;
    if (answerIndex < 0 || answerIndex >= question.answers.length) {
      return _state;
    }
    final answer = question.answers[answerIndex];
    if (answer.revealed) return _state;

    switch (_state.phase) {
      case RoundPhase.faceOff:
        return _faceOffCorrect(answerIndex, answer, first: true);
      case RoundPhase.faceOffSecond:
        return _faceOffCorrect(answerIndex, answer, first: false);
      case RoundPhase.play:
        return _playCorrect(answerIndex, answer);
      case RoundPhase.steal:
        return _stealCorrect(answerIndex, answer);
      // بعد ما تنتهي الجولة المضيف بيكشف الباقي بدون نقاط.
      case RoundPhase.roundEnd:
        return _reveal(answerIndex);
      default:
        return _state;
    }
  }

  GameState _faceOffCorrect(int index, Answer answer, {required bool first}) {
    final team = _state.faceOffTeam;
    if (team == null) return _state;
    final revealed = _reveal(index)
        .copyWith(pot: _state.pot + answer.points)
        .markCorrect(_answeringPlayerId());

    if (first) {
      // جواب رقم ١ بياخد اللوح على طول، غيره بيفتح فرصة للفريق التاني.
      if (index == 0) {
        return revealed.offerChoice(team);
      }
      return revealed.copyWith(
        phase: RoundPhase.faceOffSecond,
        buzzState: BuzzState.closed,
        faceOffTeam: team.other,
        faceOffLeader: team,
        faceOffLeaderPoints: answer.points,
        buzzedPlayerId: null,
      );
    }

    final leader = revealed.faceOffLeader;
    final TeamId winner;
    if (leader == null) {
      winner = team;
    } else if (answer.points > revealed.faceOffLeaderPoints) {
      winner = team;
    } else {
      winner = leader;
    }
    return revealed.offerChoice(winner);
  }

  GameState _playCorrect(int index, Answer answer) {
    final team = _state.controllingTeam;
    if (team == null) return _state;
    final revealed = _reveal(index)
        .copyWith(pot: _state.pot + answer.points)
        .markCorrect(_answeringPlayerId());
    return revealed.allRevealed()
        ? revealed.award(team, stolen: false)
        : revealed.advanceTurn(team);
  }

  GameState _stealCorrect(int index, Answer answer) {
    final thief = _state.stealingTeam;
    if (thief == null) return _state;
    return _reveal(index)
        .copyWith(pot: _state.pot + answer.points)
        .markCorrect(_answeringPlayerId())
        .award(thief, stolen: true);
  }

  GameState _handleWrong() {
    final answering = _answeringPlayerId();
    switch (_state.phase) {
      case RoundPhase.faceOff:
        final team = _state.faceOffTeam;
        if (team == null) return _state;
        // الخصم بيبلّش من نفس الوقت الكامل — مش من الباقي.
        return _state.markWrong(answering).copyWith(
              phase: RoundPhase.faceOffSecond,
              buzzState: BuzzState.closed,
              faceOffTeam: team.other,
              buzzedPlayerId: null,
              faceOffFailed: false,
              answerSecondsLeft: _state.answerLimitSeconds,
            );

      case RoundPhase.faceOffSecond:
        final marked = _state.markWrong(answering);
        final leader = marked.faceOffLeader;
        if (leader != null) {
          return marked.offerChoice(leader);
        }
        // الاتنين غلطوا — منرجّع الزر مفتوح لنفس السؤال.
        // ما في لاعبين تانيين ينزلوا عالمنصة — منرجّع الزر
        // لنفس الاتنين على نفس السؤال بدل ما تعلق اللعبة.
        return marked.copyWith(
          phase: RoundPhase.faceOff,
          buzzState: BuzzState.open,
          faceOffTeam: null,
          buzzedPlayerId: null,
          answerSecondsLeft: 0,
          wrongPlayers: const {},
          // الدور بينتقل للرقم اللي بعده، والمضيف بيبدّل السؤال.
          faceOffSeat: marked.nextSeat(),
          faceOffFailed: true,
        );

      case RoundPhase.play:
        final team = _state.controllingTeam;
        if (team == null) return _state;
        final strikes = _state.strikes + 1;
        final marked = _state.markWrong(answering).copyWith(strikes: strikes);
        return strikes >= _state.strikesToSteal
            ? marked.openSteal(team)
            : marked.advanceTurn(team);

      case RoundPhase.steal:
        final owner = _state.controllingTeam;
        if (owner == null) return _state;
        return _state.markWrong(answering).award(owner, stolen: false);

      default:
        return _state;
    }
  }

  /// ثانية مرقت. وقت القرار لما يخلص بيلعب الفريق الفائز، ووقت الجواب
  /// لما يخلص بينحسب خطأ زي أي جواب غلط.
  GameState _handleTick() {
    // لاعب ضاغط ومستني حكم — العدّاد واقف.
    if (_state.clockPaused) return _state;

    if (_state.choiceSecondsLeft > 0) {
      final left = _state.choiceSecondsLeft - 1;
      if (left > 0) {
        return _state.copyWith(choiceSecondsLeft: left);
      }
      // ما قرر بالوقت — منعتبرها «نلعب».
      _state = _state.copyWith(choiceSecondsLeft: 0);
      return _handleChoice(true);
    }

    if (_state.answerSecondsLeft > 0) {
      final left = _state.answerSecondsLeft - 1;
      if (left > 0) {
        return _state.copyWith(answerSecondsLeft: left);
      }
      _state = _state.copyWith(answerSecondsLeft: 0);
      return _handleWrong();
    }

    return _state;
  }

  // ---------------------------------------------------------- انتقال الجولات

  GameState _handleNextRound() {
    // بين الجولات بتظهر النتيجة عند الكل، وبعدين بتبلّش الجولة الجاية.
    if (_state.phase == RoundPhase.roundEnd) {
      return _state.copyWith(
        phase: RoundPhase.scoreboard,
        buzzState: BuzzState.closed,
      );
    }

    final nextIndex = _state.currentQuestionIndex + 1;
    if (nextIndex >= _state.questions.length) {
      return _state.copyWith(
        phase: RoundPhase.gameOver,
        gameOver: true,
        buzzState: BuzzState.closed,
        buzzedPlayerId: null,
        turnPlayerId: null,
      );
    }

    return _state.copyWith(
      currentQuestionIndex: nextIndex,
      phase: RoundPhase.faceOff,
      buzzState: BuzzState.open,
      pot: 0,
      strikes: 0,
      controllingTeam: null,
      faceOffTeam: null,
      faceOffLeader: null,
      faceOffLeaderPoints: 0,
      buzzedPlayerId: null,
      turnPlayerId: null,
      wrongPlayers: const {},
      correctPlayers: const {},
      roundWinner: null,
      faceOffWinner: null,
      faceOffFailed: false,
      faceOffSeat: _state.nextSeat(),
    );
  }

  // --------------------------------------------------------------- اللاعبين

  GameState _handlePlayerJoined(PlayerJoined event) {
    final existing = _state.player(event.playerId);
    final List<Player> players;
    if (existing == null) {
      final seat = _state.playersOf(event.teamId).length + 1;
      players = [
        ..._state.players,
        Player(id: event.playerId, name: event.name, teamId: event.teamId, seat: seat),
      ];
    } else {
      players = _state.players.map((p) {
        if (p.id != event.playerId) return p;
        return p.copyWith(
          name: event.name.trim().isEmpty ? p.name : event.name,
          connected: true,
        );
      }).toList();
    }
    return _state.copyWith(players: players).renumbered().withTeamsConnected();
  }

  GameState _handlePlayerLeft(PlayerLeft event) {
    final players = _state.players
        .map((p) => p.id == event.playerId ? p.copyWith(connected: false) : p)
        .toList();
    final teams = Map<TeamId, TeamState>.of(_state.teams);
    for (final teamId in TeamId.values) {
      final anyConnected = players.any((p) => p.teamId == teamId && p.connected);
      final team = teams[teamId];
      if (team != null) teams[teamId] = team.copyWith(connected: anyConnected);
    }
    final next = _state.copyWith(players: players, teams: teams);
    // اللي انقطع هو صاحب الدور بمرحلة اللعب؟ الدور بينتقل فوراً لزميله
    // المتّصل بدل ما يضل الفريق ناطر عدّاد لاعب مش موجود.
    final team = next.controllingTeam;
    if (next.phase == RoundPhase.play &&
        team != null &&
        next.turnPlayerId == event.playerId &&
        next.playersOf(team).any((p) => p.connected)) {
      return next.advanceTurn(team);
    }
    return next;
  }

  /// نقل لاعب لفريق تاني — وبعدها منرقّم الفريقين من جديد.
  GameState _handlePlayerMoved(PlayerMoved event) {
    final player = _state.player(event.playerId);
    if (player == null) return _state;
    if (player.teamId == event.teamId) return _state;
    final moved = _state.players
        .map((p) => p.id == event.playerId ? p.copyWith(teamId: event.teamId) : p)
        .toList();
    return _state.copyWith(players: moved).renumbered().withTeamsConnected();
  }

  // ----------------------------------------------------------------- مساعدات

  GameState _reveal(int index) => _state.mapCurrentQuestion((question) {
        final answers = List<Answer>.of(question.answers);
        answers[index] = answers[index].copyWith(revealed: true);
        return question.copyWith(answers: answers);
      });
}

/// بيرقّم لاعبين كل فريق من ١ بترتيب انضمامهم، وباقي المساعدات الخاصة
/// بمحرك اللعبة — عن نفس الـ extension functions الخاصة بـ GameEngine.kt.
extension _Engine on GameState {
  GameState renumbered() {
    final counters = <TeamId, int>{};
    final numbered = players.map((player) {
      final next = (counters[player.teamId] ?? 0) + 1;
      counters[player.teamId] = next;
      return player.copyWith(seat: next);
    }).toList();
    return copyWith(players: numbered);
  }

  /// حالة اتصال الفريق = في لاعب متصل واحد عالأقل.
  GameState withTeamsConnected() {
    final updated = Map<TeamId, TeamState>.of(teams);
    for (final teamId in TeamId.values) {
      final any = players.any((p) => p.teamId == teamId && p.connected);
      final team = updated[teamId];
      if (team != null) updated[teamId] = team.copyWith(connected: any);
    }
    return copyWith(teams: updated);
  }

  GameState mapCurrentQuestion(Question Function(Question) transform) {
    final question = currentQuestion;
    if (question == null) return this;
    final updated = List<Question>.of(questions);
    updated[currentQuestionIndex] = transform(question);
    return copyWith(questions: updated);
  }

  bool allRevealed() => currentQuestion?.answers.every((a) => a.revealed) ?? false;

  GameState markCorrect(String? playerId) {
    if (playerId == null) return this;
    return copyWith(
      correctPlayers: {...correctPlayers, playerId},
      wrongPlayers: {...wrongPlayers}..remove(playerId),
    );
  }

  GameState markWrong(String? playerId) => copyWith(
        // العدّاد بيزيد دايماً — حتى لو ما عرفنا مين اللاعب — حتى يشتغل الصوت.
        wrongTicks: wrongTicks + 1,
        wrongPlayers: playerId == null ? wrongPlayers : {...wrongPlayers, playerId},
        correctPlayers: playerId == null
            ? correctPlayers
            : ({...correctPlayers}..remove(playerId)),
      );

  /// الفائز بالمواجهة بيستنى قرار: يلعب أو يمرّر — بالوقت اللي حطّه المضيف.
  GameState offerChoice(TeamId winner) => copyWith(
        faceOffFailed: false,
        phase: RoundPhase.playOrPass,
        faceOffWinner: winner,
        faceOffTeam: null,
        buzzState: BuzzState.closed,
        buzzedPlayerId: null,
        turnPlayerId: podiumPlayer(winner)?.id,
        choiceSecondsLeft: choiceLimitSeconds,
        answerSecondsLeft: 0,
      );

  /// بداية مرحلة اللعب: الدور بينتقل للاعب اللي بعد لاعب المنصة.
  GameState startPlay(TeamId team) {
    final next = copyWith(
      phase: RoundPhase.play,
      controllingTeam: team,
      buzzState: BuzzState.closed,
      strikes: 0,
      faceOffTeam: null,
      buzzedPlayerId: null,
      turnIndex: {...turnIndex, team: podiumIndexOf(team)},
    ).advanceTurn(team);

    // لوح صغير ممكن يخلص من المواجهة نفسها.
    return next.allRevealed() ? next.award(team, stolen: false) : next;
  }

  /// الدور بينتقل للاعب اللي بعده بالفريق — واللي جاوب بيستنى دورة كاملة.
  GameState advanceTurn(TeamId team) {
    final list = playersOf(team);
    if (list.isEmpty) return copyWith(turnPlayerId: null, buzzedPlayerId: null);

    final current = turnIndex[team] ?? 0;
    final nextIndex = nextConnectedIndex(list, current);
    final nextPlayer = list[nextIndex];
    return copyWith(
      turnIndex: {...turnIndex, team: nextIndex},
      turnPlayerId: nextPlayer.id,
      buzzedPlayerId: null,
      answerSecondsLeft: answerLimitSeconds,
      choiceSecondsLeft: 0,
      // أول ما يرجع دوره بترجع شاشته حيادية.
      wrongPlayers: {...wrongPlayers}..remove(nextPlayer.id),
      correctPlayers: {...correctPlayers}..remove(nextPlayer.id),
    );
  }

  /// فرصة السرقة بتروح للاعب المنصة عند الفريق المقابل.
  GameState openSteal(TeamId controlling) {
    final thief = controlling.other;
    final podium = podiumPlayer(thief);
    return copyWith(
      phase: RoundPhase.steal,
      buzzState: BuzzState.closed,
      buzzedPlayerId: null,
      turnPlayerId: podium?.id,
      answerSecondsLeft: answerLimitSeconds,
      choiceSecondsLeft: 0,
      turnIndex: podium == null ? turnIndex : {...turnIndex, thief: podiumIndexOf(thief)},
      wrongPlayers: podium == null ? wrongPlayers : ({...wrongPlayers}..remove(podium.id)),
      correctPlayers:
          podium == null ? correctPlayers : ({...correctPlayers}..remove(podium.id)),
    );
  }

  /// مكان لاعب المنصة باللستة — منه بيبلّش الدور.
  int podiumIndexOf(TeamId team) {
    final list = playersOf(team);
    final podium = podiumPlayer(team);
    if (podium == null) return 0;
    final index = list.indexOf(podium);
    return index < 0 ? 0 : index;
  }

  int nextConnectedIndex(List<Player> list, int current) {
    for (var step = 1; step <= list.length; step++) {
      final candidate = (current + step) % list.length;
      if (list[candidate].connected) return candidate;
    }
    return (current + 1) % list.length;
  }

  /// المواجهة بتنتقل للرقم اللي بعده، وبترجع للرقم ١ بعد آخر رقم.
  int nextSeat() => (faceOffSeat % maxSeat) + 1;

  /// بتقفل الجولة: كل النقاط × مضاعف الجولة لفريق واحد، وبتكشف باقي اللوح.
  GameState award(TeamId team, {required bool stolen}) {
    final points = pot * multiplier;
    final updatedTeams = Map<TeamId, TeamState>.of(teams);
    final teamState = updatedTeams[team];
    if (teamState != null) {
      updatedTeams[team] = teamState.copyWith(score: teamState.score + points);
    }
    // اللوح ما بينكشف لحاله — المضيف بيكشف الباقي خانة خانة.
    return copyWith(
      teams: updatedTeams,
      phase: RoundPhase.roundEnd,
      buzzState: BuzzState.closed,
      buzzedPlayerId: null,
      turnPlayerId: null,
      roundWinner: team,
      lastAward: Award(teamId: team, points: points, stolen: stolen),
      answerSecondsLeft: 0,
      choiceSecondsLeft: 0,
    );
  }
}
