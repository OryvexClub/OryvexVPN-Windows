import 'dart:io';

void main() {
  final file = File('lib/services/system_check_service.dart');
  var content = file.readAsStringSync();
  
  final badString = '''    final procs = ['wg.exe', 'amneziawg.exe', 'awg.exe', 'wireservice.exe', 'v2ray.exe', 'xray.exe', 'nekoray.exe', 'v2raya.exe'];''';
  
  final goodString = '''    final procs = [
      'wg.exe', 'amneziawg.exe', 'awg.exe', 'wireservice.exe', 'wireguard.exe',
      'v2ray.exe', 'xray.exe', 'v2rayn.exe', 'nekoray.exe', 'nekobox.exe',
      'clash.exe', 'clash-verge.exe', 'clash for windows.exe', 'clash-meta.exe',
      'hiddify.exe', 'hiddify-next.exe', 'outline.exe', 'shadowsocks.exe', 
      'psiphon3.exe', 'qv2ray.exe', 'v2raya.exe', 'sing-box.exe', 
      'openvpn.exe', 'openvpn-gui.exe', 'cfon.exe', 'lantern.exe', 
      'geph-client.exe', 'gephgui.exe', 'freegate.exe', 'v2ray-core.exe',
      'xray-core.exe', 'tun2socks.exe'
    ];''';

  content = content.replaceFirst(badString, goodString);
  file.writeAsStringSync(content);
}
