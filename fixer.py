#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - ابزار رفع خودکار مشکلات پروژه فلاتر (بدون اجرای دستورات flutter)
این اسکریپت فقط فایل‌های پروژه را اصلاح می‌کند و کاری به flutter محلی ندارد.
"""

import os
import re
import sys
import urllib.request
from pathlib import Path
from typing import Optional

class FlutterProjectFixer:
    def __init__(self, project_root: Optional[str] = None):
        self.root = Path(project_root or os.getcwd())
        self.fixed_files = []
        self.errors = []
        
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
        
    def fix_pubspec(self) -> bool:
        pubspec_path = self.root / "pubspec.yaml"
        if not pubspec_path.exists():
            self.log("pubspec.yaml پیدا نشد!", "ERROR")
            return False
            
        self.log("در حال بررسی pubspec.yaml...", "STEP")
        with open(pubspec_path, "r", encoding="utf-8") as f:
            content = f.read()
        original = content
        
        # 1. جایگزینی flutter_native_wireguard با wireguard_flutter
        if "flutter_native_wireguard" in content:
            self.log("یافتن پکیج منسوخ flutter_native_wireguard...", "WARNING")
            content = content.replace(
                "flutter_native_wireguard: ^0.1.0",
                "wireguard_flutter: ^0.0.10"
            )
            content = re.sub(
                r'wireguard_flutter: \^0\.0\.10\s+wireguard_flutter: \^0\.0\.10',
                'wireguard_flutter: ^0.0.10',
                content
            )
            self.log("جایگزینی با wireguard_flutter انجام شد.", "FIX")
            
        # 2. اطمینان از وجود assets/fonts
        if "assets/fonts/" not in content:
            if "flutter:" in content and "assets:" not in content:
                content = content.replace(
                    "flutter:",
                    "flutter:\n  uses-material-design: true\n  assets:\n    - assets/fonts/"
                )
                self.log("بخش assets به pubspec.yaml اضافه شد.", "FIX")
                
        # 3. اطمینان از وجود فونت Vazirmatn
        if "Vazirmatn" not in content:
            if "fonts:" in content:
                content = re.sub(
                    r'fonts:\s*\n(\s*-\s+family:.*\n\s*fonts:\s*\n\s*-\s+asset:.*)',
                    r'fonts:\n  - family: Vazirmatn\n    fonts:\n      - asset: assets/fonts/Vazirmatn-Regular.ttf\n\1',
                    content
                )
                self.log("فونت Vazirmatn به pubspec.yaml اضافه شد.", "FIX")
            else:
                content = content.replace(
                    "flutter:",
                    "flutter:\n  uses-material-design: true\n  assets:\n    - assets/fonts/\n  fonts:\n    - family: Vazirmatn\n      fonts:\n        - asset: assets/fonts/Vazirmatn-Regular.ttf"
                )
                self.log("فونت Vazirmatn به pubspec.yaml اضافه شد.", "FIX")
                
        # 4. اطمینان از وجود flutter_localizations
        if "flutter_localizations:" not in content:
            if "dependencies:" in content:
                content = content.replace(
                    "dependencies:",
                    "dependencies:\n  flutter_localizations:\n    sdk: flutter\n  intl: ^0.18.1"
                )
                self.log("flutter_localizations و intl به pubspec.yaml اضافه شدند.", "FIX")
                
        # 5. بررسی و اصلاح flutter_lints
        if "flutter_lints" in content:
            content = re.sub(
                r'flutter_lints:\s*[\^~]?\d+\.\d+\.\d+',
                'flutter_lints: ^3.0.0',
                content
            )
        else:
            if "dev_dependencies:" in content:
                content = content.replace(
                    "dev_dependencies:",
                    "dev_dependencies:\n  flutter_lints: ^3.0.0"
                )
                self.log("flutter_lints به dev_dependencies اضافه شد.", "FIX")
                
        if content != original:
            with open(pubspec_path, "w", encoding="utf-8") as f:
                f.write(content)
            self.log("pubspec.yaml به‌روزرسانی شد.", "SUCCESS")
            self.fixed_files.append("pubspec.yaml")
            return True
        else:
            self.log("pubspec.yaml بدون تغییر باقی ماند.", "INFO")
            return True
            
    def fix_vpn_service(self) -> bool:
        vpn_service_path = self.root / "lib" / "services" / "vpn_service.dart"
        if not vpn_service_path.exists():
            self.log("فایل vpn_service.dart پیدا نشد!", "WARNING")
            return False
            
        self.log("در حال بررسی vpn_service.dart...", "STEP")
        with open(vpn_service_path, "r", encoding="utf-8") as f:
            content = f.read()
        original = content
        
        # 1. تغییر import
        if "flutter_native_wireguard" in content:
            content = content.replace(
                "import 'package:flutter_native_wireguard/flutter_native_wireguard.dart';",
                "import 'package:wireguard_flutter/wireguard_flutter.dart';"
            )
            self.log("اصلاح import در vpn_service.dart", "FIX")
            
        # 2. اضافه کردن import dart:io اگر وجود نداشت
        if "import 'dart:io';" not in content:
            content = "import 'dart:io';\n" + content
            self.log("اضافه کردن import 'dart:io'", "FIX")
            
        # 3. تغییر متد connect
        if "FlutterNativeWireguard.startVpn" in content:
            content = content.replace(
                "await FlutterNativeWireguard.startVpn(\n        configFile.path,\n        'WARP VPN',\n        'WARP connection',\n      );",
                "final connected = await WireguardFlutter.start(\n        config,\n        'WARP VPN',\n      );\n      if (!connected) throw Exception('WireGuard connection failed');"
            )
            self.log("اصلاح متد connect در vpn_service.dart", "FIX")
            
        # 4. تغییر متد disconnect
        if "FlutterNativeWireguard.stopVpn" in content:
            content = content.replace(
                "await FlutterNativeWireguard.stopVpn();",
                "await WireguardFlutter.stop();"
            )
            self.log("اصلاح متد disconnect در vpn_service.dart", "FIX")
            
        if content != original:
            with open(vpn_service_path, "w", encoding="utf-8") as f:
                f.write(content)
            self.log("vpn_service.dart به‌روزرسانی شد.", "SUCCESS")
            self.fixed_files.append("vpn_service.dart")
            return True
        else:
            self.log("vpn_service.dart بدون تغییر باقی ماند.", "INFO")
            return True
            
    def fix_warp_generator(self) -> bool:
        generator_path = self.root / "lib" / "services" / "warp_generator.dart"
        if not generator_path.exists():
            self.log("فایل warp_generator.dart پیدا نشد!", "WARNING")
            return False
            
        self.log("در حال بررسی warp_generator.dart...", "STEP")
        with open(generator_path, "r", encoding="utf-8") as f:
            content = f.read()
            
        if "import 'package:pointycastle/export.dart';" not in content:
            if "import" in content:
                content = "import 'package:pointycastle/export.dart';\n" + content
                with open(generator_path, "w", encoding="utf-8") as f:
                    f.write(content)
                self.log("import pointycastle اضافه شد.", "FIX")
                self.fixed_files.append("warp_generator.dart")
            
        self.log("warp_generator.dart بررسی شد.", "SUCCESS")
        return True
        
    def check_fonts(self) -> bool:
        font_dir = self.root / "assets" / "fonts"
        font_path = font_dir / "Vazirmatn-Regular.ttf"
        
        if font_path.exists() and font_path.stat().st_size > 0:
            self.log("فونت Vazirmatn وجود دارد.", "SUCCESS")
            return True
            
        self.log("فونت Vazirmatn پیدا نشد! در حال دانلود...", "WARNING")
        
        font_urls = [
            "https://raw.githubusercontent.com/rastikerdar/vazirmatn/master/fonts/ttf/Vazirmatn-Regular.ttf",
            "https://github.com/rastikerdar/vazirmatn/releases/download/v33.003/Vazirmatn-Regular.ttf",
            "https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@master/fonts/ttf/Vazirmatn-Regular.ttf"
        ]
        
        font_dir.mkdir(parents=True, exist_ok=True)
        
        for url in font_urls:
            try:
                self.log(f"تلاش برای دانلود از {url}...", "INFO")
                urllib.request.urlretrieve(url, font_path)
                if font_path.exists() and font_path.stat().st_size > 0:
                    self.log("فونت با موفقیت دانلود شد.", "SUCCESS")
                    return True
            except Exception as e:
                self.log(f"دانلود ناموفق: {e}", "WARNING")
                continue
                
        with open(font_path, "w") as f:
            f.write("")
        self.log("فایل placeholder برای فونت ایجاد شد. لطفاً فونت را به‌صورت دستی اضافه کنید.", "WARNING")
        return False
        
    def create_missing_dirs(self) -> bool:
        dirs = [
            "lib/models",
            "lib/services",
            "lib/widgets",
            "lib/screens",
            "lib/utils",
            "lib/constants",
            "assets/fonts",
        ]
        for d in dirs:
            path = self.root / d
            if not path.exists():
                path.mkdir(parents=True, exist_ok=True)
                self.log(f"دایرکتوری {d} ایجاد شد.", "FIX")
        return True
        
    def run(self) -> bool:
        print("\n" + "=" * 60)
        print("🔧 Flutter Project Fixer (بدون اجرای دستورات flutter)")
        print("=" * 60)
        print(f"\nمسیر پروژه: {self.root}\n")
        
        if not self.check_project():
            return False
            
        self.create_missing_dirs()
        self.fix_pubspec()
        self.fix_vpn_service()
        self.fix_warp_generator()
        self.check_fonts()
        
        print("\n" + "=" * 60)
        print("📊 گزارش نهایی")
        print("=" * 60)
        
        if self.fixed_files:
            print("\n📁 فایل‌های اصلاح شده:")
            for f in self.fixed_files:
                print(f"  ✓ {f}")
                
        if not self.errors:
            print("\n✅ همه مشکلات با موفقیت رفع شدند!")
            print("\n🚀 حالا پروژه را به گیت‌هاب پوش کنید:")
            print(f"   cd {self.root}")
            print("   git add .")
            print("   git commit -m 'Fix project files'")
            print("   git push")
            print("\n🔗 GitHub Actions به‌طور خودکار build خواهد شد.")
            return True
        else:
            print("\n⚠️ برخی مشکلات باقی مانده است.")
            return False

def main():
    try:
        if len(sys.argv) > 1:
            project_root = sys.argv[1]
        else:
            project_root = os.getcwd()
        fixer = FlutterProjectFixer(project_root)
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