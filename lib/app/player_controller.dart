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
import 'user_error.dart';

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
    client.rejection.addListener(_onRejected);
  }

  /// المضيف رفضنا (اللعبة بلّشت مثلاً): ما منحاول نرجع، ومنرجّع اللاعب
  /// للستة مع السبب — بدل خمس محاولات فاشلة و«انقطعت عن اللعبة».
  void _onRejected() {
    final reason = client.rejection.value;
    if (reason == null) return;
    _rejected = true;
    _leftOnPurpose = true;
    _reconnecting = false;
    _rejoinAttempt = 0;
    _rejoinTimer?.cancel();
    _rejoinTimer = null;
    _lastError = UserError(reason, hint: 'استنّى المضيف يفتح غرفة جديدة');
    unawaited(client.leave().then((_) => startDiscovery()));
    notifyListeners();
  }

  /// الاسم اللي كتبه اللاعب — بينحفظ لحد ما يصير في اتصال، لأن اللاعب
  /// بيكتبه قبل ما نلاقي المضيف.
  String? _pendingName;
  TeamId? _pendingTeam;

  /// عم ندوّر على غرف حالياً — بديل حالة `SEARCHING` الأصلية (حكم ٥).
  bool _discovering = false;

  /// عم نحاول نرجع لحالنا بعد انقطاع مش مقصود.
  bool _reconnecting = false;

  /// المحاولة رقم كم — منوقف بعد [_maxAutoRejoins].
  int _rejoinAttempt = 0;
  Timer? _rejoinTimer;

  /// اللاعب طلع بإرادته — ما منحاول نرجّعه.
  bool _leftOnPurpose = false;

  /// المضيف رفضنا — الشاشة بترجع للستة الغرف (بينمسح مع أول اتصال جديد).
  bool _rejected = false;

  /// عنوان المضيف اللي متّصلين فيه — منه كود الغرفة اللي بيبيّن للاعب.
  InternetAddress? _hostAddress;

  List<Room> _rooms = [];
  UserError? _lastError;

  bool get discovering => _discovering;

  /// عم نرجع للعبة لحالنا — الشاشة بتقول «عم نرجّعك…» بدل ما تسأل فوراً.
  bool get reconnecting => _reconnecting;

  /// المضيف رفض انضمامنا (شوف [_onRejected]).
  bool get rejected => _rejected;

  /// كود الغرفة (٥ أرقام) — نفس اللي عند المضيف، حتى اللاعب يقدر يعطيه
  /// لغيره. `null` قبل الاتصال أو لما العنوان مش IPv4.
  String? get roomCode {
    final host = _hostAddress;
    if (host == null || host.type != InternetAddressType.IPv4) return null;
    return encodeRoomCode(host);
  }

  /// كم مرة منحاول نرجع لحالنا قبل ما نسأل اللاعب. انقطاع الواي فاي
  /// القصير (جهاز نام، أو إشارة ضعيفة لثانية) بيخلص قبل هالمدة، فاللاعب
  /// ما بيحس فيه أصلاً.
  static const int _maxAutoRejoins = 5;

  /// بين محاولة ومحاولة — بيطلع مع كل محاولة (١، ٢، ٣… ثواني).
  static Duration _rejoinDelay(int attempt) => Duration(seconds: attempt.clamp(1, 5));
  List<Room> get rooms => _rooms;
  GameState? get state => client.state.value;
  ConnectionStatus get status => client.status.value;
  String? get playerId => client.playerId.value;
  TeamId? get teamId => client.teamId.value;
  /// عنوان آخر خطأ — بلغة الناس، مش نص الاستثناء.
  String? get lastError => _lastError?.title;

  /// شو يعمل اللاعب — اختياري.
  String? get lastErrorHint => _lastError?.hint;
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
    // ربط مقبس البثّ ممكن يفشل مؤقتاً (المنفذ لسا محجوز من بحث سابق عم
    // يتسكّر، أو الواي فاي عم يقوم) — منعيد المحاولة كم مرة بدل ما يضل
    // البحث ميت والشاشة فاضية.
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await discovery.start();
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
      if (!_discovering) return; // وقف البحث بهالأثناء
    }
    _lastError = const UserError('ما قدرنا ندوّر عالغرف', hint: 'تأكد إنه الواي فاي شغّال');
    notifyListeners();
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
      _lastError = const UserError('ما في شبكة', hint: 'افتح الواي فاي أو نقطة الاتصال');
      notifyListeners();
      return;
    }
    final host = decodeRoomCode(code, myIp);
    if (host == null) {
      _lastError = const UserError('كود الغرفة مش صحيح', hint: 'خمس أرقام متل ما مكتوبة عند المضيف');
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
    // اتصال جديد = بداية نظيفة لعدّاد المحاولات.
    _leftOnPurpose = false;
    _rejected = false;
    _rejoinAttempt = 0;
    _hostAddress = host;
    try {
      await client.connect(
        host: host,
        port: port,
        playerName: name,
        teamId: _pendingTeam,
      );
      _lastError = null;
    } catch (e) {
      _lastError = describeError(e, what: 'الاتصال بالمضيف');
      // البحث وقف قبل الاتصال — منرجّعه حتى ترجع لستة الغرف لحالها بدل ما
      // يضطر اللاعب يطلع من الشاشة ويرجع.
      await startDiscovery();
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

  /// طلوع نهائي من اللعبة («اطلع وابدأ من جديد» أو طلوع المضيف): بيوقّف
  /// البحث، بيقطع الاتصال، وبينسى الغرفة والمقعد والحالة — بس الاسم
  /// بيضل للانضمام الجاي. بدونه اللاعب اللي بيرجع ينضم بيلاقي حاله بنفس
  /// اللعبة القديمة (الاتصال كان بيضل مفتوح).
  Future<void> leave() async {
    _discovering = false;
    _rooms = [];
    _lastError = null;
    // طلوع بإرادته — منوقف أي محاولة رجوع تلقائي.
    _leftOnPurpose = true;
    _reconnecting = false;
    _rejoinAttempt = 0;
    _rejoinTimer?.cancel();
    _rejoinTimer = null;
    await discovery.stop();
    await client.leave();
    notifyListeners();
  }

  /// رجوع لنفس اللعبة بعد الانقطاع — بنفس الاسم والفريق ومعرّف اللاعب
  /// المحفوظ (المضيف بيعيد ربطنا بنفس مكاننا).
  Future<void> rejoin() async {
    if (_pendingName == null) return;
    _lastError = null;
    _leftOnPurpose = false;
    _rejoinAttempt = 0;
    _rejoinTimer?.cancel();
    _rejoinTimer = null;
    notifyListeners();
    try {
      await client.rejoin();
    } catch (e) {
      _lastError = describeError(e, what: 'الرجوع للعبة');
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

  void _onChanged() {
    _watchForDrop();
    notifyListeners();
  }

  /// انقطع الاتصال وما كنا طالعين بإرادتنا؟ منحاول نرجع لحالنا.
  ///
  /// المضيف بيحتفظ باللاعب «منقطع» بنفس رقمه ونقاطه، وبيعيد ربطه بمعرّفه
  /// (أو باسمه) — فالرجوع بيرجّعه لنفس مكانه بالضبط، حتى واللعبة شغّالة.
  void _watchForDrop() {
    final status = client.status.value;
    if (status == ConnectionStatus.connected) {
      _rejoinAttempt = 0;
      if (_reconnecting) _reconnecting = false;
      _rejoinTimer?.cancel();
      _rejoinTimer = null;
      return;
    }
    if (status != ConnectionStatus.disconnected) return;
    if (_leftOnPurpose || _pendingName == null) return;
    if (_rejoinTimer != null) return;
    if (_rejoinAttempt >= _maxAutoRejoins) {
      // خلصت المحاولات — هلق بس منخلي الشاشة تسأل اللاعب.
      _reconnecting = false;
      return;
    }

    _rejoinAttempt++;
    _reconnecting = true;
    _rejoinTimer = Timer(_rejoinDelay(_rejoinAttempt), () async {
      _rejoinTimer = null;
      if (_leftOnPurpose || client.status.value == ConnectionStatus.connected) return;
      try {
        await client.rejoin();
      } catch (_) {
        // ما زبطت — منجرب تاني تحت.
      }
      // لازم نعيد الجدولة من هون: لو ضلّت الحالة «منقطع» ما بيجي ولا
      // إشعار تغيّر من العميل، فما في شي تاني بيشغّل المحاولة الجاي.
      _watchForDrop();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _leftOnPurpose = true;
    _rejoinTimer?.cancel();
    _rejoinTimer = null;
    discovery.rooms.removeListener(_onRoomsChanged);
    client.state.removeListener(_onChanged);
    client.status.removeListener(_onChanged);
    client.playerId.removeListener(_onChanged);
    client.teamId.removeListener(_onChanged);
    client.rejection.removeListener(_onRejected);
    unawaited(client.disconnect());
    unawaited(discovery.stop());
    super.dispose();
  }
}
