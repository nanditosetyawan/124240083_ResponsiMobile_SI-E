

import 'package:flutter/material.dart';
import '../models/article_model.dart';      // ← EDIT: import model kamu
import '../services/favorite_service.dart'; // ← EDIT: import FavoriteService
import 'detail_page.dart';                  // ← EDIT: path ke DetailPage

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  List<ArticleModel> _favorites = []; // ← EDIT: ganti ArticleModel
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites(); // muat saat halaman pertama dibuka
  }


  // LOAD SEMUA FAVOURITE DARI SHAREDPREFERENCES
 
  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final List<ArticleModel> favs = await FavoriteService.getFavorites(); // ← EDIT: ArticleModel
    setState(() { _favorites = favs; _isLoading = false; });
  }


  // FITUR: HAPUS FAVOURITE DARI HALAMAN INI
 
  Future<void> _removeFavorite(ArticleModel article) async { // ← EDIT: ArticleModel
    await FavoriteService.removeFavorite(article.id); // ← EDIT: .id
    _loadFavorites(); // reload list setelah hapus
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${article.title} dihapus dari favorit.'), // ← EDIT: .title
        backgroundColor: Colors.grey,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite'), // ← EDIT: judul AppBar
        backgroundColor: const Color.fromARGB(255, 95, 183, 114), // ← EDIT: warna
        foregroundColor: const Color.fromARGB(255, 183, 244, 209),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Belum ada favorit.',           // ← EDIT: teks
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('Tambahkan dari halaman detail.', // ← EDIT: teks
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    return _buildFavoriteTile(_favorites[index]);
                  },
                ),
    );
  }


  // ITEM FAVOURITE DI LIST

  Widget _buildFavoriteTile(ArticleModel article) { 
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),

        // Gambar thumbnail
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: article.imageUrl.isNotEmpty               // ← EDIT: .imageUrl
              ? Image.network(
                  article.imageUrl,                        // ← EDIT: .imageUrl
                  width: 60, height: 60, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60, height: 60, color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    );
                  },
                )
              : Container(
                  width: 60, height: 60, color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
        ),

        title: Text(
          article.title,                                   // ← EDIT: .title
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          article.newsSite,                                // ← EDIT: .newsSite (author)
          style: const TextStyle(color: Colors.grey, fontSize: 12),
          
        ),
        

        // Ikon hati merah di kanan → klik untuk hapus dari favourite
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () => _removeFavorite(article),
        ),


        // RELOAD FAVOURITE SETELAH KEMBALI DARI DETAIL
      
        onTap: () async {
          await Navigator.push(                            // 'await' wajib ada!
            context,
            MaterialPageRoute(
              builder: (_) => DetailPage(article: article), // ← EDIT: nama class & parameter
            ),
          );
    
          _loadFavorites();
        },
        // ════════════════════════════════════════════════════
      ),
    );
  }
}
