import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// مدیریت واقعی تانل WireGuard روی ویندوز.
///
/// نیازمندی‌ها:
///  1) WireGuard for Windows نصب باشد (wireguard.com/install).
///  2) برنامه با دسترسی Administrator اجرا شود (نصب/حذف تانل نیاز به
///     ارتقای سطح دسترسی دارد - این یک محدودیت ویندوز است، نه این کد).
///  3) یک سرور VPS خودتان که WireGuard روی آن اجرا می‌شود و کانفیگ معتبر
///     برمی‌گرداند.
///
/// این سرویس هیچ کلیدی را به‌صورت ساختگی تولید نمی‌کند. کانفیگ را عیناً از
/// سرور شما می‌گیرد و همان را روی سیستم نصب می‌کند، سپس وضعیت واقعی سرویس
/// ویندوز را می‌خواند تا وضعیت اتصال هرگز دروغ نگوید.
class WireGuardService {
  static const _tunnelName = 'oryvexvpn';

  /// دریافت کانفیگ آماده از بک‌اند شما.
  /// قرارداد بک‌اند:
  ///   POST {serverUrl}/api/wireguard/config
  ///   Header: Authorization: Bearer <token>
  ///   Response JSON: { "config": "<متن کامل کانفیگ WireGuard>" }
  static Future<String> fetchConfig({
    required String serverUrl,
    required String token,
  }) async {
    if (serverUrl.trim().isEmpty) {
      throw Exception('آدرس سرور VPS تنظیم نشده است');
    }
    final base = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/wireguard/config');

    final response = await http
        .post(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('سرور کانفیگ برنگرداند (کد ${response.statusCode})');
    }

    final data = json.decode(response.body);
    final config = data['config'];
    if (config == null || config.toString().trim().isEmpty) {
      throw Exception('پاسخ سرور کانفیگ معتبری نداشت');
    }
    return config.toString();
  }

  static Future<File> _writeConfigFile(String config) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}\\$_tunnelName.conf');
    return file.writeAsString(config);
  }

  static Future<bool> isWireGuardInstalled() async {
    try {
      final result = await Process.run('where', ['wireguard.exe']);
      return result.exitCode == 0 &&
          result.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// نصب و راه‌اندازی واقعی سرویس تانل. در صورت خطا (مثل نبود دسترسی
  /// Administrator یا نصب‌نبودن WireGuard) پیام خطای قابل‌فهم می‌دهد.
  static Future<void> connect(String config) async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فعلاً فقط از ویندوز پشتیبانی می‌کند');
    }
    if (!await isWireGuardInstalled()) {
      throw Exception(
        'WireGuard برای ویندوز نصب نیست. از wireguard.com/install دانلود کنید',
      );
    }

    final file = await _writeConfigFile(config);
    final result = await Process.run(
      'wireguard.exe',
      ['/installtunnelservice', file.path],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception(
        'نصب تانل ناموفق بود. برنامه را با دسترسی Administrator اجرا کنید.\n'
        '${result.stderr}',
      );
    }
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    await Process.run(
      'wireguard.exe',
      ['/uninstalltunnelservice', _tunnelName],
      runInShell: true,
    );
  }

  /// وضعیت واقعی را از خود ویندوز می‌پرسد - رابط کاربری هرگز از این جلوتر
  /// ادعای "متصل" نمی‌کند.
  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'sc',
        ['query', 'WireGuardTunnel\$$_tunnelName'],
        runInShell: true,
      );
      return result.stdout.toString().contains('RUNNING');
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveServerSettings(String url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('oryvex_server_url', url);
    await prefs.setString('oryvex_server_token', token);
  }

  static Future<Map<String, String>> loadServerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString('oryvex_server_url') ?? '',
      'token': prefs.getString('oryvex_server_token') ?? '',
    };
  }
}
