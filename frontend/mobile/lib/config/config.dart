import 'package:flutter/foundation.dart';

String get baseUrl {
  if (kIsWeb) {
    // Chrome
    return 'http://localhost:8081';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android Emulator
    return 'http://10.0.2.2:8081';
  }

  return 'http://localhost:8081';
}