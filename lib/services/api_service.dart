import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  // ---------- Helper Token & Header ----------

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? prefs.getString('staff_access_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<void> _saveSession(Map<String, dynamic> data, {bool isStaff = false}) async {
    final prefs = await SharedPreferences.getInstance();

    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];

    if (accessToken != null) {
      if (isStaff) {
        await prefs.setString('staff_access_token', accessToken);
      } else {
        await prefs.setString('access_token', accessToken);
      }
    }

    if (refreshToken != null) {
      if (isStaff) {
        await prefs.setString('staff_refresh_token', refreshToken);
      } else {
        await prefs.setString('refresh_token', refreshToken);
      }
    }

    final user = data['user'];
    if (user is Map) {
      if (user['id'] != null) await prefs.setInt('user_id', user['id']);
      if (user['role'] != null) {
        await prefs.setString('user_role', user['role'].toString());
      }
      if (user['name'] != null) {
        await prefs.setString('saved_owner_name', user['name'].toString());
      }
      if (user['profile_photo'] != null && user['profile_photo'].toString().isNotEmpty) {
        await prefs.setString('saved_profile_photo_path', user['profile_photo'].toString());
      }
    }

    final business = data['business'];
    if (business is Map) {
      if (business['id'] != null) await prefs.setInt('business_id', business['id']);
      if (business['name'] != null) {
        await prefs.setString('saved_store_name', business['name'].toString());
      }
    }
  }

  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('staff_access_token');
    await prefs.remove('staff_refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('business_id');
    await prefs.remove('saved_owner_name');
    await prefs.remove('saved_store_name');
    await prefs.remove('saved_profile_photo_path');
  }

  // Cek apakah user yang sedang login adalah Owner
  static Future<bool> isOwner() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    if (role != null) return role.toUpperCase() == 'OWNER';

    // Fallback cek ke /auth/me jika role di prefs belum ada
    final me = await getCurrentUser();
    if (me != null && me['user'] is Map) {
      return (me['user']['role'] ?? '').toString().toUpperCase() == 'OWNER';
    }
    return true; // Default aman
  }

  // ---------- 🔐 Login ----------
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = body['data'];
        if (data != null) {
          final role = data['user']?['role']?.toString().toUpperCase() ?? '';
          await _saveSession(Map<String, dynamic>.from(data), isStaff: role == 'STAFF');
        }
        return {'success': true, 'message': body['message'] ?? 'Login berhasil', 'data': data};
      }
      return {'success': false, 'message': body['error'] ?? body['message'] ?? 'Login gagal', 'data': null};
    } catch (e) {
      debugPrint('Error login: $e');
      return {'success': false, 'message': 'Terjadi kesalahan koneksi ke server.', 'data': null};
    }
  }

  // ---------- 🔄 Refresh Access Token ----------
  static Future<bool> refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token') ?? prefs.getString('staff_refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        final newAccessToken = data != null ? data['access_token'] : null;
        if (newAccessToken != null) {
          await prefs.setString('access_token', newAccessToken);
          if (data['refresh_token'] != null) {
            await prefs.setString('refresh_token', data['refresh_token']);
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error refreshAccessToken: $e');
      return false;
    }
  }

  // ---------- 🙋 Current User (GET /auth/me) ----------
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final response = await http
          .get(
        Uri.parse('${AppConstants.baseUrl}/auth/me'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      }
    } catch (e) {
      debugPrint('Error getCurrentUser: $e');
    }
    return null;
  }

  // ---------- 🖼️ Upload Foto Profil (PUT /auth/me/photo) ----------
  // Sesuai Postman: multipart/form-data, field name = "photo".
  // Server menyimpan file lalu mengembalikan path relatif, contoh:
  // "/uploads/avatars/1/ab12cd34.jpg"
  static Future<Map<String, dynamic>> uploadProfilePhoto(File photoFile) async {
    try {
      final token = await _getAccessToken();
      final uri = Uri.parse('${AppConstants.baseUrl}/auth/me/photo');
      final request = http.MultipartRequest('PUT', uri)
        ..headers['Accept'] = 'application/json'
        ..files.add(await http.MultipartFile.fromPath('photo', photoFile.path));

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = body['data'];
        final photoPath = data != null ? data['profile_photo']?.toString() : null;

        // Simpan path foto ke lokal supaya tetap tampil setelah app dibuka ulang
        if (photoPath != null && photoPath.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_profile_photo_path', photoPath);
        }

        return {
          'success': true,
          'message': body['message'] ?? 'Foto profil berhasil diperbarui',
          'photo_url': resolvePhotoUrl(photoPath),
          'data': data,
        };
      }

      return {
        'success': false,
        'message': body['message'] ?? body['error'] ?? 'Gagal mengunggah foto profil',
      };
    } catch (e) {
      debugPrint('Error uploadProfilePhoto: $e');
      return {'success': false, 'message': 'Terjadi kesalahan koneksi ke server.'};
    }
  }

  /// Ubah path relatif dari server (mis. "/uploads/avatars/1/ab12cd34.jpg")
  /// menjadi URL absolut yang bisa dipakai NetworkImage.
  /// baseUrl biasanya berbentuk "http://VPS_IP:PORT/api", jadi "/api" perlu
  /// dibuang supaya path statis /uploads/... mengarah ke root server.
  static String? resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final serverRoot = AppConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return path.startsWith('/') ? '$serverRoot$path' : '$serverRoot/$path';
  }

  // ---------- 🚪 Logout (POST /auth/logout) ----------
  static Future<bool> logout() async {
    bool serverOk = false;
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/auth/logout'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      serverOk = response.statusCode == 200;
    } catch (e) {
      debugPrint('Error logout: $e');
    } finally {
      await _clearSession();
    }
    return serverOk;
  }

  // ---------- 📝 Register Owner + Business (POST /auth/register) ----------
  static Future<Map<String, dynamic>> registerOwner({
    required String name,
    required String email,
    required String password,
    required String businessName,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'business_name': businessName,
          'name': name,
          'email': email,
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Registrasi berhasil', 'data': body['data']};
      }
      return {'success': false, 'message': body['error'] ?? body['message'] ?? 'Registrasi gagal', 'data': null};
    } catch (e) {
      debugPrint('Error registerOwner: $e');
      return {'success': false, 'message': 'Terjadi kesalahan koneksi ke server.', 'data': null};
    }
  }

  // ---------- 📝 Create Staff (POST /staff - oleh Owner) ----------
  static Future<Map<String, dynamic>> createStaff({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/staff'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Staff berhasil dibuat', 'data': body['data']};
      }
      return {'success': false, 'message': body['error'] ?? body['message'] ?? 'Gagal membuat staff', 'data': null};
    } catch (e) {
      debugPrint('Error createStaff: $e');
      return {'success': false, 'message': 'Terjadi kesalahan koneksi ke server.', 'data': null};
    }
  }

  // ---------- 💰 Wallets (GET /wallets) ----------
  static Future<List<Map<String, dynamic>>> fetchWallets({String status = 'active'}) async {
    try {
      final response = await http
          .get(
        Uri.parse('${AppConstants.baseUrl}/wallets?status=$status'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetchWallets: $e');
    }
    return [];
  }

  // Membuat Wallet baru (POST /wallets)
  static Future<Map<String, dynamic>> createWallet({required String name}) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/wallets'),
        headers: await _authHeaders(),
        body: jsonEncode({'name': name}),
      )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Wallet berhasil dibuat', 'data': body['data']};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal membuat wallet'};
    } catch (e) {
      debugPrint('Error createWallet: $e');
      return {'success': false, 'message': 'Terjadi kesalahan koneksi'};
    }
  }

  // Nonaktifkan Wallet (DELETE /wallets/{id})
  static Future<bool> disableWallet(int id) async {
    try {
      final response = await http
          .delete(
        Uri.parse('${AppConstants.baseUrl}/wallets/$id'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error disableWallet: $e');
      return false;
    }
  }

  // Pulihkan Wallet (POST /wallets/{id}/restore)
  static Future<bool> restoreWallet(int id) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/wallets/$id/restore'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error restoreWallet: $e');
      return false;
    }
  }

  // ---------- 🏷️ Categories (GET /categories) ----------
  static Future<List<Map<String, dynamic>>> fetchCategories({String status = 'active'}) async {
    try {
      final response = await http
          .get(
        Uri.parse('${AppConstants.baseUrl}/categories?status=$status'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetchCategories: $e');
    }
    return [];
  }

  // Membuat Kategori (POST /categories)
  static Future<Map<String, dynamic>> createCategory({required String name, required String type}) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/categories'),
        headers: await _authHeaders(),
        body: jsonEncode({'name': name, 'type': type}),
      )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Kategori berhasil dibuat', 'data': body['data']};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal membuat kategori'};
    } catch (e) {
      debugPrint('Error createCategory: $e');
      return {'success': false, 'message': 'Terjadi kesalahan koneksi'};
    }
  }

  // Nonaktifkan Kategori (DELETE /categories/{id})
  static Future<bool> disableCategory(int id) async {
    try {
      final response = await http
          .delete(
        Uri.parse('${AppConstants.baseUrl}/categories/$id'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error disableCategory: $e');
      return false;
    }
  }

  // Pulihkan Kategori (POST /categories/{id}/restore)
  static Future<bool> restoreCategory(int id) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/categories/$id/restore'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error restoreCategory: $e');
      return false;
    }
  }

  // ---------- 📄 Transactions ----------
  static Future<Map<String, dynamic>> fetchTransactions({
    String? type,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      String url = '${AppConstants.baseUrl}/transactions?page=$page&per_page=$perPage';
      if (type != null && type.isNotEmpty) {
        url += '&type=$type';
      }

      final response = await http
          .get(Uri.parse(url), headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {'success': true, 'data': body['data'] ?? [], 'meta': body['meta']};
      }
      return {'success': false, 'message': 'Gagal mengambil transaksi'};
    } catch (e) {
      debugPrint('Error fetchTransactions: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  // Buat Transaksi (POST /transactions)
  // photoFile opsional: kalau diisi, dikirim sebagai multipart/form-data (field "photos"),
  // persis sesuai contoh "Create Owner Expense with Photo" di Postman collection.
  static Future<Map<String, dynamic>> createTransaction({
    required int walletId,
    required int categoryId,
    required double amount,
    required String type,
    String? description,
    String? date,
    File? photoFile,
  }) async {
    try {
      final int roundedAmount = amount.round(); // Kirim sebagai integer murni (tanpa .0), sesuai kontrak Postman
      final headers = await _authHeaders();
      http.Response response;

      if (photoFile != null) {
        // Ada foto -> wajib multipart/form-data (JSON tidak bisa membawa file biner)
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConstants.baseUrl}/transactions'),
        );
        request.headers
          ..addAll(headers)
          ..remove('Content-Type'); // biarkan http yang set boundary multipart-nya sendiri

        request.fields['wallet_id'] = walletId.toString();
        request.fields['category_id'] = categoryId.toString();
        request.fields['amount'] = roundedAmount.toString();
        request.fields['type'] = type;
        if (description != null && description.trim().isNotEmpty) {
          request.fields['description'] = description.trim();
        }
        if (date != null && date.isNotEmpty) {
          request.fields['date'] = date;
        }
        request.files.add(await http.MultipartFile.fromPath('photos', photoFile.path));

        debugPrint('Payload Create Transaction (multipart): ${request.fields}, foto: ${photoFile.path}');

        final streamed = await request.send().timeout(const Duration(seconds: 15));
        response = await http.Response.fromStream(streamed);
      } else {
        final Map<String, dynamic> payload = {
          'wallet_id': walletId,
          'category_id': categoryId,
          'amount': roundedAmount,
          'type': type,     // 'income' atau 'expense'
          if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
          if (date != null && date.isNotEmpty) 'date': date,
        };

        debugPrint('Payload Create Transaction: ${jsonEncode(payload)}'); // Untuk debugging di logcat

        response = await http
            .post(
          Uri.parse('${AppConstants.baseUrl}/transactions'),
          headers: headers,
          body: jsonEncode(payload),
        )
            .timeout(const Duration(seconds: 8));
      }

      debugPrint('Create Transaction Response (${response.statusCode}): ${response.body}'); // sementara untuk debugging foto

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Transaksi berhasil disimpan', 'data': body['data']};
      }
      return {'success': false, 'message': body['message'] ?? body['error'] ?? 'Gagal menyimpan transaksi'};
    } catch (e) {
      debugPrint('Error createTransaction: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  // Update Transaksi (PUT /transactions/{id})
  static Future<Map<String, dynamic>> updateTransaction({
    required int transactionId,
    required int walletId,
    required int categoryId,
    required double amount,
    required String type,
    String? description,
    String? date,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'wallet_id': walletId,
        'category_id': categoryId,
        'amount': amount.round(), // Kirim sebagai integer murni (tanpa .0), sesuai kontrak Postman
        'type': type,
        if (description != null) 'description': description.trim(),
        if (date != null && date.isNotEmpty) 'date': date,
      };

      debugPrint('Payload Update Transaction: ${jsonEncode(payload)}'); // Untuk debugging di logcat

      final response = await http
          .put(
        Uri.parse('${AppConstants.baseUrl}/transactions/$transactionId'),
        headers: await _authHeaders(),
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Transaksi berhasil diperbarui', 'data': body['data']};
      }
      return {'success': false, 'message': body['message'] ?? body['error'] ?? 'Gagal memperbarui transaksi'};
    } catch (e) {
      debugPrint('Error updateTransaction: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  // Void Transaksi (DELETE /transactions/{id})
  static Future<Map<String, dynamic>> voidTransaction(int id) async {
    try {
      final response = await http
          .delete(
        Uri.parse('${AppConstants.baseUrl}/transactions/$id'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Transaksi dibatalkan'};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal membatalkan'};
    } catch (e) {
      debugPrint('Error voidTransaction: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  // Hapus Foto Transaksi (DELETE /transactions/{id}/photos/{photoId})
  static Future<Map<String, dynamic>> deleteTransactionPhoto({
    required int transactionId,
    required int photoId,
  }) async {
    try {
      final response = await http
          .delete(
        Uri.parse('${AppConstants.baseUrl}/transactions/$transactionId/photos/$photoId'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Foto transaksi berhasil dihapus'};
      }
      return {'success': false, 'message': body['message'] ?? body['error'] ?? 'Gagal menghapus foto transaksi'};
    } catch (e) {
      debugPrint('Error deleteTransactionPhoto: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  // Restore Transaksi (POST /transactions/{id}/restore)
  static Future<Map<String, dynamic>> restoreTransaction(int id) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/transactions/$id/restore'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message'] ?? 'Transaksi dipulihkan'};
      }
      return {'success': false, 'message': body['message'] ?? 'Gagal memulihkan'};
    } catch (e) {
      debugPrint('Error restoreTransaction: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  // ---------- 📊 Dashboard & Reports ----------
  static Future<Map<String, dynamic>?> getDashboardSummary() async {
    try {
      final response = await http
          .get(
        Uri.parse('${AppConstants.baseUrl}/dashboard/summary'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      }
    } catch (e) {
      debugPrint('Error getDashboardSummary: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getMonthlyReport({required int year}) async {
    try {
      final response = await http
          .get(
        Uri.parse('${AppConstants.baseUrl}/reports/monthly?year=$year'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error getMonthlyReport: $e');
    }
    return [];
  }

  // ---------- 👥 Staff Approval ----------


  static Future<bool> approveStaff(int staffId) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/staff/$staffId/approve'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error approveStaff: $e');
      return false;
    }
  }

  // ---------- 👤 Profile ----------
  static Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final response = await http
          .get(
        Uri.parse('${AppConstants.baseUrl}/profile'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (e) {
      debugPrint('Error fetch profile: $e');
    }
    return null;
  }

  static Future<bool> updateProfile(Map<String, dynamic> body) async {
    try {
      final response = await http
          .put(
        Uri.parse('${AppConstants.baseUrl}/profile'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error update profile: $e');
      return false;
    }
  }

  static Future<bool> ensureValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    if (accessToken == null || accessToken.isEmpty) return false;

    final me = await getCurrentUser();
    return me != null;
  }

  static Future<List<Map<String, dynamic>>> fetchPendingStaff() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/staff'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] ?? data;
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      return [];
    }
  }
  /// Memperbarui nama atau detail kantong/wallet (PUT /wallets/{id})
  static Future<Map<String, dynamic>> updateWallet({
    required int walletId,
    required String name,
    String currency = 'IDR',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/wallets/$walletId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'currency': currency,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data['data'] ?? data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal memperbarui kantong.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<bool> rejectStaff(int staffId) async {
    try {
      final response = await http
          .post(
        Uri.parse('${AppConstants.baseUrl}/staff/$staffId/reject'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error rejectStaff: $e');
      return false;
    }
  }

  // ---------- 🔔 Activities ----------
  static Future<List<dynamic>> fetchRecentActivities() async {
    try {
      final response = await http
          .get(
        Uri.parse('${AppConstants.baseUrl}/activities/recent'),
        headers: await _authHeaders(),
      )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetch activities: $e');
    }
    return [];
  }
}