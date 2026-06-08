import 'package:flutter/material.dart';

/// Notifications push désactivées en v1 (prévu v2 avec Firebase FCM).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> tryInitialize() async {}

  Future<void> bindRepository(Object? repo) async {}

  Future<void> unregister() async {}
}
