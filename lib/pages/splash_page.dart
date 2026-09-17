import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _floatController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _topSlideAnimation;
  late Animation<Offset> _bottomSlideAnimation;

  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _topSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -1.0),
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeInOutCubic),
      ),
    );

    _bottomSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, 1.0),
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeInOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _mainController.forward();
    _checkSessionAndBiometric();
  }

  Future<void> _checkSessionAndBiometric() async {
    // Tunggu animasi splash berjalan stabil selama 2.8 detik
    await Future.delayed(const Duration(milliseconds: 2800));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final isRemembered = prefs.getBool('is_remembered') ?? false;
    final isBiometricOn = prefs.getBool('is_biometric_enabled') ?? false;

    debugPrint('--- DEBUG SESI ---');
    debugPrint('hasAccessToken: ${accessToken != null && accessToken.isNotEmpty}');
    debugPrint('isRemembered: $isRemembered');
    debugPrint('isBiometricOn: $isBiometricOn');

    // Tidak ada sesi tersimpan, atau "Ingat saya" memang tidak dicentang
    // saat login -> memang seharusnya balik ke halaman login.
    if (accessToken == null || accessToken.isEmpty || !isRemembered) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // ===== PERBAIKAN UTAMA =====
    // Sebelumnya: kalau biometrik gagal/dibatalkan, user langsung dilempar ke
    // /login walau "Ingat saya" aktif dan token masih ada -> inilah yang bikin
    // terasa "logout sendiri". Sekarang biometrik hanya lapisan tambahan yang
    // TIDAK memblokir sesi yang sudah diingat; hasil sukses/gagal/dibatalkan
    // sama-sama lanjut ke pengecekan validitas token di bawah.
    if (isBiometricOn) {
      try {
        await auth.stopAuthentication();
        final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
        if (canCheck) {
          try {
            final didAuthenticate = await auth.authenticate(
              localizedReason: 'Verifikasi sidik jari untuk masuk ke CashMate',
              options: const AuthenticationOptions(
                biometricOnly: false,
                stickyAuth: false,
                useErrorDialogs: true,
              ),
            );
            debugPrint('Hasil Autentikasi Biometrik: $didAuthenticate');
          } catch (e) {
            debugPrint('Error saat memunculkan dialog biometrik (diabaikan): $e');
          }
        }
      } catch (e) {
        debugPrint('Error utama biometrik (diabaikan): $e');
      }
    }

    // Validasi ke backend: token masih berlaku (GET /auth/me)? Kalau sudah
    // kedaluwarsa, coba refresh dulu (POST /auth/refresh) sebelum benar-benar
    // menyerah dan meminta login ulang.
    final sessionValid = await ApiService.ensureValidSession();
    if (!mounted) return;

    if (sessionValid) {
      // Arahkan sesuai role: staff/kasir -> layar & navigasi kasir sendiri,
      // owner -> navigasi owner seperti biasa.
      final role = (prefs.getString('user_role') ?? '').toUpperCase();
      Navigator.pushReplacementNamed(context, role == 'STAFF' ? '/staff-main' : '/main');
    } else {
      debugPrint('Sesi tidak valid / gagal direfresh -> kembali ke login');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001A3D),
      body: Stack(
        children: [
          SlideTransition(
            position: _topSlideAnimation,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: MediaQuery.of(context).size.height / 2,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00112C), Color(0xFF0D6EFD)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
              ),
            ),
          ),
          SlideTransition(
            position: _bottomSlideAnimation,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height / 2,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D6EFD), Color(0xFF1E6BFF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 8 * (_floatController.value - 0.5)),
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          size: 64,
                          color: Color(0xFF0D6EFD),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'CASHMATE UMKM',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Solusi Pembukuan Keuangan Modern',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
