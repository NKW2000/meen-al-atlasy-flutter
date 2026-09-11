/// خادم المضيف — WebSocket على الشبكة المحلية، بديل Nearby Connections
/// بالنسخة الأصلية (Kotlin). كل جهاز لاعب هو "نقطة نهاية" (endpoint) لها
/// معرّف نصّي، والمضيف مصدر الحقيقة الوحيد لحالة اللعبة.
library;

import 'dart:async';
import 'dart:io';

import 'messages.dart';

// ============================================================================
// Client Events (من أجهزة اللاعبين ← للمضيف)
// ============================================================================

/// حدث وصل من جهاز لاعب متّصل بالمضيف.
sealed class ClientEvent {
  final String endpointId;
  ClientEvent(this.endpointId);
}

/// جهاز لاعب جديد اتّصل.
class ClientConnected extends ClientEvent {
  ClientConnected(super.endpointId);
}

/// وصلت رسالة من جهاز لاعب.
class ClientMessageReceived extends ClientEvent {
  final ClientMessage message;
  ClientMessageReceived(super.endpointId, this.message);
}

/// جهاز لاعب انقطع اتصاله.
class ClientDisconnected extends ClientEvent {
  ClientDisconnected(super.endpointId);
}

// ============================================================================
// HostTransport — الواجهة اللي بيعتمد عليها بقية اللعبة (Task 6 بيبني عليها
// نسخة وهمية "fake" للاختبارات).
// ============================================================================

/// واجهة النقل بين المضيف وأجهزة اللاعبين — تجريدها عن `HostServer` الحقيقي
/// حتى تقدر اختبارات المضيف (Task 6) تستخدم نسخة وهمية بدل شبكة حقيقية.
abstract class HostTransport {
  /// المنفذ الفعلي اللي اتربط فيه الخادم.
  int get port;

  /// دفق أحداث بث (broadcast) — اتصال / رسالة / انقطاع.
  Stream<ClientEvent> get events;

  /// بيشغّل الخادم على [port]. لو المنفذ مشغول، بيرجع لمنفذ عشوائي (0).
  Future<void> start({int port = 47215});

  /// بيبعت رسالة للاعب واحد بس، محدّد بـ [endpointId].
  void send(String endpointId, HostMessage m);

  /// بيبعت رسالة لكل الأجهزة المتّصلة.
  void broadcast(HostMessage m);

  /// بيوقف الخادم ويسكّر كل الاتصالات.
  Future<void> stop();
}

/// التنفيذ الحقيقي لـ [HostTransport] فوق `dart:io` — `HttpServer` +
/// `WebSocketTransformer` بلا أي حزمة شبكة خارجية.
class HostServer implements HostTransport {
  HttpServer? _server;
  final Map<String, WebSocket> _sockets = {};
  StreamController<ClientEvent> _events = StreamController<ClientEvent>.broadcast();
  int _next = 0;

  @override
  int get port => _server?.port ?? 0;

  @override
  Stream<ClientEvent> get events => _events.stream;

  @override
  Future<void> start({int port = 47215}) async {
    if (_server != null) return; // شغّال أصلاً — ما منعمل شي.
    if (_events.isClosed) {
      // انوقف الخادم قبل هيك — لازم دفق جديد، القديم مسكّر نهائياً.
      _events = StreamController<ClientEvent>.broadcast();
    }
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } on SocketException {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server!.listen((req) async {
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }

      WebSocket ws;
      try {
        ws = await WebSocketTransformer.upgrade(req);
      } catch (_) {
        // الترقية فشلت (مثلاً الخادم سكّر بالمنتصف) — ما في شي نعمله.
        return;
      }

      // stop() ممكن تكون سبقتنا وحنا لسا عم نرقّي الاتصال — لو هيك، نسكّر
      // الـ socket الجديد فوراً وما نسجّله، حتى ما يتسرّب ولا ينرمى خطأ
      // بمحاولة إضافة حدث لدفق مسكّر.
      if (_events.isClosed || _server == null) {
        await ws.close(1001);
        return;
      }

      final id = 'ep${_next++}';
      _sockets[id] = ws;
      ws.pingInterval = const Duration(seconds: 5);
      _events.add(ClientConnected(id));
      ws.listen(
        (data) {
          try {
            _events.add(
              ClientMessageReceived(id, decodeClientMessage(data as String)),
            );
          } catch (_) {
            // رسالة مشوّهة — نتجاهلها.
          }
        },
        onDone: () => _drop(id),
        onError: (_) => _drop(id),
      );
    }, onError: (_) {});
  }

  void _drop(String id) {
    if (_sockets.remove(id) != null && !_events.isClosed) {
      _events.add(ClientDisconnected(id));
    }
  }

  @override
  void send(String endpointId, HostMessage m) {
    _sockets[endpointId]?.add(encodeHostMessage(m));
  }

  @override
  void broadcast(HostMessage m) {
    final payload = encodeHostMessage(m);
    for (final ws in _sockets.values) {
      try {
        ws.add(payload);
      } catch (_) {
        // اتصال ميت — نتجاهله ونكمّل للباقي.
      }
    }
  }

  @override
  Future<void> stop() async {
    // ناخذ نسخة ونفضّي الخريطة قبل الإغلاق حتى ما توصلنا أحداث onDone
    // بالمنتصف وتعدّل الخريطة ونحنا لسا عم نكرّر عليها.
    final sockets = _sockets.values.toList();
    _sockets.clear();
    for (final ws in sockets) {
      await ws.close(1001);
    }
    await _server?.close(force: true);
    _server = null;
    await _events.close();
  }
}
