/// منارة الغرفة — بثّ UDP دوري يعلن عن وجود المضيف على الشبكة المحلية،
/// بديل إعلان Nearby Connections بالنسخة الأصلية.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// منفذ UDP اللي بينبث عليه المضيف اسم الغرفة ورقم منفذ الـ WebSocket.
const int roomBeaconPort = 47216;

/// بيبث حزمة UDP كل ثانية فيها اسم الغرفة ومنفذ خادم المضيف، حتى تلاقيه
/// أجهزة اللاعبين بـ [RoomDiscovery] بدون ما يعرفوا الـ IP مسبقاً.
class RoomBeacon {
  /// عنوان البث — افتراضياً بث عام على الشبكة، وبيتغيّر لـ loopback بالاختبارات.
  final InternetAddress target;

  RoomBeacon({InternetAddress? target})
      : target = target ?? InternetAddress('255.255.255.255');

  RawDatagramSocket? _socket;
  Timer? _timer;

  /// بيبدأ البث الدوري لاسم الغرفة [roomName] ومنفذ الخادم [port].
  Future<void> start({required String roomName, required int port}) async {
    if (_socket != null) return; // شغّال أصلاً — ما منعمل شي.

    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    sock.broadcastEnabled = true;
    _socket = sock;

    Future<void> tick() async {
      final payload =
          utf8.encode(jsonEncode({'room': roomName, 'port': port, 'version': 1}));
      // البثّ العام + البثّ الموجّه لكل واجهة واي فاي/نقطة اتصال: على جهاز
      // عامل نقطة اتصال وبياناته الخلوية شغّالة، 255.255.255.255 ممكن يطلع
      // من واجهة الخلوي بدل الواي فاي، فما يوصل لولا حدا.
      final targets = <InternetAddress>{target, ...await _directedBroadcasts()};
      for (final address in targets) {
        try {
          sock.send(payload, address, roomBeaconPort);
        } on SocketException {
          // ما في شبكة مؤقتاً (مثلاً واجهة انقطعت) — منحاول تاني بالتيك الجاي.
        }
      }
    }

    unawaited(tick());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(tick()));
  }

  /// عناوين البثّ الموجّه (x.y.z.255 — نفترض /24، الشائع بالشبكات المنزلية
  /// ونقاط الاتصال) لكل واجهة IPv4 غير loopback. بالاختبارات (الهدف
  /// loopback) ما منبعت لغير الهدف نفسه.
  Future<List<InternetAddress>> _directedBroadcasts() async {
    if (target.isLoopback) return const [];
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
      return [
        for (final iface in interfaces)
          for (final addr in iface.addresses)
            if (!addr.isLoopback && !addr.address.startsWith('10.0.2.'))
              InternetAddress('${addr.address.substring(0, addr.address.lastIndexOf('.'))}.255'),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// بيوقف البث ويسكّر المقبس.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}
