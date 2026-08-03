import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'vpn_core.dart';

/// Lightweight local HTTP proxy server.
/// Handles both plain HTTP forwarding and HTTPS CONNECT tunneling.
class HttpProxy {
  static const String _tag = 'HTTP';
  ServerSocket? _server;
  int _activeConnections = 0;

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;
  int get activeConnections => _activeConnections;

  /// Start the HTTP proxy on the given [port].
  Future<void> start({int port = 1452}) async {
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
      // Read the initial request line and headers
      final request = await _readRequest(client);
      if (request == null) {
        client.close();
        return;
      }

      final firstLine = request.split('\r\n')[0];
      final parts = firstLine.split(' ');
      if (parts.length < 3) {
        client.close();
        return;
      }

      final method = parts[0].toUpperCase();
      final uri = parts[1];

      if (method == 'CONNECT') {
        // HTTPS tunneling: CONNECT host:port HTTP/1.1
        await _handleConnect(client, uri);
      } else {
        // Plain HTTP forwarding
        await _handleHttp(client, request, method, uri);
      }
    } catch (e) {
      VpnLogger.debug(_tag, 'Client error: $e');
      client.close();
    }
  }

  /// Handle CONNECT method (HTTPS tunneling).
  Future<void> _handleConnect(Socket client, String hostPort) async {
    final colonIdx = hostPort.lastIndexOf(':');
    final host = colonIdx > 0 ? hostPort.substring(0, colonIdx) : hostPort;
    final port =
        colonIdx > 0 ? int.tryParse(hostPort.substring(colonIdx + 1)) ?? 443 : 443;

    Socket remote;
    try {
      remote = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));
    } catch (_) {
      client.add(
          Utf8Encoder().convert('HTTP/1.1 502 Bad Gateway\r\n\r\n'));
      await client.flush();
      client.close();
      return;
    }

    // Tell the client the tunnel is established
    client.add(
        Utf8Encoder().convert('HTTP/1.1 200 Connection Established\r\n\r\n'));
    await client.flush();

    // Bidirectional pipe
    _pipe(client, remote);
  }

  /// Handle plain HTTP request forwarding.
  Future<void> _handleHttp(
      Socket client, String fullRequest, String method, String uri) async {
    // Parse the target from the URI (absolute form: http://host/path)
    Uri targetUri;
    try {
      targetUri = Uri.parse(uri);
    } catch (_) {
      client.add(
          Utf8Encoder().convert('HTTP/1.1 400 Bad Request\r\n\r\n'));
      await client.flush();
      client.close();
      return;
    }

    final host = targetUri.host;
    final port = targetUri.port > 0 ? targetUri.port : 80;

    Socket remote;
    try {
      remote = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));
    } catch (_) {
      client.add(
          Utf8Encoder().convert('HTTP/1.1 502 Bad Gateway\r\n\r\n'));
      await client.flush();
      client.close();
      return;
    }

    // Rewrite the request line to use the relative path
    final path = targetUri.path.isEmpty ? '/' : targetUri.path;
    final query = targetUri.hasQuery ? '?${targetUri.query}' : '';
    final newFirstLine = '$method ${path}${query} HTTP/1.1';

    // Rebuild the request with the rewritten first line
    final lines = fullRequest.split('\r\n');
    lines[0] = newFirstLine;

    // Remove Proxy-* headers
    final filteredLines = lines.where((line) {
      final lower = line.toLowerCase();
      return !lower.startsWith('proxy-');
    }).toList();

    final newRequest = filteredLines.join('\r\n');
    remote.add(Utf8Encoder().convert(newRequest));
    await remote.flush();

    // Pipe response back
    _pipe(client, remote);
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

  /// Read a full HTTP request (headers + body if Content-Length is present).
  Future<String?> _readRequest(Socket client) async {
    final completer = Completer<String?>();
    final buffer = BytesBuilder();
    bool headersComplete = false;
    int contentLength = 0;
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

            // Extract Content-Length
            for (final line in headersPart.split('\r\n')) {
              if (line.toLowerCase().startsWith('content-length:')) {
                contentLength =
                    int.tryParse(line.split(':')[1].trim()) ?? 0;
              }
            }

            bodyReceived = buffer.length - headerEnd - 4;
          }
        }

        if (headersComplete && bodyReceived >= contentLength) {
          sub.cancel();
          if (!completer.isCompleted) {
            completer.complete(String.fromCharCodes(buffer.toBytes()));
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          if (headersComplete) {
            completer.complete(String.fromCharCodes(buffer.toBytes()));
          } else {
            completer.complete(null);
          }
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
}
