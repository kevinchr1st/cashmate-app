import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isObscure = true;
  bool rememberMe = false;
  bool isLoading = false; // Status untuk animasi melingkar (loading)

  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkRememberedUserAndBiometric();
  }

  // Menentukan tujuan navigasi berdasarkan role yang tersimpan (diisi oleh
  // ApiService.login()). Owner -> '/main' (owner_navigation_page.dart),
  // Staff -> '/staff-main' (staff_navigation_page.dart -> kasir_page.dart).
  String _homeRouteForRole(String? role) {
    return (role ?? '').toUpperCase() == 'STAFF' ? '/staff-main' : '/main';
  }

  Future<void> _checkRememberedUserAndBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    bool isRemembered = prefs.getBool('is_remembered') ?? false;
    bool isBiometricOn = prefs.getBool('is_biometric_enabled') ?? false;

    if (isRemembered) {
      String savedEmail = prefs.getString('saved_email') ?? '';
      emailController.text = savedEmail;
      setState(() => rememberMe = true);

      if (isBiometricOn) {
        try {
          bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
          if (canCheck) {
            bool didAuthenticate = await auth.authenticate(
              localizedReason: 'Gunakan sidik jari untuk masuk otomatis ke CashMate',
              options: const AuthenticationOptions(
                biometricOnly: true,
                stickyAuth: true,
              ),
            );
            if (didAuthenticate && mounted) {
              setState(() => isLoading = true);
              await Future.delayed(const Duration(milliseconds: 1000));
              if (mounted) {
                final role = prefs.getString('user_role');
                Navigator.pushReplacementNamed(context, _homeRouteForRole(role));
              }
              return;
            }
          }
        } catch (e) {
          debugPrint('Biometric error: $e');
        }
      }
    }
  }

  // ===== Memanggil API login sungguhan =====
  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan Password wajib diisi!')),
      );
      return;
    }

    setState(() => isLoading = true);

    final result = await ApiService.login(
      emailController.text.trim(),
      passwordController.text,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (result['success'] != true) {
      // Pesan diambil langsung dari backend, termasuk kasus
      // "Akun Anda masih menunggu persetujuan dari pemilik usaha".
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Email atau password salah!')),
      );
      return;
    }

    // access_token, refresh_token, user_id, user_role, dan business_id
    // sudah otomatis disimpan oleh ApiService.login() sesuai skema response
    // backend (data.access_token, data.user.{id,role}, data.business.id).
    // Di sini kita hanya perlu mengurus preferensi "Ingat saya", karena inilah
    // yang dibaca SplashPage untuk memutuskan auto-login di kunjungan berikutnya.
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setBool('is_remembered', true);
      await prefs.setString('saved_email', emailController.text.trim());
    } else {
      // Kalau tidak dicentang, jangan simpan sesi untuk auto-login berikutnya.
      await prefs.remove('is_remembered');
      await prefs.remove('saved_email');
    }

    if (!mounted) return;

    // ===== PERBAIKAN: arahkan sesuai role, bukan selalu ke '/main' =====
    // 'user_role' disimpan apa adanya dari backend ('OWNER' / 'STAFF') oleh
    // ApiService.login(), jadi staff/kasir sekarang masuk ke navigasi & layar
    // kasirnya sendiri, bukan ke navigasi owner.
    final role = prefs.getString('user_role');
    Navigator.pushReplacementNamed(context, _homeRouteForRole(role));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.asset(
                            'assets/cashmate-logo.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_wallet,
                                size: 40, color: Color(0xFF0D6EFD)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'CashMate',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D6EFD)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Aplikasi Pembukuan UMKM',
                          style: TextStyle(fontSize: 11, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Masuk ke Akun',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selamat datang kembali! Masukkan detail akun Anda.',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Email atau Username',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailController,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: 'nama@tokoumkm.id',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kata Sandi (Password)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passwordController,
                    obscureText: isObscure,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => isObscure = !isObscure),
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: rememberMe,
                            onChanged: (v) => setState(() => rememberMe = v!),
                          ),
                          Text('Ingat saya',
                              style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                        ],
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Lupa password?',
                          style: TextStyle(fontSize: 12, color: Color(0xFF0D6EFD)),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6EFD),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isLoading ? null : _handleLogin,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Masuk Sekarang',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Belum punya akun CashMate? ',
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/signup'),
                        child: const Text(
                          'Daftar sekarang',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            if (isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D6EFD)),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Memproses Masuk...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
