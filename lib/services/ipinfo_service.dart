import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class IPInfoModel {
  final String ip;
  final String city;
  final String region;
  final String country;
  final String loc;
  final String org;
  final String timezone;

  String get cleanIsp {
    if (org == 'Unknown' || org == '-') {
      return 'Unknown ISP';
    }
    // Remove AS number (e.g. "AS12345 Google LLC" -> "Google LLC")
    return org.replaceFirst(RegExp(r'^AS\d+\s+'), '');
  }

  IPInfoModel({
    required this.ip,
    required this.city,
    required this.region,
    required this.country,
    required this.loc,
    required this.org,
    required this.timezone,
  });

  factory IPInfoModel.fromJson(Map<String, dynamic> json) {
    return IPInfoModel(
      ip: json['ip'] ?? 'Unknown',
      city: json['city'] ?? 'Unknown',
      region: json['region'] ?? 'Unknown',
      country: json['country'] ?? 'Unknown',
      loc: json['loc'] ?? '0,0',
      org: json['org'] ?? 'Unknown',
      timezone: json['timezone'] ?? 'Unknown',
    );
  }

  factory IPInfoModel.unknown() {
    return IPInfoModel(
      ip: 'N/A',
      city: '-',
      region: '-',
      country: '-',
      loc: '0,0',
      org: '-',
      timezone: '-',
    );
  }
}

class IPInfoService {
  static const String _apiUrl = 'https://ipinfo.io/json';

  static Future<IPInfoModel> getIPInfo() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl)).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return IPInfoModel.fromJson(data);
      } else {
        // Fallback to ipify if ipinfo fails or blocks
        var fallbackResponse = await http.get(Uri.parse('https://api.ipify.org')).timeout(const Duration(seconds: 5));
        if (fallbackResponse.statusCode != 200) fallbackResponse = await http.get(Uri.parse('https://icanhazip.com')).timeout(const Duration(seconds: 5));
        if (fallbackResponse.statusCode != 200) fallbackResponse = await http.get(Uri.parse('https://ifconfig.me/ip')).timeout(const Duration(seconds: 5));
        if (fallbackResponse.statusCode == 200) {
           return IPInfoModel(
             ip: fallbackResponse.body.trim(),
             city: 'Unknown', region: 'Unknown', country: 'Unknown', loc: '0,0', org: 'Unknown', timezone: 'Unknown'
           );
        }
        return IPInfoModel.unknown();
      }
    } catch (e) {
      try {
        var fallbackResponse = await http.get(Uri.parse('https://api.ipify.org')).timeout(const Duration(seconds: 5));
        if (fallbackResponse.statusCode != 200) fallbackResponse = await http.get(Uri.parse('https://icanhazip.com')).timeout(const Duration(seconds: 5));
        if (fallbackResponse.statusCode != 200) fallbackResponse = await http.get(Uri.parse('https://ifconfig.me/ip')).timeout(const Duration(seconds: 5));
        if (fallbackResponse.statusCode == 200) {
           return IPInfoModel(
             ip: fallbackResponse.body.trim(),
             city: 'Unknown', region: 'Unknown', country: 'Unknown', loc: '0,0', org: 'Unknown', timezone: 'Unknown'
           );
        }
      } catch (_) {}
      return IPInfoModel.unknown();
    }
  }


  /// Measure ping using raw TCP socket connect (faster and more reliable than HTTP).
  static Future<int> measurePing(String host, {int port = 443}) async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 3));
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return -1;
    }
  }
}

class ConnectionStats {
  final int ping;
  final double downloadSpeed;
  final double uploadSpeed;
  final IPInfoModel ipInfo;
  final DateTime timestamp;

  ConnectionStats({
    required this.ping,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.ipInfo,
    required this.timestamp,
  });

  factory ConnectionStats.initial() {
    return ConnectionStats(
      ping: 0,
      downloadSpeed: 0.0,
      uploadSpeed: 0.0,
      ipInfo: IPInfoModel.unknown(),
      timestamp: DateTime.now(),
    );
  }

  ConnectionStats copyWith({
    int? ping,
    double? downloadSpeed,
    double? uploadSpeed,
    IPInfoModel? ipInfo,
    DateTime? timestamp,
  }) {
    return ConnectionStats(
      ping: ping ?? this.ping,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ipInfo: ipInfo ?? this.ipInfo,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
