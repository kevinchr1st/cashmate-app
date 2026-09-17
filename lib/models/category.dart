class Category {
  final int id;
  final int? businessId;
  final String name;
  final String type; // 'income' atau 'expense'
  final String? deletedAt;

  Category({
    required this.id,
    this.businessId,
    required this.name,
    required this.type,
    this.deletedAt,
  });

  bool get isDisabled => deletedAt != null && deletedAt!.isNotEmpty;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      businessId: json['business_id'] != null
          ? (json['business_id'] is int ? json['business_id'] : int.tryParse(json['business_id'].toString()))
          : null,
      // decode HTML entity, misal "&amp;" jadi "&"
      name: (json['name'] ?? '')
          .toString()
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>'),
      type: (json['type'] ?? 'income').toString(),
      deletedAt: json['deleted_at']?.toString(),
    );
  }
}