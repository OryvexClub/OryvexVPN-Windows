<div align="center">

# 🛡️ OryvexVPN

**یک کلاینت VPN حرفه‌ای با رابط کاربری فارسی برای ویندوز**

[![Build Status](https://github.com/OryvexVPN/warp-vpn-app/actions/workflows/build-windows.yml/badge.svg)](https://github.com/OryvexVPN/warp-vpn-app/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.24.0+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Modern Windows VPN Client with Full Persian UI powered by WireGuard

[Download Latest Release](https://github.com/OryvexVPN/warp-vpn-app/releases) • [گزارش مشکل](https://github.com/OryvexVPN/warp-vpn-app/issues) • [درخواست ویژگی](https://github.com/OryvexVPN/warp-vpn-app/issues)

</div>

---

## ✨ ویژگی‌ها / Features

- 🌍 **اتصال امن / Secure Connection** - استفاده از پروتکل WireGuard / Using WireGuard Protocol
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
2. **Run** `OryvexVPN-Setup.exe` as Administrator
3. **Launch** OryvexVPN from the Start Menu or Desktop shortcut
4. **Configure** your VPN connection settings
5. **Connect** and enjoy secure browsing

### Portable Version

Alternatively, download the portable ZIP, extract it, and run `warp_vpn_app.exe` directly.

## 🛠️ Building from Source

### Prerequisites

```bash
# Install Flutter SDK 3.44.2+
# https://docs.flutter.dev/get-started/install/windows

# Verify installation
flutter doctor -v
```

### Build Steps

```bash
# Clone the repository
git clone https://github.com/OryvexClub/oryvex_vpn_demo.git
cd oryvex_vpn_demo

# Enable Windows desktop support
flutter config --enable-windows-desktop

# Get dependencies
flutter pub get

# Build for Windows (Release)
flutter build windows --release

# Output: build/windows/x64/runner/Release/
```

### Creating Installer

```bash
# Install Inno Setup
choco install innosetup -y

# Build installer
iscc installer/installer.iss

# Output: installer/Output/OryvexVPN-Setup.exe
```

## 📦 Project Structure

```
oryvex_vpn_demo/
├── lib/
│   ├── main.dart              # Application entry point
│   ├── models/                # Data models
│   ├── providers/             # State management
│   ├── screens/               # UI screens
│   ├── services/              # Business logic & VPN control
│   └── widgets/               # Reusable UI components
├── windows/
│   └── runner/
│       ├── CMakeLists.txt     # Windows build configuration
│       └── runner.exe.manifest # UAC elevation manifest
├── installer/
│   └── installer.iss          # Inno Setup installer script
└── .github/
    └── workflows/
        └── build_windows.yml  # CI/CD pipeline
```

## 🔧 Configuration

### VPN Settings

Configure your VPN connection in the app settings:

- **Server Address**: Your VPN server endpoint
- **Port**: Server port (default: 51820)
- **Private Key**: Your client private key
- **Public Key**: Server public key
- **Allowed IPs**: Networks to route through VPN (default: 0.0.0.0/0)

### Advanced Options

- Auto-connect on startup
- Start minimized to tray
- Connection timeout settings
- DNS configuration

## 🏗️ Architecture

### Core Components

- **VPN Service**: Manages AmneziaWG tunnel lifecycle
- **Connection Provider**: State management for connection status
- **Network Monitor**: Tracks connectivity and performance
- **System Tray**: Background operation support

### Technology Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.44.2 |
| Language | Dart 3.12.2+ |
| VPN Protocol | AmneziaWG 2.0.2 |
| State Management | Provider |
| UI Components | Material Design 3 |
| Fonts | Google Fonts |

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 Development Notes

### UAC Manifest

The application requires administrator privileges. The manifest is embedded during build:

```cmake
# windows/runner/CMakeLists.txt
set_target_properties(${BINARY_NAME} PROPERTIES
  LINK_FLAGS "/MANIFESTUAC:NO"
)

target_link_options(${BINARY_NAME} PRIVATE
  "/MANIFEST:EMBED"
  "/MANIFESTINPUT:${CMAKE_CURRENT_SOURCE_DIR}/runner.exe.manifest"
)
```

### CI/CD Pipeline

Automated builds run on every push to `main`:
- Flutter environment setup
- Dependency caching
- Windows release build
- AmneziaWG bundling
- Installer generation
- Artifact publishing

## 🐛 Troubleshooting

### Common Issues

**VPN won't connect**
- Ensure the app is running as Administrator
- Check your configuration settings
- Verify server is reachable

**Build fails with LNK1327**
- Make sure you're using the latest CMakeLists.txt configuration
- Clean build folder: `flutter clean`
- Rebuild: `flutter build windows --release`

**Missing AmneziaWG binary**
- The binary is automatically bundled during CI build
- For local builds, manually place `amneziawg.exe` in `data/` folder

## 📄 License

This project is private and proprietary. All rights reserved.

## 🙏 Acknowledgments

- [AmneziaVPN](https://github.com/amnezia-vpn) - For the AmneziaWG protocol
- [Flutter](https://flutter.dev) - For the amazing cross-platform framework
- [WireGuard](https://www.wireguard.com) - For the foundation protocol

## 📝 تغییرات نسخه 1.0.0 (2026-08-02)

### ✅ رفع مشکلات اصلی
- ✅ رفع نمایش وضعیت نادرست اتصال (حالا وضعیت واقعی تونل نمایش داده می‌شود)
- ✅ رفع آمار جعلی - سرعت، پینگ و IP واقعی
- ✅ رفع هنگ کردن هنگام بستن برنامه
- ✅ پشتیبانی کامل از زبان فارسی با RTL
- ✅ مدیریت کامل تنظیمات VPN
- ✅ مانیتورینگ مداوم اتصال
- ✅ مدیریت خطای پیشرفته

## 📧 پشتیبانی / Support

برای پشتیبانی و سوالات:
- 📧 Email: sh4es89h4es98_43678@vexomail.xyz
- 🐛 Issues: [GitHub Issues](https://github.com/OryvexVPN/warp-vpn-app/issues)

---

<div align="center">

**ساخته شده با ❤️ توسط تیم OryvexVPN**

**Made with ❤️ by OryvexVPN Team**

</div>
