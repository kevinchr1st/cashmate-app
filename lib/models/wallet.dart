class Wallet {
  final int id;
  final int businessId;
  final String name;
  final double balance;
  final String currency;
  final String? deletedAt;

  Wallet({
    required this.id,
    required this.businessId,
    required this.name,
    required this.balance,
    this.currency = 'IDR',
    this.deletedAt,
  });

  bool get isDisabled => deletedAt != null && deletedAt!.isNotEmpty;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      businessId: json['business_id'] is int ? json['business_id'] : int.tryParse(json['business_id'].toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] ?? 'IDR').toString(),
      deletedAt: json['deleted_at']?.toString(),
    );
  }
}