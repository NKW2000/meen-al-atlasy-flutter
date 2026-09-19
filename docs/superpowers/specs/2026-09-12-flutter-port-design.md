# مين الأطليسي — Flutter port design

**Date:** 2026-09-12
**Source of truth for behaviour:** the Kotlin app at `C:\Projects\WHO-IS-THE-ATLESY` (tag `v0.6.8`).
**Goal:** a 1:1 port of the Kotlin/Compose app to Flutter — same screens, rules, look, motion, copy, sounds and question bank — running on Android now and iOS later, with the only under-the-hood change being the transport: Wi-Fi sockets instead of Nearby Connections.

## 1. Decisions already made

| Question | Decision |
|---|---|
| Platforms | Android + iOS. iOS is built later (no Apple account yet); code stays cross-platform-clean from day one. |
| Offline | Must work with no internet. Everyone joins the same Wi-Fi or the host phone's hotspot. |
| Scope of v1 | Full parity with the Kotlin app, including animations, sounds, bank import and demo mode. |
| Transport | Host phone runs a WebSocket server (`dart:io`), players discover it by UDP broadcast, with a 5-digit room-code fallback. No native plugins for networking. |
| Code layout | One Flutter package, four folders (`game`, `network`, `questions`, `ui`). The engine stays pure Dart by convention. |
| State | `ChangeNotifier` + built-in `ListenableBuilder`. No state-management package. |
| Repo | `C:\Projects\meen-al-atlasy-flutter`, own GitHub repo. Package `meen_al_atlasy`, Android `applicationId` نفس معرّف التطبيق الأصلي, `versionCode` continues from 26. |

## 2. Architecture

```
┌──────────── host phone ─────────────┐        ┌──────── player phone ────────┐
│ ui/host/*  ──▶ HostController       │        │ ui/player/* ◀── PlayerController │
│                 │  GameEngine       │  UDP   │                   │            │
│                 │  (pure Dart)      │ beacon │                   │            │
│                 ▼                   │ ──────▶│  RoomDiscovery (listen)        │
│              HostServer             │        │                   │            │
│   HttpServer + WebSockets, :47215   │◀──────▶│  PlayerClient (WebSocket)      │
│   broadcasts masked GameState       │  JSON  │  sends join / team / buzz / choice │
└─────────────────────────────────────┘        └───────────────────────────────┘
```

The host is the single source of truth. Every event goes through `GameEngine`; the resulting `GameState` is masked and pushed to every player as one `state` message. Players render state and send intents only.

### 2.1 `lib/game/` — rules engine (pure Dart, no `flutter` imports)

Port of `core-game` line for line:

- `models.dart`: `Answer`, `Question`, `TeamId`, `TeamState`, `Player`, `PlayerMark`, `RoundPhase`, `BuzzState`, `Award`, `GameState` (all computed getters: `currentQuestion`, `multiplier`, `activeTeam`, `leadingTeam`, `podiumPlayer`, `opponentOf`, `armedPlayerIds`, `markFor`, `maxSeat`, …), `maskedForPlayers()`, constants `CHOICE_SECONDS = 5`, `DEFAULT_ANSWER_SECONDS = 10`. Immutable classes with `copyWith`, `toJson`/`fromJson` (hand-written, no codegen), value equality.
- `events.dart`: `Buzz`, `JudgeCorrect`, `JudgeWrong`, `ChooseControl`, `NextRound`, `PlayerJoined`, `PlayerLeft`, `PlayerMoved`, `StartGame`, `ReplaceQuestion`, `Tick`, `EndGame` — a sealed class hierarchy.
- `engine.dart`: `GameEngine` with `state`, `apply(GameEvent) → GameState`, and the same private handlers (face-off, second chance, play-or-pass, play, steal, round end, scoreboard, ticks, timeouts, strikes, wrong ticks, pot/award with multiplier, seat rotation, question replacement).
- `settings.dart`: `GameSettings` with the same defaults and `clamped()`, `multipliersForRounds()`, `questionsNeeded()`.

Tests: every case in `GameEngineFaceOffTest`, `GameEnginePlayersTest`, `GameEngineRoundTest`, `GameModelsTest` ported to `test/game/` with the same names, plus `test/game/settings_test.dart` from `GameSettingsTest`.

### 2.2 `lib/network/` — transport (pure `dart:io`)

