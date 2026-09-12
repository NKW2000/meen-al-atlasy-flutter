/// جهاز اللاعب — عميل "غبي": بيبعت ضغطة الزر وبيعرض الحالة اللي بتوصله.
/// ما بيحسب نقاط، ما بيقرر مين ضغط أول، وما بيوصله نص السؤال أصلاً.
///
/// نفس `PlayerViewModel.kt` بالمشروع الأصلي (Kotlin)، بفرق بنية الاتصال:
/// بدل Nearby (اكتشاف + اتصال بخطوتين، وبعدين بعت اسم الانضمام)، هون في
/// [RoomDiscovery] منفصل (بثّ UDP دوري) و[PlayerTransport] (اتصال
/// WebSocket) بياخد اسم اللاعب مباشرة كجزء من `connect()`. فـ`SEARCHING`
/// الأصلية صارت [discovering] بدل ما تكون قيمة تالتة بتعداد الحالة (حكم
/// المتحكمات ٥) — [status] بيرجّع نفس `ConnectionStatus` تبع الشبكة.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../game/models.dart';
import '../network/host_server.dart' show defaultHostPort;
import '../network/local_ip.dart';
import '../network/messages.dart';
import '../network/player_client.dart';
import '../network/room_code.dart';
import '../network/room_discovery.dart';

int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

class PlayerController extends ChangeNotifier {
  final RoomDiscovery discovery;
  final PlayerTransport client;

  /// مصدر وقت الضغطة — نفس `clock: () -> Long` بـ`PlayerViewModel.kt`،
  /// قابل للاستبدال بالاختبارات.
  final int Function() clock;

  /// مصدر عنوان الجهاز المحلي — `wifiIPv4()` افتراضياً، قابل للاستبدال
  /// بالاختبارات حتى نقدر نغطّي مسارَي `enterCode` (بند مهم #٥ بالمراجعة).
  final Future<InternetAddress?> Function() localIp;

  PlayerController({
    required this.discovery,
    required this.client,
    this.clock = _defaultClock,
    this.localIp = wifiIPv4,
  }) {
    _rooms = discovery.rooms.value;
    discovery.rooms.addListener(_onRoomsChanged);
    client.state.addListener(_onChanged);
    client.status.addListener(_onChanged);
    client.playerId.addListener(_onChanged);
    client.teamId.addListener(_onChanged);
  }

  /// الاسم اللي كتبه اللاعب — بينحفظ لحد ما يصير في اتصال، لأن اللاعب
  /// بيكتبه قبل ما نلاقي المضيف.
  String? _pendingName;
  TeamId? _pendingTeam;

  /// عم ندوّر على غرف حالياً — بديل حالة `SEARCHING` الأصلية (حكم ٥).
  bool _discovering = false;

  List<Room> _rooms = [];
  String? _lastError;

  bool get discovering => _discovering;
  List<Room> get rooms => _rooms;
  GameState? get state => client.state.value;
  ConnectionStatus get status => client.status.value;
  String? get playerId => client.playerId.value;
  TeamId? get teamId => client.teamId.value;
  String? get lastError => _lastError;
  String? get pendingName => _pendingName;

  /// بيسجّل الاسم وبيبلّش يدوّر على الغرف — بدون ما يتصل بوحدة. إذا كنا
  /// متّصلين أصلاً، بيبعت انضمام جديد بالاسم المحدّث عالاتصال الحالي.
  void join(String name, {TeamId? teamId}) {
    _pendingName = name;
    _pendingTeam = teamId;
    if (client.status.value != ConnectionStatus.connected) {
      _rooms = [];
      _discovering = true;
      notifyListeners();
      unawaited(startDiscovery());
    } else {
      client.send(JoinMessage(
        playerName: name,
        teamId: teamId,
        playerId: client.playerId.value,
      ));
    }
  }

  Future<void> startDiscovery() async {
    _discovering = true;
    notifyListeners();
    await discovery.start();
  }

