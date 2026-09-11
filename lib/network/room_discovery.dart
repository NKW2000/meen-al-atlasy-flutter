/// اكتشاف الغرف — بيسمع بثّ UDP من [RoomBeacon] ويجمّع الغرف الظاهرة حالياً
/// على الشبكة، بديل اكتشاف Nearby Connections بالنسخة الأصلية.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'room_beacon.dart';

/// غرفة مكتشَفة على الشبكة — مضيف واحد بعنوانه ومنفذه.
class Room {
  final String name;
  final InternetAddress host;
  final int port;

  Room(this.name, this.host, this.port);

  /// معرّف فريد للغرفة — عنوان المضيف + منفذه.
  String get endpointId => '${host.address}:$port';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Room && other.endpointId == endpointId);

  @override
  int get hashCode => endpointId.hashCode;
}

/// مدة بقاء الغرفة "حيّة" بدون بث جديد قبل ما تُعتبر منتهية.
const Duration _roomTtl = Duration(seconds: 4);

/// بيسمع بثّ [RoomBeacon] عبر UDP، ويحدّث [rooms] بالغرف الظاهرة حالياً —
/// الغرف اللي ما وصلها بث جديد خلال [_roomTtl] بتنشال تلقائياً.
class RoomDiscovery {
  /// عنوان الربط — افتراضياً كل الواجهات، وبيتغيّر لـ loopback بالاختبارات.
  final InternetAddress bindAddress;

  RoomDiscovery({InternetAddress? bindAddress})
      : bindAddress = bindAddress ?? InternetAddress.anyIPv4;

  final ValueNotifier<List<Room>> rooms = ValueNotifier<List<Room>>([]);

  RawDatagramSocket? _socket;
  Timer? _timer;
  final Map<String, (Room, DateTime)> _seen = {};

  /// بيبدأ الاستماع لبثّ الغرف.
  Future<void> start() async {
    final sock = await RawDatagramSocket.bind(
      bindAddress,
      roomBeaconPort,
      reuseAddress: true,
      reusePort: false,
    );
    sock.broadcastEnabled = true;
    _socket = sock;

    sock.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = sock.receive();
      if (dg == null) return;
      try {
        final j = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
        final room = Room(j['room'] as String, dg.address, j['port'] as int);
        _seen[room.endpointId] = (room, DateTime.now());
        _publish();
      } catch (_) {
        // حزمة مشوّهة — نتجاهلها.
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _publish());
  }

  void _publish() {
    final cutoff = DateTime.now().subtract(_roomTtl);
    _seen.removeWhere((_, entry) => entry.$2.isBefore(cutoff));
    final sorted = _seen.values.map((e) => e.$1).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    rooms.value = sorted;
  }

  /// بيوقف الاستماع ويسكّر المقبس.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
    _seen.clear();
  }
}
