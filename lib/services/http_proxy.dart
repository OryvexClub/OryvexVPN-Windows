import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'vpn_core.dart';

/// Local HTTP proxy server.
/// Handles both plain HTTP forwarding and HTTPS CONNECT tunneling.
class HttpProxy {
  static const String _tag = 'HTTP';
  ServerSocket? _server;
  int _activeConnections = 0;

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;
  int get activeConnections => _activeConnections;

  Future<void> start({int port = 1452}) async {
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

      // Read the initial request line + headers
      final request = await _readHttpRequest(client);
      if (request == null || request.isEmpty) {
        return;
      }

      final firstLine = request.split('\r\n')[0];
      final parts = firstLine.split(' ');
      if (parts.length < 3) {
        return;
      }

      final method = parts[0].toUpperCase();
      final uri = parts[1];

      if (method == 'CONNECT') {
        VpnLogger.debug(_tag, 'CONNECT $uri');
        await _handleConnect(client, uri);
      } else {
        VpnLogger.debug(_tag, '$method $uri');
        await _handleHttp(client, request, method, uri);
      }
    } on TimeoutException {
      VpnLogger.debug(_tag, 'Client timeout');
    } catch (e) {
      VpnLogger.debug(_tag, 'Client error: $e');
    } finally {
      try { client.close(); } catch (_) {}
    }
  }

  /// Handle CONNECT method (HTTPS tunneling).
  Future<void> _handleConnect(Socket client, String hostPort) async {
    final colonIdx = hostPort.lastIndexOf(':');
    final host = colonIdx > 0 ? hostPort.substring(0, colonIdx) : hostPort;
    final port = colonIdx > 0
        ? int.tryParse(hostPort.substring(colonIdx + 1)) ?? 443
        : 443;

    Socket remote;
    try {
      remote = await Socket.connect(host, port,
          timeout: const Duration(seconds: 15));
    } catch (e) {
      VpnLogger.debug(_tag, 'CONNECT failed to $host:$port: $e');
      _sendRaw(client, 'HTTP/1.1 502 Bad Gateway\r\n\r\n');
      return;
    }

    // Tell the client the tunnel is established
    _sendRaw(client, 'HTTP/1.1 200 Connection Established\r\n\r\n');

    // Bidirectional pipe
    _pipe(client, remote);
  }

  /// Handle plain HTTP request forwarding.
  Future<void> _handleHttp(
      Socket client, String fullRequest, String method, String uri) async {
    Uri targetUri;
    try {
      targetUri = Uri.parse(uri);
    } catch (_) {
      _sendRaw(client, 'HTTP/1.1 400 Bad Request\r\n\r\n');
      return;
    }

    final host = targetUri.host;
    final targetPort = targetUri.port > 0 ? targetUri.port : 80;

    Socket remote;
    try {
      remote = await Socket.connect(host, targetPort,
          timeout: const Duration(seconds: 15));
    } catch (e) {
      VpnLogger.debug(_tag, 'HTTP connect failed to $host:$targetPort: $e');
      _sendRaw(client, 'HTTP/1.1 502 Bad Gateway\r\n\r\n');
      return;
    }

    // Rewrite request: change absolute URL to relative path, fix Host header
    final path = targetUri.path.isEmpty ? '/' : targetUri.path;
    final query = targetUri.hasQuery ? '?${targetUri.query}' : '';
    final newFirstLine = '$method ${path}${query} HTTP/1.1';

    final lines = fullRequest.split('\r\n');
    final headerLines = <String>[newFirstLine];
    bool hostHeaderSet = false;

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) break;
      final lower = line.toLowerCase();
      if (lower.startsWith('proxy-')) continue;
      if (lower.startsWith('host:')) {
        headerLines.add('Host: $host');
        hostHeaderSet = true;
      } else {
        headerLines.add(line);
      }
    }

    if (!hostHeaderSet) headerLines.add('Host: $host');
    headerLines.add('Connection: close');
    headerLines.add('');

    remote.add(Utf8Encoder().convert(headerLines.join('\r\n')));
    await remote.flush();

    _pipe(client, remote);
  }

  void _sendRaw(Socket sock, String data) {
    try {
      sock.add(Utf8Encoder().convert(data));
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

  /// Read a full HTTP request (headers + body based on Content-Length or chunked).
  Future<String?> _readHttpRequest(Socket client) async {
    final completer = Completer<String?>();
    final buffer = BytesBuilder();
    bool headersComplete = false;
    int contentLength = -1;
    int bodyReceived = 0;

    late StreamSubscription<List<int>> sub;
    sub = client.listen(
      (data) {
        buffer.add(data);

        if (!headersComplete) {
          final current = String.fromCharCodes(buffer.toBytes());
          final headerEnd = current.indexOf('\r\n\r\n');
          if (headerEnd >= 0) {
            headersComplete = true;
            final headersPart = current.substring(0, headerEnd);

            for (final line in headersPart.split('\r\n')) {
              final lower = line.toLowerCase();
              if (lower.startsWith('content-length:')) {
                contentLength = int.tryParse(line.split(':')[1].trim()) ?? -1;
              }
            }

            bodyReceived = buffer.length - headerEnd - 4;
          }
        }

        if (headersComplete) {
          // If content-length known, wait for body; otherwise return headers only
          if (contentLength <= 0 || bodyReceived >= contentLength) {
            sub.cancel();
            if (!completer.isCompleted) {
              completer.complete(String.fromCharCodes(buffer.toBytes()));
            }
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          if (buffer.isNotEmpty) {
            completer.complete(String.fromCharCodes(buffer.toBytes()));
          } else {
            completer.complete(null);
          }
        }
      },
    );

    Future.delayed(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        sub.cancel();
        if (headersComplete && buffer.isNotEmpty) {
          completer.complete(String.fromCharCodes(buffer.toBytes()));
        } else {
          completer.completeError(TimeoutException('Read timeout'));
        }
      }
    });

    return completer.future;
  }
}
