/// جهاز المضيف — مصدر الحقيقة الوحيد. بيشغّل [GameEngine] وبيبثّ كل حالة
/// جديدة لأجهزة اللاعبين. الأجهزة ما بتحسب ولا بتقرر إشي، وبتوصلها نسخة
/// مقنّعة: بدون نص السؤال وبدون نصوص الأجوبة المخفية.
///
/// نفس `HostViewModel.kt` بالمشروع الأصلي (Kotlin)، بفرق واحد جوهري: هناك
/// معرّف نقطة نهاية Nearby ثابت طول عمر الجهاز، وهون معرّف اتصال WebSocket
/// بيتغيّر بكل إعادة اتصال. فمنفصل بين الاتنين بخريطة `endpoint → playerId`
/// (حكم المتحكمات ١) — الحدث القادم من الشبكة بيوصل بمعرّف نقطة النهاية،
/// ومنترجمه لمعرّف اللاعب الثابت قبل ما يوصل للمحرك؛ الرسائل المباشرة
/// (`Assigned`) بترجع لمعرّف نقطة النهاية.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/engine.dart';
import '../game/events.dart';
import '../game/models.dart';
import '../network/host_server.dart';
import '../network/messages.dart';
import '../network/room_beacon.dart';

/// اسم الغرفة الافتراضي — نفس `DEFAULT_ROOM_NAME` بـ`HostViewModel.kt`.
String defaultHostRoomName() => 'غرفة مين الأطليسي';

Question? _noFreshQuestion() => null;

void _noopOnQuestionShown(String _) {}

class HostController extends ChangeNotifier {
  final HostTransport server;
  final RoomBeacon beacon;

  /// حالة بداية لعبة جديدة. بتنستدعى كل مرة بيبلّش فيها المضيف لعبة، فكل
  /// لعبة بتاخد أسئلة جديدة وإعدادات محدّثة وما بتورث لاعبين قدام.
  final GameState Function() newGame;

  /// اسم الغرفة بلستة اللاعبين — بينقرأ كل مرة نبلّش بث.
  final String Function() roomName;

  /// سؤال بديل ما انقرأ — بينستعمل لما المضيف يبدّل السؤال.
  final Question? Function() freshQuestion;

  /// بينسجّل إنه السؤال انقرأ عند المضيف.
  final void Function(String) onQuestionShown;

  final Duration tick;

  HostController({
    required this.server,
    required this.beacon,
    required this.newGame,
    this.roomName = defaultHostRoomName,
    this.freshQuestion = _noFreshQuestion,
    this.onQuestionShown = _noopOnQuestionShown,
    this.tick = const Duration(seconds: 1),
  }) {
    _engine = GameEngine(newGame());
    _sub = server.events.listen(_onClientEvent);
  }

  late GameEngine _engine;
  late final StreamSubscription<ClientEvent> _sub;

  /// كل جهاز متصل = لاعب واحد؛ منستعمل معرّف الاتصال (endpoint) كمفتاح،
  /// ومعرّف اللاعب الثابت كقيمة — والعكس لإرسال رسائل مباشرة لنقطة نهاية.
  final Map<String, String> _endpointToPlayer = {};
  final Map<String, String> _playerToEndpoint = {};

  /// بعد ما تبلّش اللعبة ما بيضل حدا يغيّر فريقه.
  bool _started = false;

  /// حارس ضد نداء `startHosting` مرتين — نفس `_advertising` بالأصل.
  bool _advertising = false;

  String? _lastError;

  /// عدّاد الثواني بيمشي بجهاز المضيف بس.
  Timer? _clockTimer;

  /// آخر سؤال انعرض — حتى ما نسجّله مقروء مرتين.
  String? _shownQuestionId;

  static const int minPlayersPerTeam = 1;

  GameState get state => _engine.state;

  bool get advertising => _advertising;

  String? get lastError => _lastError;

  /// لعبة جديدة: بنسكّر الاتصالات القديمة وبنرجع الحالة من الصفر. بدونها
  /// بيرجع المضيف على نفس اللوبي القديم بنفس اللاعبين والنقاط.
  Future<void> resetSession() async {
    _clockTimer?.cancel();
    _clockTimer = null;
    _started = false;
    _endpointToPlayer.clear();
    _playerToEndpoint.clear();
    await server.stop();
    await beacon.stop();
    _advertising = false;
    _engine.reset(newGame());
    notifyListeners();
  }

