
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // ← WAJIB: untuk launch URL ke browser
import '../core/api_config.dart';
import '../models/article_model.dart';            // ← EDIT: import model kamu
import '../services/api_service.dart';
import '../services/favorite_service.dart';       // ← EDIT: import FavoriteService
import '../services/notification_service.dart';

class DetailPage extends StatefulWidget {
  
  final ArticleModel article;
  const DetailPage({super.key, required this.article});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late ArticleModel _article = widget.article;

 
  bool _isFavorite = false;   // true = sudah favorite, false = belum
  bool _isCheckingFav = true; // true = sedang proses cek/ubah (tampilkan loading)
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus(); // cek apakah artikel ini sudah difavoritkan
    _loadDetailIfConfigured(); // jika detailUrls diisi, muat detail lengkap dari API
  }

  Future<void> _loadDetailIfConfigured() async {
    final detailUrl = ApiConfig.detailUrls[widget.article.type];
    if (detailUrl == null || detailUrl.isEmpty) return;
    try {
      final detailed = await ApiService.fetchDetail(
        widget.article.type,
        widget.article.id,
      );
      if (mounted) setState(() => _article = detailed);
    } catch (_) {
      // Tetap tampilkan data dari list jika endpoint detail gagal/offline
    }
  }


  //CEK STATUS FAVOURITE SAAT HALAMAN DIBUKA

  Future<void> _checkFavoriteStatus() async {
    final bool isFav = await FavoriteService.isFavorite(widget.article.id); // ← EDIT: .id
    setState(() { _isFavorite = isFav; _isCheckingFav = false; });
  }

 
  Future<void> _toggleFavorite() async {
    setState(() => _isCheckingFav = true);
    final bool nowFavorite = await FavoriteService.toggleFavorite(_article);
    setState(() { _isFavorite = nowFavorite; _isCheckingFav = false; });

    if (nowFavorite) {
      await NotificationService.showFavoriteNotification(_article.title);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowFavorite
              ? '${_article.title} ditambahkan ke favorit!'
              : '${_article.title} dihapus dari favorit.',
        ),
        backgroundColor: nowFavorite ? const Color.fromARGB(255, 100, 206, 144) : Colors.grey,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // ══════════════════════════════════════════════════════════════

  
  Future<void> _launchUrl() async {
    final Uri uri = Uri.parse(_article.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication); // buka di browser eksternal
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka link.'), backgroundColor: Colors.red),
      );
    }
  }
  // ══════════════════════════════════════════════════════════════

 
  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return 'Tanggal tidak tersedia';
    try {
      final DateTime dt = DateTime.parse(isoDate);
      return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} ${_pad(dt.hour)}:${_pad(dt.minute)}';
    } catch (_) { return isoDate; }
  }
  String _pad(int n) => n.toString().padLeft(2, '0');
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ArticleModel article = _article;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail'),
        backgroundColor: const Color.fromARGB(255, 115, 207, 140), // ← EDIT: warna
        foregroundColor: Colors.white,
        actions: [




          // FITUR: IKON FAVOURITE DI APPBAR (merah = sudah fav, putih = belum)
       
          _isCheckingFav
              ? const Padding(
                  padding: EdgeInsets.all(14.0),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                )
              : IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white, // ← merah jika sudah fav
                  ),
                  onPressed: _toggleFavorite,
                ),
          
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

  
            //  GAMBAR UTAMA DETAIL
     
            article.imageUrl.isNotEmpty                   // ← EDIT: .imageUrl
                ? Image.network(
                    article.imageUrl,                     // ← EDIT: .imageUrl
                    width: double.infinity, height: 220, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity, height: 220, color: Colors.grey.shade300,
                        child: const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: double.infinity, height: 220, color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  )
                : Container(
                    width: double.infinity, height: 220, color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                  ),
            // ════════════════════════════════════════════════════

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  //JUDUL
              
                  Text(
                    article.title,                        // ← EDIT: .title
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // ─────────────────────────────────────────────

                  // negara
                  Row(children: [
                    const Icon(Icons.source, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(article.newsSite,                // ← EDIT: .newsSite atau article.extra('nama_key')
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                   Row(children: [
                    const Icon(Icons.source, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(article.extra('mealType'),                // ← EDIT: .newsSite atau article.extra('nama_key')
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.source, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(article.extra('rating'),                // ← EDIT: .newsSite atau article.extra('nama_key')
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.source, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Jumlah Review: '),
                    Text(article.extra('reviewCount'),                // ← EDIT: .newsSite atau article.extra('nama_key')
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                    const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.source, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                     Text('Waktu Persiapan: '),
                    Text(article.extra('prepTimeMinutes'),                // ← EDIT: .newsSite atau article.extra('nama_key')
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                      const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.source, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Kesulitan: '),
                    Text(article.extra('difficulty'),                // ← EDIT: .newsSite atau article.extra('nama_key')
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                      const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.source, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Waktu masak: '),
                    Text(article.extra('cookTimeMinutes'),                // ← EDIT: .newsSite atau article.extra('nama_key')
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                       const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.source, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Jumlah Porsi: '),
                    Text(article.extra('servings'),                // ← EDIT: .newsSite atau article.extra('nama_key')
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                       const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.source, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Kalori: '),
                    Text(article.extra('caloriesPerServing'),                // ← EDIT: .newsSite atau article.extra('nama_key')
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                  // ─────────────────────────────────────────────
                  const SizedBox(height: 8),
                  // ─────────────────────────────────────────────

                  const Divider(),
                  const SizedBox(height: 8),

                  // data ingrediend  dan menu
Text('Bahan - Bahan: '),
                  Text(
                    article.summary.isNotEmpty           // ← EDIT: .summary
                        ? article.extra('ingredients')                // ← EDIT: .summary
                        : 'Tidak ada ringkasan tersedia.',
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
Text('Instruksi Memasak: '),
                  Text(
                    article.summary.isNotEmpty           // ← EDIT: .summary
                        ? article.extra('instructions')                // ← EDIT: .summary
                        : 'Tidak ada ringkasan tersedia.',
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 24),

                  //TOMBOL TAMBAH/HAPUS FAVOURITE
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isCheckingFav ? null : _toggleFavorite,
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : const Color(0xFF5C6BC0),
                      ),
                      label: Text(
                        _isFavorite ? 'Hapus dari Favorit' : 'Tambahkan ke Favorit', // ← EDIT: teks
                        style: TextStyle(
                          color: _isFavorite ? Colors.red : const Color(0xFF5C6BC0),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _isFavorite ? Colors.red : const Color(0xFF5C6BC0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  // ════════════════════════════════════════════
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
