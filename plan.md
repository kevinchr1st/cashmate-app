# CashMate Revisi — Handoff Plan untuk Agent

Status dokumen: keputusan produk dan implementasi sudah dikunci melalui sesi grill.

## 1. Scope dan sumber kebenaran

- Ubah **Flutter app saja**: /home/myankoi/Projects/cashmate-app.
- Jangan mengubah cashmate-api atau cashmate-web untuk task ini.
- Gunakan collection terbaru sebagai kontrak API: /home/myankoi/Downloads/CashMate API MVP.postman_collection.json.
- Perubahan lokal yang sudah ada di analysis_options.yaml, android/gradle.properties, dan pubspec.lock harus dipertahankan.
- Backend yang dipakai app diasumsikan sudah menyediakan endpoint restore Staff dari collection terbaru, walaupun checkout backend lokal saat ini belum memiliki route tersebut.

## 2. Fakta baseline yang harus diperbaiki

- Flutter Owner Staff management masih salah:
  - tambah Staff memanggil registerOwner, sehingga berpotensi membuat Business/Owner baru;
  - nonaktifkan memanggil endpoint lama /staff/:id/reject;
  - belum ada client untuk POST /staff/:id/restore;
  - validasi password masih minimal enam karakter, sedangkan API meminta minimal delapan.
- Owner transaction page hanya mengambil transaksi aktif karena fetchTransactions belum menerima status; transaksi void hanya bisa dipulihkan dari snackbar sesaat.
- RekapPage menghitung tren dengan request /transactions per bulan dan meminta per_page=200, sedangkan API membatasi maksimal 100; hasil chart dapat terpotong. Gunakan GET /reports/monthly?year=YYYY yang sudah tersedia.
- Profile Owner membungkus TabBarView tinggi tetap 420 px di dalam scroll utama dan setiap tab memiliki scroll sendiri; ini menyebabkan konten tab sulit/tidak bisa digulir pada layar kecil.
- App belum memiliki logo CashMate sebagai asset Flutter dan memakai banyak warna biru hardcoded.
- API/Postman tidak menyediakan bank integration, printer/terminal, atau analisis kesehatan UMKM. Jangan membuat UI seolah fitur-fitur itu tersedia.
- Staff screens mengandung copy dan alur yang tidak didukung API: POS/shift, QRIS split 55/45, correction report, recent activities, printer, close shift, barcode, dan histori lintas hari.
- /auth/me mengembalikan data.user dan data.business, tetapi beberapa screen Staff membaca data.name/data.email dan jatuh ke data dummy.
- Baseline analyzer memiliki error test lama karena test/widget_test.dart masih memakai MyApp; class app sebenarnya CashMateApp.

## 3. Kontrak client/API yang harus dipakai

Perbarui lib/services/api_service.dart dan model terkait.

- fetchTransactions menerima status, type, page, dan perPage.
  - Owner: status=active|disabled|all; type kosong berarti income + expense.
  - Staff: client selalu membaca transaksi aktif milik sendiri pada hari berjalan; jangan izinkan status/date bypass dari UI.
- Tambahkan helper pengambilan semua halaman berdasarkan metadata API agar filter “Semua” benar-benar dapat menampilkan seluruh transaksi, bukan hanya 100 row pertama.
- Staff lifecycle:
  - POST /staff dengan {name,email,password};
  - GET /staff?status=active|disabled|all;
  - DELETE /staff/{id} untuk soft-disable;
  - POST /staff/{id}/restore untuk pulihkan.
- Hentikan pemakaian endpoint semu approve, reject, dan activities/recent pada alur yang direvisi.
- Parse transaksi dari field kontrak API: date, description, type, deleted_at, nested wallet, category, dan created_by.
- getMonthlyReport(year) menjadi sumber tunggal chart dan tabel rekap.

## 4. Perubahan Owner

### Staff

- Halaman pengelolaan Staff menampilkan status Aktif, Nonaktif, dan bila perlu Semua.
- Tambah Staff memakai endpoint /staff, bukan register Owner.
- Copy wajib memakai istilah “Staff”, “Nonaktifkan Staff”, dan “Pulihkan Staff”; tidak boleh “hapus permanen”.
- Histori transaksi Staff tetap terlihat Owner setelah akun dinonaktifkan.

### Transaksi

- Default halaman tetap status=active, tetapi menampilkan kedua jenis transaksi.
- Sediakan filter status: Aktif, Semua, Void.
- Sediakan filter jenis: Semua, Pemasukan (income), Pengeluaran (expense).
- Row void diberi badge/status jelas dan hanya menyediakan aksi Pulihkan.
- Row aktif tetap dapat diedit atau di-void sesuai hak Owner.
- Kartu total pemasukan, pengeluaran, dan saldo **tidak pernah menjumlah transaksi void**, termasuk saat daftar sedang difilter Semua/Void.
- Setelah void/restore/edit, refresh transaksi, wallet, dan total.

### Rekap bulanan

- Gunakan GET /reports/monthly?year=YYYY.
- Tampilkan seluruh 12 bulan Januari–Desember untuk tahun yang dipilih.
- Chart menampilkan dua seri: pemasukan dan pengeluaran.
- Net cashflow tetap ditampilkan sebagai angka/tabel, bukan wajib menjadi seri ketiga.
- Laporan mengikuti aturan API: transaksi void tidak masuk agregasi.

