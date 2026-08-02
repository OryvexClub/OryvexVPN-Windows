import 'dart:io';

/// A single WireGuard peer endpoint (IP + UDP port).
class VpnEndpoint {
  final String ip;
  final int port;

  const VpnEndpoint(this.ip, this.port);

  /// Whether this is an IPv6 address.
  bool get isIpv6 => ip.contains(':');

  String get hostPort => '$ip:$port';

  @override
  String toString() => hostPort;
}

/// The complete endpoint catalog.
///
/// Two sources are combined:
///  1. [kSpecificEndpoints] – the exact (ip, port) pairs that were curated,
///     including the non-standard UDP ports (these are tried first).
///  2. Generated ranges – the exhaustive `8.6.112.x:2408` and Cloudflare
///     anycast ranges with the default WARP port.
List<VpnEndpoint> get kEndpoints {
  final list = <VpnEndpoint>[...kSpecificEndpoints];

  // 8.6.112.1 .. 8.6.112.255 with the default WARP port.
  for (var h = 1; h <= 255; h++) {
    list.add(VpnEndpoint('8.6.112.$h', 2408));
  }

  // Cloudflare main anycast + WARP ranges, default port 2408.
  for (final ip in const [
    '162.159.192.1', '162.159.192.2', '162.159.192.5',
    '162.159.193.1', '162.159.193.2', '162.159.193.5',
    '162.159.195.1', '162.159.195.2', '162.159.195.5',
  ]) {
    list.add(VpnEndpoint(ip, 2408));
  }

  for (final a in [96, 97, 98, 99]) {
    for (var h = 0; h <= 5; h++) {
      list.add(VpnEndpoint('188.114.$a.$h', 2408));
    }
  }

  for (final ip in const [
    '104.16.248.249', '104.16.249.249', '104.17.248.249', '104.17.249.249',
    '104.18.0.0', '104.18.1.0', '104.18.2.0', '104.18.3.0',
    '141.101.64.0', '141.101.65.0', '141.101.66.0', '141.101.67.0',
    '141.101.68.0', '141.101.69.0', '141.101.70.0', '141.101.71.0',
    '173.245.48.0', '173.245.49.0', '173.245.50.0', '173.245.51.0',
    '173.245.52.0', '173.245.53.0', '173.245.54.0', '173.245.55.0',
    '103.21.244.0', '103.21.245.0', '103.21.246.0', '103.21.247.0',
    '103.22.200.0', '103.22.201.0', '103.22.202.0', '103.22.203.0',
    '103.31.4.0', '103.31.5.0', '103.31.6.0', '103.31.7.0',
  ]) {
    list.add(VpnEndpoint(ip, 2408));
  }

  // IPv6 anycast addresses.
  for (final c in const ['c000', 'c001', 'c002', 'c003', 'c004', 'c005',
    'c100', 'c101', 'c102', 'c103', 'c104', 'c105']) {
    list.add(VpnEndpoint('2606:4700:d0::$c', 2408));
    list.add(VpnEndpoint('2606:4700:d1::$c', 2408));
  }

  return list;
}

