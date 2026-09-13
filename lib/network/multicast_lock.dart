/// قفل الـ multicast على أندرويد — بدونه كتير أجهزة بترمي حزم البثّ UDP
/// اللي بتعتمد عليها لستة الغرف. الطرف الأندرويدي بـ`MainActivity.kt`
/// (قناة `meen_al_atlasy/multicast`). على غير أندرويد، وبالاختبارات، النداء
/// بيرجع بصمت.
library;

import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('meen_al_atlasy/multicast');

Future<void> acquireMulticastLock() => _call('acquire');

Future<void> releaseMulticastLock() => _call('release');

Future<void> _call(String method) async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>(method);
  } on MissingPluginException {
    // اختبارات أو بيئة بدون الطرف الأصلي.
  } on PlatformException {
    // ما منوقّف البحث لو فشل القفل — الحزم ممكن توصل بدونه على بعض الأجهزة.
  }
}
