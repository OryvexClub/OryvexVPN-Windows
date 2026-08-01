import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({Key? key}) : super(key: key);

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final vpn = context.read<VPNService>();
    _urlController.text = vpn.serverUrl;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A22),
      title: const Text(
        'تنظیمات سرور VPS',
        style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'آدرس سرور (https://vps.example.com)',
              labelStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'توکن دسترسی',
              labelStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'سرور شما باید روی مسیر /api/wireguard/config یک کانفیگ '
            'WireGuard معتبر برگرداند. برنامه فقط همان کانفیگ را دریافت '
            'و روی سیستم نصب می‌کند.',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        ElevatedButton(
          onPressed: () {
            context.read<VPNService>().saveSettings(
                  _urlController.text.trim(),
                  _tokenController.text.trim(),
                );
            Navigator.pop(context);
          },
          child: const Text('ذخیره'),
        ),
      ],
    );
  }
}
