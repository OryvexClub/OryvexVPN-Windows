import 'dart:async';
import 'dart:io';
import 'vpn_core.dart';

/// Local SOCKS5 proxy server.
/// Listens on [port] and forwards TCP connections through the system
/// routing table (i.e. through the WireGuard tunnel when it is active).
class Socks5Proxy {
  static const String _tag = 'SOCKS5';
  ServerSocket? _server;
  int _activeConnections = 0;

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;
  int get activeConnections => _activeConnections;

  Future<void> start({int port = 8563}) async {
    if (_server != null) return;
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    VpnLogger.info(_tag, 'Listening on 127.0.0.1:$port');
    _server!.listen(
      _onNewConnection,
      onError: (e) => VpnLogger.error(_tag, 'Server error: $e'),
    );
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close();
    _activeConnections = 0;
    VpnLogger.info(_tag, 'Stopped');
  }

  void _onNewConnection(Socket client) {
    _activeConnections++;
    VpnLogger.debug(_tag, 'New connection (active: $_activeConnections)');
    _handleClient(client).catchError((e) {
      VpnLogger.debug(_tag, 'Unhandled error: $e');
    }).whenComplete(() {
      _activeConnections--;
    });
  }

  Future<void> _handleClient(Socket client) async {
    try {
      client.timeout(const Duration(seconds: 30));

      // --- SOCKS5 greeting ---
      final header = await _readExact(client, 2, timeout: 10);
      if (header[0] != 0x05) {
        VpnLogger.debug(_tag, 'Bad version: ${header[0]}');
        client.close();
        return;
      }
      final nMethods = header[1];
      await _readExact(client, nMethods, timeout: 5); // consume method list

      // Reply: no authentication required
      _addExact(client, [0x05, 0x00]);

      // --- Connection request ---
      final req = await _readExact(client, 4, timeout: 10);
      if (req[1] != 0x01) {
        // Only CONNECT (0x01) supported
        _addExact(client, _buildReply(0x07));
        return;
      }

      // Parse target address
      String host;
      switch (req[3]) {
        case 0x01: // IPv4
          final ip = await _readExact(client, 4, timeout: 5);
          host = ip.join('.');
          break;
        case 0x03: // Domain name
          final len = (await _readExact(client, 1, timeout: 5))[0];
          final domain = await _readExact(client, len, timeout: 5);
          host = String.fromCharCodes(domain);
          break;
        case 0x04: // IPv6
          final ip = await _readExact(client, 16, timeout: 5);
          host = _formatIpv6(ip);
          break;
        default:
          _addExact(client, _buildReply(0x08));
          return;
      }

      final portBytes = await _readExact(client, 2, timeout: 5);
      final port = (portBytes[0] << 8) | portBytes[1];

      VpnLogger.debug(_tag, 'CONNECT $host:$port');

      // Connect to the real target
      Socket remote;
      try {
        remote = await Socket.connect(host, port,
            timeout: const Duration(seconds: 15));
      } catch (e) {
        VpnLogger.debug(_tag, 'Connect failed to $host:$port: $e');
        _addExact(client, _buildReply(0x05)); // connection refused
        return;
      }

      // Success reply
      _addExact(client, _buildReply(0x00, remote.address.address));

      // Bidirectional pipe
      _pipe(client, remote);
    } on TimeoutException {
      VpnLogger.debug(_tag, 'Client timeout');
    } catch (e) {
      VpnLogger.debug(_tag, 'Client error: $e');
    } finally {
      try { client.close(); } catch (_) {}
    }
  }

  List<int> _buildReply(int status, [String? bindAddr]) {
    final reply = [0x05, status, 0x00, 0x01];
    if (bindAddr != null) {
      final parts = bindAddr.split('.');
      if (parts.length == 4) {
        reply.addAll(parts.map(int.parse));
      } else {
        reply.addAll([0, 0, 0, 0]);
      }
    } else {
      reply.addAll([0, 0, 0, 0]);
    }
    reply.addAll([0, 0]); // port 0
    return reply;
  }

  void _addExact(Socket sock, List<int> data) {
    try {
      sock.add(data);
      sock.flush();
    } catch (_) {}
  }

  void _pipe(Socket a, Socket b) {
    bool aClosed = false;
    bool bClosed = false;

    void checkClose() {
      if (aClosed && bClosed) {
        try { a.close(); } catch (_) {}
        try { b.close(); } catch (_) {}
      }
    }

    a.listen(
      (data) {
        try {
          b.add(data);
          b.flush();
        } catch (_) {
          if (!bClosed) { bClosed = true; checkClose(); }
        }
      },
      onDone: () { aClosed = true; try { b.close(); } catch (_) {} checkClose(); },
      onError: (_) { aClosed = true; try { b.close(); } catch (_) {} checkClose(); },
    );

    b.listen(
      (data) {
        try {
          a.add(data);
          a.flush();
        } catch (_) {
          if (!aClosed) { aClosed = true; checkClose(); }
        }
      },
      onDone: () { bClosed = true; try { a.close(); } catch (_) {} checkClose(); },
      onError: (_) { bClosed = true; try { a.close(); } catch (_) {} checkClose(); },
    );
  }

  Future<List<int>> _readExact(Socket sock, int n, {int timeout = 10}) async {
    final completer = Completer<List<int>>();
    final buffer = <int>[];

    late StreamSubscription<List<int>> sub;
    sub = sock.listen(
      (data) {
        buffer.addAll(data);
        if (buffer.length >= n) {
          sub.cancel();
          if (!completer.isCompleted) completer.complete(buffer.sublist(0, n));
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          if (buffer.length >= n) {
            completer.complete(buffer.sublist(0, n));
          } else {
            completer.completeError(Exception('Connection closed'));
          }
        }
      },
    );

    Future.delayed(Duration(seconds: timeout), () {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.completeError(TimeoutException('Read timeout'));
      }
    });

    return completer.future;
  }

  String _formatIpv6(List<int> bytes) {
    final parts = <String>[];
    for (var i = 0; i < 16; i += 2) {
      parts.add(
          '${bytes[i].toRadixString(16).padLeft(2, '0')}${bytes[i + 1].toRadixString(16).padLeft(2, '0')}');
    }
    return '[${parts.join(':')}]';
  }
}
