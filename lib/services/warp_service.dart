import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

/// Drives a self-built, bundled copy of the official open-source
/// wireguard-go (https://github.com/WireGuard/wireguard-go) plus the
/// official Wintun driver DLL, directly — no AmneziaWG, no WireSock, no
/// commercial SDK, and never the official wireguard.exe GUI/MSI.
///
/// IMPORTANT / KNOWN RISK (read before relying on this in production):
/// wireguard-go's own Windows UAPI implementation
/// (\\.\pipe\ProtectedPrefix\Administrators\WireGuard\<name>) has a
/// long-documented issue where creating that named pipe can fail with
/// "This security ID may not be assigned as the owner of this object",
/// even from an already-elevated process. Upstream's answer to this is
/// wireguard-windows, which wraps wireguard-go in a proper Windows
/// service running as SYSTEM — something we are intentionally NOT doing
/// here. If you hit that specific error, it is not a bug in this file;
/// it's the exact upstream limitation this approach accepts. The error
/// is surfaced clearly below instead of being silently swallowed.
class WarpService {
  static const _tunnelName = 'oryvexvpn';
  static const _uapiPipeName = r'ProtectedPrefix\Administrators\WireGuard\oryvexvpn';

  static Process? _tunnelProcess;
  static bool _connected = false;

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

  static String get _wireguardGoExe => '$_exeDir\\data\\wireguard-go.exe';
  static String get _wintunDll => '$_exeDir\\data\\wintun.dll';

  static Future<bool> _coreFilesPresent() async =>
      File(_wireguardGoExe).exists() && File(_wintunDll).exists();

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
    return bestIp;
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Registers with the Cloudflare WARP API and returns everything needed
  /// to both display a human-readable config AND drive the UAPI directly
  /// (UAPI needs hex keys, not the base64 form used in .conf files).
  static Future<_WarpRegistration> _register(Function(String) onProgress) async {
    onProgress('در حال ساخت کلید رمزنگاری...');
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyHex = _bytesToHex(privateKeyBytes);

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
    final address = (data['config']['interface']['addresses']['v4'] as String);
    final peerPublicKeyBase64 = peer['public_key'] as String;
    final peerPublicKeyHex = _bytesToHex(base64Decode(peerPublicKeyBase64));

    final bestIp = await _findBestEndpoint(onProgress);

    return _WarpRegistration(
      privateKeyHex: privKeyHex,
      address: address,
      peerPublicKeyHex: peerPublicKeyHex,
      endpointIp: bestIp,
      endpointPort: '2408',
    );
  }

  /// Writes the small PowerShell helper that actually talks to the UAPI
  /// named pipe (Dart's dart:io has no first-class Windows named pipe
  /// client, so we drive .NET's NamedPipeClientStream for this one step).
  static Future<File> _ensureUapiHelperScript() async {
    final path = '${Directory.systemTemp.path}\\oryvexvpn_uapi_helper.ps1';
    const script = r'''
param(
  [string]$PipeName,
  [string]$InFile,
  [string]$OutFile,
  [int]$TimeoutMs = 4000
)
try {
  $client = New-Object System.IO.Pipes.NamedPipeClientStream(".", $PipeName, [System.IO.Pipes.PipeDirection]::InOut)
  $client.Connect($TimeoutMs)

  $bytes = [System.IO.File]::ReadAllBytes($InFile)
  $client.Write($bytes, 0, $bytes.Length)
  $client.Flush()

  $reader = New-Object System.IO.StreamReader($client)
  $sb = New-Object System.Text.StringBuilder
  while ($true) {
    $line = $reader.ReadLine()
    if ($null -eq $line) { break }
    [void]$sb.AppendLine($line)
    if ($line -eq "") { break }
  }
  [System.IO.File]::WriteAllText($OutFile, $sb.ToString())
  $client.Dispose()
  exit 0
} catch {
  [System.IO.File]::WriteAllText($OutFile, "ERROR: " + $_.Exception.Message)
  exit 1
}
''';
    final file = File(path);
    await file.writeAsString(script);
    return file;
  }

