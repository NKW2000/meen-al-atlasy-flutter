# Flutter Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild مين الأطليسي in Flutter as a 1:1 port of the Kotlin app, with Wi-Fi sockets replacing Nearby Connections.

**Architecture:** One Flutter package. `lib/game` is a pure-Dart rules engine (ported line for line from `core-game`), `lib/network` is a `dart:io` WebSocket host server + UDP beacon discovery + client, `lib/app` holds two `ChangeNotifier` controllers mirroring the Kotlin ViewModels, `lib/ui` is a screen-for-screen port of the Compose UI with the same theme, copy and show-motion keyframes.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `dart:io` sockets, `audioplayers`, `shared_preferences`, `file_picker`, `path_provider`. No state-management or networking packages.

**Spec:** `docs/superpowers/specs/2026-09-12-flutter-port-design.md`

**Kotlin source of truth:** `C:\Projects\WHO-IS-THE-ATLESY` at tag `v0.6.8` (referred to below as `$K`). Every "port" step means: open the named Kotlin file, reproduce its behaviour, structure, and Arabic comments/copy in Dart. Do not redesign.

## Global Constraints

- Package name `meen_al_atlasy`; Android `applicationId` `com.feudparty.app`; `minSdk 26`, `targetSdk 34`; `version: 0.7.0+26`.
- Engine files under `lib/game/` must not import `package:flutter`.
- All user-facing text is Levantine Arabic copied verbatim from the Kotlin sources; numbers render as Arabic-Indic via `.ar()`.
- RTL everywhere: `MaterialApp` wrapped in `Directionality(textDirection: TextDirection.rtl)`.
- No screen scrolls except the host settings screen; content inside `SafeArea`, backgrounds under the notch.
- Fonts: Baloo Bhaijaan 2 (display), Tajawal (body) from `assets/fonts/`; never network fonts.
- Ports: WebSocket `47215`, UDP beacon `47216`. Wire protocol JSON identical to `$K/core-network/.../Messages.kt`.
- Toolchain on this PC (Bash tool): `export PATH="/c/flutter/bin:$PATH"; export JAVA_HOME="<scratchpad>/jdk-17.0.20.1+1"; export ANDROID_HOME="C:/Users/abdal/AppData/Local/Android/Sdk"`.
- Commit after every task, message style `feat(scope): …` / `test(scope): …`, ending with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

---

## File structure

```
lib/
  main.dart                      app bootstrap, controllers, router
  game/
    models.dart                  Answer, Question, TeamId, TeamState, Player, PlayerMark, RoundPhase, BuzzState, Award, GameState (+ masking, getters)
    events.dart                  sealed GameEvent hierarchy
    engine.dart                  GameEngine.apply
    settings.dart                GameSettings + defaults + clamped()
  network/
    messages.dart                ClientMessage / HostMessage + JSON codec
    host_server.dart             HostServer (HttpServer → WebSockets)
    room_beacon.dart             UDP beacon (host)
    room_discovery.dart          UDP listener (player)
    room_code.dart               encode/decode 5-digit code
    player_client.dart           PlayerClient (WebSocket + reconnect)
    local_ip.dart                pick the Wi-Fi IPv4
  questions/
    bank.dart                    parse + validate bank JSON, built-in bank
    bank_store.dart              imported bank on disk
  app/
    host_controller.dart         ChangeNotifier owning engine+server+clock
    player_controller.dart       ChangeNotifier owning discovery+client
    settings_repository.dart     shared_preferences persistence
    scope.dart                   InheritedNotifier accessors
  feedback/
    game_feedback.dart           audioplayers + haptics, Cue enum
    game_cues.dart               GameCues / CountdownCues / PlayerMarkCues listeners
  ui/
    theme.dart                   FeudColors, FeudShape, text styles, FeudTheme widget
    arabic_numerals.dart         int.ar(), String.arDigits()
    responsive.dart              isPortrait(context), shortSide(context)
    motion/show_motion.dart      bang, keys, thump, drop, wipe, rise, slam*, appear, shockRing, revealDelays, ShowClock, SpinningRays
    components/…                 stage, buttons, banners, info_blocks, score_header, strikes, countdown, fireworks, brand_logo, wordmark, confirm_dialog, name_prompt_dialog, answer_slot, settings_pieces
    intro/intro_screen.dart
    home/home_screen.dart
    settings/bank_settings_screen.dart
    host/host_settings_screen.dart, host_lobby_screen.dart, host_board_screen.dart
    player/player_join_screen.dart, room_list_screen.dart, player_screen.dart, player_lobby.dart, buzzer.dart, player_board.dart, play_or_pass.dart
    show/round_opening.dart, scoreboard_screen.dart, game_over_screen.dart
  demo/demo_gallery.dart, demo_data.dart
assets/
  fonts/ (6 ttf), sounds/ (8 files), questions/starter_questions.json
test/
  game/ (fixtures + 5 test files), network/ (4), questions/ (1), app/ (1)
```

---

### Task 1: Models and settings (pure Dart)

**Files:**
- Create: `lib/game/models.dart`, `lib/game/settings.dart`
- Create: `test/game/fixtures.dart`, `test/game/models_test.dart`, `test/game/settings_test.dart`
- Port from: `$K/core-game/src/main/kotlin/com/feudparty/core/game/GameModels.kt`, `$K/app/src/main/kotlin/com/feudparty/app/settings/GameSettings.kt`, tests `GameModelsTest.kt`, `GameSettingsTest.kt`, `TestFixtures.kt`

**Interfaces (Produces):**

