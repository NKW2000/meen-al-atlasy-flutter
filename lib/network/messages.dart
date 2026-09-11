/// رسائل الشبكة بين المضيف و اللاعبين — JSON على السلك.
library;

import 'dart:convert';
import '../game/models.dart';

// ============================================================================
// Client Messages (من جهاز اللاعب ← للمضيف)
// ============================================================================

/// رسالة من جهاز اللاعب — اختيار من عِدّة أنواع متفاوتة.
sealed class ClientMessage {
  Map<String, dynamic> toJson();

  static ClientMessage fromJson(Map<String, dynamic> json) {
    try {
      final type = json['type'] as String?;
      switch (type) {
        case 'join':
          return JoinMessage(
            playerName: json['playerName'] as String,
            teamId: json['teamId'] != null
                ? TeamIdX.fromWire(json['teamId'] as String)
                : null,
          );
        case 'team':
          return ChangeTeamMessage(
            playerId: json['playerId'] as String,
            teamId: TeamIdX.fromWire(json['teamId'] as String),
          );
        case 'buzz':
          return BuzzMessage(
            playerId: json['playerId'] as String,
            atMillis: json['atMillis'] as int,
          );
        case 'choice':
          return ChooseMessage(
            playerId: json['playerId'] as String,
            play: json['play'] as bool,
          );
        default:
          throw FormatException('Unknown ClientMessage type: $type');
      }
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Failed to decode ClientMessage: $e');
    }
  }
}

/// الاتصال الأول من لاعب جديد.
class JoinMessage extends ClientMessage {
  final String playerName;
  final TeamId? teamId;

  JoinMessage({
    required this.playerName,
    this.teamId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'join',
        'playerName': playerName,
        'teamId': teamId?.wire,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JoinMessage &&
          other.playerName == playerName &&
          other.teamId == teamId);

  @override
  int get hashCode => Object.hash(playerName, teamId);
}

/// اللاعب بيغيّر فريقه قبل ما تبلّش اللعبة.
class ChangeTeamMessage extends ClientMessage {
  final String playerId;
  final TeamId teamId;

  ChangeTeamMessage({
    required this.playerId,
    required this.teamId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'team',
        'playerId': playerId,
        'teamId': teamId.wire,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChangeTeamMessage &&
          other.playerId == playerId &&
          other.teamId == teamId);

  @override
  int get hashCode => Object.hash(playerId, teamId);
}

/// اللاعب ضغط الزر — المضيف بيسجّل الوقت.
class BuzzMessage extends ClientMessage {
  final String playerId;
  final int atMillis;

  BuzzMessage({
    required this.playerId,
    required this.atMillis,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'buzz',
        'playerId': playerId,
        'atMillis': atMillis,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BuzzMessage &&
          other.playerId == playerId &&
          other.atMillis == atMillis);

  @override
  int get hashCode => Object.hash(playerId, atMillis);
}

/// قرار الفائز بالمواجهة: يلعب اللوح أو يمرّرو.
class ChooseMessage extends ClientMessage {
  final String playerId;
  final bool play;

  ChooseMessage({
    required this.playerId,
    required this.play,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'choice',
        'playerId': playerId,
        'play': play,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChooseMessage &&
          other.playerId == playerId &&
          other.play == play);

  @override
  int get hashCode => Object.hash(playerId, play);
}

// ============================================================================
// Host Messages (من المضيف ← لأجهزة اللاعبين — المضيف مصدر الحقيقة الوحيد)
// ============================================================================

/// رسالة من المضيف — اختيار من عِدّة أنواع.
sealed class HostMessage {
  Map<String, dynamic> toJson();

  static HostMessage fromJson(Map<String, dynamic> json) {
    try {
      final type = json['type'] as String?;
      switch (type) {
        case 'state':
          return StateUpdate(
            state: GameState.fromJson(json['state'] as Map<String, dynamic>),
          );
        case 'assigned':
          return Assigned(
            playerId: json['playerId'] as String,
            teamId: TeamIdX.fromWire(json['teamId'] as String),
          );
        default:
          throw FormatException('Unknown HostMessage type: $type');
      }
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Failed to decode HostMessage: $e');
    }
  }
}

/// تحديث حالة اللعبة للاعبين.
class StateUpdate extends HostMessage {
  final GameState state;

  StateUpdate({required this.state});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'state',
        'state': state.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is StateUpdate && other.state == state);

  @override
  int get hashCode => state.hashCode;
}

/// المضيف عيّن لاعب لفريق ما.
class Assigned extends HostMessage {
  final String playerId;
  final TeamId teamId;

  Assigned({
    required this.playerId,
    required this.teamId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'assigned',
        'playerId': playerId,
        'teamId': teamId.wire,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Assigned &&
          other.playerId == playerId &&
          other.teamId == teamId);

  @override
  int get hashCode => Object.hash(playerId, teamId);
}

// ============================================================================
// Encoding / Decoding Functions
// ============================================================================

/// رسالة من اللاعب → بايتات (JSON).
String encodeClientMessage(ClientMessage message) {
  return jsonEncode(message.toJson());
}

/// بايتات (JSON) → رسالة من اللاعب.
ClientMessage decodeClientMessage(List<int> bytes) {
  try {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return ClientMessage.fromJson(json);
  } catch (e) {
    if (e is FormatException) rethrow;
    throw FormatException('Failed to decode ClientMessage bytes: $e');
  }
}

/// رسالة من المضيف → بايتات (JSON).
String encodeHostMessage(HostMessage message) {
  return jsonEncode(message.toJson());
}

/// بايتات (JSON) → رسالة من المضيف.
HostMessage decodeHostMessage(List<int> bytes) {
  try {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return HostMessage.fromJson(json);
  } catch (e) {
    if (e is FormatException) rethrow;
    throw FormatException('Failed to decode HostMessage bytes: $e');
  }
}
