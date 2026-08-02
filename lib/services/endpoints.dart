import 'dart:io';
import 'dart:math';

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

/// Standard WARP ports that are known to work with Cloudflare WARP.
const List<int> kWarpStandardPorts = [2408, 500, 1701, 4500];

/// Comprehensive endpoint list matching the Python WARP generator.
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
  VpnEndpoint('8.6.112.67', 7103), VpnEndpoint('188.114.97.6', 7281),
  VpnEndpoint('8.6.112.235', 1070), VpnEndpoint('8.6.112.228', 1843),
  VpnEndpoint('8.6.112.19', 908), VpnEndpoint('8.6.112.184', 7281),
  VpnEndpoint('8.6.112.51', 2506), VpnEndpoint('188.114.97.6', 859),
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

  // Cloudflare Main Anycast IPs
  VpnEndpoint('162.159.192.1', 2408), VpnEndpoint('162.159.192.1', 500),
  VpnEndpoint('162.159.192.1', 4500), VpnEndpoint('162.159.192.1', 1701),
  VpnEndpoint('162.159.192.2', 2408), VpnEndpoint('162.159.192.2', 500),
  VpnEndpoint('162.159.193.1', 2408), VpnEndpoint('162.159.193.1', 500),
  VpnEndpoint('162.159.193.1', 4500), VpnEndpoint('162.159.193.1', 1701),
  VpnEndpoint('162.159.193.5', 2408), VpnEndpoint('162.159.195.1', 2408),
  VpnEndpoint('162.159.195.2', 2408), VpnEndpoint('162.159.195.5', 2408),
  VpnEndpoint('162.159.192.5', 2408), VpnEndpoint('162.159.193.2', 2408),

  // 188.114.x.x range
  VpnEndpoint('188.114.96.0', 2408), VpnEndpoint('188.114.96.1', 2408),
  VpnEndpoint('188.114.96.2', 2408), VpnEndpoint('188.114.96.3', 2408),
  VpnEndpoint('188.114.96.4', 2408), VpnEndpoint('188.114.96.5', 2408),
  VpnEndpoint('188.114.97.0', 2408), VpnEndpoint('188.114.97.1', 2408),
  VpnEndpoint('188.114.97.2', 2408), VpnEndpoint('188.114.97.3', 2408),
  VpnEndpoint('188.114.97.4', 2408), VpnEndpoint('188.114.97.5', 2408),
  VpnEndpoint('188.114.98.0', 2408), VpnEndpoint('188.114.98.1', 2408),
  VpnEndpoint('188.114.98.2', 2408), VpnEndpoint('188.114.99.0', 2408),
  VpnEndpoint('188.114.99.1', 2408), VpnEndpoint('188.114.99.2', 2408),

  // 104.x.x.x range
  VpnEndpoint('104.16.248.249', 2408), VpnEndpoint('104.16.249.249', 2408),
  VpnEndpoint('104.17.248.249', 2408), VpnEndpoint('104.17.249.249', 2408),
  VpnEndpoint('104.18.0.0', 2408), VpnEndpoint('104.18.1.0', 2408),
  VpnEndpoint('104.18.2.0', 2408), VpnEndpoint('104.18.3.0', 2408),

  // 141.101.x.x range
  VpnEndpoint('141.101.64.0', 2408), VpnEndpoint('141.101.65.0', 2408),
  VpnEndpoint('141.101.66.0', 2408), VpnEndpoint('141.101.67.0', 2408),
  VpnEndpoint('141.101.68.0', 2408), VpnEndpoint('141.101.69.0', 2408),
  VpnEndpoint('141.101.70.0', 2408), VpnEndpoint('141.101.71.0', 2408),

  // 173.245.x.x range
  VpnEndpoint('173.245.48.0', 2408), VpnEndpoint('173.245.49.0', 2408),
  VpnEndpoint('173.245.50.0', 2408), VpnEndpoint('173.245.51.0', 2408),
  VpnEndpoint('173.245.52.0', 2408), VpnEndpoint('173.245.53.0', 2408),
  VpnEndpoint('173.245.54.0', 2408), VpnEndpoint('173.245.55.0', 2408),

  // 103.x.x.x range
  VpnEndpoint('103.21.244.0', 2408), VpnEndpoint('103.21.245.0', 2408),
  VpnEndpoint('103.21.246.0', 2408), VpnEndpoint('103.21.247.0', 2408),
  VpnEndpoint('103.22.200.0', 2408), VpnEndpoint('103.22.201.0', 2408),
  VpnEndpoint('103.22.202.0', 2408), VpnEndpoint('103.22.203.0', 2408),
  VpnEndpoint('103.31.4.0', 2408), VpnEndpoint('103.31.5.0', 2408),
  VpnEndpoint('103.31.6.0', 2408), VpnEndpoint('103.31.7.0', 2408),
];

/// Generated endpoints for 8.6.112.x range (1-255, port 2408).
List<VpnEndpoint> get _generated86112Endpoints {
  final list = <VpnEndpoint>[];
  for (var h = 1; h <= 255; h++) {
    // Skip IPs already in kSpecificEndpoints with non-2408 ports
    if (h == 165 || h == 139 || h == 178 || h == 205 || h == 176 ||
        h == 190 || h == 121 || h == 202 || h == 223 || h == 230 ||
        h == 200 || h == 233 || h == 4 || h == 159 || h == 93 ||
        h == 182 || h == 133 || h == 52 || h == 78 || h == 248 ||
        h == 246 || h == 172 || h == 104 || h == 249 || h == 46 ||
        h == 234 || h == 136 || h == 224 || h == 251 || h == 127 ||
        h == 237 || h == 82 || h == 170 || h == 29 || h == 7 ||
        h == 67 || h == 235 || h == 228 || h == 19 || h == 184 ||
        h == 51 || h == 8 || h == 253 || h == 221 || h == 96 ||
        h == 174 || h == 212 || h == 154 || h == 65 || h == 171 ||
        h == 160 || h == 86 || h == 163 || h == 122 || h == 191 ||
        h == 79 || h == 180 || h == 61 || h == 77 || h == 107 ||
        h == 106 || h == 60 || h == 70 || h == 53 || h == 181) {
      continue;
    }
    list.add(VpnEndpoint('8.6.112.$h', 2408));
  }
  return list;
}

