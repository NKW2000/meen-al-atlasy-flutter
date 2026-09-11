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

/// عميل اللاعب — بيتّصل بمضيف عبر WebSocket، ويعرض حالة اللعبة ومعرّف
/// اللاعب وفريقه كـ [ValueNotifier] تقدر الواجهة تستمع له مباشرة.
class PlayerClient {
  final ValueNotifier<GameState?> state = ValueNotifier<GameState?>(null);
  final ValueNotifier<ConnectionStatus> status =
      ValueNotifier<ConnectionStatus>(ConnectionStatus.idle);
  final ValueNotifier<String?> playerId = ValueNotifier<String?>(null);
  final ValueNotifier<TeamId?> teamId = ValueNotifier<TeamId?>(null);

  WebSocket? _ws;
  InternetAddress? _lastHost;
  int? _lastPort;
  String? _lastPlayerName;

  /// بيتّصل بمضيف على [host]:[port] وبيبعت رسالة انضمام باسم [playerName].
  Future<void> connect({
    required InternetAddress host,
    required int port,
    required String playerName,
    TeamId? teamId,
  }) async {
    _lastHost = host;
    _lastPort = port;
    _lastPlayerName = playerName;
    this.teamId.value = teamId;

    status.value = ConnectionStatus.connecting;
    final WebSocket ws;
    try {
      ws = await WebSocket.connect('ws://${host.address}:$port/')
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      status.value = ConnectionStatus.disconnected;
      rethrow;
    }
    _ws = ws;
    ws.pingInterval = const Duration(seconds: 5);
    status.value = ConnectionStatus.connected;
    ws.listen(_onData, onDone: _onClosed, onError: (_) => _onClosed());
    send(JoinMessage(playerName: playerName, teamId: teamId));
  }

  void _onData(dynamic data) {
    try {
      final message = decodeHostMessage(data as String);
      switch (message) {
        case StateUpdate(:final state):
          this.state.value = state;
        case Assigned(:final playerId, :final teamId):
          this.playerId.value = playerId;
          this.teamId.value = teamId;
      }
    } catch (_) {
      // رسالة مشوّهة — نتجاهلها.
    }
  }

  void _onClosed() {
    status.value = ConnectionStatus.disconnected;
  }

  /// بيبعت رسالة للمضيف عبر الاتصال الحالي.
  void send(ClientMessage m) {
    _ws?.add(encodeClientMessage(m));
  }

  /// بيعيد الاتصال بآخر مضيف، وبيبعت انضمام جديد بنفس الاسم والفريق —
  /// المضيف بيتعرّف على اللاعب من اسمه ويعيد ربطه بنفس معرّفه (Task 6).
  Future<void> rejoin() async {
    final host = _lastHost;
    final port = _lastPort;
    final playerName = _lastPlayerName;
    if (host == null || port == null || playerName == null) {
      throw StateError('rejoin() called before a first connect()');
    }
    // نحافظ على playerId الحالي — الاتصال الجديد ما بيصفّره.
    await connect(
      host: host,
      port: port,
      playerName: playerName,
      teamId: teamId.value,
    );
  }

  /// بيقطع الاتصال بالمضيف نهائياً.
  Future<void> disconnect() async {
    final ws = _ws;
    _ws = null;
    if (ws != null) {
      await ws.close();
    }
    status.value = ConnectionStatus.disconnected;
  }
}
