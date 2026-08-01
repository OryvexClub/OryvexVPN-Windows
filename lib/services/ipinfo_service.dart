import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class IPInfoModel {
  final String ip;
  final String city;
  final String region;
  final String country;
  final String loc;
  final String org;
  final String timezone;

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
      ip: 'Disconnected',
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
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return IPInfoModel.fromJson(data);
      } else {
        return IPInfoModel.unknown();
      }
    } catch (e) {
      print('Error fetching IP info: $e');
      return IPInfoModel.unknown();
    }
  }

  static Future<int> measurePing(String host) async {
    try {
      final stopwatch = Stopwatch()..start();

      final response = await http.head(Uri.parse('https://$host')).timeout(
        const Duration(seconds: 5),
      );

      stopwatch.stop();

      if (response.statusCode < 500) {
        return stopwatch.elapsedMilliseconds;
      }
      return -1;
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
