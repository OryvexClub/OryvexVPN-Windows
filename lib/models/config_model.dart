class ConfigModel {
  final String configText;
  final Map<String, dynamic> accountInfo;
  final String qrCode;
  const ConfigModel({required this.configText, required this.accountInfo, required this.qrCode});
  factory ConfigModel.fromJson(Map<String, dynamic> json) => ConfigModel(
    configText: json['config'] ?? '',
    accountInfo: json['account_info'] ?? {},
    qrCode: json['qr_code'] ?? '',
  );
}
class EndpointModel {
  final String ip; final String port; final int? latency; final String status; final int totalScanned;
  const EndpointModel({required this.ip, required this.port, this.latency, required this.status, required this.totalScanned});
  factory EndpointModel.fromJson(Map<String, dynamic> json) {
    final e = json['endpoint'] ?? {};
    return EndpointModel(ip: e['ip']??'', port: e['port']??'', latency: e['latency'], status: e['status']??'unknown', totalScanned: e['total_scanned']??0);
  }
}
class VPNStatus {
  final bool isConnected, isConnecting; final String message; final String? endpoint; final Map<String, dynamic>? accountInfo;
  const VPNStatus({required this.isConnected, required this.isConnecting, required this.message, this.endpoint, this.accountInfo});
  VPNStatus copyWith({bool? isConnected, bool? isConnecting, String? message, String? endpoint, Map<String, dynamic>? accountInfo}) =>
    VPNStatus(isConnected: isConnected??this.isConnected, isConnecting: isConnecting??this.isConnecting, message: message??this.message, endpoint: endpoint??this.endpoint, accountInfo: accountInfo??this.accountInfo);
}
