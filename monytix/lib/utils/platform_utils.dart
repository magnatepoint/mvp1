import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isMobile => isIOS || isAndroid;
  static bool get isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
}

