class Category {
  final int id;
  final String name;
  final String type; // 'income' atau 'expense'

  Category({
    required this.id,
    required this.name,
    required this.type,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      // decode HTML entity, misal "&amp;" jadi "&"
      name: (json['name'] ?? '')
          .toString()
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>'),
      type: json['type'] ?? 'income',
    );
  }
}