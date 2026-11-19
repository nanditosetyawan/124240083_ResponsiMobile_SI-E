
import 'package:flutter/material.dart';
import '../models/article_model.dart';   
import '../services/api_service.dart';   
import 'detail_page.dart';               
import 'favorite_page.dart';             

class ListPage extends StatefulWidget {
  
  final String type;
  const ListPage({super.key, required this.type});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  
  List<ArticleModel> _articles = [];         // semua data dari API
  List<ArticleModel> _filteredArticles = []; // data setelah filter chip aktif
  List<String> _authors = [];               // daftar unik author → untuk buat chip
  String? _selectedAuthor;                  // author yang dipilih (null = tampilkan semua)
  // ───────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData(); // ambil data saat halaman pertama dibuka
  }


  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final List<ArticleModel> data = await ApiService.fetchList(widget.type); // ← EDIT: service & model

      // Ekstrak daftar author unik untuk FilterChip
 
      final List<String> uniqueAuthors =
          data.map((article) => article.newsSite).toSet().toList(); // ← EDIT: .newsSite

      setState(() {
        _articles = data;
        _filteredArticles = data; // awalnya tampilkan semua
        _authors = uniqueAuthors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMessage = 'Gagal memuat data: $e'; _isLoading = false; });
    }
  }


  //FILTER CHIP — LOGIKA FILTER
 
  void _applyFilter(String author) {
    setState(() {
      if (_selectedAuthor == author) {
        // Chip yang sama diklik lagi → hapus filter, tampilkan semua
        _selectedAuthor = null;
        _filteredArticles = _articles;
      } else {
        // Pilih filter baru → tampilkan hanya artikel dengan author ini
        _selectedAuthor = author;
        _filteredArticles = _articles.where((a) => a.newsSite == author).toList(); // ← EDIT: .newsSite
      }
    });
  }
  // ══════════════════════════════════════════════════════════════

  // Judul AppBar berdasarkan type (OPSIONAL)
 
  String get _pageTitle {
    switch (widget.type) {
      case 'news': return 'Menu';       // ← JANGAN ubah 'news' | BOLEH EDIT teks 'News'
      case 'blogs': return 'Blog';      // ← JANGAN ubah 'blogs' | BOLEH EDIT teks 'Blog'
      case 'reports': return 'Reports'; // ← JANGAN ubah 'reports' | BOLEH EDIT teks 'Reports'
      default: return widget.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        backgroundColor: const Color.fromARGB(255, 128, 238, 151), // ← EDIT: warna
        foregroundColor: Colors.white,
        actions: [
          // Tombol Favourite di AppBar kanan
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritePage()), // ← EDIT: nama class
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchData, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    return Column(
      children: [
 
        // FITUR: FILTER CHIP 
     
        if (_authors.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _authors.length,
              itemBuilder: (context, index) {
                final String author = _authors[index];
                final bool isSelected = _selectedAuthor == author;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    //  FilterChip
                    label: Text(
                      author,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,                          // aktif atau tidak
                    selectedColor: const Color(0xFF5C6BC0),        // ← EDIT: warna chip aktif
                    backgroundColor: Colors.grey.shade200,         // ← EDIT: warna chip tidak aktif
                    checkmarkColor: Colors.white,                  // ← warna tanda ✓
                    onSelected: (_) => _applyFilter(author),       // panggil logika filter
          
                  ),
                );
              },
            ),
          ),
        // ════════════════════════════════════════════════════════

        // ── Daftar Artikel ───────────────────────────────────────
        Expanded(
          child: _filteredArticles.isEmpty
              ? const Center(child: Text('Tidak ada data untuk filter ini.'))
              : ListView.builder(
                  itemCount: _filteredArticles.length,
                  itemBuilder: (context, index) {
                    return _buildArticleTile(_filteredArticles[index]);
                  },
                ),
        ),
        // ─────────────────────────────────────────────────────────
      ],
    );
  }

  // FITUR: ITEM ARTIKEL DI LIST

  Widget _buildArticleTile(ArticleModel article) { // ← EDIT: ganti ArticleModel
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),

        //  GAMBAR LEADING + EXCEPTION HANDLING ──────────
     
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: article.imageUrl.isNotEmpty               // ← EDIT: .imageUrl
              ? Image.network(
                  article.imageUrl,                        // ← EDIT: .imageUrl
                  width: 80, height: 80, fit: BoxFit.cover,
                  // errorBuilder: EXCEPTION HANDLING saat gambar gagal load
                  // Ketentuan: "memberikan exception handling apabila gambarnya tidak muncul"
                  errorBuilder: (context, error, stackTrace) {
                    // Jika gambar gagal → tampilkan icon placeholder
                    return Container(
                      width: 80, height: 80,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child; // sudah selesai load
                    return Container(
                      width: 80, height: 80, color: Colors.grey.shade100,
                      child: const Center(
                        child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    );
                  },
                )
            
              : Container(
                  width: 80, height: 80, color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
        ),
        // ─────────────────────────────────────────────────────────

        // ── FITUR: JUDUL ─────────────────────────────────────────

        title: Text(
          article.title,                   // ← EDIT: .title
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        // ─────────────────────────────────────────────────────────

     
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              article.newsSite,
              article.extra('nickname'),    
              article.extra('rating'),
            ].where((s) => s.isNotEmpty).join('\n'),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        // ─────────────────────────────────────────────────────────


        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(article: article), 
          ),
        ),
      ),
    );
  }
}
