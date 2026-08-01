class Endpoint {
  final String ip;
  final String port;
  final int? latency;
  final bool isActive;

  const Endpoint({
    required this.ip,
    required this.port,
    this.latency,
    this.isActive = true,
  });

  factory Endpoint.fromJson(Map<String, dynamic> json) => Endpoint(
        ip: json['ip'] ?? '',
        port: json['port'] ?? '2408',
        latency: json['latency'],
        isActive: json['isActive'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'port': port,
        'latency': latency,
        'isActive': isActive,
      };

  String get endpointString => '$ip:$port';
}
