/// جهاز اللاعب — عميل WebSocket يتّصل بمضيف الغرفة، بديل جانب اللاعب
/// بـ Nearby Connections بالنسخة الأصلية.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../game/models.dart';
import 'messages.dart';

/// حالة اتصال جهاز اللاعب بالمضيف.
enum ConnectionStatus { idle, connecting, connected, disconnected }

/// واجهة النقل اللي بيعتمد عليها [PlayerController] (Task 6) — تجريدها عن
/// [PlayerClient] الحقيقي حتى تقدر اختبارات اللاعب تستخدم نسخة وهمية بدل
/// اتصال WebSocket حقيقي. نفس فكرة `HostTransport` بجانب المضيف.
abstract class PlayerTransport {
  ValueListenable<GameState?> get state;
  ValueListenable<ConnectionStatus> get status;
  ValueListenable<String?> get playerId;
  ValueListenable<TeamId?> get teamId;

  /// آخر سبب رفض من المضيف ([Rejected]) — `null` لما ما في. بينمسح مع
  /// كل اتصال جديد.
  ValueListenable<String?> get rejection;

  /// [playerId] معرّف محفوظ من اتصال سابق يبعته المضيف بـ[Assigned] —
  /// مرّره بس لما هاي *فعلاً* إعادة اتصال لنفس اللاعب ([rejoin]). اتصال
  /// جديد لغرفة جديدة لازم يترك القيمة الافتراضية (`null`) — معرّفات
  /// نقاط النهاية بترجع تتكرر بكل مضيف، فمعرّف قديم من لعبة سابقة ممكن
  /// يصادف يطابق لاعب حيّ تاني باللعبة الجديدة (حكم المراجعة الحرج #٢).
  Future<void> connect({
    required InternetAddress host,
    required int port,
    required String playerName,
    TeamId? teamId,
    String? playerId,
  });

  void send(ClientMessage m);

  Future<void> rejoin();

  Future<void> disconnect();

  /// بيطلع من اللعبة نهائياً: بيقطع الاتصال وبينسى الحالة والمقعد والفريق
  /// — عكس [disconnect] اللي بيحافظ عليهم لـ[rejoin].
  Future<void> leave();

  Future<void> dispose();
}

/// عميل اللاعب — بيتّصل بمضيف عبر WebSocket، ويعرض حالة اللعبة ومعرّف
/// اللاعب وفريقه كـ [ValueNotifier] تقدر الواجهة تستمع له مباشرة.
class PlayerClient implements PlayerTransport {
  @override
  final ValueNotifier<GameState?> state = ValueNotifier<GameState?>(null);
  @override
  final ValueNotifier<ConnectionStatus> status =
      ValueNotifier<ConnectionStatus>(ConnectionStatus.idle);
  @override
  final ValueNotifier<String?> playerId = ValueNotifier<String?>(null);
  @override
  final ValueNotifier<TeamId?> teamId = ValueNotifier<TeamId?>(null);
  @override
  final ValueNotifier<String?> rejection = ValueNotifier<String?>(null);

  WebSocket? _ws;
  InternetAddress? _lastHost;
  int? _lastPort;
  String? _lastPlayerName;

  /// بيتّصل بمضيف على [host]:[port] وبيبعت رسالة انضمام باسم [playerName].
  ///
  /// لو في اتصال قديم لسا مفتوح (مثلاً نداء ثاني لـ [connect] أو [rejoin])،
  /// منسكّره الأول — وبما إنه ممكن يوصل حدث onDone/onError تبعه بعد ما
  /// نبدأ اتصال جديد، منربط كل مستمع بنسخة الـ socket اللي انطلق منها
  /// (`ws` محليّة) حتى ما يقدر اتصال قديم يقلب حالة الاتصال الجديد.
  @override
  Future<void> connect({
    required InternetAddress host,
    required int port,
    required String playerName,
    TeamId? teamId,
    String? playerId,
  }) async {
    final previous = _ws;
    _ws = null;
    if (previous != null) {
      // الاتصال القديم غالباً نص ميت (هيك وصلنا لهون) — إغلاقه ممكن ينطر
      // مهلة TCP كاملة، وهاد كان يأخّر الرجوع للعبة ثواني. ثانيتين وبنكمّل.
      unawaited(_closeQuietly(previous));
    }

    _lastHost = host;
    _lastPort = port;
    _lastPlayerName = playerName;
    this.teamId.value = teamId;
    // اتصال جديد (بدون معرّف ممرّر) بيصفّر المعرّف المحفوظ من جلسة سابقة —
    // وإلا معرّف قديم بيتصادف مع لاعب حيّ تاني بمضيف جديد (حكم مراجعة حرج
    // #٢). [rejoin] هو الوحيد اللي بيمرّر معرّف فعلي هون.
    this.playerId.value = playerId;
    // اتصال جديد ما بيورث حالة لعبة قديمة — اللاعب ما بيشوف لوح غرفة راحت
    // لحد ما توصل أول لقطة من المضيف الجديد.
    if (playerId == null) state.value = null;
    rejection.value = null;

    status.value = ConnectionStatus.connecting;
    final WebSocket ws;
    // لو مرق الوقت والاتصال لسا عم يتفاوض، الـ socket اللي بيوصل بعدين
    // لازم ينسكّر — وإلا بيضل مفتوح عند المضيف كلاعب شبح ما بيبعت Join.
    final pending = WebSocket.connect('ws://${host.address}:$port/');
    try {
      ws = await pending.timeout(const Duration(seconds: 5));
    } catch (_) {
      unawaited(pending.then((late) => late.close(), onError: (_) {}));
      status.value = ConnectionStatus.disconnected;
      rethrow;
    }
    _ws = ws;
    ws.pingInterval = const Duration(seconds: 5);
    status.value = ConnectionStatus.connected;
    ws.listen(
      (data) => _onData(ws, data),
      onDone: () => _onClosed(ws),
      onError: (_) => _onClosed(ws),
    );
    send(JoinMessage(playerName: playerName, teamId: teamId, playerId: playerId));
  }

