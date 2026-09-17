import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FotoNotaPage extends StatefulWidget {
  const FotoNotaPage({super.key});

  @override
  State<FotoNotaPage> createState() => _FotoNotaPageState();
}

class _FotoNotaPageState extends State<FotoNotaPage> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isAutoDetectActive = true;
  String _selectedTransaction = 'Beli Es Batu Kristal — Rp 25.000';
  final String _merchantName = 'Toko Plastik Berkah';
  final String _nominalNote = '50000';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e')),
        );
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Foto Nota', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: const Text('POS-01', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Color(0xFF0D6EFD)),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Shift & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Colors.green),
                  const SizedBox(width: 6),
                  Text('Shift Pagi (Kasir 01)', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text('Petty Cash Siaga', style: TextStyle(fontSize: 10, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Text('Ambil & Unggah Foto Nota Fisik', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

// Area Kamera / Viewfinder
          Container(
            height: 340,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Gambar Nota (jika sudah diambil) atau Placeholder Scan
                Center(
                  child: _imageFile != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_imageFile!, height: 300, width: 240, fit: BoxFit.cover),
                  )
                      : Container(
                    height: 290,
                    width: 230,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(child: Text('SUPERMARKET LOKAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        const Center(child: Text('Jl. Melati No. 45, Jakarta Selatan', style: TextStyle(fontSize: 8, color: Colors.grey))),
                        const SizedBox(height: 10),
                        const Text('NOTA PEMBELIAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        const Text('Kasir: Rina\nTanggal: 12/05/2023 14:32', style: TextStyle(fontSize: 8, color: Colors.grey)),
                        const Divider(),
                        _receiptRow('Indomie Goreng (5)', 'Rp 13.750'),
                        _receiptRow('Susu UHT Ultra (1L)', 'Rp 18.900'),
                        _receiptRow('Roti Tawar Sari Roti', 'Rp 15.500'),
                        _receiptRow('Telur Ayam (1 kg)', 'Rp 28.000'),
                        const Divider(),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text('Total: Rp 115.029', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Bar dalam Kamera (Deteksi Otomatis & Flash)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Icon(Icons.center_focus_strong, size: 14, color: _isAutoDetectActive ? Colors.greenAccent : Colors.white),
                            const SizedBox(width: 4),
                            Text('Deteksi Otomatis: ${_isAutoDetectActive ? "Aktif" : "Mati"}',
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                          onPressed: () => _showSnack('Flash diaktifkan'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Panduan teks di bawah viewfinder
                const Positioned(
                  bottom: 70,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Posisikan struk di dalam kotak garis panduan',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ),

                // Tombol Kontrol Kamera Bawah (Galeri, Jepret/Kamera, Reset)
                Positioned(
                  bottom: 12,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        tooltip: 'Galeri',
                      ),
                      GestureDetector(
                        onTap: () => _pickImage(ImageSource.camera),
                        child: Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D6EFD),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => setState(() => _imageFile = null),
                        tooltip: 'Reset',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Hubungkan ke Transaksi Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.link, size: 18, color: Color(0xFF0D6EFD)),
                        SizedBox(width: 8),
                        Text('Hubungkan ke Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                      child: const Text('Wajib', style: TextStyle(fontSize: 10, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dropdown Transaksi Terkait
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTransaction,
                      isExpanded: true,
                      items: <String>[
                        'Beli Es Batu Kristal — Rp 25.000',
                        'Beli Plastik Takeaway — Rp 50.000',
                        'Bahan Baku Tambahan — Rp 120.000',
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedTransaction = newValue);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Merchant Name Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_merchantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D6EFD))),
                ),

                const SizedBox(height: 10),

                // Nominal Nota Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Rp $_nominalNote', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D6EFD))),
                ),

                const SizedBox(height: 12),

                // Catatan Pemeriksaan
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.verified_outlined, size: 16, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan Pemeriksaan: Pastikan tanggal, stempel toko, dan total nominal terbaca jelas untuk validasi audit harian Owner.',
                          style: TextStyle(fontSize: 11, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tombol Simpan & Lampirkan
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                _showSnack('Foto nota berhasil dilampirkan ke pembukuan kasir!');
                Navigator.pop(context);
              },
              icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),
              label: const Text('Simpan & Lampirkan ke Pembukuan Kasir',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _receiptRow(String item, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item, style: const TextStyle(fontSize: 8)),
          Text(price, style: const TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
}