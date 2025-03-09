import 'package:flutter/foundation.dart';

sealed class PlatformUtil {
  static TargetPlatform get current => defaultTargetPlatform;
  static bool get isWeb => kIsWeb;
  static bool get isIOS => current == TargetPlatform.iOS;
  static bool get isAndroid => current == TargetPlatform.android;
  static bool get isWindows => current == TargetPlatform.windows;
  static bool get isMacOS => current == TargetPlatform.macOS;
  static bool get isLinux => current == TargetPlatform.linux;
}
