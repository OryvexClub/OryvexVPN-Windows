import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WireguardConfig {
  final String name;
  final String privateKey;
  final String address;
  final String publicKey;
  final String endpoint;
  final String dns;
  final int mtu;
  final String allowedIPs;
  final int persistentKeepalive;
  final DateTime createdAt;
  final DateTime? lastConnected;
  final String protocol;
  final String serverLocation;
  final int serverLatency;

  WireguardConfig({
    required this.name,
    required this.privateKey,
    required this.address,
    required this.publicKey,
    required this.endpoint,
    this.dns = '1.1.1.1, 1.0.0.1',
    this.mtu = 1280,
    this.allowedIPs = '0.0.0.0/0',
    this.persistentKeepalive = 25,
    required this.createdAt,
    this.lastConnected,
    this.protocol = 'WireGuard',
    this.serverLocation = 'Auto',
    this.serverLatency = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'privateKey': privateKey,
      'address': address,
      'publicKey': publicKey,
      'endpoint': endpoint,
      'dns': dns,
      'mtu': mtu,
      'allowedIPs': allowedIPs,
      'persistentKeepalive': persistentKeepalive,
      'createdAt': createdAt.toIso8601String(),
      'lastConnected': lastConnected?.toIso8601String(),
      'protocol': protocol,
      'serverLocation': serverLocation,
      'serverLatency': serverLatency,
    };
  }

  factory WireguardConfig.fromJson(Map<String, dynamic> json) {
    return WireguardConfig(
      name: json['name'] as String,
      privateKey: json['privateKey'] as String,
      address: json['address'] as String,
      publicKey: json['publicKey'] as String,
      endpoint: json['endpoint'] as String,
      dns: json['dns'] as String? ?? '1.1.1.1, 1.0.0.1',
      mtu: json['mtu'] as int? ?? 1280,
      allowedIPs: json['allowedIPs'] as String? ?? '0.0.0.0/0',
      persistentKeepalive: json['persistentKeepalive'] as int? ?? 25,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastConnected: json['lastConnected'] != null
          ? DateTime.parse(json['lastConnected'] as String)
          : null,
      protocol: json['protocol'] as String? ?? 'WireGuard',
      serverLocation: json['serverLocation'] as String? ?? 'Auto',
      serverLatency: json['serverLatency'] as int? ?? 0,
    );
  }

  String toWireguardConf() {
    final buffer = StringBuffer();
    buffer.writeln('[Interface]');
    buffer.writeln('PrivateKey = $privateKey');
    buffer.writeln('Address = $address');
    buffer.writeln('DNS = $dns');
    buffer.writeln('MTU = $mtu');
    buffer.writeln('');
    buffer.writeln('[Peer]');
    buffer.writeln('PublicKey = $publicKey');
    buffer.writeln('Endpoint = $endpoint');
    buffer.writeln('AllowedIPs = $allowedIPs');
    buffer.writeln('PersistentKeepalive = $persistentKeepalive');
    return buffer.toString();
  }

  WireguardConfig copyWith({
    String? name,
    DateTime? lastConnected,
    int? serverLatency,
    String? serverLocation,
  }) {
    return WireguardConfig(
      name: name ?? this.name,
      privateKey: privateKey,
      address: address,
      publicKey: publicKey,
      endpoint: endpoint,
      dns: dns,
      mtu: mtu,
      allowedIPs: allowedIPs,
      persistentKeepalive: persistentKeepalive,
      createdAt: createdAt,
      lastConnected: lastConnected ?? this.lastConnected,
      protocol: protocol,
      serverLocation: serverLocation ?? this.serverLocation,
      serverLatency: serverLatency ?? this.serverLatency,
    );
  }
}

class ConfigManager {
  static const String _configsKey = 'saved_configs';
  static const String _activeConfigKey = 'active_config_name';

  static Future<String> _getConfigDir() async {
    final appDir = await getApplicationSupportDirectory();
    final configDir = Directory('${appDir.path}\\oryvexvpn\\configs');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return configDir.path;
  }