  /// لعبة جديدة **بنفس الغرفة**: اللاعبين بيضلوا متصلين وبيرجعوا للوبي
  /// يختاروا فرقهم، والنقاط والأسئلة بتبلّش من جديد. البثّ ما بيوقف —
  /// والمنارة (اللي startGame وقّفها) بترجع تشتغل.
  Future<void> backToLobby() async {
    _clockTimer?.cancel();
    _clockTimer = null;
    _started = false;
    final players = List<Player>.of(_engine.state.players);
    _engine.reset(newGame());
    for (final player in players) {
      _engine.apply(PlayerJoined(player.id, player.name, player.teamId));
    }
    server.broadcast(StateUpdate(state: _engine.state.maskedForPlayers()));
    try {
      await beacon.start(roomName: roomName(), port: server.port);
    } catch (e) {
      _lastError = e.toString();
    }
    notifyListeners();
  }

  Future<void> startHosting() async {
    if (_advertising) return;
    _advertising = true;
    try {
      await server.start();
      await beacon.start(roomName: roomName(), port: server.port);
    } catch (e) {
      _lastError = e.toString();
    }
    notifyListeners();
  }

  /// بيرجّع إذا في سؤال بديل من البنك — أو false إذا ما في.
  bool canChangeQuestion() => freshQuestion() != null;

  /// المضيف بينقل لاعب لفريق تاني — بس قبل ما تبلّش اللعبة.
  void movePlayer(String playerId, TeamId teamId) {
    if (_started) return;
    _applyAndBroadcast(PlayerMoved(playerId, teamId));
    final endpointId = _playerToEndpoint[playerId];
    if (endpointId != null) {
      server.send(endpointId, Assigned(playerId: playerId, teamId: teamId));
    }
  }

  void startGame() {
    _started = true;
    _applyAndBroadcast(const StartGame());
    // المنارة ما عاد لازمة بعد ما بلّشت اللعبة — اللاعبين المتّصلين أصلاً
    // بيضلوا متّصلين، وأي إعادة اتصال بترجع لنفس عنوان المضيف المحفوظ.
    unawaited(beacon.stop());
    _startClock();
    notifyListeners();
  }

  /// بدّل سؤال الجولة — بيرجّع اللوح والمواجهة من الصفر بسؤال تاني.
  void changeQuestion() {
    final question = freshQuestion();
    if (question == null) return;
    _applyAndBroadcast(ReplaceQuestion(question));
  }

  void judgeCorrect(int answerIndex) =>
      _applyAndBroadcast(JudgeCorrect(answerIndex));

  void judgeWrong() => _applyAndBroadcast(const JudgeWrong());

  void nextRound() => _applyAndBroadcast(const NextRound());

  void endGame() {
    _clockTimer?.cancel();
    _clockTimer = null;
    _applyAndBroadcast(const EndGame());
  }