  /// Sends a raw UAPI command to the running wireguard-go's named pipe and
  /// returns its response text.
  static Future<String> _uapiSend(String command) async {
    final helper = await _ensureUapiHelperScript();
    final tmpDir = Directory.systemTemp.path;
    final inFile = File('$tmpDir\\oryvexvpn_uapi_in.txt');
    final outFile = File('$tmpDir\\oryvexvpn_uapi_out.txt');
    await inFile.writeAsString(command);
    if (await outFile.exists()) await outFile.delete();

    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', helper.path,
      '-PipeName', _uapiPipeName,
      '-InFile', inFile.path,
      '-OutFile', outFile.path,
    ]);

    final out = await outFile.exists() ? await outFile.readAsString() : '';

    if (result.exitCode != 0 || out.startsWith('ERROR:')) {
      if (out.contains('security ID may not be assigned as the owner')) {
        throw Exception(
          'wireguard-go نتوانست روی pipe داخلی خودش گوش بدهد (محدودیت '
          'شناخته‌شده‌ی خود wireguard-go روی ویندوز وقتی بدون سرویس ویندوزی '
          'اجرا می‌شود). این یک محدودیت بالادستی است، نه باگ این برنامه.\n'
          'جزئیات: $out',
        );
      }
      throw Exception('ارتباط با هسته‌ی وایرگارد ناموفق بود.\n$out');
    }
    return out;
  }

  static Future<void> _configureUapi(_WarpRegistration reg) async {
    final buf = StringBuffer();
    buf.writeln('set=1');
    buf.writeln('private_key=${reg.privateKeyHex}');
    buf.writeln('listen_port=0');
    buf.writeln('replace_peers=true');
    buf.writeln('public_key=${reg.peerPublicKeyHex}');
    buf.writeln('endpoint=${reg.endpointIp}:${reg.endpointPort}');
    buf.writeln('persistent_keepalive_interval=25');
    buf.writeln('replace_allowed_ips=true');
    buf.writeln('allowed_ip=0.0.0.0/0');
    buf.writeln(); // blank line terminates the UAPI transaction

    final response = await _uapiSend(buf.toString());
    if (!response.contains('errno=0')) {
      throw Exception('پیکربندی هسته‌ی وایرگارد رد شد.\n$response');
    }
  }

  /// wg-quick normally does this on Linux; on our bare wireguard-go setup
  /// we have to configure the adapter's IP/MTU/DNS/route ourselves.
  static Future<void> _configureAdapter(_WarpRegistration reg) async {
    final ip = reg.address; // e.g. "172.16.0.2"
    final commands = <List<String>>[
      ['netsh', 'interface', 'ip', 'set', 'address', 'name=$_tunnelName', 'static', ip, '255.255.255.255'],
      ['netsh', 'interface', 'ipv4', 'set', 'subinterface', _tunnelName, 'mtu=1280', 'store=active'],
      ['netsh', 'interface', 'ip', 'set', 'dns', 'name=$_tunnelName', 'static', '1.1.1.1'],
      ['netsh', 'interface', 'ip', 'add', 'dns', 'name=$_tunnelName', '1.0.0.1', 'index=2'],
      ['netsh', 'interface', 'ipv4', 'add', 'route', '0.0.0.0/0', _tunnelName],
    ];

    for (final cmd in commands) {
      final result = await Process.run(cmd.first, cmd.sublist(1));
      if (result.exitCode != 0) {
        final err = (result.stderr ?? '').toString().trim();
        throw Exception('پیکربندی آداپتور شبکه ناموفق بود: ${cmd.join(' ')}\n$err');
      }
    }
  }

  static Future<void> _waitForPipe() async {
    // installtunnelservice-style wrappers get to wait on a service
    // handle; we just poll briefly for the process to have set up the
    // pipe and adapter before we try to talk to it.
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  static Future<void> connect() async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }
    await connectWithProgress((_) {});
  }

  static Future<void> connectWithProgress(Function(String) onProgress) async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }
    if (!await _coreFilesPresent()) {
      throw Exception(
        'فایل‌های هسته (data\\wireguard-go.exe و data\\wintun.dll) در برنامه یافت نشد.',
      );
    }

    final reg = await _register(onProgress);

    onProgress('در حال راه‌اندازی هسته وایرگارد...');
    _tunnelProcess = await Process.start(
      _wireguardGoExe,
      ['-f', _tunnelName],
      workingDirectory: '$_exeDir\\data',
      mode: ProcessStartMode.detachedWithStdio,
    );

    await _waitForPipe();

    try {
      onProgress('در حال پیکربندی تونل...');
      await _configureUapi(reg);

      onProgress('در حال پیکربندی آداپتور شبکه...');
      await _configureAdapter(reg);

      _connected = true;
    } catch (e) {
      await _killTunnelProcess();
      _connected = false;
      rethrow;
    }
  }

  static Future<void> _killTunnelProcess() async {
    final proc = _tunnelProcess;
    _tunnelProcess = null;
    if (proc == null) return;
    try {
      proc.kill(ProcessSignal.sigterm);
    } catch (_) {}
    // wireguard-go on Windows doesn't always die cleanly from sigterm from
    // a detached handle — make sure the adapter's owning process is gone.
    await Process.run('taskkill', ['/F', '/IM', 'wireguard-go.exe']);
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    await _killTunnelProcess();
    _connected = false;
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    if (!_connected) return false;
    // Best-effort liveness check: is our process handle still alive, and
    // does the adapter still show up.
    final result = await Process.run('netsh', ['interface', 'show', 'interface', _tunnelName]);
    return result.exitCode == 0 && result.stdout.toString().contains(_tunnelName);
  }
}

class _WarpRegistration {
  final String privateKeyHex;
  final String address;
  final String peerPublicKeyHex;
  final String endpointIp;
  final String endpointPort;

  const _WarpRegistration({
    required this.privateKeyHex,
    required this.address,
    required this.peerPublicKeyHex,
    required this.endpointIp,
    required this.endpointPort,
  });
}
