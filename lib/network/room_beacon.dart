/// منارة الغرفة — بثّ UDP دوري يعلن عن وجود المضيف على الشبكة المحلية،
/// بديل إعلان Nearby Connections بالنسخة الأصلية.
///
/// وفيها مسار تاني مهم: المضيف بيسمع «سؤال» من اللاعب على [roomProbePort]
/// وبيجاوبه **مباشرة (unicast)**. البثّ (broadcast) هو أضعف إشي بالواي فاي
/// — توفير الطاقة بالأندرويد بيرمي حزم البثّ الواصلة، وكتير راوترات
/// بتفلترها أو بتأخّرها بين نطاقي ٢.٤ و٥ — بينما الحزمة المباشرة بتوصل
/// عادي. فيكفي إنه اتجاه واحد من البثّ يشتغل حتى يشوف اللاعب الغرفة.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'broadcast_targets.dart';

/// منفذ UDP اللي بينبث عليه المضيف اسم الغرفة ورقم منفذ الـ WebSocket،
/// وهو نفسه اللي بيسمع عليه اللاعب (جواب المضيف المباشر بيوصله عليه).
const int roomBeaconPort = 47216;

/// منفذ «سؤال اللاعب»: *وين الغرف؟* — المضيف بيسمع عليه وبيجاوب مباشرة.
const int roomProbePort = 47217;

/// بيبث حزمة UDP كل ثانية فيها اسم الغرفة ومنفذ خادم المضيف، حتى تلاقيه
/// أجهزة اللاعبين بـ[RoomDiscovery] بدون ما يعرفوا الـ IP مسبقاً.
class RoomBeacon {
  /// عنوان البث — افتراضياً بث عام على الشبكة، وبيتغيّر لـ loopback بالاختبارات.
  final InternetAddress target;

  /// منفذ الإعلان ومنفذ الأسئلة. ثابتين بالتطبيق، وبيتغيّروا بالاختبارات
  /// حتى كل اختبار ياخد زوج منافذ لحاله (ملفات الاختبار بتمشي بالتوازي).
  final int announcePort;
  final int probePort;

  RoomBeacon({
    InternetAddress? target,
    this.announcePort = roomBeaconPort,
    this.probePort = roomProbePort,
  }) : target = target ?? limitedBroadcast;

  RawDatagramSocket? _socket;

  /// مقبس الأسئلة — مربوط على [roomProbePort] حتى يسمع أسئلة اللاعبين.
  RawDatagramSocket? _probeSocket;
  Timer? _timer;
  String? _roomName;
  int _port = 0;
  String _sessionId = '';

  /// بيبدأ البث الدوري لاسم الغرفة [roomName] ومنفذ الخادم [port].
  Future<void> start({required String roomName, required int port}) async {
    if (_socket != null) return; // شغّال أصلاً — ما منعمل شي.

    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    sock.broadcastEnabled = true;
    _socket = sock;
    _roomName = roomName;
    _port = port;
    // معرّف عشوائي لهالاستضافة — اللاعب بيميّز فيه نفس الغرفة لو وصلت حزمها
    // من أكتر من عنوان (واي فاي + نقطة اتصال)، وبيميّز استضافة جديدة عن
    // القديمة (شوف RoomDiscovery.handlePacket).
    _sessionId = _newSessionId();

    await _listenForProbes();

    unawaited(announce());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(announce()));
  }

  /// بيبعت الإعلان بالبثّ. مفصولة ومرئية للاختبار حتى نقدر نختبر مسار
  /// «سؤال وجواب» لحاله (منارة ما بتبثّ أبداً، ولازم اللاعب يلاقيها).
  @visibleForTesting
  Future<void> announce() async {
    final sock = _socket;
    if (sock == null) return;
    final payload = _payload();
    if (payload == null) return;
    // البثّ العام + البثّ الموجّه لكل واجهة واي فاي/نقطة اتصال: على جهاز
    // عامل نقطة اتصال وبياناته الخلوية شغّالة، 255.255.255.255 ممكن يطلع
    // من واجهة الخلوي بدل الواي فاي، فما يوصل لولا حدا.
    final targets = <InternetAddress>{
      target,
      if (!target.isLoopback) ...await directedBroadcasts(),
    };
    // stop() ممكن يكون سبقنا ونحنا عم نجمع العناوين — المقبس سكّر.
    if (!identical(_socket, sock)) return;
    for (final address in targets) {
      try {
        sock.send(payload, address, announcePort);
      } on SocketException {
        // ما في شبكة مؤقتاً (مثلاً واجهة انقطعت) — منحاول تاني بالتيك الجاي.
      }
    }
  }

  /// بيسمع أسئلة اللاعبين على [roomProbePort]. إذا المنفذ محجوز (تطبيق
  /// تاني، أو استضافة سابقة لسا عم تسكّر) منكمّل بالبثّ لحاله.
  Future<void> _listenForProbes() async {
    try {
      final probe = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        probePort,
        reuseAddress: true,
      );
      probe.broadcastEnabled = true;
      _probeSocket = probe;
      probe.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          final dg = probe.receive();
          if (dg == null) return;
          if (!_isProbe(dg.data)) return;
          _answerProbe(probe, dg.address);
        },
        // نفس سبب [RoomDiscovery]: خطأ مقبس ما بيجوز يوقّف الاستضافة.
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      _probeSocket = null;
    }
  }

  /// جواب مباشر (unicast) على عنوان اللاعب — بيوصل لمقبسه المربوط على
  /// [roomBeaconPort]، نفس شكل حزمة الإعلان بالضبط.
  void _answerProbe(RawDatagramSocket sock, InternetAddress to) {
    final payload = _payload();
    if (payload == null) return;
    try {
      sock.send(payload, to, announcePort);
    } on SocketException {
      // الجهاز اختفى — ما في شي نعمله، وبيسأل تاني بعد ثانية.
    }
  }

  Uint8List? _payload() {
    final name = _roomName;
    if (name == null) return null;
    return Uint8List.fromList(utf8.encode(
      jsonEncode({'room': name, 'port': _port, 'version': 1, 'id': _sessionId}),
    ));
  }

  /// سؤال اللاعب: حزمة صغيرة فيها `probe`. أي إشي تاني منتجاهله.
  static bool _isProbe(List<int> data) {
    if (data.length > 512) return false;
    try {
      final j = jsonDecode(utf8.decode(data));
      return j is Map<String, dynamic> && j['probe'] != null;
    } catch (_) {
      return false;
    }
  }

  /// بيوقف البث ويسكّر المقبس.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
    _probeSocket?.close();
    _probeSocket = null;
    _roomName = null;
  }
}

/// معرّف عشوائي (١٦ خانة ست عشرية) لكل تشغيل للمنارة.
String _newSessionId() {
  final random = Random.secure();
  return List.generate(8, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
