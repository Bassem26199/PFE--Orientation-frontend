import 'dart:io';

import 'package:flutter/foundation.dart';

/// URL de l'API Laravel selon la plateforme.
class ApiConfig {
  /// true = émulateur Android | false = téléphone physique (même Wi‑Fi que le PC)
  static const bool androidEmulator = true;

  /// IP du PC : ipconfig dans PowerShell (IPv4)
  static const String lanHost = '192.168.1.31';

  static const int port = 8000;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$port/api';
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'http://127.0.0.1:$port/api';
    }

    if (Platform.isAndroid) {
      final host = androidEmulator ? '10.0.2.2' : lanHost;
      return 'http://$host:$port/api';
    }

    return 'http://$lanHost:$port/api';
  }
}
