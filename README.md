<div align="center">

# 🛡️ OryvexVPN

**یک کلاینت VPN حرفه‌ای با رابط کاربری فارسی برای ویندوز**

[![Build Status](https://github.com/OryvexClub/oryvex_vpn_demo/actions/workflows/build-windows.yml/badge.svg)](https://github.com/OryvexClub/oryvex_vpn_demo/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Modern Windows VPN Client with Full Persian UI

[Download Latest Release](https://github.com/OryvexClub/oryvex_vpn_demo/releases) • [گزارش مشکل](https://github.com/OryvexClub/oryvex_vpn_demo/issues) • [درخواست ویژگی](https://github.com/OryvexClub/oryvex_vpn_demo/issues)

</div>

---

## ✨ ویژگی‌ها / Features

- 🌍 **اتصال امن / Secure Connection** - پروتکل VPN امن / Secure VPN Protocol
- 🇮🇷 **رابط فارسی کامل / Full Persian UI** - تمام متن‌ها به فارسی با پشتیبانی RTL / All texts in Persian with RTL support
- 📊 **آمار واقعی / Real Statistics** - سرعت، پینگ و IP واقعی / Real speed, ping and IP
- 🎯 **اتصال خودکار / Auto-Connect** - انتخاب بهترین سرور / Best server selection
- 🔄 **مانیتورینگ مداوم / Continuous Monitoring** - بررسی وضعیت اتصال / Connection status checking
- 💾 **مدیریت تنظیمات / Config Management** - ذخیره و بارگذاری تنظیمات / Save and load configs
- 🎨 **طراحی مدرن / Modern Design** - رابط کاربری زیبا / Beautiful UI
- ⚡ **عملکرد بالا / High Performance** - بدون تاخیر و هنگ / No lag or freezing

## 📋 Requirements

- **OS**: Windows 10/11 (64-bit)
- **RAM**: 256 MB minimum
- **Disk**: 100 MB free space
- **Privileges**: Administrator rights (required for VPN tunnel creation)

## 🚀 Quick Start

### Installation

1. **Download** the latest installer from [Releases](https://github.com/OryvexClub/oryvex_vpn_demo/releases)
2. **Run** `OryvexVPN-Setup-v1.0.0.exe` as Administrator
3. **Launch** OryvexVPN from the Start Menu or Desktop shortcut
4. **Click Connect** to start secure VPN connection
5. **Enjoy** secure and private browsing

### Portable Version

Alternatively, download the portable ZIP, extract it, and run `warp_vpn_app.exe` as Administrator.

## 🛠️ Building from Source

### Prerequisites

```bash
# Install Flutter SDK 3.44+
# https://docs.flutter.dev/get-started/install/windows

# Verify installation
flutter doctor -v
```

### Build Steps

```bash
# Clone the repository
git clone https://github.com/OryvexClub/oryvex_vpn_demo.git
cd oryvex_vpn_demo

# Get dependencies
flutter pub get

# Build for Windows (Release)
flutter build windows --release

# Output: build/windows/x64/runner/Release/
```

### Building with GitHub Actions

The project includes automated CI/CD pipeline that:
- Downloads and bundles VPN binaries
- Builds the Flutter application
- Creates Windows installer with Inno Setup
- Packages portable ZIP version
- Uploads artifacts for download

Simply push to `main` branch and GitHub Actions will handle the entire build process.

## 📦 Project Structure

```
warp_vpn_app/
├── lib/
│   ├── main.dart              # Application entry point
│   ├── constants/             # App constants and strings
│   ├── core/                  # Core configuration
│   ├── l10n/                  # Localization (Persian)
│   ├── models/                # Data models
│   ├── screens/               # UI screens
│   ├── services/              # Business logic & VPN control
│   ├── theme/                 # App theming
│   ├── ui/                    # UI components
│   ├── utils/                 # Utilities and helpers
│   └── widgets/               # Reusable UI widgets
├── windows/
│   └── runner/                # Windows native code
├── installer/
│   └── installer.iss          # Inno Setup installer script
├── assets/
│   └── fonts/                 # Vazirmatn font
└── .github/
    └── workflows/
        └── build-windows.yml  # CI/CD pipeline
```

## 🏗️ Architecture

### Core Components

- **VPN Service**: Manages connection lifecycle and state
- **Network Manager**: Tracks connectivity and performance
- **System Tray**: Background operation support
- **Config Manager**: Persistent configuration storage

### Technology Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.44+ |
| Language | Dart 3.12+ |
| State Management | Provider |
| UI Components | Material Design 3 |
| Fonts | Vazirmatn (Google Fonts) |
| Installer | Inno Setup 6 |
| CI/CD | GitHub Actions |

## 🔧 VPN Configuration

The app automatically:
- Registers with Cloudflare WARP
- Selects the fastest available server
- Configures secure tunnel with optimal settings
- Monitors connection health

No manual configuration required!

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 🐛 Troubleshooting

### Common Issues

**VPN won't connect**
- Ensure the app is running as Administrator
- Check your internet connection
- Verify Windows Firewall isn't blocking the app

**"Core files not found" error**
- Download the correct build from Releases
- If building locally, ensure GitHub Actions workflow completed

**App crashes on close**
- Fixed in v1.0.0 - ensure you have the latest version

**Build fails**
- Run `flutter clean` then `flutter pub get`
- Ensure Flutter SDK is 3.44+
- Check that you're using Windows 10/11 64-bit

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - For the amazing cross-platform framework
- [Cloudflare WARP](https://developers.cloudflare.com/warp-client/) - For WARP registration API
- [Inno Setup](https://jrsoftware.org/isinfo.php) - For the installer creation tool

## 📝 Changelog

### Version 1.0.0 (2026-08-02)

#### ✅ Major Fixes
- ✅ Fixed incorrect connection status display (now shows real tunnel state)
- ✅ Fixed fake statistics - real speed, ping, and IP
- ✅ Fixed app freezing on close
- ✅ Complete Persian language support with RTL
- ✅ Full VPN configuration management
- ✅ Continuous connection monitoring
- ✅ Advanced error handling
- ✅ Automatic reconnection on connection loss

#### 🎯 Features
- Cloudflare WARP integration
- Automatic endpoint selection
- Real-time connection statistics
- System tray support
- Windows startup option
- Professional installer

#### 🔧 Technical Improvements
- Removed unused legacy code
- Cleaned up project structure
- Added comprehensive CI/CD pipeline
- Improved error handling and logging

## 📧 Support

For support and questions:
- 📧 Email: sh4es89h4es98_43678@vexomail.xyz
- 🐛 Issues: [GitHub Issues](https://github.com/OryvexClub/oryvex_vpn_demo/issues)

---

<div align="center">

**ساخته شده با ❤️ توسط تیم OryvexVPN**

**Made with ❤️ by OryvexVPN Team**

</div>
