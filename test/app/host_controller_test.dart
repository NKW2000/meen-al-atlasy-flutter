/// اختبارات [HostController] — نسخة عن `HostViewModelTest.kt` بالمشروع
/// الأصلي، بفارق جوهري: هون منستعمل `FakeHostTransport` (بدل
/// `FakeNearbyConnectionsManager`) و`FakeRoomBeacon`، ومنتحقق كمان من ترجمة
/// نقطة النهاية (endpoint) لمعرّف اللاعب الثابت (حكم المتحكمات ١).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/app/host_controller.dart';
import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/network/host_server.dart';
import 'package:meen_al_atlasy/network/messages.dart';

import 'host_controller_fakes.dart';

Question _question(String id, String text, List<Answer> answers) =>
    Question(id: id, text: text, category: 'عام', answers: answers);

GameState _newGame() => GameState(
      questions: [
        _question('q1', 'سؤال١', [
          const Answer(text: 'أ', points: 60),
          const Answer(text: 'ب', points: 40),
        ]),
        _question('q2', 'سؤال٢', [const Answer(text: 'ج', points: 100)]),
      ],
      multipliers: const [1, 1],
      teams: const {
        TeamId.team1: TeamState(id: TeamId.team1, name: 'الفريق الأخضر'),
        TeamId.team2: TeamState(id: TeamId.team2, name: 'الفريق الأزرق'),
      },
    );