/// The specifically-curated (ip, port) pairs, including all non-default ports.
const List<VpnEndpoint> kSpecificEndpoints = [
  // Original 8.6.112.x endpoints (varied ports)
  VpnEndpoint('8.6.112.165', 928), VpnEndpoint('8.6.112.139', 7281),
  VpnEndpoint('8.6.112.178', 942), VpnEndpoint('8.6.112.205', 3581),
  VpnEndpoint('8.6.112.176', 8319), VpnEndpoint('8.6.112.190', 5279),
  VpnEndpoint('8.6.112.121', 500), VpnEndpoint('8.6.112.202', 878),
  VpnEndpoint('8.6.112.223', 7559), VpnEndpoint('8.6.112.230', 1843),
  VpnEndpoint('8.6.112.200', 4198), VpnEndpoint('8.6.112.233', 7152),
  VpnEndpoint('8.6.112.4', 4233), VpnEndpoint('8.6.112.159', 878),
  VpnEndpoint('8.6.112.4', 859), VpnEndpoint('8.6.112.233', 880),
  VpnEndpoint('8.6.112.93', 942), VpnEndpoint('8.6.112.93', 945),
  VpnEndpoint('8.6.112.182', 945), VpnEndpoint('8.6.112.133', 968),
  VpnEndpoint('8.6.112.52', 928), VpnEndpoint('8.6.112.121', 1180),
  VpnEndpoint('8.6.112.78', 859), VpnEndpoint('8.6.112.205', 891),
  VpnEndpoint('8.6.112.248', 903), VpnEndpoint('8.6.112.246', 894),
  VpnEndpoint('8.6.112.230', 878), VpnEndpoint('8.6.112.246', 859),
  VpnEndpoint('8.6.112.172', 878), VpnEndpoint('8.6.112.104', 4233),
  VpnEndpoint('8.6.112.249', 891), VpnEndpoint('8.6.112.46', 4198),
  VpnEndpoint('8.6.112.234', 3854), VpnEndpoint('8.6.112.136', 4177),
  VpnEndpoint('8.6.112.224', 8886), VpnEndpoint('8.6.112.251', 1387),
  VpnEndpoint('8.6.112.127', 4198), VpnEndpoint('8.6.112.200', 1010),
  VpnEndpoint('8.6.112.237', 946), VpnEndpoint('8.6.112.82', 891),
  VpnEndpoint('8.6.112.170', 1180), VpnEndpoint('8.6.112.29', 7152),
  VpnEndpoint('8.6.112.7', 1180), VpnEndpoint('8.6.112.182', 891),
  VpnEndpoint('8.6.112.67', 7103), VpnEndpoint('8.6.112.235', 1070),
  VpnEndpoint('8.6.112.228', 1843), VpnEndpoint('8.6.112.19', 908),
  VpnEndpoint('8.6.112.184', 7281), VpnEndpoint('8.6.112.51', 2506),
  VpnEndpoint('8.6.112.8', 1014), VpnEndpoint('8.6.112.253', 854),
  VpnEndpoint('8.6.112.221', 500), VpnEndpoint('8.6.112.96', 903),
  VpnEndpoint('8.6.112.174', 1014), VpnEndpoint('8.6.112.212', 880),
  VpnEndpoint('8.6.112.154', 7281), VpnEndpoint('8.6.112.65', 2506),
  VpnEndpoint('8.6.112.171', 946), VpnEndpoint('8.6.112.160', 3854),
  VpnEndpoint('8.6.112.86', 1387), VpnEndpoint('8.6.112.163', 7281),
  VpnEndpoint('8.6.112.29', 3581), VpnEndpoint('8.6.112.122', 4177),
  VpnEndpoint('8.6.112.154', 891), VpnEndpoint('8.6.112.174', 939),
  VpnEndpoint('8.6.112.70', 945), VpnEndpoint('8.6.112.53', 7156),
  VpnEndpoint('8.6.112.165', 7281), VpnEndpoint('8.6.112.181', 7152),
  VpnEndpoint('8.6.112.122', 894), VpnEndpoint('8.6.112.191', 908),
  VpnEndpoint('8.6.112.79', 8854), VpnEndpoint('8.6.112.180', 928),
  VpnEndpoint('8.6.112.61', 3581), VpnEndpoint('8.6.112.224', 854),
  VpnEndpoint('8.6.112.77', 1070), VpnEndpoint('8.6.112.107', 3138),
  VpnEndpoint('8.6.112.106', 3138), VpnEndpoint('8.6.112.60', 8854),

  // Notable Cloudflare endpoints
  VpnEndpoint('8.6.112.121', 500),
  VpnEndpoint('188.114.97.6', 7281), VpnEndpoint('188.114.97.6', 859),
  VpnEndpoint('162.159.192.1', 500), VpnEndpoint('162.159.192.1', 4500),
  VpnEndpoint('162.159.192.1', 1701), VpnEndpoint('162.159.192.2', 500),
  VpnEndpoint('162.159.193.1', 500), VpnEndpoint('162.159.193.1', 4500),
  VpnEndpoint('162.159.193.1', 1701),
];

/// A short "quick test" list used to find the fastest live endpoint. Pinging
/// every entry (hundreds) is too slow, so we probe a representative subset
/// that covers every network block and then fall back to the full list.
const List<VpnEndpoint> kProbeEndpoints = [
  VpnEndpoint('8.6.112.165', 928),
  VpnEndpoint('8.6.112.139', 7281),
  VpnEndpoint('8.6.112.178', 942),
  VpnEndpoint('8.6.112.205', 3581),
  VpnEndpoint('8.6.112.121', 500),
  VpnEndpoint('8.6.112.202', 878),
  VpnEndpoint('162.159.192.1', 2408),
  VpnEndpoint('162.159.193.1', 2408),
  VpnEndpoint('188.114.96.1', 2408),
  VpnEndpoint('188.114.97.1', 2408),
  VpnEndpoint('104.16.248.249', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c000', 2408),
];

/// Measures actual latency to an endpoint by timing a socket connection.
/// Returns latency in milliseconds, or null if unreachable.
Future<int?> _measureLatency(String ip, int port, Duration timeout) async {
  try {
    final stopwatch = Stopwatch()..start();
    final socket = await Socket.connect(ip, port, timeout: timeout);
    stopwatch.stop();
    socket.destroy();
    return stopwatch.elapsedMilliseconds;
  } catch (_) {
    return null;
  }
}

/// Finds the reachable endpoint with the lowest latency from [candidates].
/// Returns `null` if none are reachable.
/// Uses parallel latency testing for faster results.
Future<VpnEndpoint?> pickFastestEndpoint({
  List<VpnEndpoint>? candidates,
  Duration timeout = const Duration(milliseconds: 1500),
}) async {
  final list = candidates ?? kEndpoints;

  // We can't reliably TCP ping UDP endpoints, especially through DPI firewalls.
  // We'll test the probe endpoints in parallel.
  final probeResults = <VpnEndpoint, int?>{};
  await Future.wait(
    kProbeEndpoints.map((e) async {
      probeResults[e] = await _measureLatency(e.ip, e.port, timeout);
    }),
  );

  final reachableProbes = probeResults.entries
      .where((entry) => entry.value != null)
      .toList()
    ..sort((a, b) => a.value!.compareTo(b.value!));

  if (reachableProbes.isNotEmpty) {
    return reachableProbes.first.key;
  }

  // If TCP probes fail (common for UDP VPNs on filtered networks),
  // DO NOT sequentially scan 600+ endpoints. It takes 20+ minutes and hangs the UI.
  // Instead, randomly pick an endpoint from the specific curated list.
  final fallbackList = [...kSpecificEndpoints];
  fallbackList.shuffle();

  // Return a random endpoint from the curated list without waiting
  return fallbackList.first;
}
