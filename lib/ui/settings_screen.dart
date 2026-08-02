import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/vpn_service.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoConnect = false;
  bool _startMinimized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoConnect = prefs.getBool('auto_connect') ?? false;
      _startMinimized = prefs.getBool('start_minimized') ?? false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SettingsList(
        lightTheme: const SettingsThemeData(
          settingsListBackground: AppTheme.background,
          settingsSectionBackground: AppTheme.surface,
          titleTextColor: AppTheme.primary,
        ),
        darkTheme: const SettingsThemeData(
          settingsListBackground: AppTheme.background,
          settingsSectionBackground: AppTheme.surface,
          titleTextColor: AppTheme.primary,
        ),
        sections: [
          SettingsSection(
            title: Text(l10n.general),
            tiles: <SettingsTile>[
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() => _autoConnect = value);
                  _saveSetting('auto_connect', value);
                },
                initialValue: _autoConnect,
                leading: const Icon(Icons.autorenew),
                title: Text(l10n.autoConnect),
                description: Text(l10n.autoConnectDesc, style: const TextStyle(fontSize: 12)),
              ),
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() => _startMinimized = value);
                  _saveSetting('start_minimized', value);
                },
                initialValue: _startMinimized,
                leading: const Icon(Icons.minimize),
                title: Text(l10n.startMinimized),
                description: Text(l10n.startMinimizedDesc, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(l10n.networkStatus),
            tiles: <SettingsTile>[
              SettingsTile(
                leading: const Icon(Icons.network_check),
                title: Text(l10n.proxyStatus),
                value: Consumer<VPNService>(
                  builder: (context, vpn, child) => Text(
                    vpn.isConnected ? l10n.proxyActive : l10n.proxyDefault,
                    style: TextStyle(
                      color: vpn.isConnected ? AppTheme.success : Colors.white54,
                    ),
                  ),
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.dns),
                title: Text(l10n.dnsStatus),
                value: Consumer<VPNService>(
                  builder: (context, vpn, child) => Text(
                    vpn.isConnected ? l10n.dnsCloudflare : l10n.dnsDefault,
                    style: TextStyle(
                      color: vpn.isConnected ? AppTheme.success : Colors.white54,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(l10n.about),
            tiles: <SettingsTile>[
              SettingsTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.version),
                value: const Text('1.0.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