  Future<void> stopDiscovery() async {
    _discovering = false;
    await discovery.stop();
    notifyListeners();
  }

  /// اللاعب اختار غرفة من اللستة.
  Future<void> enterRoom(Room room) async {
    if (client.status.value == ConnectionStatus.connected) return;
    final name = _pendingName;
    if (name == null) return;
    _discovering = false;
    await discovery.stop();
    await _connect(room.host, room.port, name);
  }

  /// اللاعب كتب كود الغرفة يدوياً — بيتحول لعنوان IP باستعمال عنوانه هو.
  Future<void> enterCode(String code) async {
    final myIp = await localIp();
    if (myIp == null) {
      _lastError = 'افتح الواي فاي أو نقطة الاتصال';
      notifyListeners();
      return;
    }
    final host = decodeRoomCode(code, myIp);
    if (host == null) {
      _lastError = 'كود الغرفة مش صحيح';
      notifyListeners();
      return;
    }
    final name = _pendingName;
    if (name == null) return;
    _discovering = false;
    await discovery.stop();
    await _connect(host, defaultHostPort, name);
  }

  Future<void> _connect(InternetAddress host, int port, String name) async {
    try {
      await client.connect(
        host: host,
        port: port,
        playerName: name,
        teamId: _pendingTeam,
      );
      _lastError = null;
    } catch (_) {
      _lastError = 'تعذّر الاتصال بالمضيف';
    }
    notifyListeners();
  }

  void onBuzzTapped() {
    if (!canBuzz()) return;
    final id = client.playerId.value;
    if (id == null) return;
    client.send(BuzzMessage(playerId: id, atMillis: clock()));
  }

  /// قرار «نلعب» أو «نمرّر» — بيوصل بس من اللاعب اللي كسب المواجهة.
  void choose(bool play) {
    final id = client.playerId.value;
    if (id == null) return;
    if (client.state.value?.phase != RoundPhase.playOrPass) return;
    client.send(ChooseMessage(playerId: id, play: play));
  }

  /// الزر بيشتغل بس لما المضيف يفتحه لهاد اللاعب بالذات.
  bool canBuzz() {
    final s = client.state.value;
    final id = client.playerId.value;
    if (s == null || id == null) return false;
    return client.status.value == ConnectionStatus.connected &&
        s.armedPlayerIds().contains(id);
  }

  /// لون شاشة اللاعب: وميض / أزرق / أخضر / أحمر.
  PlayerMark mark() =>
      client.state.value?.markFor(client.playerId.value) ?? PlayerMark.idle;

  /// تغيير الفريق باللوبي قبل ما تبلّش اللعبة.
  void changeTeam(TeamId t) {
    final id = client.playerId.value;
    if (id == null) return;
    _pendingTeam = t;
    client.send(ChangeTeamMessage(playerId: id, teamId: t));
  }

  /// رجوع لنفس اللعبة بعد الانقطاع — بنفس الاسم والفريق ومعرّف اللاعب
  /// المحفوظ (المضيف بيعيد ربطنا بنفس مكاننا).
  Future<void> rejoin() async {
    if (_pendingName == null) return;
    _lastError = null;
    notifyListeners();
    try {
      await client.rejoin();
    } catch (_) {
      _lastError = 'تعذّر الاتصال بالمضيف';
      notifyListeners();
    }
  }

  void dismissError() {
    _lastError = null;
    notifyListeners();
  }

  void _onRoomsChanged() {
    _rooms = discovery.rooms.value;
    notifyListeners();
  }

  void _onChanged() => notifyListeners();

  @override
  void dispose() {
    discovery.rooms.removeListener(_onRoomsChanged);
    client.state.removeListener(_onChanged);
    client.status.removeListener(_onChanged);
    client.playerId.removeListener(_onChanged);
    client.teamId.removeListener(_onChanged);
    unawaited(client.disconnect());
    unawaited(discovery.stop());
    super.dispose();
  }
}
