/// Formatter bersama supaya angka & tanggal tampil konsisten di seluruh app.

class Rupiah {
  Rupiah._();

  /// `Rp 1.250.000` (nilai negatif diberi tanda minus di depan).
  static String format(num amount) {
    final bool negative = amount < 0;
    final String digits = amount.abs().round().toString();
    final String grouped =
        digits.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '${negative ? '-' : ''}Rp $grouped';
  }

  /// Ringkas untuk kartu sempit: `Rp 1,2 Jt`, `Rp 950 rb`, dst.
  static String compact(num amount) {
    final double abs = amount.abs().toDouble();
    String value;
    if (abs >= 1000000000) {
      value = '${_trim(abs / 1000000000)} M';
    } else if (abs >= 1000000) {
      value = '${_trim(abs / 1000000)} Jt';
    } else if (abs >= 1000) {
      value = '${(abs / 1000).round()} rb';
    } else {
      return format(amount);
    }
    return '${amount < 0 ? '-' : ''}Rp $value';
  }

  static String _trim(double v) {
    final String s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s.replaceAll('.', ',');
  }
}

class AppDate {
  AppDate._();

  static const List<String> monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static const List<String> monthLong = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  /// `17 Sep 2026`
  static String short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${monthShort[d.month - 1]} ${d.year}';

  /// `17 September 2026`
  static String long(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${monthLong[d.month - 1]} ${d.year}';

  /// `14:05`
  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Ubah format `HH:mm` untuk tanggal yang datang dari API (created_at).
  static String timeFrom(String? raw) {
    if (raw == null) return '';
    final DateTime? dt = DateTime.tryParse(raw);
    return dt == null ? '' : time(dt);
  }
}
