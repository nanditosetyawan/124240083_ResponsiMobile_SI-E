// ╔══════════════════════════════════════════════════════════════╗
// ║  FITUR: MODEL DATA (News / Blog / Report)                    ║
// ║  FILE : models/article_model.dart                            ║
// ║  COPY : Seluruh file ini                                     ║
// ║  EDIT : Sesuaikan nama field dengan key JSON dari API-mu     ║
// ╚══════════════════════════════════════════════════════════════╝
//
// CARA CEK KEY JSON API:
//   Buka URL API di browser, lihat key-key yang ada.
//   Contoh Spaceflight News API v4:
//     { "id": 1, "title": "...", "image_url": "...", "news_site": "...",
//       "summary": "...", "published_at": "...", "url": "..." }
//
// WAJIB ADA di model untuk FavoriteService:
//   - field 'id' (int)
//   - method toMap()
//   - factory fromMap(map)
//
// KETENTUAN YANG DIPENUHI (dari model ini):
//   ✅ Judul (title)
//   ✅ Gambar (imageUrl ← dari JSON key 'image_url')
//   ✅ Author (newsSite ← dari JSON key 'news_site')
//   ✅ Tanggal publish (publishedAt ← dari JSON key 'published_at')
//   ✅ Summary (summary)
//   ✅ URL situs resmi (url)

import '../core/api_adapter.dart';

class ArticleModel {
  // ── FIELD-FIELD MODEL ───────────────────────────────────────────
  final int id;           // id unik — WAJIB ADA untuk fitur Favourite
  final String title;     // judul berita — tampil di list & detail
  final String url;       // link ke situs resmi — dipakai url_launcher di detail
  final String imageUrl;  // URL gambar — tampil sebagai thumbnail & gambar detail
  final String newsSite;  // nama sumber/author — tampil di list & dipakai filter chip
  final String summary;   // ringkasan isi — tampil di detail
  final String publishedAt; // tanggal publish — tampil di detail
  final String type;      // "news" / "blogs" / "reports" — agar FavoriteService tahu jenisnya

  /// Menyimpan JSON mentah dari API agar field tambahan tetap bisa diakses tanpa ubah Model.
  final Map<String, dynamic> rawData;
  // ───────────────────────────────────────────────────────────────

  const ArticleModel({
    required this.id,
    required this.title,
    required this.url,
    required this.imageUrl,
    required this.newsSite,
    required this.summary,
    required this.publishedAt,
    required this.type,
    this.rawData = const {},
  });

  /// Ambil field tambahan dari [rawData], mendukung dot notation (mis. `'meta.category'`).
  dynamic getExtra(String path) => ApiAdapter.extractPath(rawData, path);

  /// Versi praktis: langsung jadi String aman tanpa perlu cek null (mis. `article.extra('genre')`).
  String extra(String path, [String fallback = '']) => (getExtra(path) ?? fallback).toString();

  /// Menerima hasil normalisasi dari [ApiAdapter] maupun JSON mentah lama Spaceflight.
  factory ArticleModel.fromJson(
    Map<String, dynamic> json, {
    required String type,
    Map<String, dynamic>? rawData,
  }) {
    final dynamic rawId = json['id'];
    final int parsedId = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;

    return ArticleModel(
      id: parsedId,
      title: (json['title'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'] ?? '').toString(),
      newsSite: (json['newsSite'] ?? json['news_site'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      publishedAt: (json['publishedAt'] ?? json['published_at'] ?? '').toString(),
      type: type,
      rawData: Map<String, dynamic>.from(rawData ?? json),
    );
  }

  /// Simpan ke SharedPreferences (dipakai oleh FavoriteService).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'imageUrl': imageUrl,
      'newsSite': newsSite,
      'summary': summary,
      'publishedAt': publishedAt,
      'type': type,
      if (rawData.isNotEmpty) 'rawData': rawData,
    };
  }

  /// Baca dari SharedPreferences (tetap kompatibel dengan data favorite lama tanpa rawData).
  factory ArticleModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawId = map['id'];
    final int parsedId = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
    final dynamic savedRaw = map['rawData'];

    return ArticleModel(
      id: parsedId,
      title: map['title'] as String? ?? '',
      url: map['url'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      newsSite: map['newsSite'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      publishedAt: map['publishedAt'] as String? ?? '',
      type: map['type'] as String? ?? '',
      rawData: savedRaw is Map ? Map<String, dynamic>.from(savedRaw) : const {},
    );
  }
}
