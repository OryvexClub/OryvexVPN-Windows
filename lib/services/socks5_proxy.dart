import 'dart:async';
import 'dart:io';
import 'vpn_core.dart';

/// Lightweight local SOCKS5 proxy server.
/// Listens on [port] and forwards TCP connections through the system
/// routing table (i.e. through the WireGuard tunnel when it is active).
class Socks5Proxy {
  static const String _tag = 'SOCKS5';
  ServerSocket? _server;
  int _activeConnections = 0;

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;
  int get activeConnections => _activeConnections;

  /// Start the SOCKS5 proxy on the given [port].
  Future<void> start({int port = 8563}) async {
    if (_server != null) return;
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    VpnLogger.info(_tag, 'Listening on port $port');
    _server!.listen(_onNewConnection, onError: (e) {
      VpnLogger.error(_tag, 'Server error: $e');
    });
  }

  /// Stop the proxy and close all connections.
  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close();
    VpnLogger.info(_tag, 'Stopped');
  }

  void _onNewConnection(Socket client) {
    _activeConnections++;
    _handleClient(client).whenComplete(() {
      _activeConnections--;
    });
  }

  Future<void> _handleClient(Socket client) async {
    try {
      // --- SOCKS5 handshake ---
      final header = await _readExact(client, 2);
      if (header[0] != 0x05) {
        client.close();
        return;
      }
      final nMethods = header[1];
      await _readExact(client, nMethods); // consume method list

      // Reply: no authentication required
      client.add([0x05, 0x00]);
      await client.flush();

      // --- Connection request ---
      final req = await _readExact(client, 4);
      if (req[1] != 0x01) {
        // Only CONNECT (0x01) supported
        await _sendReply(client, 0x07); // command not supported
        return;
      }

      // Parse target address
      String host;
      switch (req[3]) {
        case 0x01: // IPv4
          final ip = await _readExact(client, 4);
          host = ip.map((b) => b.toString()).join('.');
          break;
        case 0x03: // Domain name
          final len = (await _readExact(client, 1))[0];
          final domain = await _readExact(client, len);
          host = String.fromCharCodes(domain);
          break;
        case 0x04: // IPv6
          final ip = await _readExact(client, 16);
          host = '[' + _formatIpv6(ip) + ']';
          break;
        default:
          await _sendReply(client, 0x08); // address type not supported
          return;
      }

      final portBytes = await _readExact(client, 2);
      final port = (portBytes[0] << 8) | portBytes[1];

      // Connect to the real target
      Socket remote;
      try {
        remote = await Socket.connect(host, port,
            timeout: const Duration(seconds: 10));
      } catch (_) {
        await _sendReply(client, 0x05); // connection refused
        return;
      }

      // Success reply
      await _sendReply(client, 0x00, remote.address.address);

      // Bidirectional pipe
      _pipe(client, remote);
    } catch (e) {
      VpnLogger.debug(_tag, 'Client error: $e');
      client.close();
    }
  }

  Future<void> _sendReply(Socket sock, int status,
      [String? bindAddr]) async {
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
    sock.add(reply);
    await sock.flush();
  }

  void _pipe(Socket a, Socket b) {
    bool aClosed = false;
    bool bClosed = false;

    void checkClose() {
      if (aClosed && bClosed) {
        a.close();
        b.close();
      }
    }

    a.listen(
      (data) {
        try {
          b.add(data);
          b.flush();
        } catch (_) {
          if (!bClosed) {
            bClosed = true;
            checkClose();
          }
        }
      },
      onDone: () {
        aClosed = true;
        try {
          b.close();
        } catch (_) {}
        checkClose();
      },
      onError: (_) {
        aClosed = true;
        try {
          b.close();
        } catch (_) {}
        checkClose();
      },
    );

    b.listen(
      (data) {
        try {
          a.add(data);
          a.flush();
        } catch (_) {
          if (!aClosed) {
            aClosed = true;
            checkClose();
          }
        }
      },
      onDone: () {
        bClosed = true;
        try {
          a.close();
        } catch (_) {}
        checkClose();
      },
      onError: (_) {
        bClosed = true;
        try {
          a.close();
        } catch (_) {}
        checkClose();
      },
    );
  }

  Future<List<int>> _readExact(Socket sock, int n) async {
    final completer = Completer<List<int>>();
    final buffer = <int>[];

    late StreamSubscription<List<int>> sub;
    sub = sock.listen(
      (data) {
        buffer.addAll(data);
        if (buffer.length >= n) {
          sub.cancel();
          if (!completer.isCompleted) {
            completer.complete(buffer.sublist(0, n));
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Connection closed early'));
        }
      },
    );

    // Timeout
    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.completeError(Exception('Read timeout'));
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
    return parts.join(':');
  }
}
