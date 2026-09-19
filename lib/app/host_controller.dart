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

  /// اشتراكنا الحالي على أحداث الشبكة. `HostServer.stop()` بيسكّر
  /// الـ`StreamController` الداخلي و`start()` بيعمل واحد جديد، فلازم
  /// نعيد الاشتراك بعد كل `startHosting()` (مو بس بالمُنشئ) وإلا كل
  /// أحداث اللعبة الجديدة بعد `resetSession()` بتضيع (بند حرج بالمراجعة).
  StreamSubscription<ClientEvent>? _sub;

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

  /// أطول اسم لاعب بينعرض عاللوح — أطول من هيك بينقص.
  static const int maxPlayerName = 20;

  /// بيرجّع إذا كل فريق فيه لاعب متّصل عالأقل — بدونه ما في مواجهة أصلاً.
  bool get canStart {
    if (_started) return false;
    for (final team in TeamId.values) {
      final connected = _engine.state.playersOf(team).where((p) => p.connected).length;
      if (connected < minPlayersPerTeam) return false;
    }
    return true;
  }

  GameState get state => _engine.state;

  bool get advertising => _advertising;

  String? get lastError => _lastError;

  /// لعبة جديدة: بنسكّر الاتصالات القديمة وبنرجع الحالة من الصفر. بدونها
  /// بيرجع المضيف على نفس اللوبي القديم بنفس اللاعبين والنقاط.
  Future<void> resetSession() async {
    _stopClock();
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
  /// والمنارة (اللي startGame وقّفها) بترجع تشتغل — بس إذا كنا أصلاً عم
  /// نستضيف (بند بسيط بالمراجعة؛ `resetSession` هو الطريق الوحيد لوقف
  /// الاستضافة كليّاً).
  Future<void> backToLobby() async {
    _stopClock();
    _started = false;
    _rebuildWithPlayers();
    if (_advertising) {
      try {
        await beacon.start(roomName: roomName(), port: server.port);
      } catch (e) {
        _lastError = 'تعذّر بثّ الغرفة: $e';
      }
    }
    notifyListeners();
  }

  /// اللوبي بيبني الحالة من الإعدادات **الحالية** أول ما يفوت عليه: أسماء
  /// الفرق، الجولات، المضاعفات والوقت بتتعدّل بشاشة الإعدادات بعد
  /// [resetSession]، فبدون هالنداء اللعبة بتبلّش بالإعدادات القديمة
  /// واللاعبين بيشوفوا أسماء فرق غير اللي سمّاها المضيف. اللاعبين
  /// المتّصلين بيضلوا بأماكنهم. بعد ما تبلّش اللعبة ما بيغيّر شي.
  void applySettings() {
    if (_started) return;
    _rebuildWithPlayers();
    notifyListeners();
  }

  /// حالة جديدة من [newGame] مع إعادة انضمام نفس اللاعبين، وبثّها للكل.
  void _rebuildWithPlayers() {
    // بس اللي لسا متّصلين — اللي طلع بنص اللعبة وما رجع ما إلو مكان
    // باللوبي الجديد (كان بيرجع يظهر «متّصل» وجهازه مش موجود).
    final players = _engine.state.players.where((p) => p.connected).toList();
    _engine.reset(newGame());
    for (final player in players) {
      _engine.apply(PlayerJoined(player.id, player.name, player.teamId));
    }
    server.broadcast(StateUpdate(state: _engine.state.maskedForPlayers()));
  }

  Future<void> startHosting() async {
    if (_advertising) return;
    _advertising = true;
    try {
      await server.start();
      // `server.start()` بينشئ دفق أحداث جديد إذا كان القديم انسكّر
      // (مثلاً بعد `resetSession()`) — لازم نعيد الاشتراك وإلا منضل
      // نسمع دفق ميت وكل أحداث اللعبة الجديدة بتضيع بصمت.
      await _sub?.cancel();
      _sub = server.events.listen(_onClientEvent);
      await beacon.start(roomName: roomName(), port: server.port);
    } catch (e) {
      _lastError = 'تعذّر بدء الاستضافة: $e';
      _advertising = false;
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
    // شاشة اللوبي بتعطّل الزر، بس الحارس هون كمان: لعبة بفريق فاضي ما
    // إلها مواجهة وبتعلق عالمنصة.
    if (!canStart) return;
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

  /// [turn] هو [GameState.answerTurn] اللي كانت شاشة المضيف مبنية عليه.
  /// إذا الدور تغيّر بهالأثناء (خلص وقت اللاعب لحاله بنفس اللحظة) المحرك
  /// بيتجاهل الحكم بدل ما ينزل على اللاعب الجديد.
  void judgeCorrect(int answerIndex, {int? turn}) =>
      _applyAndBroadcast(JudgeCorrect(answerIndex, turn: turn));

  void judgeWrong({int? turn}) => _applyAndBroadcast(JudgeWrong(turn: turn));

  void nextRound() => _applyAndBroadcast(const NextRound());

  void endGame() {
    _stopClock();
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

  /// لاعب جديد انضم، أو قديم رجع بعد انقطاع (حكم المتحكمات ١ب، ومعدّل
  /// بمراجعة الحرجة/المهمة #٢-#٣):
  /// 1. إذا الرسالة حاملة [providedPlayerId] وهو لاعب موجود فعلاً، ومسموح
  ///    الرجوع بيه (`_canReattachById` — شوف تعليقها) — منعيد ربطه (نفس
  ///    المعرّف، بس نقطة نهاية جديدة).
  /// 2. وإلا إذا في لاعب **منقطع** بنفس الاسم — منعيد ربطه هو.
  /// 3. وإلا لاعب جديد كليّاً، معرّفه = معرّف نقطة النهاية.
  void _addPlayer(
    String endpointId,
    String rawName,
    TeamId? wanted,
    String? providedPlayerId,
  ) {
    final name = sanitizePlayerName(rawName);
    String? reattachId;
    // نفس الجهاز (نفس نقطة النهاية) بعت Join تاني — مثلاً غيّر اسمه
    // باللوبي. هاد نفس اللاعب مهما كان الاسم، مش لاعب جديد: بدون هالفرع
    // كان بينضاف لاعب تاني بنفس الجهاز وبيضل القديم «متّصل» للأبد.
    final samePlayer = _endpointToPlayer[endpointId];
    if (samePlayer != null && _engine.state.player(samePlayer) != null) {
      reattachId = samePlayer;
    } else if (providedPlayerId != null) {
      final existingById = _engine.state.player(providedPlayerId);
      if (existingById != null && _canReattachById(existingById, name)) {
        reattachId = providedPlayerId;
      }
    }
    reattachId ??= _disconnectedPlayerByName(name);

    // بعد ما تبلّش اللعبة ما في انضمام جديد — بس رجوع لاعب انقطع. لاعب
    // جديد بنص الجولة كان بياخد رقم وبيغيّر مين عالمنصة، وممكن يكون أي
    // جهاز غريب عالشبكة. منسكّر اتصاله وبيشوف عنده إنه انقطع.
    if (reattachId == null && _started) {
      unawaited(server.close(endpointId));
      return;
    }

    final playerId = reattachId ?? endpointId;
    final existing = _engine.state.player(playerId);
    // اللاعب بيختار فريقه؛ إذا ما اختار منحطه بالفريق الأقل عدداً.
    final teamId = wanted ?? existing?.teamId ?? _smallerTeam();

    _endpointToPlayer[endpointId] = playerId;
    // إذا في نقطة نهاية قديمة كانت مربوطة بنفس اللاعب — مثلاً رجع بنقطة
    // نهاية جديدة قبل ما توصلنا إشعار انقطاع القديمة لسا (سباق شبكة عادي)
    // — منفصلها فوراً حتى ما يوصل منها قطع اتصال متأخر يطرد اللاعب الحيّ
    // الجديد (بند مهم #٣ بالمراجعة).
    final oldEndpoint = _playerToEndpoint[playerId];
    if (oldEndpoint != null && oldEndpoint != endpointId) {
      _endpointToPlayer.remove(oldEndpoint);
    }
    _playerToEndpoint[playerId] = endpointId;

    server.send(endpointId, Assigned(playerId: playerId, teamId: teamId));
    _applyAndBroadcast(PlayerJoined(playerId, name, teamId));
  }

  /// دفاع إضافي (بند حرج #٢-ب بالمراجعة): معرّفات نقاط النهاية
  /// (`ep0, ep1, …`) بترجع تتكرر بكل مضيف جديد، فجهاز بعت معرّف قديم من
  /// لعبة/مضيف سابق ممكن — بمحض الصدفة — يطابق معرّف لاعب **حيّ حالياً**
  /// بهاي اللعبة. المدافعة الأساسية عند العميل (`PlayerClient.connect`
  /// ما بيبعت معرّف محفوظ إلا بـ`rejoin`)، وهاي دفاع ثاني عند المضيف:
  /// منقبل الرجوع بمعرّف للاعب "حيّ" (عنده نقطة نهاية مربوطة حالياً) بس
  /// لو نفس الاسم بالضبط — يعني نفس الجهاز عم يرجع يتصل بسباق شبكة
  /// (نقطة نهايته القديمة سكّرت فعلياً بس إشعار الانقطاع لسا ما وصلنا).
  /// اسم مختلف مع معرّف "حيّ" = على الأرجح تصادف معرّفات، مش نفس الجهاز
  /// — فمنرفضه ومنعامل الطلب كلاعب جديد كليّاً.
  bool _canReattachById(Player existing, String claimedName) {
    final liveEndpoint = _playerToEndpoint[existing.id];
    if (liveEndpoint == null) return true;
    return existing.name == claimedName;
  }

  /// اسم اللاعب متل ما بيوصل من الشبكة: بدون فراغات زايدة، مش فاضي،
  /// ومش أطول من [maxPlayerName] حتى ما يكسر اللوح.
  @visibleForTesting
  static String sanitizePlayerName(String raw) {
    final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return 'لاعب';
    return collapsed.length > maxPlayerName ? collapsed.substring(0, maxPlayerName) : collapsed;
  }

  String? _disconnectedPlayerByName(String name) {
    for (final p in _engine.state.players) {
      if (!p.connected && p.name == name) return p.id;
    }
    return null;
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
    // نقطة النهاية هاي مش الحالية المرتبطة باللاعب — يعني رجع أصلاً
    // بنقطة نهاية جديدة و[_addPlayer] فصل القديمة، وهاد إشعار انقطاع
    // متأخر وصل بعدين. منتجاهله حتى ما نطرد اللاعب الحيّ (بند مهم #٣).
    if (_playerToEndpoint[playerId] != endpointId) return;
    _playerToEndpoint.remove(playerId);
    _applyAndBroadcast(PlayerLeft(playerId));
  }

  // ------------------------------------------------------------------ الساعة

  /// عدّاد الثواني — بيمشي بجهاز المضيف وبينبثّ للكل مع الحالة.
  void _startClock() {
    if (_clockTimer != null) return;
    _clockTimer = Timer.periodic(tick, (timer) {
      final current = _engine.state;
      if (current.gameOver) {
        _stopClock();
        return;
      }
      if (current.answerSecondsLeft > 0 || current.choiceSecondsLeft > 0) {
        _tickAndBroadcast(current);
      }
    });
  }

  void _stopClock() {
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  /// ثانية عالعدّاد. إذا ما تغيّر غير العدّاد منبعت [ClockUpdate] الزغيرة
  /// بدل الحالة كاملة — شوف سبب الحجم هناك. وإذا الثانية غيّرت إشي تاني
  /// (خلص الوقت فصار خطأ، أو انتقل الدور) منبعت الحالة كاملة متل أي حدث.
  void _tickAndBroadcast(GameState before) {
    final after = _engine.apply(const Tick());
    // العدّاد واقف (لاعب دوس «بجاوب») — الثانية ما غيّرت إشي، فما منبعت
    // حزمة عدّاد مكرّرة كل ثانية لكل الأجهزة.
    if (after == before) return;
    final onlyClockMoved = after.copyWith(
          answerSecondsLeft: before.answerSecondsLeft,
          choiceSecondsLeft: before.choiceSecondsLeft,
        ) ==
        before;
    if (onlyClockMoved) {
      server.broadcast(ClockUpdate(
        answerSecondsLeft: after.answerSecondsLeft,
        choiceSecondsLeft: after.choiceSecondsLeft,
      ));
    } else {
      _noteQuestionShown(after);
      server.broadcast(StateUpdate(state: after.maskedForPlayers()));
    }
    notifyListeners();
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
    _stopClock();
    final sub = _sub;
    if (sub != null) unawaited(sub.cancel());
    unawaited(server.stop());
    unawaited(beacon.stop());
    super.dispose();
  }
}
