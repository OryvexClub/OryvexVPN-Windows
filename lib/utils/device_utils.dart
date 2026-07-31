import 'dart:io';
class DeviceUtils {
  static bool get isWindows => Platform.isWindows;
  static String get platformName => isWindows ? 'Windows' : 'Unknown';
}