  void dismissError() {
    _lastError = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------ الشبكة

  void _onClientEvent(ClientEvent event) {
    switch (event) {
      case ClientConnected():
        break; // ما في شي نعمله لحد ما توصل رسالة Join.
      case ClientMessageReceived(:final endpointId, :final message):
        _handleClientMessage(endpointId, message);
      case ClientDisconnected(:final endpointId):
        _handleDisconnect(endpointId);
    }
  }

  void _handleClientMessage(String endpointId, ClientMessage message) {
    switch (message) {
      case JoinMessage(:final playerName, :final teamId, :final playerId):
        _addPlayer(endpointId, playerName, teamId, playerId);

      case ChangeTeamMessage(:final teamId):
        // تغيير الفريق مسموح بس قبل ما تبلّش اللعبة.
        final playerId = _endpointToPlayer[endpointId];
        if (playerId != null && !_started) {
          _applyAndBroadcast(PlayerMoved(playerId, teamId));
          server.send(endpointId, Assigned(playerId: playerId, teamId: teamId));
        }

      case BuzzMessage(:final atMillis):
        // منعتمد على معرّف الجهاز المعروف عندنا، مش على اللي الرسالة بتدّعيه.
        final playerId = _endpointToPlayer[endpointId];
        if (playerId == null) return;
        _applyAndBroadcast(Buzz(playerId, atMillis));

      case ChooseMessage(:final play):
        // بس اللاعب اللي المحرك فاتح له القرار بينسمع منه.
        final playerId = _endpointToPlayer[endpointId];
        if (playerId == null || !_engine.state.armedPlayerIds().contains(playerId)) {
          return;
        }
        _applyAndBroadcast(ChooseControl(play));
    }
  }

  /// لاعب جديد انضم، أو قديم رجع بعد انقطاع (حكم المتحكمات ١ب):
  /// 1. إذا الرسالة حاملة [providedPlayerId] وهو لاعب موجود فعلاً — منعيد
  ///    ربطه (نفس المعرّف، بس نقطة نهاية جديدة).
  /// 2. وإلا إذا في لاعب **منقطع** بنفس الاسم — منعيد ربطه هو.
  /// 3. وإلا لاعب جديد كليّاً، معرّفه = معرّف نقطة النهاية.
  void _addPlayer(
    String endpointId,
    String name,
    TeamId? wanted,
    String? providedPlayerId,
  ) {
    String? reattachId;
    if (providedPlayerId != null &&
        _engine.state.player(providedPlayerId) != null) {
      reattachId = providedPlayerId;
    } else {
      for (final p in _engine.state.players) {
        if (!p.connected && p.name == name) {
          reattachId = p.id;
          break;
        }
      }
    }

    final playerId = reattachId ?? endpointId;
    final existing = _engine.state.player(playerId);
    // اللاعب بيختار فريقه؛ إذا ما اختار منحطه بالفريق الأقل عدداً.
    final teamId = wanted ?? existing?.teamId ?? _smallerTeam();

    _endpointToPlayer[endpointId] = playerId;
    _playerToEndpoint[playerId] = endpointId;

    server.send(endpointId, Assigned(playerId: playerId, teamId: teamId));
    _applyAndBroadcast(PlayerJoined(playerId, name, teamId));
  }

  /// اللاعب الجديد بيروح للفريق الأقل عدداً حتى تضل الفرق متوازنة.
  TeamId _smallerTeam() {
    final one = _engine.state.playersOf(TeamId.team1).length;
    final two = _engine.state.playersOf(TeamId.team2).length;
    return two < one ? TeamId.team2 : TeamId.team1;
  }

  void _handleDisconnect(String endpointId) {
    final playerId = _endpointToPlayer.remove(endpointId);
    if (playerId == null) return;
    // ما منشيل _playerToEndpoint هون لأنه إعادة الاتصال ممكن توصل بنقطة
    // نهاية جديدة وتحدّثه أصلاً؛ خريطة قديمة ما بتضرّ لأنها ما بتستعمل
    // إلا لما اللاعب يكون بلستة اللاعبين المتصلين حالياً (movePlayer).
    _applyAndBroadcast(PlayerLeft(playerId));
  }

  // ------------------------------------------------------------------ الساعة

  /// عدّاد الثواني — بيمشي بجهاز المضيف وبينبثّ للكل مع الحالة.
  void _startClock() {
    if (_clockTimer != null) return;
    _clockTimer = Timer.periodic(tick, (timer) {
      final current = _engine.state;
      if (current.gameOver) {
        timer.cancel();
        _clockTimer = null;
        return;
      }
      if (current.answerSecondsLeft > 0 || current.choiceSecondsLeft > 0) {
        _applyAndBroadcast(const Tick());
      }
    });
  }

  void _applyAndBroadcast(GameEvent event) {
    final newState = _engine.apply(event);
    _noteQuestionShown(newState);
    server.broadcast(StateUpdate(state: newState.maskedForPlayers()));
    notifyListeners();
  }

  /// السؤال بينحسب «انقرأ» أول ما يبان عند المضيف باللعبة الشغّالة.
  void _noteQuestionShown(GameState state) {
    if (!state.matchStarted) return;
    final id = state.currentQuestion?.id;
    if (id == null) return;
    if (id == _shownQuestionId) return;
    _shownQuestionId = id;
    onQuestionShown(id);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _clockTimer = null;
    unawaited(_sub.cancel());
    unawaited(server.stop());
    unawaited(beacon.stop());
    super.dispose();
  }
}
