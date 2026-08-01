import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/vpn_service.dart';
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'تنظیمات',
          style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
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
            title: const Text('عمومی', style: TextStyle(fontFamily: 'Vazirmatn')),
            tiles: <SettingsTile>[
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() => _autoConnect = value);
                  _saveSetting('auto_connect', value);
                },
                initialValue: _autoConnect,
                leading: const Icon(Icons.autorenew),
                title: const Text('اتصال خودکار', style: TextStyle(fontFamily: 'Vazirmatn')),
                description: const Text('وصل شدن خودکار در هنگام باز شدن برنامه', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
              ),
              SettingsTile.switchTile(
                onToggle: (value) {
                  setState(() => _startMinimized = value);
                  _saveSetting('start_minimized', value);
                },
                initialValue: _startMinimized,
                leading: const Icon(Icons.minimize),
                title: const Text('شروع کمینه شده', style: TextStyle(fontFamily: 'Vazirmatn')),
                description: const Text('اجرای برنامه در System Tray', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('وضعیت شبکه', style: TextStyle(fontFamily: 'Vazirmatn')),
            tiles: <SettingsTile>[
              SettingsTile(
                leading: const Icon(Icons.network_check),
                title: const Text('وضعیت پروکسی سیستم', style: TextStyle(fontFamily: 'Vazirmatn')),
                value: Consumer<VPNService>(
                  builder: (context, vpn, child) => Text(
                    vpn.isConnected ? 'تنظیم شده توسط اورایوکس' : 'پیش‌فرض سیستم',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: vpn.isConnected ? AppTheme.success : Colors.white54,
                    ),
                  ),
                ),
              ),
              SettingsTile(
                leading: const Icon(Icons.dns),
                title: const Text('وضعیت DNS', style: TextStyle(fontFamily: 'Vazirmatn')),
                value: Consumer<VPNService>(
                  builder: (context, vpn, child) => Text(
                    vpn.isConnected ? 'Cloudflare DNS (1.1.1.1)' : 'پیش‌فرض شبکه',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      color: vpn.isConnected ? AppTheme.success : Colors.white54,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('درباره', style: TextStyle(fontFamily: 'Vazirmatn')),
            tiles: <SettingsTile>[
              SettingsTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('نسخه', style: TextStyle(fontFamily: 'Vazirmatn')),
                value: const Text('1.0.0', style: TextStyle(fontFamily: 'Vazirmatn')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
