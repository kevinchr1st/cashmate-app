const _htmlEntityMap = <String, String>{
  '&nbsp;': '\u00A0',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
};

/// Mengubah entitas HTML standar kembali ke karakter aslinya.
/// Padanan ringan dari `HtmlUnescape().convert` (package:html) sehingga
/// teks seperti "[Pindah] Bank &gt; Laci" menjadi "Bank > Laci" tanpa
/// menambah dependency baru. Digunakan untuk seluruh teks dari API/database.
String htmlUnescape(String? input) {
  final s = input ?? '';
  if (s.isEmpty) return s;

  // Named entities (tanpa &amp; dulu, agar &amp;gt; ter-decode menjadi &gt;).
  var result = s;
  for (final e in _htmlEntityMap.entries) {
    result = result.replaceAll(e.key, e.value);
  }

  // Numeric entities: &#39; / &#x27; / &#x1F600; dst.
  result = result.replaceAllMapped(
    RegExp(r'&#(x?[0-9a-fA-F]+);'),
    (m) {
      final raw = m[1]!;
      final code = raw.startsWith('x') || raw.startsWith('X')
          ? int.tryParse(raw.substring(1), radix: 16)
          : int.tryParse(raw);
      if (code == null || code < 0 || code > 0x10FFFF) return m[0]!;
      return String.fromCharCode(code);
    },
  );

  // &amp; terakhir: entitas lain sudah bersih, sisanya berarti literal.
  return result.replaceAll('&amp;', '&');
}
