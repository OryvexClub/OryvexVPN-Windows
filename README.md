<div align="center">

# 🛡️ OryvexVPN

**Modern Windows VPN Client powered by AmneziaWG**

[![Build Status](https://github.com/OryvexClub/oryvex_vpn_demo/actions/workflows/build_windows.yml/badge.svg)](https://github.com/OryvexClub/oryvex_vpn_demo/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.2-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-Private-red)]()

A beautiful, modern VPN client built with Flutter for Windows, featuring AmneziaWG integration and advanced connection management.

[Download Latest Release](https://github.com/OryvexClub/oryvex_vpn_demo/releases) • [Report Bug](https://github.com/OryvexClub/oryvex_vpn_demo/issues) • [Request Feature](https://github.com/OryvexClub/oryvex_vpn_demo/issues)

</div>

---

## ✨ Features

- 🚀 **Fast & Secure** - Powered by AmneziaWG protocol
- 🎨 **Modern UI** - Clean, intuitive interface built with Flutter
- 🔐 **Admin Privileges** - Runs with elevated permissions for tunnel management
- 📡 **Connection Monitor** - Real-time connection status and network monitoring
- ⚙️ **Easy Configuration** - Simple settings management
- 🪟 **System Tray** - Minimizes to tray for background operation
- 🎯 **Auto-Connect** - Optional automatic connection on startup
- 📊 **Connection Stats** - Monitor your VPN usage and performance

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

## 📧 Support

For support and inquiries:
- 📧 Email: sh4es89h4es98_43678@vexomail.xyz
- 🐛 Issues: [GitHub Issues](https://github.com/OryvexClub/oryvex_vpn_demo/issues)

---

<div align="center">

**Made with ❤️ by OryvexVPN Team**

[Website](https://oryvex.com) • [Documentation](https://docs.oryvex.com) • [Community](https://community.oryvex.com)

</div>
