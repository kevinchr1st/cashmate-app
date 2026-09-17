class Transaction {
  final int? id;
  final String title;
  final double amount;
  final String type;
  final int userId;
  final DateTime date;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.userId,
    required this.date,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] ?? 'Cash In',
      userId: json['user_id'] ?? 1,
      date: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "amount": amount,
      "type": type,
      "category_id": 1,
      "wallet_id": 1,
      "user_id": userId,
    };
  }
}