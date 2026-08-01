class AccountInfo {
  final String accountId;
  final String deviceId;
  final String accountType;
  final String? created;
  final bool isWarpPlus;

  const AccountInfo({
    required this.accountId,
    required this.deviceId,
    required this.accountType,
    this.created,
    this.isWarpPlus = false,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    final acc = json['account'] ?? {};
    final warpPlus = acc['warp_plus'] ?? false;
    return AccountInfo(
      accountId: acc['id'] ?? '-',
      deviceId: json['id'] ?? '-',
      accountType: '${warpPlus ? 'WARP+ ' : ''}${acc['account_type'] ?? 'free'}',
      created: json['created'],
      isWarpPlus: warpPlus,
    );
  }
}
