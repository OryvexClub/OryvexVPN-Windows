import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

/// Which VPN core actually ended up carrying the current tunnel.
enum VpnCore { amneziawg, wiresock }

class WarpService {
  static const _tunnelName = 'oryvexvpn';
  static const _wiresockProfileName = 'oryvexvpn';

  static VpnCore? _activeCore;

  // Same Cloudflare WARP endpoint list you already had — unrelated to the
  // core swap, left untouched.
  static const List<String> _endpoints = [
    "8.6.112.165", "8.6.112.139", "8.6.112.178", "8.6.112.205",
    "8.6.112.176", "8.6.112.190", "8.6.112.121", "8.6.112.202",
    "8.6.112.223", "8.6.112.230", "8.6.112.200", "8.6.112.233",
    "8.6.112.4", "8.6.112.159", "8.6.112.93", "8.6.112.182",
    "8.6.112.133", "8.6.112.52", "8.6.112.78", "8.6.112.248",
    "8.6.112.246", "8.6.112.172", "8.6.112.104", "8.6.112.249",
    "8.6.112.46", "8.6.112.234", "8.6.112.136", "8.6.112.224",
    "8.6.112.251", "8.6.112.127", "8.6.112.237", "8.6.112.82",
    "8.6.112.170", "8.6.112.29", "8.6.112.7", "8.6.112.67",
    "188.114.97.6", "8.6.112.235", "8.6.112.228", "8.6.112.19",
    "8.6.112.184", "8.6.112.51", "8.6.112.8", "8.6.112.253",
    "8.6.112.221", "8.6.112.96", "8.6.112.174", "8.6.112.212",
    "8.6.112.154", "8.6.112.65", "8.6.112.171", "8.6.112.160",
    "8.6.112.86", "8.6.112.163", "8.6.112.122", "8.6.112.70",
    "8.6.112.53", "8.6.112.181", "8.6.112.191", "8.6.112.79",
    "8.6.112.180", "8.6.112.61", "8.6.112.77", "8.6.112.107",
    "8.6.112.106", "8.6.112.60",
    "162.159.192.1", "162.159.192.2", "162.159.193.1", "162.159.193.5",
    "162.159.195.1", "162.159.195.2", "162.159.195.5",
    "188.114.96.0", "188.114.96.1", "188.114.96.2", "188.114.96.3",
    "188.114.96.4", "188.114.96.5", "188.114.97.0", "188.114.97.1",
    "188.114.97.2", "188.114.97.3", "188.114.97.4", "188.114.97.5",
    "188.114.98.0", "188.114.98.1", "188.114.98.2", "188.114.99.0",
    "188.114.99.1", "188.114.99.2",
  ];

  static String get _exeDir {
    final exePath = Platform.resolvedExecutable;
    return File(exePath).parent.path;
  }

  /// Bundled the same way wireguard.exe used to be — see the updated
  /// build_windows.yml, which now downloads amneziawg.exe into data/.
  static String get _amneziawgExe => '$_exeDir\\data\\amneziawg.exe';

  /// WireSock Secure Connect is a real installer + background service, not
  /// something we can portably bundle, so we just look for it where the
  /// official installer places it if the user has it installed.
  static String get _wiresockCli {
    final pf = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    return '$pf\\WireSock Secure Connect\\wiresock-connect-cli.exe';
  }

  /// Concurrent ping scan to find the fastest Cloudflare endpoint.
  static Future<String> _findBestEndpoint(Function(String) onProgress) async {
    onProgress('در حال جستجوی سریع‌ترین سرور...');
    final futures = _endpoints.map((ip) async {
      try {
        final start = DateTime.now();
        final res = await Process.run('ping', ['-n', '1', '-w', '1000', ip]);
        if (res.exitCode == 0) {
          final latency = DateTime.now().difference(start).inMilliseconds;
          return {'ip': ip, 'latency': latency};
        }
      } catch (_) {}
      return {'ip': ip, 'latency': 9999};
    });

    final results = await Future.wait(futures);
    results.sort((a, b) => (a['latency'] as int).compareTo(b['latency'] as int));

    final bestIp = results.first['latency'] != 9999
        ? results.first['ip'] as String
        : _endpoints.first;
    return '$bestIp:2408';
  }

