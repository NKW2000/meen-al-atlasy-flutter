/// نسخ وهمية مشتركة لاختبارات [HostController] — نقل شبكة بالذاكرة
/// ومنارة ما بتبعت UDP، مع مساعدات الانضمام والضغط. مفصولة بملف لحالها
/// لأنها بتنستعمل بأكتر من ملف اختبار (المتحكّم نفسه، والغرفة الكبيرة).
library;

import 'dart:async';

import 'package:meen_al_atlasy/game/models.dart';
import 'package:meen_al_atlasy/game/settings.dart';
import 'package:meen_al_atlasy/network/host_server.dart';
import 'package:meen_al_atlasy/network/messages.dart';
import 'package:meen_al_atlasy/network/room_beacon.dart';

/// بديل بالذاكرة عن [HostTransport] — بيخلينا نختبر [HostController] بدون
/// شبكة حقيقية. نفس فكرة `FakeNearbyConnectionsManager.kt`.
class FakeHostTransport implements HostTransport {
  StreamController<ClientEvent> _controller = StreamController<ClientEvent>.broadcast();

  int startCalls = 0;
  int stopCalls = 0;
  bool started = false;
  int _port = 4000;

  final List<(String, HostMessage)> sends = [];
  final List<HostMessage> broadcasts = [];

  @override
  int get port => _port;

  @override
  Stream<ClientEvent> get events => _controller.stream;

  @override
  Future<void> start({int port = defaultHostPort}) async {
    startCalls++;
    started = true;
    _port = port == 0 ? 4000 : port;
    // نفس `HostServer` الحقيقي: `stop()` بيسكّر الدفق، فلازم واحد جديد
    // هون وإلا `startHosting()` بتشترك بدفق ميت (بند حرج #١ بالمراجعة).
    if (_controller.isClosed) {
      _controller = StreamController<ClientEvent>.broadcast();
    }
  }

  @override
  void send(String endpointId, HostMessage m) => sends.add((endpointId, m));

  @override
  void broadcast(HostMessage m) => broadcasts.add(m);

  /// نقاط النهاية اللي المضيف سكّرها (لاعب جديد بعد بداية اللعبة مثلاً).
  final List<String> closed = [];

  @override
  Future<void> close(String endpointId) async => closed.add(endpointId);

  @override
  Future<void> stop() async {
    stopCalls++;
    started = false;
    await _controller.close();
  }

  void emit(ClientEvent e) => _controller.add(e);
}

/// بديل بالذاكرة عن [RoomBeacon] — بيسجّل نداءات start/stop بدل ما يبعت
/// UDP فعلي.
class FakeRoomBeacon extends RoomBeacon {
  int startCalls = 0;
  int stopCalls = 0;
  bool running = false;
  String? lastRoomName;
  int? lastPort;

  @override
  Future<void> start({required String roomName, required int port}) async {
    startCalls++;
    running = true;
    lastRoomName = roomName;
    lastPort = port;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    running = false;
  }
}

/// بينتظر لحد ما تخلص كل الـ microtasks المعلّقة (وصول أحداث الـ
/// StreamController.broadcast للمستمعين) — بديل بسيط عن
/// `testScheduler.advanceUntilIdle()` بكوتلن.
Future<void> pump() => Future.delayed(Duration.zero);

void join(FakeHostTransport t, List<String> endpoints) {
  for (final id in endpoints) {
    t.emit(ClientMessageReceived(id, JoinMessage(playerName: id)));
  }
}

void buzz(FakeHostTransport t, String endpointId, {int atMillis = 1}) {
  t.emit(ClientMessageReceived(
    endpointId,
    BuzzMessage(playerId: endpointId, atMillis: atMillis),
  ));
}

void choose(FakeHostTransport t, String endpointId, bool play) {
  t.emit(ClientMessageReceived(
    endpointId,
    ChooseMessage(playerId: endpointId, play: play),
  ));
}

/// سؤال جاهز للاختبارات — جوابين وبس، نص السؤال مش مهم هون.
Question testQuestion(String id) => Question(
      id: id,
      text: 'سؤال $id',
      category: 'عام',
      answers: const [
        Answer(text: 'أ', points: 60),
        Answer(text: 'ب', points: 40),
      ],
    );

/// لعبة بأقصى عدد جولات — لغرفة كبيرة بلاعبين كتير.
GameState bigGameState() => GameState(
      questions: [
        for (var i = 1; i <= GameSettings.maxRounds; i++) testQuestion('q$i'),
      ],
      multipliers: List.filled(GameSettings.maxRounds, 1),
      teams: const {
        TeamId.team1: TeamState(id: TeamId.team1, name: 'الفريق الأخضر'),
        TeamId.team2: TeamState(id: TeamId.team2, name: 'الفريق الأزرق'),
      },
    );