- `messages.dart`: `ClientMessage` (`join {playerName, teamId?}`, `team {playerId, teamId}`, `buzz {playerId, atMillis}`, `choice {playerId, play}`) and `HostMessage` (`state {state}`, `assigned {playerId, teamId}`). JSON shape identical to `Messages.kt` (`"type"` discriminator, unknown keys ignored).
- `host_server.dart`: `HostServer.start({port = 47215})` binds `0.0.0.0` (random port if taken), upgrades HTTP to WebSocket at `/`, assigns each socket an `endpointId`. API: `Stream<ClientEvent>` (`Connected(id)`, `Message(id, ClientMessage)`, `Disconnected(id)`), `send(id, HostMessage)`, `broadcast(HostMessage)`, `stop()`. Ping every 5 s; three missed pongs = disconnected.
- `room_beacon.dart` (host): every 1 s sends a UDP broadcast to `255.255.255.255:47216` — `{"room": name, "port": p, "version": 1}`. Runs only while the lobby is open (stops at `StartGame`, restarts on "back to lobby").
- `room_discovery.dart` (player): binds UDP `0.0.0.0:47216` with `broadcastEnabled`, keeps rooms seen in the last 4 s as `ValueNotifier<List<Room>>` where `Room = (name, host: InternetAddress, port, endpointId = "$host:$port")`.
- `room_code.dart`: `encode(InternetAddress ip) → "11009"` — five digits = `third * 256 + fourth` (so `192.168.43.1` → `43·256 + 1 = 11009`; covers every octet value) — and `decode(code, myIp) → InternetAddress` (first two octets from the player's own IPv4, since both phones share the /16 in every hotspot or home setup). Pure functions, unit-tested; the host screen shows the full IP too for the rare case where the /16 differs.
- `player_client.dart`: `connect(host, port, playerName, teamId?)`, `send(ClientMessage)`, `ValueNotifier<GameState?> state`, `ValueNotifier<ConnectionStatus> status` (`connecting / connected / disconnected`), `rejoin()` which reconnects and re-sends `join` with the same `playerId` (the host maps a re-joining `playerId` back to its seat, as today).
- `local_ip.dart`: picks the host's IPv4 on the Wi-Fi/hotspot interface (`NetworkInterface.list`, prefer `wlan*`/`ap*`/`en0`/`bridge*`, exclude loopback and `10.0.2.*` emulator). Shown on the host lobby with the room code.

Tests in `test/network/`: message round-trips, `maskedForPlayers` never leaks hidden answer text or the question text, room code encode/decode, and a loopback test that starts `HostServer` on `127.0.0.1`, connects a `PlayerClient`, sends `join`, and receives `assigned` + `state`.

### 2.3 `lib/questions/` — bank

- `bank.dart`: `QuestionBank.builtIn()` loads `assets/questions/starter_questions.json` (copied from `data-questions`), `QuestionBank.parse(String json)` validates exactly as `docs/question-bank.md` (required `text`, 2–8 answers, positive points, generated ids, `isRead` default false, duplicates by text rejected), returns either questions or a list of human-readable Arabic errors.
- `bank_store.dart`: the imported bank is stored as a file in the app documents directory; `SettingsRepository` remembers its name and count. Same "read questions don't come back until all are read" bookkeeping.

### 2.4 `lib/app/` — controllers and settings

- `host_controller.dart` (`ChangeNotifier`): owns `GameEngine`, `HostServer`, `RoomBeacon`, the 1 s tick timer (`Timer.periodic`, ticking only while `answerSecondsLeft > 0 || choiceSecondsLeft > 0`), player ↔ endpoint mapping, `lastError`. Public API mirrors `HostViewModel`: `resetSession`, `startHosting`, `movePlayer`, `startGame`, `judgeCorrect(i)`, `judgeWrong`, `nextRound`, `changeQuestion`, `dismissError`, `advertising`.
- `player_controller.dart` (`ChangeNotifier`): owns `RoomDiscovery` and `PlayerClient`; API mirrors `PlayerViewModel`: `startDiscovery`, `enterRoom(room)`, `enterCode(code)`, `onBuzzTapped`, `choose(play)`, `changeTeam`, `rejoin`, `mark()`.
- `settings_repository.dart`: `shared_preferences`, same keys and defaults as `GameSettings`.
- Both controllers are created once above the router (in `main.dart`) and passed down via an `InheritedNotifier`, so the connection survives navigation.

### 2.5 `lib/ui/` — screens, one file per Kotlin screen

| Kotlin | Dart | Notes |
|---|---|---|
| `IntroScreen` / `IntroPortraitScreen` | `intro/intro_screen.dart` | same 7.6 s choreography, tap skips |
| `HomeScreen` | `home/home_screen.dart` | |
| `HostSettingsScreen` | `host/host_settings_screen.dart` | rounds, multipliers, seconds, strikes, min/max answers (max 8), bank filter count |
| `HostSetupScreen` | `host/host_lobby_screen.dart` | + room code and IP line |
| `PlayerJoinScreen`, `RoomListScreen` | `player/player_join_screen.dart`, `player/room_list_screen.dart` | + "enter code" field |
| `HostGameBoardScreen` | `host/host_board_screen.dart` | 8 slots, reveal flip + stagger, strike flash, judge bar, change question |
| `PlayerScreen` | `player/player_screen.dart`, `player/player_lobby.dart`, `player/buzzer.dart`, `player/player_board.dart`, `player/play_or_pass.dart` | full-screen buzzer; colour = message; time-driven bar |
| `RoundOpening` | `show/round_opening.dart` | intro + versus; non-skippable, swallows taps; shown on host and players |
| `ScoreboardScreen` | `show/scoreboard_screen.dart` | |
| `GameOverScreen` | `show/game_over_screen.dart` | fireworks |
| `BankSettingsScreen` | `settings/bank_settings_screen.dart` | `file_picker` import |
| `PermissionExplanationScreen` | dropped — no runtime permissions are needed for sockets on Android; iOS shows its own Local Network prompt |
| Demo gallery | `demo/demo_gallery.dart`, enabled by `--dart-define=DEMO=true` | same fixtures as `DemoData.kt` |

Shared pieces in `ui/components/`: `stage.dart` (`StageBackground`, `CartoonSurface`, `blockSkin`, `flatShadow`), `buttons.dart`, `banners.dart`, `info_blocks.dart`, `score_header.dart`, `strikes.dart` (+ `StrikeFlash`), `countdown.dart`, `fireworks.dart`, `brand_logo.dart`, `wordmark.dart`, `confirm_dialog.dart`, `name_prompt_dialog.dart`, `answer_slot.dart` (the two-face flip row).

`ui/theme.dart`: `FeudColors`, `FeudShape`, the type scale (display = Baloo Bhaijaan 2, body = Tajawal), `arabic_numerals.dart` (`.ar()` extension). The whole app is wrapped in `Directionality(TextDirection.rtl)` and `MaterialApp(locale: ar)`.

`ui/motion/show_motion.dart`: `bang`, `keys`, `thump`, `drop`, `wipe`, `rise`, `slamScale`, `slamRotation`, `appear`, `shockRing`, `revealDelays`, plus `ShowClock` — a `Ticker`-driven `ValueNotifier<double>` of seconds since start, capped, re-keyed like `rememberShowClock`. `SpinningRays` is a `CustomPainter`.

`ui/responsive.dart`: `isPortrait`, `shortSide` from `MediaQuery`, the same "no screen scrolls; content inside safe area; background under the notch" rules.

### 2.6 Feedback

`lib/feedback/`: `GameFeedback` wraps `audioplayers` (cues `reveal`, `wrong`, `strike1..3`, `buzz`, `win`, `press`, looping `clock`) and `HapticFeedback`. `GameCues`, `CountdownCues`, `PlayerMarkCues` port the exact trigger rules from `GameCues.kt` as listeners on the controllers. Assets copied from `app/src/main/res/raw/` to `assets/sounds/`.

### 2.7 Error handling

- Host cannot bind the port → try a random port; if no Wi-Fi IPv4 at all → lobby shows "افتح الواي فاي أو نقطة الاتصال" and hosting is disabled.
- Player loses the socket → status `disconnected`, the "انقطعت عن اللعبة" dialog with `rejoin` (same as today). Reconnect keeps `playerId`.
- Bad bank file → Arabic error list on the bank screen, nothing imported.
- Malformed message → logged and ignored (unknown `type`, missing fields).

## 3. Discovery UX

- Host lobby shows: room name, "الواي فاي: 192.168.43.1", and "كود الغرفة: ١١٠٠٩".
- Player room list refreshes live from beacons; below the list a field "أو اكتب كود الغرفة" → `enterCode`.
- Both screens say once, in muted text: "لازم الكل يكون على نفس الواي فاي أو نقطة اتصال المضيف".

## 4. Build, tests, CI

- Android `minSdk 26`, `targetSdk 34`, `applicationId` نفس التطبيق الأصلي, debug signing for release when no keystore is configured (as today). A proper release keystore is a follow-up.
- Fonts under `assets/fonts/` (OFL), declared in `pubspec.yaml`.
- `flutter test` runs `test/game`, `test/network`, `test/questions`.
- `.github/workflows/release.yml`: on tag `v*` — `flutter test`, `flutter build apk --release`, `flutter build apk --release --dart-define=DEMO=true` (renamed `-demo`), publish both to a GitHub Release. An `ios` job is written but gated with `if: false`.

## 5. Out of scope for v1

- iOS signing/TestFlight (needs the Apple account).
- Internet/relay play.
- A release keystore.
- Any new feature not in the Kotlin app.

## 6. Order of work

1. Engine + models + ported tests (green before anything else).
2. Network layer + loopback tests.
3. Theme, motion helpers, shared components.
4. Screens in play order: intro, home, settings, lobby/join, board + buzzer, openings, scoreboard, game over, bank import.
5. Feedback (sounds/haptics), demo mode.
6. CI release workflow; tag `v0.7.0`.

Checkpoints for a real-device try: after step 2+4-lobby (host + two players over Wi-Fi/hotspot), and after the full loop.
