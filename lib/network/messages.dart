/// رسائل الشبكة بين المضيف و اللاعبين — JSON على السلك.
library;

import 'dart:convert';
import '../game/models.dart';

// ============================================================================
// Utilities
// ============================================================================

/// Wrap the body in try/catch and convert exceptions to FormatException.
T _asFormat<T>(T Function() body) {
  try {
    return body();
  } catch (e) {
    if (e is FormatException) rethrow;
    throw FormatException('Failed to decode: $e');
  }
}

// ============================================================================
// Client Messages (من جهاز اللاعب ← للمضيف)
// ============================================================================

/// رسالة من جهاز اللاعب — اختيار من عِدّة أنواع متفاوتة.
sealed class ClientMessage {
  Map<String, dynamic> toJson();

  static ClientMessage fromJson(Map<String, dynamic> json) {
    return _asFormat(() {
      final type = json['type'] as String?;
      switch (type) {
        case 'join':
          return JoinMessage(
            playerName: json['playerName'] as String,
            teamId: json['teamId'] != null
                ? TeamIdX.fromWire(json['teamId'] as String)
                : null,
            playerId: json['playerId'] as String?,
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
    });
  }
}

/// الاتصال الأول من لاعب جديد.
///
/// [playerId] هو معرّف اللاعب اللي عيّنه المضيف قبل هيك — منبعته لما
/// نعيد الاتصال (WebSocket جديد = معرّف نقطة نهاية جديد) حتى يقدر المضيف
/// يعيد ربطنا بنفس اللاعب بدل ما يعتبرنا لاعب جديد. `null` لأول انضمام.
class JoinMessage extends ClientMessage {
  final String playerName;
  final TeamId? teamId;
  final String? playerId;

  JoinMessage({
    required this.playerName,
    this.teamId,
    this.playerId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'join',
        'playerName': playerName,
        'teamId': teamId?.wire,
        'playerId': playerId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JoinMessage &&
          other.playerName == playerName &&
          other.teamId == teamId &&
          other.playerId == playerId);

  @override
  int get hashCode => Object.hash(playerName, teamId, playerId);
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
    return _asFormat(() {
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
        case 'clock':
          return ClockUpdate(
            answerSecondsLeft: json['answerSecondsLeft'] as int,
            choiceSecondsLeft: json['choiceSecondsLeft'] as int,
          );
        default:
          throw FormatException('Unknown HostMessage type: $type');
      }
    });
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

/// ثانية مرقت عالعدّاد وما تغيّر غيرها.
///
/// حالة اللعبة كاملة بتنبعت بكل حدث، بس العدّاد بيتغيّر **كل ثانية** —
/// وببعتها كاملة كل ثانية لـ١٨ جهاز بيصير الحمل على الواي فاي أكبر من
/// اللزوم، وبيأخّر وصول الضغطة. فالتيك لحاله بيمشي برسالة زغيرة،
/// والحالة الكاملة بتنبعت بس لما يتغيّر إشي تاني (مثلاً خلص الوقت).
class ClockUpdate extends HostMessage {
  final int answerSecondsLeft;
  final int choiceSecondsLeft;

  ClockUpdate({
    required this.answerSecondsLeft,
    required this.choiceSecondsLeft,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'clock',
        'answerSecondsLeft': answerSecondsLeft,
        'choiceSecondsLeft': choiceSecondsLeft,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClockUpdate &&
          other.answerSecondsLeft == answerSecondsLeft &&
          other.choiceSecondsLeft == choiceSecondsLeft);

  @override
  int get hashCode => Object.hash(answerSecondsLeft, choiceSecondsLeft);
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

/// رسالة من اللاعب → JSON string.
String encodeClientMessage(ClientMessage message) {
  return jsonEncode(message.toJson());
}

/// JSON string → رسالة من اللاعب.
ClientMessage decodeClientMessage(String s) {
  return _asFormat(() {
    final json = jsonDecode(s) as Map<String, dynamic>;
    return ClientMessage.fromJson(json);
  });
}

/// رسالة من المضيف → JSON string.
String encodeHostMessage(HostMessage message) {
  return jsonEncode(message.toJson());
}

/// JSON string → رسالة من المضيف.
HostMessage decodeHostMessage(String s) {
  return _asFormat(() {
    final json = jsonDecode(s) as Map<String, dynamic>;
    return HostMessage.fromJson(json);
  });
}