### Profile/Toko dan scroll

- Hapus total bagian bank/QRIS terhubung, tombol tambah rekening, printer thermal, dan copy cloud/shift/POS yang tidak punya endpoint.
- Pertahankan kontrol nyata untuk kategori dan wallet, misalnya di tab “Data Usaha”.
- Hapus kartu “Analisis Kesehatan Kas UMKM” dari RekapPage.
- Pertahankan tab informasi Staff dan keamanan/tampilan.
- Ganti struktur nested scroll dengan satu scroll vertikal pada halaman/tab aktif; jangan memakai TabBarView tinggi tetap yang berisi scroll bersarang.
- Uji pada viewport kecil sampai tombol logout dan seluruh isi tab dapat dicapai.

## 5. Perubahan Staff app

Pertahankan lima posisi bottom navigation sebagai empat layar nyata plus satu action tengah:

1. Beranda — identitas usaha dan aktivitas ringkas Staff hari ini; tanpa saldo/dashboard Owner.
2. Aktivitas — transaksi milik Staff pada hari berjalan, dengan filter pemasukan/pengeluaran.
3. Tombol tengah Catat Transaksi — membuka form pencatatan, bukan halaman kamera palsu.
4. Data Aktif — wallet aktif tanpa saldo dan kategori aktif yang tersedia untuk form.
5. Akun — user, business, role Staff, preferensi tema, dan logout.

Form transaksi Staff:

- Mendukung income dan expense.
- Hanya wallet/kategori aktif.
- Deskripsi opsional.
- Tidak menampilkan input tanggal; tanggal ditetapkan server.
- Tidak menyediakan edit, void, restore, backdate, laporan, shift, QRIS split, printer, barcode, atau correction report.
- Tidak mempertahankan layar Foto Nota terpisah dalam navigasi.

Copy Staff harus mengikuti vocabulary endpoint: “Staff”, “Transaksi”, “Pemasukan”, “Pengeluaran”, “Wallet”, “Kategori”, dan “Transaksi Hari Ini”. Hilangkan istilah POS, kasir, shift, petty cash, saldo toko terlindungi, dan klaim operasional yang tidak didukung API.

## 6. Branding dan warna

- Salin asset resmi cashmate-logo.png dari cashmate-web/src/assets/figma/ ke asset Flutter dan daftarkan di pubspec.yaml.
- Gunakan logo pada splash, login/register, dan header utama Owner/Staff.
- Biru tetap menjadi warna dominan.
- Warna bottom navigation tidak diubah.
- Tambahkan amber/kuning secara bertahap pada icon surface, chip, badge, section highlight, dan aksen chart.
- Hijau/merah tetap dipakai untuk semantik pemasukan/pengeluaran/status sukses-gagal.
- Hindari mengganti semua biru menjadi kuning secara global.

## 7. Urutan pengerjaan yang disarankan

1. Benahi ApiService, model transaksi, parsing /auth/me, dan helper pagination.
2. Benahi lifecycle Staff Owner dan filter/restore transaksi Owner.
3. Ganti sumber data RekapPage ke endpoint monthly report dan hapus health card.
4. Restrukturisasi Profile Owner agar scroll tunggal dan hapus bank/printer/fake operational copy.
5. Sederhanakan Staff navigation, home/activity/data/account, dan form transaksi sesuai endpoint.
6. Tambahkan asset logo dan aksen amber terukur.
7. Tambahkan/benahi tests dan lakukan smoke test terhadap server API.

## 8. Acceptance test

- Owner membuat Staff baru; request masuk ke POST /staff, role tetap STAFF, password minimum delapan karakter.
- Owner menonaktifkan Staff; Staff kehilangan akses login/token; histori transaksi tetap ada.
- Owner memulihkan Staff melalui POST /staff/{id}/restore; Staff dapat login kembali.
- Owner melihat transaksi aktif, pemasukan, pengeluaran, dan void melalui filter yang sesuai.
- Void transaction tidak masuk total uang, dashboard-style summary, atau chart monthly; restore mengembalikan efeknya.
- Semua halaman transaksi dapat memuat lebih dari satu page bila data melebihi batas API.
- Chart menampilkan tepat 12 bulan untuk tahun terpilih dan nilainya cocok dengan response /reports/monthly.
- Staff hanya melihat transaksi sendiri hari ini, tidak melihat saldo/report Owner, dan tidak bisa edit/void/backdate.
- Staff dapat mencatat pemasukan maupun pengeluaran dengan tanggal server.
- Profile Owner dapat digulir sampai akhir pada layar kecil; isi bank, printer, dan health analysis tidak muncul.
- Logo muncul di splash, auth, dan header; bottom navigation tetap menggunakan warna biru lama dengan aksen kuning tambahan.
- Ganti smoke test lama yang merujuk MyApp; jalankan flutter test dan flutter analyze, minimal tanpa error baru pada file yang disentuh.

## 9. Catatan risiko

- Collection terbaru mendokumentasikan restore Staff, tetapi checkout backend lokal belum memiliki route itu. Jika server target mengembalikan 404, laporkan sebagai backend/deployment blocker; jangan membuat fallback endpoint palsu di app.
- Collection tidak memberi contoh filter status transaksi, meskipun backend lokal mendukung status=active|disabled|all. Verifikasi ini pada smoke test sebelum demo.
- Jangan menghapus perubahan lokal yang tidak terkait task ini.

