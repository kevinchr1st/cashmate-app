import '../utils/string_utils.dart';

/// Model transaksi yang sesuai kontrak API Postman.
/// Parse semua field dari response: id, business_id, wallet_id, category_id,
/// created_by_user_id, amount, type, description, date, timestamps,
/// dan nested wallet, category, created_by, photos.
class Transaction {
  final int id;
  final int businessId;
  final int walletId;
  final int categoryId;
  final int createdByUserId;
  final double amount;
  final String type; // 'income' atau 'expense'
  final String description;
  final String date; // YYYY-MM-DD dari server
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  // Nested objects dari API response
  final TransactionWallet? wallet;
  final TransactionCategory? category;
  final TransactionCreator? createdBy;
  final List<TransactionPhoto> photos;

  Transaction({
    required this.id,
    required this.businessId,
    required this.walletId,
    required this.categoryId,
    required this.createdByUserId,
    required this.amount,
    required this.type,
    this.description = '',
    required this.date,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.wallet,
    this.category,
    this.createdBy,
    this.photos = const [],
  });

  /// True jika transaksi sudah di-void (soft-deleted)
  bool get isVoid => deletedAt != null && deletedAt!.isNotEmpty;

  /// Tanggal sebagai DateTime; fallback ke now jika parse gagal
  DateTime get dateTime {
    final parsed = DateTime.tryParse(date);
    if (parsed != null) return parsed;
    if (createdAt != null) {
      final fallback = DateTime.tryParse(createdAt!);
      if (fallback != null) return fallback;
    }
    return DateTime.now();
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Parse nested wallet
    TransactionWallet? wallet;
    if (json['wallet'] is Map) {
      wallet =
          TransactionWallet.fromJson(Map<String, dynamic>.from(json['wallet']));
    }

    // Parse nested category
    TransactionCategory? category;
    if (json['category'] is Map) {
      category = TransactionCategory.fromJson(
          Map<String, dynamic>.from(json['category']));
    }

    // Parse nested created_by
    TransactionCreator? createdBy;
    if (json['created_by'] is Map) {
      createdBy = TransactionCreator.fromJson(
          Map<String, dynamic>.from(json['created_by']));
    }

    // Parse photos array
    List<TransactionPhoto> photos = [];
    if (json['photos'] is List) {
      photos = (json['photos'] as List)
          .where((p) => p is Map)
          .map((p) => TransactionPhoto.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }

    return Transaction(
      id: _parseInt(json['id']),
      businessId: _parseInt(json['business_id']),
      walletId: _parseInt(json['wallet_id']),
      categoryId: _parseInt(json['category_id']),
      createdByUserId: _parseInt(json['created_by_user_id']),
      amount: _parseDouble(json['amount']),
      type: (json['type'] ?? 'income').toString(),
      description: (json['description'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
      wallet: wallet,
      category: category,
      createdBy: createdBy,
      photos: photos,
    );
  }

  /// Nama tampilan: deskripsi > kategori > fallback.
  /// Teks dari API di-decode entitas HTML-nya (&gt; → >) agar judul bersih.
  String get displayTitle {
    if (description.trim().isNotEmpty) return htmlUnescape(description.trim());
    if (category != null && category!.name.isNotEmpty) {
      final prefix = type == 'income' ? 'Pemasukan' : 'Pengeluaran';
      return '$prefix • ${htmlUnescape(category!.name)}';
    }
    return 'Transaksi Tanpa Keterangan';
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

/// Nested wallet info di dalam response transaksi (tanpa balance untuk Staff)
class TransactionWallet {
  final int id;
  final int businessId;
  final String name;
  final String currency;
  final double? balance; // Hanya ada untuk Owner

  TransactionWallet({
    required this.id,
    required this.businessId,
    required this.name,
    this.currency = 'IDR',
    this.balance,
  });

  factory TransactionWallet.fromJson(Map<String, dynamic> json) {
    return TransactionWallet(
      id: Transaction._parseInt(json['id']),
      businessId: Transaction._parseInt(json['business_id']),
      name: (json['name'] ?? '').toString(),
      currency: (json['currency'] ?? 'IDR').toString(),
      balance: json['balance'] != null
          ? Transaction._parseDouble(json['balance'])
          : null,
    );
  }
}

/// Nested category info di dalam response transaksi
class TransactionCategory {
  final int id;
  final int? businessId;
  final String name;
  final String type;

  TransactionCategory({
    required this.id,
    this.businessId,
    required this.name,
    required this.type,
  });

  factory TransactionCategory.fromJson(Map<String, dynamic> json) {
    return TransactionCategory(
      id: Transaction._parseInt(json['id']),
      businessId: json['business_id'] != null
          ? Transaction._parseInt(json['business_id'])
          : null,
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'income').toString(),
    );
  }
}

/// Nested creator info di dalam response transaksi
class TransactionCreator {
  final int id;
  final String name;
  final String role;
  final String? profilePhoto;

  TransactionCreator({
    required this.id,
    required this.name,
    required this.role,
    this.profilePhoto,
  });

  factory TransactionCreator.fromJson(Map<String, dynamic> json) {
    return TransactionCreator(
      id: Transaction._parseInt(json['id']),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      profilePhoto: json['profile_photo']?.toString(),
    );
  }
}

/// Foto yang dilampirkan ke transaksi
class TransactionPhoto {
  final int id;
  final String url;

  TransactionPhoto({required this.id, required this.url});

  factory TransactionPhoto.fromJson(Map<String, dynamic> json) {
    return TransactionPhoto(
      id: Transaction._parseInt(json['id']),
      url: (json['url'] ?? '').toString(),
    );
  }
}
