import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../add_transaction_page.dart';
import 'dashboard_page.dart';
import 'profile_page.dart';
import 'rekap_page.dart';
import 'transaction_page.dart';
import 'wallet_page.dart';

/// Bottom navigation CashMate.
class OwnerNavigationPage extends StatefulWidget {
  final int userId;
  const OwnerNavigationPage({super.key, this.userId = 1});

  @override
  State<OwnerNavigationPage> createState() => _OwnerNavigationPageState();
}

class _OwnerNavigationPageState extends State<OwnerNavigationPage> {
  static const Color _blue = Color(0xFF1155D9);
  static const Color _amber = Color(0xFFF5A524);
  static const Color _kantong = Color(0xFFC97A3D);

  int _currentIndex = 0;
  bool _isOwner = true;
  bool _hasPromptedWalletSetup = false;

  List<Map<String, dynamic>> _wallets = [];

  @override
  void initState() {
    super.initState();
    _init();
    openKantongTabNotifier.addListener(_goToKantongTab);
  }

  void _goToKantongTab() {
    if (!mounted) return;
    setState(() => _currentIndex = 2);
  }

  @override
  void dispose() {
    openKantongTabNotifier.removeListener(_goToKantongTab);
    super.dispose();
  }

  Future<void> _init() async {
    _isOwner = await ApiService.isOwner();
    await _loadWallets();
    if (!mounted) return;

    if (_isOwner && _wallets.isEmpty && !_hasPromptedWalletSetup) {
      _hasPromptedWalletSetup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Buat kantong kas pertama untuk mulai mencatat.'),
            backgroundColor: _amber,
          ),
        );
        _openWalletPage();
      });
    }
    setState(() {});
  }

  Future<void> _loadWallets() async {
    final wallets = await ApiService.fetchWallets(status: 'active');
    if (!mounted) return;
    setState(() => _wallets = wallets);
  }

  void _openWalletPage() {
    setState(() => _currentIndex = 2);
  }

  Future<void> _openRecordSheet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
    if (result == true) {
      dashboardRefreshNotifier.value++;
      await _loadWallets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      TransactionPage(userId: widget.userId),
      const WalletPage(),
      RekapPage(userId: widget.userId),
      ProfilePage(userId: widget.userId),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true, // Membuat konten tembus ke bawah dan menghilangkan batas hitam
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  static const double _barHeight = 70;
  static const double _navHeight = 92;
  static const double _fabSize = 58;

  Widget _buildBottomNav() {
    final theme = Theme.of(context);
    final bool kantongSelected = _currentIndex == 2;
    final barColor = theme.cardColor;

    return SizedBox(
      height: _navHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight,
            child: CustomPaint(
              size: const Size(double.infinity, _barHeight),
              painter: _NotchedBarPainter(color: barColor),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _navItem(Icons.grid_view_outlined,
                        Icons.grid_view_rounded, 'Beranda', 0, theme),
                    _navItem(Icons.receipt_long_outlined,
                        Icons.receipt_long, 'Transaksi', 1, theme),
                    const SizedBox(width: 82),
                    _navItem(Icons.bar_chart_outlined, Icons.bar_chart,
                        'Rekap', 3, theme),
                    _navItem(Icons.storefront_outlined, Icons.storefront,
                        'Toko', 4, theme),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _currentIndex = 2),
              onLongPress: _openRecordSheet,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: kantongSelected ? _fabSize + 2 : _fabSize,
                    width: kantongSelected ? _fabSize + 2 : _fabSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kantong,
                      border: Border.all(color: barColor, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: _kantong.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.savings_rounded,
                        color: Colors.white,
                        size: kantongSelected ? 26 : 24),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Kantong',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: kantongSelected
                          ? _kantong
                          : _kantong.withOpacity(0.55),
                      fontWeight:
                      kantongSelected ? FontWeight.bold : FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
      IconData icon, IconData activeIcon, String label, int index, ThemeData theme) {
    final selected = _currentIndex == index;
    final unselectedColor = theme.hintColor;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon,
                size: 22, color: selected ? _blue : unselectedColor),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: selected ? _blue : unselectedColor,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  final Color color;
  const _NotchedBarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const topPad = 16.0;
    const notchDepth = 15.0;
    const notchHalfWidth = 46.0;
    const corner = 14.0;
    final cx = w / 2;

    final path = Path()
      ..moveTo(0, topPad + corner)
      ..quadraticBezierTo(0, topPad, corner, topPad)
      ..lineTo(cx - notchHalfWidth, topPad)
      ..cubicTo(
        cx - notchHalfWidth + 18, topPad,
        cx - notchHalfWidth + 22, topPad + notchDepth,
        cx, topPad + notchDepth,
      )
      ..cubicTo(
        cx + notchHalfWidth - 22, topPad + notchDepth,
        cx + notchHalfWidth - 18, topPad,
        cx + notchHalfWidth, topPad,
      )
      ..lineTo(w - corner, topPad)
      ..quadraticBezierTo(w, topPad, w, topPad + corner)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter oldDelegate) =>
      oldDelegate.color != color;
}