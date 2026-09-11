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
    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    sock.broadcastEnabled = true;
    _socket = sock;

    void tick() {
      final payload =
          utf8.encode(jsonEncode({'room': roomName, 'port': port, 'version': 1}));
      sock.send(payload, target, roomBeaconPort);
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// بيوقف البث ويسكّر المقبس.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}
