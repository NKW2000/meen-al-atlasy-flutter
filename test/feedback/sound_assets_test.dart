/// كل تنبيه إله ملف صوت موجود فعلاً بالمشروع — ما منكتشف ملف ناقص عند
/// أول لعبة على الجهاز.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/feedback/game_feedback.dart';

void main() {
  test('every cue has its mp3 in assets/sounds', () {
    final missing = <String>[];
    for (final cue in Cue.values) {
      final file = File('assets/sounds/sfx_${cue.name}.mp3');
      if (!file.existsSync() || file.lengthSync() < 1000) missing.add(cue.name);
    }
    expect(missing, isEmpty, reason: 'ملفات ناقصة أو فاضية: $missing');
  });

  test('no stray sound files without a cue', () {
    final names = Cue.values.map((c) => 'sfx_${c.name}.mp3').toSet();
    final stray = Directory('assets/sounds')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => !names.contains(n))
        .toList();
    expect(stray, isEmpty, reason: 'ملفات بلا تنبيه: $stray');
  });
}