  /// Save a configuration
  static Future<void> saveConfig(WireguardConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing configs
      final configsList = await getAllConfigs();

      // Remove config with same name if exists
      configsList.removeWhere((c) => c.name == config.name);

      // Add new config
      configsList.add(config);

      // Save to preferences
      final jsonList = configsList.map((c) => jsonEncode(c.toJson())).toList();
      await prefs.setStringList(_configsKey, jsonList);

      // Save config file to disk
      final configDir = await _getConfigDir();
      final configFile = File('$configDir\\${config.name}.conf');
      await configFile.writeAsString(config.toWireguardConf());

      print('✓ Configuration saved: ${config.name}');
    } catch (e) {
      print('Error saving config: $e');
      rethrow;
    }
  }

  /// Get all saved configurations
  static Future<List<WireguardConfig>> getAllConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_configsKey) ?? [];

      return jsonList.map((jsonStr) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return WireguardConfig.fromJson(json);
      }).toList();
    } catch (e) {
      print('Error loading configs: $e');
      return [];
    }
  }

  /// Delete a configuration
  static Future<void> deleteConfig(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove from list
      final configs = await getAllConfigs();
      configs.removeWhere((c) => c.name == name);

      final jsonList = configs.map((c) => jsonEncode(c.toJson())).toList();
      await prefs.setStringList(_configsKey, jsonList);

      // Remove file
      final configDir = await _getConfigDir();
      final configFile = File('$configDir\\$name.conf');
      if (await configFile.exists()) {
        await configFile.delete();
      }

      // Clear active if it was this config
      if (await getActiveConfigName() == name) {
        await setActiveConfig(null);
      }

      print('✓ Configuration deleted: $name');
    } catch (e) {
      print('Error deleting config: $e');
      rethrow;
    }
  }

  /// Set the active configuration
  static Future<void> setActiveConfig(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_activeConfigKey);
    } else {
      await prefs.setString(_activeConfigKey, name);
    }
  }

  /// Get the active configuration name
  static Future<String?> getActiveConfigName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeConfigKey);
  }

  /// Get the active configuration
  static Future<WireguardConfig?> getActiveConfig() async {
    final name = await getActiveConfigName();
    if (name == null) return null;

    final configs = await getAllConfigs();
    try {
      return configs.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Update last connected time
  static Future<void> updateLastConnected(String name) async {
    final configs = await getAllConfigs();
    final index = configs.indexWhere((c) => c.name == name);

    if (index != -1) {
      configs[index] = configs[index].copyWith(
        lastConnected: DateTime.now(),
      );

      final prefs = await SharedPreferences.getInstance();
      final jsonList = configs.map((c) => jsonEncode(c.toJson())).toList();
      await prefs.setStringList(_configsKey, jsonList);
    }
  }

  /// Import config from .conf file
  static Future<WireguardConfig?> importFromFile(File file) async {
    try {
      final content = await file.readAsString();
      return parseWireguardConf(content, file.path.split('\\').last.replaceAll('.conf', ''));
    } catch (e) {
      print('Error importing config: $e');
      return null;
    }
  }

  /// Parse WireGuard configuration
  static WireguardConfig? parseWireguardConf(String content, String defaultName) {
    try {
      String? privateKey;
      String? address;
      String? publicKey;
      String? endpoint;
      String dns = '1.1.1.1, 1.0.0.1';
      int mtu = 1280;
      String allowedIPs = '0.0.0.0/0';
      int persistentKeepalive = 25;

      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('PrivateKey')) {
          privateKey = trimmed.split('=')[1].trim();
        } else if (trimmed.startsWith('Address')) {
          address = trimmed.split('=')[1].trim();
        } else if (trimmed.startsWith('PublicKey')) {
          publicKey = trimmed.split('=')[1].trim();
        } else if (trimmed.startsWith('Endpoint')) {
          endpoint = trimmed.split('=')[1].trim();
        } else if (trimmed.startsWith('DNS')) {
          dns = trimmed.split('=')[1].trim();
        } else if (trimmed.startsWith('MTU')) {
          mtu = int.tryParse(trimmed.split('=')[1].trim()) ?? 1280;
        } else if (trimmed.startsWith('AllowedIPs')) {
          allowedIPs = trimmed.split('=')[1].trim();
        } else if (trimmed.startsWith('PersistentKeepalive')) {
          persistentKeepalive = int.tryParse(trimmed.split('=')[1].trim()) ?? 25;
        }
      }

      if (privateKey == null || address == null || publicKey == null || endpoint == null) {
        throw Exception('Invalid WireGuard configuration');
      }

      // Extract server location from endpoint
      final serverIp = endpoint.split(':')[0];
      String location = 'Unknown';
      if (serverIp.startsWith('162.159')) {
        location = 'Cloudflare US';
      } else if (serverIp.startsWith('188.114')) {
        location = 'Cloudflare EU';
      }

      return WireguardConfig(
        name: defaultName,
        privateKey: privateKey,
        address: address,
        publicKey: publicKey,
        endpoint: endpoint,
        dns: dns,
        mtu: mtu,
        allowedIPs: allowedIPs,
        persistentKeepalive: persistentKeepalive,
        createdAt: DateTime.now(),
        serverLocation: location,
      );
    } catch (e) {
      print('Error parsing config: $e');
      return null;
    }
  }

  /// Export config to file
  static Future<File?> exportConfig(WireguardConfig config, String path) async {
    try {
      final file = File(path);
      await file.writeAsString(config.toWireguardConf());
      return file;
    } catch (e) {
      print('Error exporting config: $e');
      return null;
    }
  }
}
