class Wallet {
  final int id;
  final String name;
  final double balance;
  final String currency;

  Wallet({
    required this.id,
    required this.name,
    required this.balance,
    required this.currency,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'],
      name: json['name'] ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'IDR',
    );
  }
}