with open("lib/services/vpn_service.dart", "r") as f:
    content = f.read()

content = content.replace("  VpnStage get stage => _stage;", "  bool _isFullTunnel = true;\n  bool get isFullTunnel => _isFullTunnel;\n\n  void toggleFullTunnel() {\n    _isFullTunnel = !_isFullTunnel;\n    notifyListeners();\n  }\n\n  VpnStage get stage => _stage;")
content = content.replace("await WireGuardService.connectWithProgress(\n      onProgress: (msg, stage) {", "await WireGuardService.connectWithProgress(\n      isFullTunnel: _isFullTunnel,\n      onProgress: (msg, stage) {")

with open("lib/services/vpn_service.dart", "w") as f:
    f.write(content)