void main() {
  late FakeHostTransport transport;
  late FakeRoomBeacon beacon;

  HostController controller({Duration tick = const Duration(seconds: 1)}) {
    return HostController(
      server: transport,
      beacon: beacon,
      newGame: _newGame,
      tick: tick,
    );
  }

  setUp(() {
    transport = FakeHostTransport();
    beacon = FakeRoomBeacon();
  });

  test('startHosting starts the server and the beacon once', () async {
    final vm = controller();
    await vm.startHosting();
    await vm.startHosting();

    expect(transport.startCalls, equals(1));
    expect(beacon.startCalls, equals(1));
    expect(vm.advertising, isTrue);
  });

  test(
      'startHosting resubscribes to a fresh event stream after '
      'resetSession recreates it (review critical #1)', () async {
    final vm = controller();
    await vm.startHosting();
    join(transport, ['ep-a']);
    await pump();
    expect(vm.state.players, hasLength(1));

    await vm.resetSession();
    await vm.startHosting();

    // بدون إعادة الاشتراك هون، هاد الحدث كان رح يضيع بصمت لأنه الدفق
    // القديم (اللي اشتركنا فيه بالمُنشئ) انسكّر مع resetSession().
    join(transport, ['ep-b']);
    await pump();

    expect(vm.state.players.map((p) => p.id), contains('ep-b'));
    expect(
      transport.sends.last,
      equals(('ep-b', Assigned(playerId: 'ep-b', teamId: TeamId.team1))),
    );
  });

  test('players are handed out to keep the teams balanced', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b', 'ep-c', 'ep-d']);
    await pump();

    final state = vm.state;
    expect(state.playersOf(TeamId.team1).map((p) => p.id).toList(),
        equals(['ep-a', 'ep-c']));
    expect(state.playersOf(TeamId.team2).map((p) => p.id).toList(),
        equals(['ep-b', 'ep-d']));
    expect(
      transport.sends,
      equals([
        ('ep-a', Assigned(playerId: 'ep-a', teamId: TeamId.team1)),
        ('ep-b', Assigned(playerId: 'ep-b', teamId: TeamId.team2)),
        ('ep-c', Assigned(playerId: 'ep-c', teamId: TeamId.team1)),
        ('ep-d', Assigned(playerId: 'ep-d', teamId: TeamId.team2)),
      ]),
    );
  });

  test('only the podium player of a team can buzz', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b', 'ep-c']);
    await pump();

    buzz(transport, 'ep-c'); // نفس فريق ep-a بس مش لاعب المنصة
    await pump();
    expect(vm.state.buzzState, equals(BuzzState.open));

    buzz(transport, 'ep-b');
    await pump();
    expect(vm.state.buzzState, equals(BuzzState.lockedTeam2));
    expect(vm.state.buzzedPlayerId, equals('ep-b'));
  });

  test('buzz from an unknown endpoint is ignored', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    buzz(transport, 'stranger');
    await pump();

    expect(vm.state.buzzState, equals(BuzzState.open));
    expect(vm.state.buzzedPlayerId, isNull);
  });

  test(
      'a Buzz/Choose message is resolved by endpoint, not by whatever '
      'playerId the message itself claims', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    await pump();

    // ep-a يبعت بزّة بمعرّف مزيّف — لازم تنحسب على معرّفه الحقيقي فقط.
    transport.emit(ClientMessageReceived(
      'ep-a',
      BuzzMessage(playerId: 'someone-else', atMillis: 5),
    ));
    await pump();

    expect(vm.state.buzzedPlayerId, equals('ep-a'));
  });

  test('judging correct fills the round pot and passes the turn down the line',
      () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b', 'ep-c']);
    buzz(transport, 'ep-a');
    await pump();

    vm.judgeCorrect(0); // الجواب رقم ١ بيكسب المواجهة
    choose(transport, 'ep-a', true);
    await pump();

    final state = vm.state;
    expect(state.phase, equals(RoundPhase.play));
    expect(state.controllingTeam, equals(TeamId.team1));
    expect(state.pot, equals(60));
    expect(state.teams[TeamId.team1]!.score, equals(0));
    expect(state.turnPlayerId, equals('ep-c')); // مش نفس اللاعب اللي جاوب
  });

  test('players never receive the hidden answers', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    buzz(transport, 'ep-a');
    await pump();
    vm.judgeCorrect(0);
    await pump();

    final sent = (transport.broadcasts.last as StateUpdate).state;
    final question = sent.currentQuestion!;
    expect(question.answers[0].text, equals('أ'));
    expect(question.answers[1].text, equals(''));
    expect(vm.state.currentQuestion!.text, equals('سؤال١'));
    // نص السؤال نفسه ما بيوصل ولا جهاز لاعب.
    expect(question.text, equals(''));
  });

  test("three strikes hand the steal to the other team's podium player",
      () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    buzz(transport, 'ep-a');
    await pump();
    vm.judgeCorrect(0);
    choose(transport, 'ep-a', true);
    await pump();
    vm.judgeWrong();
    vm.judgeWrong();
    vm.judgeWrong();
    await pump();

    final state = vm.state;
    expect(state.phase, equals(RoundPhase.steal));
    expect(state.stealingTeam, equals(TeamId.team2));
    expect(state.turnPlayerId, equals('ep-b'));
  });

  test('ChangeTeam is accepted only before the game has started', () async {
    final vm = controller();
    // تلاتة: بعد ما ينتقل ep-a للفريق ٢ بيضل بالفريق ١ لاعب (ep-c) حتى
    // تقدر اللعبة تبلّش — startGame بيرفض فريق فاضي.
    join(transport, ['ep-a', 'ep-b', 'ep-c']);
    await pump();

    transport.emit(ClientMessageReceived(
      'ep-a',
      ChangeTeamMessage(playerId: 'ep-a', teamId: TeamId.team2),
    ));
    await pump();
    expect(vm.state.player('ep-a')!.teamId, equals(TeamId.team2));

    vm.startGame();
    await pump();
    transport.emit(ClientMessageReceived(
      'ep-a',
      ChangeTeamMessage(playerId: 'ep-a', teamId: TeamId.team1),
    ));
    await pump();
    // بعد بداية اللعبة ما بيضل حدا يغيّر فريقه.
    expect(vm.state.player('ep-a')!.teamId, equals(TeamId.team2));
  });

  test('only the winning podium player\'s choice is accepted', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    buzz(transport, 'ep-a');
    await pump();
    vm.judgeCorrect(0);
    await pump();

    // ep-b مش صاحب القرار — بينتجاهل.
    choose(transport, 'ep-b', false);
    await pump();
    expect(vm.state.phase, equals(RoundPhase.playOrPass));

    choose(transport, 'ep-a', false);
    await pump();

    // مرّرها، فاللوح راح للفريق التاني.
    expect(vm.state.phase, equals(RoundPhase.play));
    expect(vm.state.controllingTeam, equals(TeamId.team2));
  });

  test('next round shows everyone the scoreboard first', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    buzz(transport, 'ep-a');
    await pump();
    vm.judgeCorrect(0);
    choose(transport, 'ep-a', true);
    await pump();
    vm.judgeCorrect(1); // انكشف اللوح كله
    await pump();
    vm.nextRound();
    await pump();

    final sent = (transport.broadcasts.last as StateUpdate).state;
    expect(sent.phase, equals(RoundPhase.scoreboard));
    expect(vm.state.phase, equals(RoundPhase.scoreboard));
  });

  test('a disconnected device is marked offline and rejoining by name '
      're-attaches it', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    await pump();
    transport.emit(ClientDisconnected('ep-a'));
    await pump();

    expect(vm.state.player('ep-a')!.connected, isFalse);
    expect(vm.state.teams[TeamId.team1]!.connected, isFalse);

    // إعادة اتصال بنقطة نهاية جديدة، بنفس الاسم — ما في playerId محفوظ
    // (أول اتصال ثاني من هاد الجهاز مثلاً).
    transport.emit(ClientMessageReceived('ep-a-2', JoinMessage(playerName: 'ep-a')));
    await pump();

    expect(vm.state.players.length, equals(2));
    expect(vm.state.player('ep-a')!.connected, isTrue);
    expect(vm.state.playersOf(TeamId.team1).length, equals(1));
    expect(
      transport.sends.last,
      equals(('ep-a-2', Assigned(playerId: 'ep-a', teamId: TeamId.team1))),
    );
  });

  test('rejoining with a remembered playerId re-attaches regardless of name',
      () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    await pump();
    transport.emit(ClientDisconnected('ep-a'));
    await pump();
    expect(vm.state.player('ep-a')!.connected, isFalse);

    // إعادة اتصال بنقطة نهاية جديدة كليّاً، حاملة معرّف اللاعب المحفوظ من
    // آخر Assigned — حتى لو الاسم تغيّر.
    transport.emit(ClientMessageReceived(
      'ep-a-new',
      JoinMessage(playerName: 'اسم جديد', playerId: 'ep-a'),
    ));
    await pump();

    expect(vm.state.players.length, equals(2));
    final reattached = vm.state.player('ep-a')!;
    expect(reattached.connected, isTrue);
    expect(reattached.name, equals('اسم جديد'));
    expect(
      transport.sends.last,
      equals(('ep-a-new', Assigned(playerId: 'ep-a', teamId: TeamId.team1))),
    );

    // نقطة النهاية القديمة ما عاد لها تأثير — أي رسالة منها بتتجاهل.
    buzz(transport, 'ep-a');
    await pump();
    expect(vm.state.buzzedPlayerId, isNull);

    buzz(transport, 'ep-a-new');
    await pump();
    expect(vm.state.buzzedPlayerId, equals('ep-a'));
  });

  test(
      'an id-based reattach is rejected when the claimed name does not '
      'match a still-live player (review critical #2, defense in depth)',
      () async {
    final vm = controller();
    join(transport, ['ep0']);
    await pump();
    expect(vm.state.player('ep0')!.connected, isTrue);

    // نقطة نهاية ثانية بتدّعي نفس معرّف لاعب حيّ حالياً، باسم مختلف —
    // بالضبط زي معرّف نقطة نهاية اتكرر بمضيف جديد بمحض الصدفة.
    transport.emit(ClientMessageReceived(
      'ep-other',
      JoinMessage(playerName: 'غريب', playerId: 'ep0'),
    ));
    await pump();

    expect(vm.state.players.length, equals(2));
    expect(vm.state.player('ep0')!.name, equals('ep0')); // ما تغيّر
    expect(vm.state.player('ep-other'), isNotNull); // لاعب جديد كليّاً
    expect(
      transport.sends.last,
      equals(('ep-other', Assigned(playerId: 'ep-other', teamId: TeamId.team2))),
    );
  });

  test(
      'a same-identity reconnect race (new join arrives before the old '
      'disconnect notice) still re-attaches, and the late stale disconnect '
      'is a no-op (review important #3)', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    await pump();

    // إعادة اتصال بنقطة نهاية جديدة، بنفس المعرّف **ونفس الاسم**، **قبل**
    // ما توصلنا إشعار انقطاع نقطة النهاية القديمة — سباق شبكة شائع (نقطة
    // النهاية القديمة سكّرت فعلياً بس إشعارها لسا بالطريق).
    transport.emit(ClientMessageReceived(
      'ep-a-2',
      JoinMessage(playerName: 'ep-a', playerId: 'ep-a'),
    ));
    await pump();

    expect(vm.state.players.length, equals(2)); // ما انضاف لاعب جديد
    expect(vm.state.player('ep-a')!.connected, isTrue);

    // إشعار الانقطاع المتأخر لنقطة النهاية القديمة وصل أخيراً — ما لازم
    // يطرد اللاعب اللي رجع أصلاً بنقطة نهاية جديدة.
    transport.emit(ClientDisconnected('ep-a'));
    await pump();
    expect(vm.state.player('ep-a')!.connected, isTrue);

    // نقطة النهاية القديمة ماتت فعلياً — بزّة منها بتتجاهل.
    buzz(transport, 'ep-a');
    await pump();
    expect(vm.state.buzzedPlayerId, isNull);

    buzz(transport, 'ep-a-2');
    await pump();
    expect(vm.state.buzzedPlayerId, equals('ep-a'));
  });

  test('movePlayer works before the game starts and is blocked after',
      () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b', 'ep-c']);
    await pump();

    vm.movePlayer('ep-a', TeamId.team2);
    expect(vm.state.player('ep-a')!.teamId, equals(TeamId.team2));
    expect(
      transport.sends.last,
      equals(('ep-a', Assigned(playerId: 'ep-a', teamId: TeamId.team2))),
    );

    vm.startGame();
    vm.movePlayer('ep-a', TeamId.team1);
    expect(vm.state.player('ep-a')!.teamId, equals(TeamId.team2));
  });

  test('canChangeQuestion reflects the fresh-question supplier, and '
      'changeQuestion swaps the board', () async {
    final replacement = _question('q1-b', 'سؤال بديل', [
      const Answer(text: 'س', points: 10),
      const Answer(text: 'ص', points: 5),
    ]);
    Question? next = replacement;
    final vm = HostController(
      server: transport,
      beacon: beacon,
      newGame: _newGame,
      freshQuestion: () => next,
    );

    expect(vm.canChangeQuestion(), isTrue);
    vm.changeQuestion();
    expect(vm.state.currentQuestion!.id, equals('q1-b'));

    next = null;
    expect(vm.canChangeQuestion(), isFalse);
  });

  test('startGame stops the beacon; backToLobby keeps the players, clears '
      'the scores, and restarts the beacon', () async {
    final vm = controller();
    await vm.startHosting();
    join(transport, ['سامر', 'ليلى']);
    await pump();

    expect(beacon.running, isTrue);
    vm.startGame();
    await pump();
    expect(beacon.running, isFalse);

    await vm.backToLobby();
    await pump();

    final state = vm.state;
    expect(state.players.map((p) => p.name).toSet(), equals({'سامر', 'ليلى'}));
    expect(state.matchStarted, isFalse);
    expect(state.gameOver, isFalse);
    expect(state.teams.values.fold<int>(0, (sum, t) => sum + t.score), equals(0));
    // البثّ ما وقف والمنارة رجعت تشتغل — اللاعبين بيضلوا شايفين الغرفة.
    expect(beacon.running, isTrue);
    expect(transport.stopCalls, equals(0));
  });

  test('applySettings rebuilds the lobby state from the current settings and keeps '
      'the connected players', () async {
    // الإعدادات بتتغيّر بعد resetSession (المضيف بيعدّلها بشاشة الإعدادات
    // قبل اللوبي) — اللوبي لازم يبني الحالة من الإعدادات الحالية.
    var teamName = 'الفريق الأخضر';
    final vm = HostController(
      server: transport,
      beacon: beacon,
      newGame: () => _newGame().copyWith(
        teams: {
          TeamId.team1: TeamState(id: TeamId.team1, name: teamName),
          TeamId.team2: const TeamState(id: TeamId.team2, name: 'الفريق الأزرق'),
        },
        multipliers: const [1, 2, 3],
      ),
    );
    await vm.startHosting();
    join(transport, ['سامر', 'ليلى']);
    await pump();
    expect(vm.state.teams[TeamId.team1]!.name, 'الفريق الأخضر');

    teamName = 'نمور الشام';
    final before = transport.broadcasts.length;
    vm.applySettings();
    await pump();

    expect(vm.state.teams[TeamId.team1]!.name, 'نمور الشام');
    expect(vm.state.multipliers, [1, 2, 3]);
    expect(vm.state.players.map((p) => p.name).toSet(), {'سامر', 'ليلى'});
    // اللاعبين لازم يشوفوا الأسماء الجديدة فوراً.
    expect(transport.broadcasts.length, greaterThan(before));
    final last = transport.broadcasts.whereType<StateUpdate>().last;
    expect(last.state.teams[TeamId.team1]!.name, 'نمور الشام');

    // بعد ما تبلّش اللعبة ما بتنعاد الحالة.
    vm.startGame();
    teamName = 'غيره';
    vm.applySettings();
    expect(vm.state.teams[TeamId.team1]!.name, 'نمور الشام');
    expect(vm.state.matchStarted, isTrue);
  });

  test('a second Join from the same endpoint renames the same player instead of adding a ghost', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    await pump();

    transport.emit(ClientMessageReceived('ep-a', JoinMessage(playerName: 'سامر')));
    await pump();

    expect(vm.state.players.length, equals(2));
    expect(vm.state.player('ep-a')!.name, equals('سامر'));
    expect(vm.state.players.where((p) => p.connected).length, equals(2));
  });

  test('a brand-new player after the game started is refused and its connection closed', () async {
    final vm = controller();
    join(transport, ['ep-a', 'ep-b']);
    await pump();
    vm.startGame();

    join(transport, ['ep-late']);
    await pump();

    expect(vm.state.player('ep-late'), isNull);
    expect(transport.closed, equals(['ep-late']));

    // بس لاعب انقطع بيقدر يرجع بنقطة نهاية جديدة.
    transport.emit(ClientDisconnected('ep-b'));
    await pump();
    transport.emit(ClientMessageReceived('ep-b2', JoinMessage(playerName: 'ep-b', playerId: 'ep-b')));
    await pump();
    expect(vm.state.player('ep-b')!.connected, isTrue);
    expect(transport.closed, equals(['ep-late']));
  });

  test('player names are trimmed, capped and never empty', () async {
    final vm = controller();
    transport.emit(ClientMessageReceived('ep-a', JoinMessage(playerName: '   ')));
    transport.emit(ClientMessageReceived('ep-b', JoinMessage(playerName: '  أبو   العبد  ')));
    transport.emit(ClientMessageReceived('ep-c', JoinMessage(playerName: 'x' * 60)));
    await pump();

    expect(vm.state.player('ep-a')!.name, equals('لاعب'));
    expect(vm.state.player('ep-b')!.name, equals('أبو العبد'));
    expect(vm.state.player('ep-c')!.name.length, equals(HostController.maxPlayerName));
  });

  test('startGame refuses to start with an empty team', () async {
    final vm = controller();
    join(transport, ['ep-a']);
    await pump();

    expect(vm.canStart, isFalse);
    vm.startGame();
    expect(vm.state.matchStarted, isFalse);

    join(transport, ['ep-b']);
    await pump();
    expect(vm.canStart, isTrue);
    vm.startGame();
    expect(vm.state.matchStarted, isTrue);
  });

  test('resetSession stops the server and the beacon and clears the state',
      () async {
    final vm = controller();
    await vm.startHosting();
    join(transport, ['ep-a', 'ep-b']);
    await pump();
    vm.startGame();

    await vm.resetSession();

    expect(transport.stopCalls, equals(1));
    // startGame() وقف المنارة أصلاً، وresetSession() بيوقفها (تاني) للتأكد.
    expect(beacon.stopCalls, equals(2));
    expect(beacon.running, isFalse);
    expect(vm.advertising, isFalse);
    expect(vm.state.players, isEmpty);

    // بعد الرجوع منقدر نبلّش استضافة جديدة.
    await vm.startHosting();
    expect(transport.startCalls, equals(2));
  });

  test('the clock ticks the engine down while a decision or answer is '
      'pending, and stops once the game is over', () async {
    final vm = controller(tick: const Duration(milliseconds: 10));
    join(transport, ['ep-a', 'ep-b']);
    await pump(); // اللاعبين لازم ينضموا قبل ما تبلّش اللعبة.
    vm.startGame();
    buzz(transport, 'ep-a');
    await pump();
    vm.judgeCorrect(0); // -> playOrPass, choiceSecondsLeft = 5
    // منتأكد فوراً — قبل أي `await` ممكن يخلّي الساعة الحقيقية (١٠ملي)
    // تلحق تدق قبل ما نلقط القيمة الأصلية.
    expect(vm.state.choiceSecondsLeft, equals(5));

    await Future.delayed(const Duration(milliseconds: 55));

    expect(vm.state.choiceSecondsLeft, lessThan(5));
    expect(
      transport.broadcasts.whereType<StateUpdate>().length,
      greaterThan(2),
    );
  });

  test('a plain second on the clock sends the small packet, not the whole state',
      () async {
    final vm = controller(tick: const Duration(milliseconds: 10));
    join(transport, ['ep-a', 'ep-b']);
    await pump();
    vm.startGame();
    buzz(transport, 'ep-a');
    await pump();
    vm.judgeCorrect(0); // -> playOrPass، العدّاد ٥ ثواني
    expect(vm.state.choiceSecondsLeft, equals(5));

    final statesBefore = transport.broadcasts.whereType<StateUpdate>().length;
    await Future.delayed(const Duration(milliseconds: 25));

    // مرقت ثواني: وصلت حزم عدّاد، وما انبعتت حالة كاملة بلا داعي.
    final clocks = transport.broadcasts.whereType<ClockUpdate>().toList();
    expect(clocks, isNotEmpty);
    expect(transport.broadcasts.whereType<StateUpdate>().length, statesBefore);
    expect(clocks.last.choiceSecondsLeft, lessThan(5));
  });

  test('a second that changes more than the clock still sends the full state',
      () async {
    final vm = controller(tick: const Duration(milliseconds: 10));
    join(transport, ['ep-a', 'ep-b']);
    await pump();
    vm.startGame();
    buzz(transport, 'ep-a');
    await pump();
    vm.judgeCorrect(0);
    final statesBefore = transport.broadcasts.whereType<StateUpdate>().length;

    // خلّي العدّاد يوصل للصفر — هناك الثانية بتغيّر المرحلة كمان.
    await Future.delayed(const Duration(milliseconds: 120));

    expect(vm.state.choiceSecondsLeft, equals(0));
    expect(
      transport.broadcasts.whereType<StateUpdate>().length,
      greaterThan(statesBefore),
    );
  });

  test('a judgement that belongs to an older answer turn is ignored', () async {
    final vm = controller(tick: const Duration(milliseconds: 10));
    join(transport, ['ep-a', 'ep-b']);
    await pump();
    vm.startGame();
    buzz(transport, 'ep-a');
    await pump();

    // الرقم اللي شاشة المضيف مبنية عليه وهو عم يستنى جواب اللاعب الأول.
    final turnOnScreen = vm.state.answerTurn;

    // خلص وقت اللاعب لحاله — المحرك حسبها غلط ونقل الدور للخصم.
    await Future.delayed(const Duration(milliseconds: 150));
    expect(vm.state.phase, RoundPhase.faceOffSecond);
    final opponentTurn = vm.state.answerTurn;

    // المضيف دوس «غلط» متأخّر — بترجع بلا مفعول.
    vm.judgeWrong(turn: turnOnScreen);

    expect(vm.state.phase, RoundPhase.faceOffSecond);
    expect(vm.state.answerTurn, opponentTurn);

    // وبرقم الدور الحالي بتزبط عادي.
    vm.judgeWrong(turn: vm.state.answerTurn);
    expect(vm.state.phase, isNot(RoundPhase.faceOffSecond));
  });

  test('endGame stops the clock', () async {
    final vm = controller(tick: const Duration(milliseconds: 10));
    join(transport, ['ep-a', 'ep-b']);
    await pump();
    vm.startGame();
    buzz(transport, 'ep-a');
    await pump();
    vm.judgeCorrect(0);
    expect(vm.state.choiceSecondsLeft, equals(5));

    vm.endGame();
    final countAfterEnd = transport.broadcasts.length;
    await Future.delayed(const Duration(milliseconds: 60));

    expect(vm.state.gameOver, isTrue);
    expect(transport.broadcasts.length, equals(countAfterEnd));
  });

  test('dismissError clears the last error, and a failed startHosting '
      'resets advertising so it can be retried', () async {
    final failing = _FailingTransport();
    final vm = HostController(server: failing, beacon: beacon, newGame: _newGame);
    await vm.startHosting();

    expect(vm.lastError, isNotNull);
    expect(vm.advertising, isFalse); // review important #4
    vm.dismissError();
    expect(vm.lastError, isNull);
  });
}

/// نقل وهمي بيفشل بداية التشغيل — لاختبار [HostController.lastError].
class _FailingTransport implements HostTransport {
  final _controller = StreamController<ClientEvent>.broadcast();

  @override
  int get port => 0;

  @override
  Stream<ClientEvent> get events => _controller.stream;

  @override
  Future<void> start({int port = defaultHostPort}) async {
    throw Exception('تعذّر بدء البث');
  }

  @override
  void send(String endpointId, HostMessage m) {}

  @override
  void broadcast(HostMessage m) {}

  @override
  Future<void> close(String endpointId) async {}

  @override
  Future<void> stop() async {}
}
