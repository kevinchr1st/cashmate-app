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
    return prefs.getString('access_token') ??
        prefs.getString('staff_access_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<void> _saveSession(Map<String, dynamic> data,
      {bool isStaff = false}) async {
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

    // API /auth/login dan /auth/me mengembalikan data.user dan data.business
    final user = data['user'];
    if (user is Map) {
      if (user['id'] != null) await prefs.setInt('user_id', user['id']);
      if (user['role'] != null) {
        await prefs.setString('user_role', user['role'].toString());
      }
      if (user['name'] != null) {
        await prefs.setString('saved_owner_name', user['name'].toString());
      }
      if (user['email'] != null) {
        await prefs.setString('saved_email', user['email'].toString());
      }
      if (user['profile_photo'] != null &&
          user['profile_photo'].toString().isNotEmpty) {
        await prefs.setString(
            'saved_profile_photo_path', user['profile_photo'].toString());
      }
    }

    final business = data['business'];
    if (business is Map) {
      if (business['id'] != null)
        await prefs.setInt('business_id', business['id']);
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
    await prefs.remove('saved_email');
    await prefs.remove('saved_profile_photo_path');
  }

  // Implementasi RBAC sederhana: role user yang sedang login diambil dari
  // sesi lokal ('user_role') dengan fallback ke /auth/me.
  static Future<String> currentRole() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_role');
    if (saved != null && saved.isNotEmpty) return saved.toUpperCase();

    final me = await getCurrentUser();
    if (me != null && me['user'] is Map) {
      final role = (me['user']['role'] ?? '').toString().toUpperCase();
      if (role.isNotEmpty) await prefs.setString('user_role', role);
      return role;
    }
    return 'OWNER';
  }

  // Cek apakah user yang sedang login adalah Owner
  static Future<bool> isOwner() async {
    return await currentRole() == 'OWNER';
  }

  // ---------- 🔐 Login ----------
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = body['data'];
        if (data != null) {
          final role = data['user']?['role']?.toString().toUpperCase() ?? '';
          await _saveSession(Map<String, dynamic>.from(data),
              isStaff: role == 'STAFF');
        }
        return {
          'success': true,
          'message': body['message'] ?? 'Login berhasil',
          'data': data
        };
      }
      return {
        'success': false,
        'message': body['error'] ?? body['message'] ?? 'Login gagal',
        'data': null
      };
    } catch (e) {
      debugPrint('Error login: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi ke server.',
        'data': null
      };
    }
  }

  // ---------- 🔄 Refresh Access Token ----------
  static Future<bool> refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token') ??
          prefs.getString('staff_refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
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
  // Response: { data: { user: {...}, business: {...} } }
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

      final streamed =
          await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = body['data'];
        final photoPath =
            data != null ? data['profile_photo']?.toString() : null;

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
        'message':
            body['message'] ?? body['error'] ?? 'Gagal mengunggah foto profil',
      };
    } catch (e) {
      debugPrint('Error uploadProfilePhoto: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi ke server.'
      };
    }
  }

  /// Ubah path relatif dari server menjadi URL absolut.
  static String? resolvePhotoUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final serverRoot =
        AppConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
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
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
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
        return {
          'success': true,
          'message': body['message'] ?? 'Registrasi berhasil',
          'data': body['data']
        };
      }
      return {
        'success': false,
        'message': body['error'] ?? body['message'] ?? 'Registrasi gagal',
        'data': null
      };
    } catch (e) {
      debugPrint('Error registerOwner: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi ke server.',
        'data': null
      };
    }
  }

  // ---------- 👥 Staff Management ----------

  /// Membuat Staff baru (POST /staff) — hanya Owner
  /// Sesuai kontrak Postman: { name, email, password }
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
        return {
          'success': true,
          'message': body['message'] ?? 'Staff berhasil dibuat',
          'data': body['data']
        };
      }
      return {
        'success': false,
        'message': body['error'] ?? body['message'] ?? 'Gagal membuat staff',
        'data': null
      };
    } catch (e) {
      debugPrint('Error createStaff: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi ke server.',
        'data': null
      };
    }
  }

  /// Mengambil daftar Staff (GET /staff?status=active|disabled|all) — hanya Owner
  static Future<List<Map<String, dynamic>>> fetchStaff(
      {String status = 'active'}) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/staff?status=$status'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] ?? data;
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetchStaff: $e');
      return [];
    }
  }

  /// Nonaktifkan Staff (DELETE /staff/{id}) — soft delete
  static Future<Map<String, dynamic>> disableStaff(int staffId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${AppConstants.baseUrl}/staff/$staffId'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Staff berhasil dinonaktifkan'
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menonaktifkan staff'
      };
    } catch (e) {
      debugPrint('Error disableStaff: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  /// Pulihkan Staff (POST /staff/{id}/restore) — mengembalikan akses login
  static Future<Map<String, dynamic>> restoreStaff(int staffId) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/staff/$staffId/restore'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Staff berhasil diaktifkan',
          'data': body['data']
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal memulihkan staff'
      };
    } catch (e) {
      debugPrint('Error restoreStaff: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  // ---------- 💰 Wallets ----------

  static Future<List<Map<String, dynamic>>> fetchWallets(
      {String status = 'active'}) async {
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

  static Future<Map<String, dynamic>> createWallet(
      {required String name}) async {
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
        return {
          'success': true,
          'message': body['message'] ?? 'Wallet berhasil dibuat',
          'data': body['data']
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal membuat wallet'
      };
    } catch (e) {
      debugPrint('Error createWallet: $e');
      return {'success': false, 'message': 'Terjadi kesalahan koneksi'};
    }
  }

  static Future<Map<String, dynamic>> updateWallet({
    required int walletId,
    required String name,
    String currency = 'IDR',
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConstants.baseUrl}/wallets/$walletId'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'name': name,
              'currency': currency,
            }),
          )
          .timeout(const Duration(seconds: 8));

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

  // ---------- 🏷️ Categories ----------

  static Future<List<Map<String, dynamic>>> fetchCategories(
      {String status = 'active'}) async {
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

  static Future<Map<String, dynamic>> createCategory(
      {required String name, required String type}) async {
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
        return {
          'success': true,
          'message': body['message'] ?? 'Kategori berhasil dibuat',
          'data': body['data']
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal membuat kategori'
      };
    } catch (e) {
      debugPrint('Error createCategory: $e');
      return {'success': false, 'message': 'Terjadi kesalahan koneksi'};
    }
  }

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

  /// Fetch transaksi dengan filter lengkap sesuai kontrak Postman.
  /// Owner: bisa kirim status=active|disabled|all, type, wallet_id, category_id, creator_id, from_date, to_date
  /// Staff: API mengabaikan date filter dan hanya menampilkan transaksi sendiri hari ini.
  static Future<Map<String, dynamic>> fetchTransactions({
    String? status,
    String? type,
    int? walletId,
    int? categoryId,
    int? creatorId,
    String? fromDate,
    String? toDate,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (type != null && type.isNotEmpty) params['type'] = type;
      if (walletId != null) params['wallet_id'] = walletId.toString();
      if (categoryId != null) params['category_id'] = categoryId.toString();
      if (creatorId != null) params['creator_id'] = creatorId.toString();
      if (fromDate != null && fromDate.isNotEmpty)
        params['from_date'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) params['to_date'] = toDate;

      final uri = Uri.parse('${AppConstants.baseUrl}/transactions')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return {
          'success': true,
          'data': body['data'] ?? [],
          'meta': body['meta']
        };
      }
      return {'success': false, 'message': 'Gagal mengambil transaksi'};
    } catch (e) {
      debugPrint('Error fetchTransactions: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  /// Helper: Ambil semua halaman transaksi berdasarkan metadata paginasi API.
  /// Berguna ketika filter "Semua" perlu menampilkan data lengkap > 1 halaman.
  static Future<List<Map<String, dynamic>>> fetchAllTransactions({
    String? status,
    String? type,
    int perPage = 100,
  }) async {
    final allData = <Map<String, dynamic>>[];
    int currentPage = 1;
    int lastPage = 1;

    do {
      final result = await fetchTransactions(
        status: status,
        type: type,
        page: currentPage,
        perPage: perPage,
      );
      if (result['success'] != true) break;

      final List<dynamic> pageData = result['data'] ?? [];
      allData.addAll(pageData.map((e) => Map<String, dynamic>.from(e)));

      final meta = result['meta'];
      if (meta is Map) {
        lastPage = meta['last_page'] ?? 1;
      } else {
        break;
      }
      currentPage++;
    } while (currentPage <= lastPage);

    return allData;
  }

  /// Buat Transaksi (POST /transactions)
  /// photoFile opsional: kalau diisi, dikirim sebagai multipart/form-data (field "photos")
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
      final int roundedAmount = amount.round();
      final headers = await _authHeaders();
      http.Response response;

      if (photoFile != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConstants.baseUrl}/transactions'),
        );
        request.headers
          ..addAll(headers)
          ..remove('Content-Type');

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
        request.files
            .add(await http.MultipartFile.fromPath('photos', photoFile.path));

        final streamed =
            await request.send().timeout(const Duration(seconds: 15));
        response = await http.Response.fromStream(streamed);
      } else {
        final Map<String, dynamic> payload = {
          'wallet_id': walletId,
          'category_id': categoryId,
          'amount': roundedAmount,
          'type': type,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (date != null && date.isNotEmpty) 'date': date,
        };

        response = await http
            .post(
              Uri.parse('${AppConstants.baseUrl}/transactions'),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 8));
      }

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Transaksi berhasil disimpan',
          'data': body['data']
        };
      }
      return {
        'success': false,
        'message':
            body['message'] ?? body['error'] ?? 'Gagal menyimpan transaksi'
      };
    } catch (e) {
      debugPrint('Error createTransaction: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  /// Update Transaksi (PUT /transactions/{id}) — hanya Owner
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
        'amount': amount.round(),
        'type': type,
        if (description != null) 'description': description.trim(),
        if (date != null && date.isNotEmpty) 'date': date,
      };

      final response = await http
          .put(
            Uri.parse('${AppConstants.baseUrl}/transactions/$transactionId'),
            headers: await _authHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Transaksi berhasil diperbarui',
          'data': body['data']
        };
      }
      return {
        'success': false,
        'message':
            body['message'] ?? body['error'] ?? 'Gagal memperbarui transaksi'
      };
    } catch (e) {
      debugPrint('Error updateTransaction: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  /// Void Transaksi (DELETE /transactions/{id}) — hanya Owner
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
        return {
          'success': true,
          'message': body['message'] ?? 'Transaksi dibatalkan'
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal membatalkan'
      };
    } catch (e) {
      debugPrint('Error voidTransaction: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  /// Restore Transaksi (POST /transactions/{id}/restore) — hanya Owner
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
        return {
          'success': true,
          'message': body['message'] ?? 'Transaksi dipulihkan',
          'data': body['data']
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal memulihkan'
      };
    } catch (e) {
      debugPrint('Error restoreTransaction: $e');
      return {'success': false, 'message': 'Kesalahan koneksi'};
    }
  }

  /// Hapus Foto Transaksi (DELETE /transactions/{id}/photos/{photoId})
  static Future<Map<String, dynamic>> deleteTransactionPhoto({
    required int transactionId,
    required int photoId,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse(
                '${AppConstants.baseUrl}/transactions/$transactionId/photos/$photoId'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': body['message'] ?? 'Foto transaksi berhasil dihapus'
        };
      }
      return {
        'success': false,
        'message':
            body['message'] ?? body['error'] ?? 'Gagal menghapus foto transaksi'
      };
    } catch (e) {
      debugPrint('Error deleteTransactionPhoto: $e');
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

  /// GET /reports/monthly?year=YYYY — mengembalikan 12 bulan
  /// Setiap entri: { month, income, expense, net_cashflow }
  static Future<List<Map<String, dynamic>>> getMonthlyReport(
      {required int year}) async {
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

  // ---------- 🔐 Session Helpers ----------

  static Future<bool> ensureValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    if (accessToken == null || accessToken.isEmpty) return false;

    final me = await getCurrentUser();
    return me != null;
  }
}
