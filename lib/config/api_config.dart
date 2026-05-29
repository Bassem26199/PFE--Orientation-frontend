import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  static const bool androidEmulator = true;

  static const String lanHost = '192.168.72.64';

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
