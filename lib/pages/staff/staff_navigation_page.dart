import 'package:flutter/material.dart';
import 'staff_home_page.dart';
import 'staff_activity_page.dart';
import 'staff_data_page.dart';
import 'staff_profile_page.dart';
import '../add_transaction_page.dart';

/// Bottom navigation Staff CashMate.
/// 4 tab + 1 center action (Catat Transaksi):
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
  static const Color _blue = Color(0xFF0D6EFD);
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
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        height: 65,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navItem(Icons.home_outlined, 'Beranda', 0),
            _navItem(Icons.list_alt_rounded, 'Aktivitas', 1),
            _centerFabItem(),
            _navItem(Icons.folder_open_outlined, 'Data', 3),
            _navItem(Icons.person_outline_rounded, 'Akun', 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: selected ? _blue : Colors.grey),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? _blue : Colors.grey,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerFabItem() {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTransactionPage()),
            );
            if (result == true && mounted) {
              // Trigger refresh pada page aktif
              setState(() {});
            }
          },
          child: Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              color: _blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}