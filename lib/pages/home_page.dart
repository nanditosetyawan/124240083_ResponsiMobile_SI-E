
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';   // ← EDIT: path ke LoginPage
import 'list_page.dart';    // ← EDIT: path ke ListPage
import 'favorite_page.dart'; // ← EDIT: path ke FavoritePage

class HomePage extends StatelessWidget {

  final String username;
  const HomePage({super.key, required this.username});

  // FITUR: LOGOUT

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout(); // hapus sesi dari SharedPreferences

    if (!context.mounted) return;
    // pushAndRemoveUntil → hapus semua route di stack
    // Sehingga tombol back tidak bisa kembali ke HomePage setelah logout
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()), // ← EDIT: nama class
      (route) => false,
    );
  }
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // TAMPILKAN USERNAME DI APPBAR ───────────────
       
        title: Text('Hai, $username!'), // ← EDIT: format teks boleh diganti
        // ──────────────────────────────────────────────────────
        backgroundColor: const Color.fromARGB(255, 87, 181, 128), // ← EDIT: warna AppBar
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // Tombol Favourite di AppBar kanan (opsional, boleh dihapus)
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritePage()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // DAFTAR MENU 
          
            Expanded(
              child: ListView(
                children: [
                  // ── KARTU MENU 1 (terhubung ke ApiConfig.urls['menuuuuuuuuu makanannnn']) ──
                  _buildMenuCard(
                    context,
                    icon: Icons.newspaper,
                    title: 'Menu', // ← BOLEH EDIT (opsional): ubah nama menu sesuai API 1
                    subtitle: 'Masakan Wuenakk....', // ← BOLEH EDIT (opsional)
                    type: 'news', // ← JANGAN DIUBAH (harus sama dengan key di ApiConfig.urls)
                  ),
                  const SizedBox(height: 12),

              
                ],
              ),
            ),
     

    
            // FITUR: TOMBOL LOGOUT DI BAWAH
         
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _logout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,     // ← merah untuk logout
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Log Out', style: TextStyle(fontSize: 16)), // ← EDIT: teks
              ),
            ),
            const SizedBox(height: 8),
            // ══════════════════════════════════════════════════
          ],
        ),
      ),
    );
  }

 
  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String type, 
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 92, 192, 114).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color.fromARGB(255, 109, 199, 127), size: 28), // ← EDIT: warna ikon
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ),
        // Saat diklik → ke ListPage dengan type yang sesuai
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListPage(type: type), // ← EDIT: nama class ListPage
          ),
        ),
      ),
    );
  }
}