  void _onData(WebSocket ws, dynamic data) {
    if (!identical(_ws, ws)) return; // اتصال قديم استُبدل — نتجاهل حدثه.
    try {
      final message = decodeHostMessage(data as String);
      switch (message) {
        case StateUpdate(:final state):
          this.state.value = state;
        case ClockUpdate(:final answerSecondsLeft, :final choiceSecondsLeft):
          // تيك لحاله: منحدّث العدّاد على آخر حالة عنا بدل ما توصلنا الحالة
          // كاملة كل ثانية. قبل أول حالة ما في شي نحدّثه.
          final current = state.value;
          if (current != null) {
            state.value = current.copyWith(
              answerSecondsLeft: answerSecondsLeft,
              choiceSecondsLeft: choiceSecondsLeft,
            );
          }
        case Assigned(:final playerId, :final teamId):
          this.playerId.value = playerId;
          this.teamId.value = teamId;
        case Rejected(:final reason):
          // المضيف بيسكّر الاتصال بعدها — منسجّل السبب قبل ما يوصل onDone،
          // حتى المتحكّم يعرف إنه رفض مقصود مش انقطاع ويوقف محاولات الرجوع.
          rejection.value = reason;
      }
    } catch (_) {
      // رسالة مشوّهة — نتجاهلها.
    }
  }

  void _onClosed(WebSocket ws) {
    if (!identical(_ws, ws)) return; // اتصال قديم استُبدل — نتجاهل حدثه.
    status.value = ConnectionStatus.disconnected;
  }

  /// بيبعت رسالة للمضيف عبر الاتصال الحالي.
  @override
  void send(ClientMessage m) {
    try {
      _ws?.add(encodeClientMessage(m));
    } catch (_) {
      // الاتصال عم يسكّر بنفس اللحظة (ضغطة وصلت مع انقطاع) — الرمي هون
      // كان يطلع لمعالج الضغطة بالواجهة كاستثناء غير ممسوك.
    }
  }

  /// بيعيد الاتصال بآخر مضيف، وبيبعت انضمام جديد بنفس الاسم والفريق
  /// ونفس [playerId] المحفوظ — المضيف بيتعرّف على اللاعب من معرّفه (أو
  /// اسمه إذا انقطع) ويعيد ربطه بنفس مكانه (Task 6).
  @override
  Future<void> rejoin() async {
    final host = _lastHost;
    final port = _lastPort;
    final playerName = _lastPlayerName;
    if (host == null || port == null || playerName == null) {
      throw StateError('rejoin() called before a first connect()');
    }
    // منمرّر playerId المحفوظ صراحةً — هاي فعلاً إعادة اتصال لنفس اللاعب،
    // مش اتصال جديد لغرفة جديدة (حكم مراجعة حرج #٢).
    await connect(
      host: host,
      port: port,
      playerName: playerName,
      teamId: teamId.value,
      playerId: playerId.value,
    );
  }

  /// بيقطع الاتصال بالمضيف نهائياً.
  @override
  Future<void> disconnect() async {
    final ws = _ws;
    _ws = null;
    if (ws != null) {
      await _closeQuietly(ws);
    }
    status.value = ConnectionStatus.disconnected;
  }

  /// إغلاق بمهلة: مقبس ميت ما بيرد على المصافحة، وما منخلّي الواجهة تنطره.
  static Future<void> _closeQuietly(WebSocket ws) async {
    try {
      await ws.close().timeout(const Duration(seconds: 2));
    } catch (_) {
      // انقطع أصلاً، أو ما ردّ — النتيجة نفسها.
    }
  }

  @override
  Future<void> leave() async {
    await disconnect();
    status.value = ConnectionStatus.idle;
    _lastHost = null;
    _lastPort = null;
    state.value = null;
    playerId.value = null;
    teamId.value = null;
  }

  /// بيقطع الاتصال ويحرّر كل الـ [ValueNotifier] — لازم تناديها لما تخلص
  /// من العميل نهائياً (مش بين إعادة اتصال وإعادة اتصال).
  @override
  Future<void> dispose() async {
    await disconnect();
    rejection.dispose();
    state.dispose();
    status.dispose();
    playerId.dispose();
    teamId.dispose();
  }
}
