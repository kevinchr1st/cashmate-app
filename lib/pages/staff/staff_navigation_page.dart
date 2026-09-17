import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../add_transaction_page.dart';
import 'staff_activity_page.dart';
import 'staff_data_page.dart';
import 'staff_home_page.dart';
import 'staff_profile_page.dart';

/// Bottom navigation Staff CashMate — mengadopsi bahasa desain navigasi Owner:
/// bar berlekuk dengan tombol tengah "Catat" untuk menambahkan transaksi.
///
///   0. Beranda — identitas usaha + ringkasan hari ini
///   1. Aktivitas — transaksi Staff hari ini
///   2. (center) — buka form Catat Transaksi
///   3. Data Aktif — wallet aktif + kategori aktif (read-only)
///   4. Akun — user info, tema, logout
class StaffNavigationPage extends StatefulWidget {
  final int userId;
  const StaffNavigationPage({super.key, this.userId = 1});

  @override
  State<StaffNavigationPage> createState() => _StaffNavigationPageState();
}

class _StaffNavigationPageState extends State<StaffNavigationPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const StaffHomePage(),
      const StaffActivityPage(),
      const SizedBox.shrink(), // Placeholder untuk center action
      const StaffDataPage(),
      StaffProfilePage(userId: widget.userId),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  void _goTo(int index) => setState(() => _currentIndex = index);

  Future<void> _openRecordSheet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
    if (result == true && mounted) {
      staffRefreshNotifier.value++;
    }
  }

  static const double _barHeight = 70;
  static const double _navHeight = 92;
  static const double _fabSize = 58;

  Widget _buildBottomNav() {
    final theme = Theme.of(context);
    final bool centerSelected = _currentIndex == 2;
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
                    _navItem(Icons.home_outlined, Icons.home_rounded, 'Beranda', 0, theme),
                    _navItem(Icons.list_alt_outlined, Icons.list_alt_rounded, 'Aktivitas', 1, theme),
                    const SizedBox(width: 82),
                    _navItem(Icons.folder_open_outlined, Icons.folder_open_rounded, 'Data', 3, theme),
                    _navItem(Icons.person_outline_rounded, Icons.person_rounded, 'Akun', 4, theme),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openRecordSheet,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: centerSelected ? _fabSize + 2 : _fabSize,
                    width: centerSelected ? _fabSize + 2 : _fabSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.darken(),
                          AppColors.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: barColor, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.note_add_rounded,
                      color: Colors.white,
                      size: centerSelected ? 26 : 24,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Catat',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: centerSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.55),
                      fontWeight: centerSelected ? FontWeight.bold : FontWeight.w600,
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
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
    ThemeData theme,
  ) {
    final selected = _currentIndex == index;
    final unselectedColor = theme.hintColor;

    return Expanded(
      child: InkWell(
        onTap: () => _goTo(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 22,
              color: selected ? AppColors.primary : unselectedColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: selected ? AppColors.primary : unselectedColor,
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