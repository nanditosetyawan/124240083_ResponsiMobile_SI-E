// ╔══════════════════════════════════════════════════════════════╗
// ║  FITUR: FAVOURITE (Tambah, Hapus, Cek, Toggle)               ║
// ║  FILE : services/favorite_service.dart                       ║
// ║  COPY : Seluruh file ini                                     ║
// ║  EDIT : Ganti 'ArticleModel' dengan nama model kamu          ║
// ╚══════════════════════════════════════════════════════════════╝
//
// CARA PAKAI:
//   FavoriteService.getFavorites()          → List<ArticleModel>
//   FavoriteService.isFavorite(id)          → bool
//   FavoriteService.addFavorite(article)
//   FavoriteService.removeFavorite(id)
//   FavoriteService.toggleFavorite(article) → bool (true=jadi fav, false=dihapus)
//
// SYARAT MODEL:
//   Model kamu HARUS punya:
//   - field 'id' (int)       → untuk identifikasi unik
//   - method toMap()         → untuk disimpan ke SharedPreferences
//   - factory fromMap(map)   → untuk dibaca kembali dari SharedPreferences
//   Lihat article_model.dart sebagai contoh implementasinya.
//
// KETENTUAN YANG DIPENUHI:
//   ✅ Penambahan favourite dari halaman detail
//   ✅ List favourite terupdate dari halaman manapun

import 'dart:convert'; // jsonEncode / jsonDecode — JANGAN HAPUS
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article_model.dart'; // ← EDIT: ganti dengan import model kamu

class FavoriteService {
  // KEY penyimpanan di SharedPreferences — UNIVERSAL, tidak perlu diganti
  static const String _keyFavorites = 'favorites';

  // ══════════════════════════════════════════════════════════════
  // FITUR: AMBIL SEMUA FAVORITE
  // COPY: method ini
  // EDIT: ganti 'ArticleModel' dan 'ArticleModel.fromMap' dengan model kamu
  // ══════════════════════════════════════════════════════════════
  static Future<List<ArticleModel>> getFavorites() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? favJson = prefs.getString(_keyFavorites);
    if (favJson == null) return []; // belum ada favorite → list kosong
    final List<dynamic> favList = jsonDecode(favJson) as List<dynamic>;
    return favList
        .map((item) => ArticleModel.fromMap(item as Map<String, dynamic>)) // ← EDIT: ganti ArticleModel
        .toList();
  }

  // ══════════════════════════════════════════════════════════════
  // FITUR: CEK APAKAH ITEM SUDAH FAVORITE
  // COPY: method ini — UNIVERSAL, tidak perlu edit
  // Dipakai di detail_page untuk tampilkan ikon hati merah/putih
  // ══════════════════════════════════════════════════════════════
  static Future<bool> isFavorite(int id) async {
    final List<ArticleModel> favorites = await getFavorites(); // ← EDIT: ganti ArticleModel
    return favorites.any((item) => item.id == id); // ← EDIT: 'item.id' sesuaikan nama field id-mu
  }

  // ══════════════════════════════════════════════════════════════
  // FITUR: TAMBAH FAVORITE
  // COPY: method ini
  // EDIT: ganti 'ArticleModel' dengan model kamu
  // ══════════════════════════════════════════════════════════════
  static Future<void> addFavorite(ArticleModel article) async { // ← EDIT: ganti ArticleModel
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<ArticleModel> favorites = await getFavorites(); // ← EDIT: ganti ArticleModel

    // Cegah duplikat: jika sudah ada, abaikan
    if (favorites.any((item) => item.id == article.id)) return; // ← EDIT: 'item.id', 'article.id'

    favorites.add(article);

    // Simpan ke SharedPreferences sebagai JSON string
    final String encoded = jsonEncode(
      favorites.map((item) => item.toMap()).toList(), // ← EDIT: pastikan model punya toMap()
    );
    await prefs.setString(_keyFavorites, encoded);
  }

  // ══════════════════════════════════════════════════════════════
  // FITUR: HAPUS FAVORITE
  // COPY: method ini — UNIVERSAL setelah ganti ArticleModel
  // ══════════════════════════════════════════════════════════════
  static Future<void> removeFavorite(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<ArticleModel> favorites = await getFavorites(); // ← EDIT: ganti ArticleModel

    favorites.removeWhere((item) => item.id == id); // ← EDIT: 'item.id' sesuaikan nama field id

    final String encoded = jsonEncode(
      favorites.map((item) => item.toMap()).toList(),
    );
    await prefs.setString(_keyFavorites, encoded);
  }

  // ══════════════════════════════════════════════════════════════
  // FITUR: TOGGLE FAVORITE (tambah jika belum, hapus jika sudah)
  // COPY: method ini — UNIVERSAL setelah ganti ArticleModel
  // Return: true = sekarang jadi favorite, false = dihapus dari favorite
  // Dipakai di detail_page saat tombol hati ditekan
  // ══════════════════════════════════════════════════════════════
  static Future<bool> toggleFavorite(ArticleModel article) async { // ← EDIT: ganti ArticleModel
    final bool alreadyFav = await isFavorite(article.id); // ← EDIT: 'article.id'
    if (alreadyFav) {
      await removeFavorite(article.id); // ← EDIT: 'article.id'
      return false;
    } else {
      await addFavorite(article);
      return true;
    }
  }
}