/// IPv6 endpoints matching the Python core.
const List<VpnEndpoint> _ipv6Endpoints = [
  // 2606:4700:d0::a29f:cxxx range
  VpnEndpoint('2606:4700:d0::a29f:c000', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c001', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c002', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c003', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c004', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c005', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c100', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c101', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c102', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c103', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c104', 2408),
  VpnEndpoint('2606:4700:d0::a29f:c105', 2408),
  // 2606:4700:d1::a29f:cxxx range
  VpnEndpoint('2606:4700:d1::a29f:c000', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c001', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c002', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c003', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c004', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c005', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c100', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c101', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c102', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c103', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c104', 2408),
  VpnEndpoint('2606:4700:d1::a29f:c105', 2408),
  // 2606:4700:xxxx::1 range
  VpnEndpoint('2606:4700:1000::1', 2408),
  VpnEndpoint('2606:4700:2000::1', 2408),
  VpnEndpoint('2606:4700:3000::1', 2408),
  VpnEndpoint('2606:4700:4000::1', 2408),
  VpnEndpoint('2606:4700:5000::1', 2408),
  VpnEndpoint('2606:4700:6000::1', 2408),
  VpnEndpoint('2606:4700:7000::1', 2408),
  VpnEndpoint('2606:4700:8000::1', 2408),
  VpnEndpoint('2606:4700:9000::1', 2408),
  VpnEndpoint('2606:4700:a000::1', 2408),
  VpnEndpoint('2606:4700:b000::1', 2408),
  VpnEndpoint('2606:4700:c000::1', 2408),
  VpnEndpoint('2606:4700:d000::1', 2408),
  VpnEndpoint('2606:4700:e000::1', 2408),
  VpnEndpoint('2606:4700:f000::1', 2408),
];

/// The complete endpoint catalog combining all sources.
List<VpnEndpoint> get kEndpoints {
  final list = <VpnEndpoint>[
    ...kSpecificEndpoints,
    ..._generated86112Endpoints,
    ..._ipv6Endpoints,
  ];

  // Deduplicate
  final seen = <String>{};
  final unique = <VpnEndpoint>[];
  for (final ep in list) {
    final key = '${ep.ip}:${ep.port}';
    if (seen.add(key)) {
      unique.add(ep);
    }
  }
  return unique;
}

/// Quick probe list for finding the fastest endpoint.
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
Future<int?> _measureLatency(String ip, int port, Duration timeout) async {
  try {
    final stopwatch = Stopwatch()..start();

    // WireGuard uses UDP, so a TCP connect might fail even if the UDP endpoint is active.
    // However, some firewalls block UDP probes or they silently drop packets.
    // We will do a quick TCP probe to check general routing/reachability, and if it fails,
    // we'll still consider endpoints but prioritize those that respond to TCP.

    final tcpSocket = await Socket.connect(ip, port, timeout: timeout);
    stopwatch.stop();
    tcpSocket.destroy();
    return stopwatch.elapsedMilliseconds;
  } catch (_) {
    // If TCP fails, we don't necessarily want to drop the endpoint completely,
    // but for picking the *fastest*, we need some metric. Let's return null here
    // but the fallback logic will still pick a random endpoint if all probes fail.
    return null;
  }
}

/// Finds the reachable endpoint with the lowest latency.
Future<VpnEndpoint?> pickFastestEndpoint({
  List<VpnEndpoint>? candidates,
  Duration timeout = const Duration(milliseconds: 1500),
}) async {
  final list = candidates ?? kEndpoints;

  // Phase 1: Probe standard WARP endpoints with standard ports
  final standardProbes = <VpnEndpoint>[];
  for (final ip in const [
    '162.159.192.1', '162.159.192.2', '162.159.193.1',
    '188.114.96.1', '188.114.97.1',
    '8.6.112.1', '8.6.112.100', '8.6.112.200',
  ]) {
    for (final port in kWarpStandardPorts) {
      standardProbes.add(VpnEndpoint(ip, port));
    }
  }

  final probeResults = <VpnEndpoint, int?>{};
  await Future.wait(
    standardProbes.map((e) async {
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

  // Phase 2: Try curated probe endpoints
  final curatedResults = <VpnEndpoint, int?>{};
  await Future.wait(
    kProbeEndpoints.map((e) async {
      curatedResults[e] = await _measureLatency(e.ip, e.port, timeout);
    }),
  );

  final reachableCurated = curatedResults.entries
      .where((entry) => entry.value != null)
      .toList()
    ..sort((a, b) => a.value!.compareTo(b.value!));

  if (reachableCurated.isNotEmpty) {
    return reachableCurated.first.key;
  }

  // Phase 3: Fallback - random standard port endpoint
  final standardPortEndpoints = list
      .where((e) => kWarpStandardPorts.contains(e.port))
      .toList();
  if (standardPortEndpoints.isNotEmpty) {
    final random = Random();
    return standardPortEndpoints[random.nextInt(standardPortEndpoints.length)];
  }

  // Last resort: random from full list
  final random = Random();
  return list[random.nextInt(list.length)];
}
