#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - ابزار رفع خودکار مشکلات پروژه فلاتر (شامل پاک‌سازی توکن‌های درز کرده و آپدیت ویندوز)
"""

import os
import re
import sys
from pathlib import Path
from typing import Optional

class FlutterProjectFixer:
    def __init__(self, project_root: Optional[str] = None):
        self.root = Path(project_root or os.getcwd())
        self.fixed_files = []

    def log(self, message: str, level: str = "INFO"):
        icons = {
            "INFO": "[i]",
            "SUCCESS": "[✓]",
            "WARNING": "[!]",
            "ERROR": "[✗]",
            "STEP": "[>]",
            "FIX": "[🔧]"
        }
        print(f"{icons.get(level, '[i]')} {message}")

    def check_project(self) -> bool:
        if not (self.root / "pubspec.yaml").exists():
            self.log("فایل pubspec.yaml پیدا نشد! این یک پروژه فلاتر نیست.", "ERROR")
            return False
        self.log("پروژه فلاتر شناسایی شد.", "SUCCESS")
        return True

    def fix_vpn_service(self) -> bool:
        """تصحیح API وایرگارد در vpn_service.dart"""
        vpn_service_path = self.root / "lib" / "services" / "vpn_service.dart"
        if not vpn_service_path.exists():
            self.log("vpn_service.dart پیدا نشد!", "WARNING")
            return False

        self.log("در حال تصحیح vpn_service.dart...", "STEP")
        correct = '''import 'package:flutter/foundation.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'warp_generator.dart';
import '../constants/strings.dart';

class VPNService extends ChangeNotifier {
  bool _isConnected = false, _isConnecting = false;
  String _statusMessage = Strings.statusReady;
  String? _currentConfig, _errorMessage;
  Map<String, dynamic>? _accountInfo;
  String _selectedEndpoint = '';
  final WARPGenerator _generator = WARPGenerator();

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get statusMessage => _statusMessage;
  Map<String, dynamic>? get accountInfo => _accountInfo;
  String get selectedEndpoint => _selectedEndpoint;
  String? get errorMessage => _errorMessage;

  Future<bool> generateAndConnect({String? customIp, String? customPort}) async {
    if (_isConnected) await disconnect();
    _isConnecting = true;
    _statusMessage = Strings.statusGenerating;
    _errorMessage = null;
    notifyListeners();

    try {
      _statusMessage = Strings.statusGeneratingKey;
      notifyListeners();

      final config = await _generator.generateFullConfig(
          customIp: customIp, customPort: customPort);

      _accountInfo = _generator.getAccountInfo();
      _currentConfig = config;

      final lines = config.split('\\n');
      for (var line in lines) {
        if (line.startsWith('Endpoint = ')) {
          _selectedEndpoint = line.replaceFirst('Endpoint = ', '');
          break;
        }
      }

      _statusMessage = Strings.statusConnecting;
      notifyListeners();

      final connected = await WireguardFlutter.start(config, 'WARP VPN');
      if (!connected) {
        throw Exception('WireGuard connection failed');
      }

      _isConnected = true;
      _statusMessage = Strings.statusConnected;
      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isConnecting = false;
      _statusMessage = Strings.statusError;
      _errorMessage = e.toString();
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await WireguardFlutter.stop();
      _isConnected = false;
      _currentConfig = null;
      _statusMessage = Strings.statusDisconnected;
      notifyListeners();
    } catch (e) {
      _statusMessage = '${Strings.statusError}: $e';
      notifyListeners();
    }
  }

  String? getConfig() => _currentConfig;
}
'''
        with open(vpn_service_path, "w", encoding="utf-8") as f:
            f.write(correct)
        self.log("vpn_service.dart تصحیح شد.", "FIX")
        self.fixed_files.append("vpn_service.dart")
        return True

    def fix_workflow(self) -> bool:
        """تنظیم و تصحیح اکشن بیلد ویندوز (اضافه کردن precache و pub get مجدد)"""
        workflow_path = self.root / ".github" / "workflows" / "build_windows.yml"
        if not workflow_path.exists():
            self.log("build_windows.yml پیدا نشد!", "WARNING")
            return False

        self.log("در حال تصحیح build_windows.yml...", "STEP")
        correct = '''name: Build Windows App

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION: true

jobs:
  build:
    runs-on: windows-2022

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Precache Windows artifacts
        run: flutter precache --windows

      - name: Run flutter doctor
        run: flutter doctor -v

      - name: Enable Windows desktop
        run: flutter config --enable-windows-desktop

      - name: Clean previous builds
        run: flutter clean

      - name: Get dependencies
        run: flutter pub get

      - name: Update Windows Project Files
        run: flutter create --platforms windows .

      - name: Get dependencies (again after create)
        run: flutter pub get

      - name: Build Windows app
        run: flutter build windows --release

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: warp-vpn-windows
          path: build/windows/runner/Release/
'''
        with open(workflow_path, "w", encoding="utf-8") as f:
            f.write(correct)
        self.log("build_windows.yml تصحیح شد.", "FIX")
        self.fixed_files.append("build_windows.yml")
        return True

    def scrub_tokens(self):
        """جایگزینی توکن‌های واقعی گیت‌هاب (ghp_ + حداقل ۳۶ کاراکتر) با YOUR_GITHUB_TOKEN در تمام فایل‌ها"""
        self.log("در حال پاک‌سازی توکن‌های درز کرده...", "STEP")
        token_regex = re.compile(r'ghp_[A-Za-z0-9_]{36,}')
        modified = False
        for filepath in self.root.rglob('*'):
            if filepath.is_dir():
                continue
            # پرش از پوشه‌های git
            if any(part.startswith('.git') for part in filepath.parts):
                continue
            try:
                content = filepath.read_text(encoding='utf-8')
                new_content, count = token_regex.subn('YOUR_GITHUB_TOKEN', content)
                if count > 0:
                    filepath.write_text(new_content, encoding='utf-8')
                    self.log(f"  → {count} توکن در {filepath.relative_to(self.root)} جایگزین شد.", "WARNING")
                    modified = True
            except Exception:
                # فایل‌های باینری یا غیرقابل خواندن
                pass
        if not modified:
            self.log("هیچ توکن واقعی پیدا نشد.", "SUCCESS")
        return modified

    def update_gitignore(self):
        """اضافه کردن الگوهای امنیتی به .gitignore"""
        gi_path = self.root / ".gitignore"
        required = [".env", "*.token", "*.secret", "key.properties", "*.keystore", "*.jks"]
        existing = gi_path.read_text(encoding='utf-8') if gi_path.exists() else ""
        missing = [r for r in required if r not in existing]
        if missing:
            with gi_path.open('a', encoding='utf-8') as f:
                f.write("\n" + "\n".join(missing) + "\n")
            self.log(".gitignore به‌روزرسانی شد.", "FIX")
            self.fixed_files.append(".gitignore")
        else:
            self.log(".gitignore در حال حاضر کامل است.", "SUCCESS")

    def run(self) -> bool:
        print("\n" + "=" * 60)
        print("🔧 Flutter Project Fixer (نسخه‌ی کامل)")
        print("=" * 60)
        print(f"\nمسیر پروژه: {self.root}\n")

        if not self.check_project():
            return False

        self.fix_vpn_service()
        self.fix_workflow()
        self.scrub_tokens()
        self.update_gitignore()

        print("\n" + "=" * 60)
        print("📊 گزارش نهایی")
        print("=" * 60)
        if self.fixed_files:
            print("\n📁 فایل‌های اصلاح شده:")
            for f in self.fixed_files:
                print(f"  ✓ {f}")
        print("\n✅ همه مشکلات برطرف شد. حالا می‌توانید push کنید.")
        return True

def main():
    try:
        if len(sys.argv) > 1:
            root = sys.argv[1]
        else:
            root = os.getcwd()
        fixer = FlutterProjectFixer(root)
        success = fixer.run()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n⏹️ عملیات توسط کاربر لغو شد.")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ خطای غیرمنتظره: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()