```dart
enum TeamId { team1, team2 }                     // JSON "TEAM_1" / "TEAM_2"
extension TeamIdX on TeamId { TeamId get other; String get wire; }  // wire = "TEAM_1"
enum PlayerMark { idle, armed, buzzed, correct, wrong }
enum RoundPhase { faceOff, faceOffSecond, playOrPass, play, steal, roundEnd, scoreboard, gameOver }  // wire = SCREAMING_SNAKE
enum BuzzState { open, lockedTeam1, lockedTeam2, closed }

class Answer { final String text; final int points; final bool revealed; copyWith; toJson; fromJson; ==/hashCode }
class Question { final String id, text, category; final List<Answer> answers; final bool isRead; … }
class TeamState { final TeamId id; final String name; final int score; final bool connected; … }
class Player { final String id, name; final TeamId teamId; final int seat; final bool connected; … }
class Award { final TeamId teamId; final int points; final bool stolen; … }
const int choiceSeconds = 5;
const int defaultAnswerSeconds = 10;

class GameState {
  // every field of GameState.kt with the same defaults
  final List<Question> questions; final int currentQuestionIndex; final Map<TeamId, TeamState> teams;
  final List<Player> players; final RoundPhase phase; final BuzzState buzzState; final int pot, strikes;
  final TeamId? controllingTeam, faceOffTeam, faceOffLeader, faceOffWinner; final int faceOffLeaderPoints;
  final String? buzzedPlayerId, turnPlayerId; final int faceOffSeat; final Map<TeamId, int> turnIndex;
  final Set<String> wrongPlayers, correctPlayers; final int wrongTicks; final bool faceOffFailed;
  final TeamId? roundWinner; final Award? lastAward; final List<int> multipliers; final int strikesToSteal;
  final int answerLimitSeconds, choiceLimitSeconds, answerSecondsLeft; final bool clockPaused;
  final int choiceSecondsLeft; final bool matchStarted, gameOver;
  GameState copyWith({...});                      // nullable fields use a sentinel: `Object? controllingTeam = _unset`
  Question? get currentQuestion; int get multiplier; bool get roundOver, isLastRound;
  TeamId? get stealingTeam, activeTeam, leadingTeam; int get maxSeat;
  List<Player> playersOf(TeamId); Player? player(String?); Player? podiumPlayer(TeamId);
  Player? opponentOf(Player); Set<String> armedPlayerIds(); PlayerMark markFor(String?);
  TeamId? buzzedTeam(); GameState maskedForPlayers();
  Map<String, dynamic> toJson(); factory GameState.fromJson(Map<String, dynamic>);
}

class GameSettings { rounds, multipliers, strikesToSteal, answerSeconds, choiceSeconds, teamNames, roomName, minAnswers, maxAnswers, bankName, bankQuestionCount;
  List<int> multipliersForRounds(); int questionsNeeded(); GameSettings clamped(); copyWith; }
// constants: defaultRounds, defaultMultipliers, defaultStrikes, defaultAnswerSeconds, defaultChoiceSeconds, defaultTeamNames, defaultRoomName, defaultMinAnswers, maxAnswers = 8 — copy the exact values from GameSettings.kt
```