  /// Generates a WireGuard-format config via the Cloudflare WARP
  /// registration API. Both AmneziaWG and WireSock accept this format
  /// as-is. If your server actually speaks AmneziaWG's obfuscated
  /// protocol (the thing that made it work in the Amnezia app but not in
  /// wireguard.exe), copy the Jc/Jmin/Jmax/S1/S2/H1-H4 lines from your
  /// working Amnezia config into the [Interface] block this returns —
  /// see [obfuscationParams] below.
  static Future<String> generateConfig(
    Function(String) onProgress, {
    Map<String, String>? obfuscationParams,
  }) async {
    onProgress('در حال ساخت کلید رمزنگاری...');
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyBase64 = base64Encode(privateKeyBytes);

    onProgress('در حال ثبت‌نام در شبکه...');
    final response = await http.post(
      Uri.parse('https://api.cloudflareclient.com/v0a737/reg'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "key": pubKeyBase64,
        "install_id": "",
        "warp_enabled": true,
        "tos": DateTime.now().toUtc().toIso8601String(),
        "type": "Windows",
        "locale": "fa_IR"
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('ثبت‌نام دستگاه ناموفق بود.');
    }

    final data = jsonDecode(response.body);
    final peer = data['config']['peers'][0];
    final address = data['config']['interface']['addresses']['v4'];
    final peerPublicKey = peer['public_key'];

    final bestEndpoint = await _findBestEndpoint(onProgress);

    onProgress('در حال آماده‌سازی کانفیگ...');

    final extraInterfaceLines = StringBuffer();
    obfuscationParams?.forEach((key, value) {
      extraInterfaceLines.writeln('$key = $value');
    });

    return '''[Interface]
PrivateKey = $privKeyBase64
Address = $address/32
DNS = 1.1.1.1, 1.0.0.1
MTU = 1280
$extraInterfaceLines
[Peer]
PublicKey = $peerPublicKey
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $bestEndpoint
PersistentKeepalive = 25''';
  }

  static Future<File> _writeConfigFile(String config) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}\\$_tunnelName.conf');
    return file.writeAsString(config);
  }

  static Future<bool> isAmneziaWGAvailable() async => File(_amneziawgExe).exists();
  static Future<bool> isWireSockAvailable() async => File(_wiresockCli).exists();

  /// Escapes a string for safe embedding inside a single-quoted
  /// PowerShell string literal.
  static String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

  /// Runs [exePath] with [args] fully elevated. No extra UAC prompt if the
  /// app itself is already running as admin.
  static Future<int> _runElevated(String exePath, List<String> args) async {
    final argList = args.map(_psQuote).join(',');
    final psCommand =
        "\$p = Start-Process -FilePath ${_psQuote(exePath)} "
        "-ArgumentList $argList "
        "-Verb RunAs -Wait -PassThru -WindowStyle Hidden; "
        "exit \$p.ExitCode";

    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', psCommand],
      runInShell: false,
    );

    if (result.exitCode != 0) {
      final stderrText = (result.stderr ?? '').toString().trim();
      final stdoutText = (result.stdout ?? '').toString().trim();
      final detail = [stderrText, stdoutText].where((s) => s.isNotEmpty).join(' | ');
      final detailSuffix = detail.isNotEmpty ? '\nجزئیات: $detail' : '';
      throw Exception('اجرای هسته وی‌پی‌ان ناموفق بود (کد: ${result.exitCode})$detailSuffix');
    }
    return result.exitCode;
  }

  static Future<void> connect(String config) async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }

    final file = await _writeConfigFile(config);

    // AmneziaWG first — bundled, same install flow as wireguard.exe used
    // to have, and generally fixes the driver-install "Access is denied"
    // class of bug. Fall back to WireSock (different driver family) only
    // if AmneziaWG isn't present or its install fails and WireSock Secure
    // Connect happens to be installed already.
    if (await isAmneziaWGAvailable()) {
      try {
        await _connectAmneziaWG(file);
        _activeCore = VpnCore.amneziawg;
        return;
      } catch (e) {
        if (!await isWireSockAvailable()) rethrow;
      }
    }

    if (await isWireSockAvailable()) {
      await _connectWireSock(file);
      _activeCore = VpnCore.wiresock;
      return;
    }

    throw Exception(
      'هیچ هسته وی‌پی‌ان‌ای پیدا نشد.\n'
      'AmneziaWG (data\\amneziawg.exe) در برنامه یافت نشد و WireSock Secure Connect هم نصب نیست.\n'
      'یکی از این دو را نصب کنید.',
    );
  }

  static Future<void> _connectAmneziaWG(File configFile) async {
    try {
      await _runElevated(_amneziawgExe, ['/installtunnelservice', configFile.path]);
    } catch (e) {
      throw Exception('نصب تونل AmneziaWG ناموفق بود.\n$e');
    }
    final isUp = await _isAmneziaWGConnected();
    if (!isUp) {
      throw Exception('سرویس AmneziaWG پس از نصب شروع نشد.');
    }
  }

  static Future<void> _connectWireSock(File configFile) async {
    // wiresock-connect-cli talks to the already-running WireSock service.
    // Best-effort delete of any stale profile with the same name, then
    // (re)import and connect.
    await Process.run(_wiresockCli, ['delete', _wiresockProfileName]);

    final importResult = await Process.run(_wiresockCli, ['import', configFile.path]);
    if (importResult.exitCode != 0) {
      throw Exception('وارد کردن پروفایل در WireSock ناموفق بود.\n${importResult.stderr}');
    }

    final connectResult = await Process.run(
      _wiresockCli,
      ['connect', _wiresockProfileName, '-exit'],
    );
    if (connectResult.exitCode != 0) {
      throw Exception('اتصال WireSock ناموفق بود.\n${connectResult.stderr}');
    }
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;

    if (_activeCore == VpnCore.wiresock) {
      await Process.run(_wiresockCli, ['disconnect']);
      _activeCore = null;
      return;
    }

    try {
      await _runElevated(_amneziawgExe, ['/uninstalltunnelservice', _tunnelName]);
    } catch (e) {
      if (e.toString().contains('The system cannot find the file specified') ||
          e.toString().contains('service does not exist')) {
        _activeCore = null;
        return;
      }
      rethrow;
    }
    _activeCore = null;
  }

  static Future<bool> _isAmneziaWGConnected() async {
    try {
      final result = await Process.run(
        'sc.exe',
        ['query', 'AmneziaWGTunnel\$' + _tunnelName],
      );
      return result.stdout.toString().contains('RUNNING');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isWireSockConnected() async {
    try {
      final result = await Process.run(_wiresockCli, ['status']);
      final out = result.stdout.toString();
      return out.contains('Connected') && !out.contains('NotConnected');
    } catch (_) {
      return false;
    }
  }

  /// Best-effort status check on app startup, before we know which core
  /// (if any) currently owns the tunnel.
  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;

    if (_activeCore == VpnCore.wiresock) return _isWireSockConnected();
    if (_activeCore == VpnCore.amneziawg) return _isAmneziaWGConnected();

    // Unknown yet (e.g. fresh app launch) — check both.
    if (await _isAmneziaWGConnected()) {
      _activeCore = VpnCore.amneziawg;
      return true;
    }
    if (await isWireSockAvailable() && await _isWireSockConnected()) {
      _activeCore = VpnCore.wiresock;
      return true;
    }
    return false;
  }
}