JSON: keys are the Kotlin property names (`currentQuestionIndex`, `faceOffSeat`, …); enums serialise as their Kotlin names; `teams` is a JSON object keyed by `"TEAM_1"`; `turnIndex` likewise; sets are JSON arrays. `fromJson` tolerates missing keys by using the defaults (Kotlin's `ignoreUnknownKeys` + default values).

- [ ] **Step 1: Write fixtures** — `test/game/fixtures.dart` porting `TestFixtures.kt`: `board(id)`, `defaultPlayers(perTeam)`, `freshState({questions, multipliers, players})`, and engine helpers `buzz`, `buzzPodium`, `correct`, `wrong`, `choosePlay`, `choosePass`, `giveControlTo`, `score` as extension methods on `GameEngine`/`GameState` (the `GameEngine` class comes in Task 2; write the extension file now and it compiles once Task 2 lands — for Task 1 keep only the state fixtures in a first version, add the engine helpers in Task 2).
- [ ] **Step 2: Write `models_test.dart`** with the 7 cases from `GameModelsTest.kt` (same names: `currentQuestion returns question at currentQuestionIndex`, `currentQuestion returns null when index out of range`, `multiplier follows the round and sticks to the last value`, `active team follows the phase`, `the question is hidden from players while the buzzer is open`, `the question never reaches a player, revealed answers do`, `the next round hides its question again`) plus a JSON round-trip test: `GameState.fromJson(jsonDecode(jsonEncode(freshState().toJson()))) == freshState()`.
- [ ] **Step 3: Write `settings_test.dart`** with the 5 cases from `GameSettingsTest.kt`.
- [ ] **Step 4: Run `flutter test test/game` — expect compile failures** (models missing).
- [ ] **Step 5: Implement `models.dart` and `settings.dart`** by porting the Kotlin files. Value equality: implement `==`/`hashCode` by hand using `const ListEquality`-free helpers (write a small `listEq`, `mapEq`, `setEq` at the bottom of `models.dart`) — do not add `equatable`.
- [ ] **Step 6: Run `flutter test test/game` — expect all green.**
- [ ] **Step 7: Commit** `feat(game): models, settings and their tests ported from core-game`.

---

### Task 2: Game engine and events

**Files:**
- Create: `lib/game/events.dart`, `lib/game/engine.dart`
- Create: `test/game/engine_face_off_test.dart`, `test/game/engine_players_test.dart`, `test/game/engine_round_test.dart`
- Modify: `test/game/fixtures.dart` (add engine helpers)
- Port from: `GameEvent.kt`, `GameEngine.kt`, `GameEngineFaceOffTest.kt`, `GameEnginePlayersTest.kt`, `GameEngineRoundTest.kt`

**Interfaces (Produces):**

```dart
sealed class GameEvent { const GameEvent(); }
class Buzz extends GameEvent { final String playerId; final int atMillis; }
class JudgeCorrect extends GameEvent { final int answerIndex; }
class JudgeWrong extends GameEvent { const JudgeWrong(); }
class ChooseControl extends GameEvent { final bool play; }
class NextRound extends GameEvent { const NextRound(); }
class PlayerJoined extends GameEvent { final String playerId, name; final TeamId teamId; }
class PlayerLeft extends GameEvent { final String playerId; }
class PlayerMoved extends GameEvent { final String playerId; final TeamId teamId; }
class StartGame extends GameEvent { const StartGame(); }
class ReplaceQuestion extends GameEvent { final Question question; }
class Tick extends GameEvent { const Tick(); }
class EndGame extends GameEvent { const EndGame(); }

class GameEngine {
  GameEngine(GameState initial);
  GameState get state;
  void reset(GameState newState);
  GameState apply(GameEvent event);
  static const defaultStrikesToSteal = 3;
}
```

- [ ] **Step 1: Port the 51 engine tests** (names listed in the three Kotlin test files) into the three Dart files, using the fixture helpers. Keep one `test('…')` per Kotlin `@Test`, same name string.
- [ ] **Step 2: Run `flutter test test/game` — expect failures** (engine missing).
- [ ] **Step 3: Port `GameEngine.kt`** — `apply` switches on the sealed event with `switch (event) { case Buzz(): …}`; every private helper (`handleBuzz`, `handleReplaceQuestion`, `answeringPlayerId`, `handleChoice`, `handleCorrect`, `faceOffCorrect`, `playCorrect`, `stealCorrect`, `handleWrong`, `handleTick`, `handleNextRound`, `handlePlayerJoined`, `handlePlayerLeft`, `handlePlayerMoved`, `reveal`) becomes a private method; the Kotlin extension functions (`renumbered`, `withTeamsConnected`, `mapCurrentQuestion`, `allRevealed`, `markCorrect`, `markWrong`, `offerChoice`, `startPlay`, `advanceTurn`, `openSteal`, `podiumIndexOf`, `nextConnectedIndex`, `nextSeat`, `award`) become a private `extension _Engine on GameState` in `engine.dart`. Note the two places where Kotlin mutates `state` mid-handler (`handleTick` → `handleChoice`/`handleWrong`): reproduce by assigning `_state` before calling the next handler. Keep the `clockPaused = false` reset after every non-Buzz/non-Tick event.
- [ ] **Step 4: Run `flutter test test/game` — expect all 63 tests green.**
- [ ] **Step 5: Commit** `feat(game): rules engine ported from core-game with all 51 engine tests`.

---

### Task 3: Wire messages and the room code

**Files:**
- Create: `lib/network/messages.dart`, `lib/network/room_code.dart`
- Create: `test/network/messages_test.dart`, `test/network/room_code_test.dart`
- Port from: `$K/core-network/src/main/kotlin/com/feudparty/core/network/Messages.kt`

**Interfaces (Produces):**

```dart
sealed class ClientMessage { Map<String, dynamic> toJson(); static ClientMessage fromJson(Map<String, dynamic>); }
class JoinMessage extends ClientMessage { final String playerName; final TeamId? teamId; }         // type "join"
class ChangeTeamMessage extends ClientMessage { final String playerId; final TeamId teamId; }       // "team"
class BuzzMessage extends ClientMessage { final String playerId; final int atMillis; }              // "buzz"
class ChooseMessage extends ClientMessage { final String playerId; final bool play; }               // "choice"
sealed class HostMessage { … }
class StateUpdate extends HostMessage { final GameState state; }                                   // "state"
class Assigned extends HostMessage { final String playerId; final TeamId teamId; }                 // "assigned"
String encodeClientMessage(ClientMessage m); ClientMessage decodeClientMessage(String s);
String encodeHostMessage(HostMessage m);     HostMessage decodeHostMessage(String s);
// room_code.dart
String encodeRoomCode(InternetAddress ip);                       // third*256+fourth, 5 digits zero-padded
InternetAddress? decodeRoomCode(String code, InternetAddress myIp); // null if not 5 digits or > 65535
```

- [ ] **Step 1: Write `messages_test.dart`**: each message type round-trips; decoding `{"type":"state","state":{...}}` produced from `freshState().maskedForPlayers().toJson()` yields an equal state; unknown keys ignored; unknown `type` throws `FormatException`.
- [ ] **Step 2: Write `room_code_test.dart`**: `encodeRoomCode(192.168.43.1) == "11009"`; `decodeRoomCode("11009", 192.168.0.7) == 192.168.43.1`; `"00001"` → `x.y.0.1`; `"abc"` and `"70000"` → null.
- [ ] **Step 3: Run tests — expect failures.**
- [ ] **Step 4: Implement both files.** Use `jsonEncode`/`jsonDecode` from `dart:convert`; the discriminator key is `"type"`.
- [ ] **Step 5: Run tests — green. Commit** `feat(network): wire messages and room code`.

---

### Task 4: Host server, beacon, discovery, client (with loopback test)

**Files:**
- Create: `lib/network/host_server.dart`, `lib/network/room_beacon.dart`, `lib/network/room_discovery.dart`, `lib/network/player_client.dart`, `lib/network/local_ip.dart`
- Create: `test/network/loopback_test.dart`, `test/network/discovery_test.dart`

**Interfaces (Produces):**

```dart
// host_server.dart
sealed class ClientEvent { final String endpointId; }
class ClientConnected extends ClientEvent {}
class ClientMessageReceived extends ClientEvent { final ClientMessage message; }
class ClientDisconnected extends ClientEvent {}
class HostServer {
  HostServer();
  int get port;                                   // actual bound port
  Stream<ClientEvent> get events;                 // broadcast stream
  Future<void> start({int port = 47215});         // falls back to port 0 (random) on SocketException
  void send(String endpointId, HostMessage m);
  void broadcast(HostMessage m);
  Future<void> stop();
}
// room_beacon.dart
class RoomBeacon { Future<void> start({required String roomName, required int port}); Future<void> stop(); }
// room_discovery.dart
class Room { final String name; final InternetAddress host; final int port; String get endpointId => '${host.address}:$port'; }
class RoomDiscovery { final ValueNotifier<List<Room>> rooms; Future<void> start(); Future<void> stop(); }
// player_client.dart
enum ConnectionStatus { idle, connecting, connected, disconnected }
class PlayerClient {
  final ValueNotifier<GameState?> state; final ValueNotifier<ConnectionStatus> status; final ValueNotifier<String?> playerId; final ValueNotifier<TeamId?> teamId;
  Future<void> connect({required InternetAddress host, required int port, required String playerName, TeamId? teamId});
  void send(ClientMessage m); Future<void> rejoin(); Future<void> disconnect();
}
// local_ip.dart
Future<InternetAddress?> wifiIPv4();
```

Implementation notes (write these, they are the whole file):

```dart
// host_server.dart — core of start()
_server = await HttpServer.bind(InternetAddress.anyIPv4, port).catchError(
    (_) => HttpServer.bind(InternetAddress.anyIPv4, 0));
_server!.listen((req) async {
  if (!WebSocketTransformer.isUpgradeRequest(req)) { req.response.statusCode = 404; await req.response.close(); return; }
  final ws = await WebSocketTransformer.upgrade(req);
  final id = 'ep${_next++}';
  _sockets[id] = ws;
  _events.add(ClientConnected(id));
  ws.listen((data) {
    try { _events.add(ClientMessageReceived(id, decodeClientMessage(data as String))); } catch (_) {/* ignore malformed */}
  }, onDone: () => _drop(id), onError: (_) => _drop(id));
});
// ping: Timer.periodic(5s) → for each socket ws.pingInterval is set instead: ws.pingInterval = const Duration(seconds: 5);
// dart:io WebSocket closes the socket itself when pings go unanswered, which fires onDone → _drop(id).
```

```dart
// room_beacon.dart
final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
sock.broadcastEnabled = true;
_timer = Timer.periodic(const Duration(seconds: 1), (_) {
  final payload = utf8.encode(jsonEncode({'room': roomName, 'port': port, 'version': 1}));
  sock.send(payload, InternetAddress('255.255.255.255'), 47216);
});
```

```dart
// room_discovery.dart
final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 47216, reuseAddress: true, reusePort: false);
sock.broadcastEnabled = true;
sock.listen((e) { if (e != RawSocketEvent.read) return; final dg = sock.receive(); if (dg == null) return;
  final j = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
  _seen['${dg.address.address}:${j['port']}'] = (Room(j['room'] as String, dg.address, j['port'] as int), DateTime.now()); _publish(); });
// _publish(): drop entries older than 4 s (a Timer.periodic(1s) also calls _publish), then rooms.value = sorted by name.
```

```dart
// player_client.dart — connect()
status.value = ConnectionStatus.connecting;
_ws = await WebSocket.connect('ws://${host.address}:$port/').timeout(const Duration(seconds: 5));
_ws!.pingInterval = const Duration(seconds: 5);
status.value = ConnectionStatus.connected;
_ws!.listen(_onData, onDone: _onClosed, onError: (_) => _onClosed());
send(JoinMessage(playerName: playerName, teamId: teamId));
// _onData: decodeHostMessage → StateUpdate → state.value; Assigned → playerId.value/teamId.value
// _onClosed: status.value = disconnected (keep playerId so rejoin() re-sends join with playerName and the host re-attaches by name+id — the host's addPlayer treats a Join whose playerName matches a disconnected player as that player; see Task 6)
```

- [ ] **Step 1: Write `loopback_test.dart`**: start `HostServer` on port 0, `PlayerClient.connect(127.0.0.1, server.port, 'سلمان')`; expect a `ClientConnected` then `ClientMessageReceived(JoinMessage)` on the server; server `send(id, Assigned('p1', team1))` and `broadcast(StateUpdate(freshState().maskedForPlayers()))`; expect client `playerId.value == 'p1'` and `state.value == that state`; `server.stop()` → client `status == disconnected`.
- [ ] **Step 2: Write `discovery_test.dart`**: run `RoomBeacon` and `RoomDiscovery` on localhost (bind the discovery socket to `InternetAddress.loopbackIPv4` in a test-only constructor parameter `bindAddress`); expect `rooms.value` to contain the room within 3 s; stop beacon; expect the room to expire within 6 s. Mark the test `@Tags(['network'])` and skip on CI if the runner blocks UDP broadcast (`skip: Platform.environment['CI'] == 'true'`).
- [ ] **Step 3: Run tests — fail. Implement the five files. Run — green.**
- [ ] **Step 4: `local_ip.dart`**: `NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false)`; score interfaces: name starts with `wlan`/`ap`/`swlan`/`en0`/`bridge` → 2, contains `rmnet`/`tun`/`lo` → skip, else 1; skip `10.0.2.x`; return the address of the best.
- [ ] **Step 5: Commit** `feat(network): host server, beacon discovery, player client with loopback tests`.

---

### Task 5: Question bank

**Files:**
- Create: `lib/questions/bank.dart`, `lib/questions/bank_store.dart`, `assets/questions/starter_questions.json` (copy from `$K/data-questions/src/main/resources/starter_questions.json`)
- Create: `test/questions/bank_test.dart`
- Port from: `$K/data-questions/src/main/kotlin/com/feudparty/data/questions/*.kt` and the rules in `$K/docs/question-bank.md`

**Interfaces (Produces):**

```dart
class BankParseResult { final List<Question> questions; final List<String> errors; bool get ok => errors.isEmpty; }
class QuestionBank {
  static BankParseResult parse(String json);                       // validation per docs/question-bank.md
  static Future<List<Question>> builtIn();                          // rootBundle asset
  static List<Question> pick({required List<Question> from, required int count, required int minAnswers, required int maxAnswers, required Random random}); // unread first, filtered by answer count, shuffled; falls back to all when unread run out (same as the Kotlin picker)
}
class BankStore { Future<List<Question>?> load(); Future<void> save(String name, List<Question>); Future<void> clear(); Future<void> markRead(Iterable<String> ids); }
```

- [ ] **Step 1: Write `bank_test.dart`** from the Kotlin bank tests if present, else from the rules: valid file parses; missing `text` → error mentioning the index; 1 answer → error; 9 answers → error; points ≤ 0 → error; duplicate question text → error; ids generated as `q001`… when absent.
- [ ] **Step 2: Fail → implement → green.** Register the asset in `pubspec.yaml` (`assets: - assets/questions/`).
- [ ] **Step 3: Commit** `feat(questions): bank parser, picker and store`.

---

### Task 6: Controllers and settings repository

**Files:**
- Create: `lib/app/host_controller.dart`, `lib/app/player_controller.dart`, `lib/app/settings_repository.dart`, `lib/app/scope.dart`
- Create: `test/app/host_controller_test.dart`
- Port from: `$K/app/src/main/kotlin/com/feudparty/app/viewmodel/HostViewModel.kt`, `PlayerViewModel.kt`, `settings/SettingsRepository.kt`, tests `HostViewModelTest.kt`, `PlayerViewModelTest.kt`, `FakeNearbyConnectionsManager.kt`

**Interfaces (Produces):**

```dart
class HostController extends ChangeNotifier {
  HostController({required HostServer server, required RoomBeacon beacon, required SettingsRepository settings, required Future<List<Question>> Function() bankLoader, Duration tick = const Duration(seconds: 1)});
  GameState get state; bool get advertising; String? get lastError;
  Future<void> resetSession(); Future<void> startHosting(); void movePlayer(String id, TeamId to);
  void startGame(); void judgeCorrect(int i); void judgeWrong(); void nextRound(); void changeQuestion(); void dismissError();
  static const minPlayersPerTeam = 1;   // copy the Kotlin value
}
class PlayerController extends ChangeNotifier {
  PlayerController({required RoomDiscovery discovery, required PlayerClient client});
  String playerName; List<Room> get rooms; GameState? get state; ConnectionStatus get status; String? get playerId; TeamId? get teamId; String? get lastError;
  Future<void> startDiscovery(); Future<void> stopDiscovery(); Future<void> enterRoom(Room r); Future<void> enterCode(String code);
  void onBuzzTapped(); void choose(bool play); void changeTeam(TeamId t); Future<void> rejoin(); PlayerMark mark(); void dismissError();
}
class SettingsRepository { Future<GameSettings> load(); Future<void> save(GameSettings s); }
// scope.dart
class AppScope extends InheritedWidget { final HostController host; final PlayerController player; final SettingsRepository settings; static AppScope of(BuildContext); }
```

Behaviour to carry over from `HostViewModel.kt` (read it; these are the non-obvious bits): player id = endpointId on first join; a `Join` arriving from a new endpoint whose `playerName` equals a *disconnected* player's name re-attaches that player (`PlayerJoined` with the old id) and the endpoint map is updated; `Assigned` is sent after every join; `StateUpdate(state.maskedForPlayers())` is broadcast after every engine event; `ClientDisconnected` → `PlayerLeft`; the tick timer runs only while `answerSecondsLeft > 0 || choiceSecondsLeft > 0`; `startGame` picks `settings.questionsNeeded()` questions with `QuestionBank.pick` and builds the initial `GameState` from `GameSettings` (team names, multipliersForRounds, strikesToSteal, answer/choice seconds); `changeQuestion` replaces the current question with the next unused one; `resetSession` stops server/beacon and clears state; the beacon runs from `startHosting` until `startGame`.

- [ ] **Step 1: Write `host_controller_test.dart`** using a `FakeHostServer` (implements the same API with an in-memory `StreamController<ClientEvent>` and a list of sent messages) porting the cases in `HostViewModelTest.kt` (joins assign seats and send `assigned`; a disconnected player re-attaches by name; every event broadcasts a masked state; the clock ticks the engine once per second — use `tick: Duration(milliseconds: 10)` and `await Future.delayed`).
- [ ] **Step 2: Fail → implement the four files → green.** Make `HostServer` an abstract interface `HostTransport` in `host_server.dart` with the real class implementing it, so the fake can too.
- [ ] **Step 3: Commit** `feat(app): host and player controllers, settings repository`.

---

### Task 7: Theme, numerals, responsive, show motion, shared components

**Files:**
- Create: `lib/ui/theme.dart`, `lib/ui/arabic_numerals.dart`, `lib/ui/responsive.dart`, `lib/ui/motion/show_motion.dart`, `lib/ui/components/{stage,buttons,banners,info_blocks,score_header,strikes,countdown,fireworks,brand_logo,wordmark,confirm_dialog,name_prompt_dialog,answer_slot,settings_pieces}.dart`
- Copy: `$K/app/src/main/res/font/*.ttf` → `assets/fonts/`; declare the two families in `pubspec.yaml` (weights 500/700/800).
- Create: `test/ui/show_motion_test.dart`, `test/ui/arabic_numerals_test.dart`
- Port from: `$K/app/src/main/kotlin/com/feudparty/app/ui/theme/Theme.kt`, `ui/ArabicNumerals.kt`, `ui/Responsive.kt`, `ui/components/*.kt`

**Interfaces (Produces):**

```dart
// theme.dart
abstract final class FeudColors { static const ink = Color(0xFF140626); canvas, stage, stageAlt, gold, pink, teal, lime, cream, team1, team1Ink, team2, team2Ink, panelDark, textMuted, textSoft, textFaint, deepNavy … copy every value from Theme.kt }
abstract final class FeudShape { static const block = 14.0; … }
class FeudText { static TextStyle displayLarge(BuildContext), headlineMedium, headlineSmall, titleLarge, titleMedium, titleSmall, bodyLarge, bodyMedium, labelLarge, labelMedium — sizes from Theme.kt's type scale }
Widget feudApp(Widget home) // MaterialApp with Directionality rtl, theme, no debug banner
// arabic_numerals.dart
extension ArabicInt on int { String ar(); }  extension ArabicString on String { String arDigits(); }
// responsive.dart
bool isPortrait(BuildContext); double shortSide(BuildContext);
// show_motion.dart  (pure functions identical to ShowMotion.kt)
double bang(double p); double keys(double t, double delay, double duration, List<(double, double)> stops, {double Function(double) curve = bang});
double thump(double t, double delay, [double duration = 0.46]); double drop(...); double wipe(...); double rise(...); double slamScale(...); double slamRotation(...); double appear(double t, double delay, [double over = 0.12]);
class ShockRing { final double scale, alpha, width; } ShockRing shockRing(double t, double delay, [double duration = 0.76]);
Map<int, double> revealDelays(Set<int>? previous, Set<int> current, {double step = 0.12});
class ShowClock extends ValueNotifier<double> { ShowClock(TickerProvider vsync, {double cap = 12}); void restart(); void dispose(); }  // seconds since start, ticks via Ticker, stops at cap
class SpinningRays extends StatefulWidget { … CustomPainter, 12 arcs of 15°, 14 s period }
// stage.dart
class StageBackground extends StatelessWidget { child, contentPadding }
class CartoonSurface extends StatelessWidget { color, borderWidth, corner, shadow, onClick, enabled, child }  // hard ink shadow offset, presses down on tap
BoxDecoration blockSkin(Color color, {double border = 4, double shadow = 6, double corner = FeudShape.block}) // + a BlockSkin widget that paints the offset shadow behind
// components: PrimaryButton, SecondaryButton, GoldBanner/LeadBanner, RoundBlock, Pill, ScoreHeader, StrikeRow, StrikeFlash, Countdown, Fireworks, BrandLogo, Wordmark, ConfirmDialog, NamePromptDialog, SeatBadge, AnswerSlotRow (two-face flip from HostGameBoardScreen.kt PortraitAnswerRow), settings pieces (Stepper rows, section headers)
```

- [ ] **Step 1: Tests first** — `show_motion_test.dart`: `bang(0)==0`, `bang(1)==1`, `keys` before delay returns first stop, after duration returns last, `thump(t,0)` peaks at 1.22 near `t=0.24`, `revealDelays` — the four cases from `RevealMotionTest.kt`; `arabic_numerals_test.dart`: `1234.ar() == '١٢٣٤'`, `(-5).ar() == '-٥'`.
- [ ] **Step 2: Fail → implement `show_motion.dart`, `arabic_numerals.dart` → green.**
- [ ] **Step 3: Port theme + responsive + every component file.** For each Kotlin composable produce a Dart widget with the same name and parameters; keep the Arabic doc comments. `CartoonSurface` press-down: use `GestureDetector` + `AnimatedContainer`/`Transform.translate` by the shadow offset while pressed.
- [ ] **Step 4: Widget smoke test** `test/ui/components_test.dart`: pump each component inside `feudApp` and expect no exceptions (`tester.pumpWidget`, `expect(tester.takeException(), isNull)`).
- [ ] **Step 5: `flutter analyze` clean. Commit** `feat(ui): theme, show motion helpers and shared components`.

---

### Task 8: Intro, home, bank settings, host settings

**Files:**
- Create: `lib/ui/intro/intro_screen.dart`, `lib/ui/home/home_screen.dart`, `lib/ui/settings/bank_settings_screen.dart`, `lib/ui/host/host_settings_screen.dart`, `lib/main.dart` (router with named routes `intro, home, hostSettings, hostLobby, hostBoard, hostResult, playerJoin, playerRooms, playerBuzzer, bankSettings`)
- Port from: `IntroScreen.kt`, `IntroPortraitScreen.kt`, `HomeScreen.kt`, `BankSettingsScreen.kt`, `HostSettingsScreen.kt`, `navigation/FeudNavGraph.kt` (route names, transitions: slide 340 ms + fade 240 ms), `MainActivity.kt` (full-screen, notch, orientation `fullUser`)

- [ ] **Step 1: `main.dart`** — `WidgetsFlutterBinding`, `SystemChrome.setEnabledSystemUIMode(immersiveSticky)`, edge-to-edge, create `SettingsRepository`, `HostController`, `PlayerController` once; `AppScope` above `MaterialApp`; `onGenerateRoute` with the slide/fade `PageRouteBuilder`; `const demo = bool.fromEnvironment('DEMO')` → start at the gallery (Task 12) instead of intro.
- [ ] **Step 2: Port the four screens.** Intro: both orientations' choreography with a `ShowClock`; tap → `Navigator.pushReplacementNamed('home')`. Host settings: the only scrolling screen; all steppers; bank filter count from `QuestionBank`; "كمّل للوبي" → `hostLobby`. Bank settings: `file_picker` (`FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'])`) → `QuestionBank.parse` → `BankStore.save` or show the error list; "امسح البنك".
- [ ] **Step 3: Android manifest** — `android:screenOrientation="fullUser"`, `INTERNET` permission, app label `مين الأطليسي`, `applicationId com.feudparty.app`, `minSdk 26`, `targetSdk 34`, version from pubspec; copy the launcher icon from `$K/app/src/main/res/mipmap-*`. iOS: `NSLocalNetworkUsageDescription` = "اللعبة بتتواصل مع أجهزة اللاعبين على نفس الواي فاي" and `NSBonjourServices` not needed.
- [ ] **Step 4: `flutter build apk --debug` succeeds; `flutter analyze` clean. Commit** `feat(ui): intro, home, bank and host settings screens with the router`.

---

### Task 9: Lobbies and joining (checkpoint 1)

**Files:**
- Create: `lib/ui/host/host_lobby_screen.dart`, `lib/ui/player/player_join_screen.dart`, `lib/ui/player/room_list_screen.dart`, `lib/ui/player/player_lobby.dart`
- Port from: `HostSetupScreen.kt`, `PlayerJoinScreen.kt`, `RoomListScreen.kt`, `PlayerScreen.kt` (`PlayerLobbyScreen`), `FeudNavGraph.kt` (HOST_SETUP / PLAYER_JOIN / PLAYER_ROOMS / lobby part of PLAYER_BUZZER)

New copy (the only UX additions, see spec §3):
- Host lobby, under the room name: `"الواي فاي: ${ip.address}"` and `"كود الغرفة: ${code.arDigits()}"` in a `Pill`, and the muted line `"لازم الكل يكون على نفس الواي فاي أو نقطة اتصال المضيف"`. If `wifiIPv4()` is null: replace with `"افتح الواي فاي أو نقطة الاتصال"` and disable "استضافة".
- Room list: below the list a `TextField` (device keyboard, digits only, `maxLength: 5`) labelled `"أو اكتب كود الغرفة"` with a `PrimaryButton("انضم")` → `player.enterCode(text)`; same muted Wi-Fi line.

- [ ] **Step 1: Port the four screens** exactly as the Kotlin ones (team cards, move `⇄`, min-per-team gate, "ابدأ اللعبة", name prompt with device keyboard + `imePadding` equivalent `MediaQuery.viewInsets`).
- [ ] **Step 2: Wire routes**: `home → playerJoin → playerRooms → playerBuzzer` on `status == connected`; `home → hostSettings → hostLobby → hostBoard` on "ابدأ اللعبة"; back handlers with the same `ConfirmDialog`s.
- [ ] **Step 3: Build debug APK, install on two phones (`adb install -r`), verify: host lobby shows IP + code; player sees the room within ~2 s on the same Wi-Fi and on the host's hotspot; joining by code works with Wi-Fi discovery blocked (test on a hotspot with a second phone typing the code); moving players renumbers; disconnect/reconnect keeps the seat.** Hand the APK to the user for the same check.
- [ ] **Step 4: Commit** `feat(ui): host lobby, player join, room list with Wi-Fi discovery and room code`.

---

### Task 10: Host board, player screen, round opening

**Files:**
- Create: `lib/ui/host/host_board_screen.dart`, `lib/ui/player/player_screen.dart`, `lib/ui/player/buzzer.dart`, `lib/ui/player/player_board.dart`, `lib/ui/player/play_or_pass.dart`, `lib/ui/show/round_opening.dart`
- Port from: `HostGameBoardScreen.kt`, `PlayerScreen.kt`, `RoundOpeningScreen.kt`, `components/Buzzer.kt`, `FeudNavGraph.kt` (HOST_BOARD / PLAYER_BUZZER bodies)

Specific behaviours to preserve (all in the Kotlin files — this list is what to double-check):
- Host board: 8 slots always (`BOARD_SLOTS = 8`), one column portrait / two landscape, `PortraitBoardHeader` with the question card between time and strikes in landscape; judge bar: "غلط" (pink) or "بدّل السؤال" when `faceOffFailed`; `ROUND_END` bar: "اكشف الباقي" until all revealed, then `nextButtonLabel()`; strike flash overlay; slot tap = `judgeCorrect(index)` only when `canJudge()`.
- `AnswerSlotRow` (Task 7) with `revealDelay` from `revealDelays` on both boards.
- Player: lobby / play-or-pass (only the armed player, doors slide, bar drains **on time** as in `v0.6.8`) / full-screen buzzer (`mark == armed && phase == faceOff`) / board (colour = mark: buzzed → team2, correct → team1, wrong → pink, else stage; tap sends buzz only when armed) + `TurnBlock` + `StrikeFlash`.
- `RoundOpening` overlay on **both** host and player routes: shows once per round when `matchStarted && !gameOver && phase == faceOff`; intro 1.9 s then versus 2.0 s (skipped if a podium name is missing); **absorbs all taps, cannot be skipped**.
- Scoreboard phase swaps the board for `ScoreboardScreen` (Task 11) on both routes; `gameOver` → `GameOverScreen`.

- [ ] **Step 1: Port `round_opening.dart`** (`RoundIntroScreen`, `VersusScreen`, `VersusCard`, `GoldBanner`, `RoundOpeningOverlay`) with `ShowClock`; wrap in an `AbsorbPointer`-equivalent: a `GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {})` over a `Stack`.
- [ ] **Step 2: Port the host board.** Verify in a widget test: with `freshState()` and phase `roundEnd`, tapping a hidden slot calls `onCorrect(index)`; with all revealed the button label equals `state.nextButtonLabel()`.
- [ ] **Step 3: Port the player screen family.** Widget test: `mark == armed && phase == faceOff` renders `Buzzer`; `phase == playOrPass` and armed renders `PlayOrPass`; otherwise `PlayerBoard`.
- [ ] **Step 4: Wire both routes** in `main.dart`: host board route hosts `GameCues`, `CountdownCues` (Task 12 adds them; leave the hooks), the exit `ConfirmDialog`, navigation to `hostResult` on `gameOver`; player route hosts the disconnect dialog with `rejoin` / leave.
- [ ] **Step 5: Build, run on two phones, play a full round: face-off, play/pass, rotation, strikes, steal, reveal-rest, next round. Commit** `feat(ui): host board, player buzzer/board/play-or-pass and the round opening`.

---

### Task 11: Scoreboard and game over

**Files:**
- Create: `lib/ui/show/scoreboard_screen.dart`, `lib/ui/show/game_over_screen.dart`
- Port from: `ScoreboardScreen.kt` (`TeamPanel`, `LeadBanner`), `GameOverScreen.kt`, `components/Fireworks.kt`

- [ ] **Step 1: Port both screens** with `ShowClock`: title drops, panels rise (portrait stacked / landscape side by side), numbers count up over 0.9 s from 0.5 s, crown (landscape gold strip / portrait pulsing border) at 1.5 s, banner wipes at 1.56 s; host has "الجولة الجاية"/"النتيجة النهائية", players see "بانتظار المضيف يبلّش الجولة الجاية". Game over: winner banner, fireworks, host "رجوع للوبي" → `resetSession` + back to `hostLobby`.
- [ ] **Step 2: Widget test**: pump `ScoreboardScreen` with scores 140/95, advance the clock 3 s (`tester.pump(const Duration(seconds: 3))`), expect the text `١٤٠` and `٩٥` and the banner text `الفريق الأخضر بالمقدمة`.
- [ ] **Step 3: Commit** `feat(ui): scoreboard and game over scenes`.

---

### Task 12: Feedback (sounds, haptics) and demo mode

**Files:**
- Create: `lib/feedback/game_feedback.dart`, `lib/feedback/game_cues.dart`, `lib/demo/demo_gallery.dart`, `lib/demo/demo_data.dart`
- Copy: `$K/app/src/main/res/raw/*` → `assets/sounds/` (declare in pubspec)
- Port from: `feedback/GameFeedback.kt`, `feedback/GameCues.kt`, `demo/DemoActivity.kt`, `DemoData.kt`, `DemoGallery.kt`

**Interfaces:**

```dart
enum Cue { reveal, wrong, strike1, strike2, strike3, buzz, win, press }
class GameFeedback { Future<void> play(Cue c); Future<void> playStrike(int n); int startClock(); void stopStream(int id); }  // audioplayers AudioPlayer per cue, low-latency mode, clock loops
class GameCues extends StatefulWidget { final GameState? state; child }       // same diff rules as GameCues.kt: award → win; strikes ↑ → strike n; wrongTicks ↑ → wrong; revealed ↑ → reveal
class CountdownCues extends StatefulWidget { final int seconds; from = 5; child }
class PlayerMarkCues extends StatefulWidget { final PlayerMark mark; final bool faceOff; child }  // buzz sound only in face-off
```

- [ ] **Step 1: Unit-test the cue diffing** by extracting `List<Cue> cuesFor(GameState? previous, GameState next)` as a pure function (test: award set → `[win]` only; strikes 1→2 → `[strike2]`; wrongTicks ↑ with no strike → `[wrong]`; reveal ↑ → `[reveal]`; several at once → the first matching rule only, as in Kotlin's `when`).
- [ ] **Step 2: Implement feedback + cues; mount them on the host board and player routes** (host: `GameCues`, `CountdownCues`; player: `GameCues`, `CountdownCues`, `PlayerMarkCues`). `HapticFeedback.heavyImpact()` on buzz tap.
- [ ] **Step 3: Demo gallery**: `--dart-define=DEMO=true` → the app opens on a list of every screen with the fixtures from `DemoData.kt`; each entry pushes the screen with fake state and no controllers. Verify `flutter build apk --debug --dart-define=DEMO=true` and browse every entry on a phone.
- [ ] **Step 4: Commit** `feat: sounds, haptics and the demo gallery`.

---

### Task 13: CI, README, release v0.7.0 (checkpoint 2)

**Files:**
- Create: `.github/workflows/release.yml`, `README.md` (port `$K/README.md`, replacing the Nearby paragraph with the Wi-Fi/hotspot + room-code explanation and the Flutter build instructions), `docs/design.md` (port; add the transport section), `docs/question-bank.md` (copy), `docs/manual-test-checklist.md` (copy + add "join by code" and "hotspot" rows)

- [ ] **Step 1: Workflow**: on `push: tags: v*` and `workflow_dispatch`; `ubuntu-latest`; `subosito/flutter-action@v2` with `flutter-version: 3.47.4`; `actions/setup-java@v4` temurin 17; `flutter pub get`; `flutter test`; `flutter build apk --release`; `flutter build apk --release --dart-define=DEMO=true` (copy to `meen-al-atlasy-$version-demo.apk` — build the demo first and rename before the main build, since both write `app-release.apk`); `softprops/action-gh-release@v2` with both files and the same Arabic body as the Kotlin workflow. `ios` job: `macos-latest`, `flutter build ios --no-codesign`, `if: false`.
- [ ] **Step 2: Full manual pass on two phones** following `docs/manual-test-checklist.md`, both orientations. Hand the debug APK to the user.
- [ ] **Step 3: Push `main`, tag `v0.7.0`, confirm the release publishes.** Commit `chore: release 0.7.0 — the Flutter build`.

---

## Self-review notes

- Spec coverage: §2.1 → T1–2; §2.2 → T3–4; §2.3 → T5; §2.4 → T6; §2.5 → T7–11; §2.6 → T12; §2.7 error handling → T4 (malformed messages ignored, port fallback), T6 (`lastError`), T9 (no Wi-Fi), T10 (disconnect dialog), T8 (bank errors); §3 → T9; §4 → T8 (manifest), T13 (CI).
- Names used consistently: `HostServer/HostTransport`, `RoomBeacon`, `RoomDiscovery`, `Room`, `PlayerClient`, `ConnectionStatus`, `HostController`, `PlayerController`, `ShowClock`, `AnswerSlotRow`, `revealDelays`, `encodeRoomCode/decodeRoomCode`, `wifiIPv4`.
- The Kotlin `PermissionExplanationScreen` and `NearbyPermissions.kt` are intentionally not ported (spec §2.5).
