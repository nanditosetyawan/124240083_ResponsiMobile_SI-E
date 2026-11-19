// ╔══════════════════════════════════════════════════════════════╗
// ║  FITUR: CEK LOGIN PERSIST DI STARTUP APP                    ║
// ║  FILE : main.dart                                            ║
// ║  COPY : Seluruh file ini                                     ║
// ║  EDIT : Import halaman LoginPage dan HomePage sesuai path-mu ║
// ╚══════════════════════════════════════════════════════════════╝
//
// KETENTUAN YANG DIPENUHI:
//   ✅ Login tersimpan di SharedPreferences — saat app dibuka ulang
//      tanpa logout, user langsung masuk ke HomePage (tidak perlu login lagi)
//
// ALUR:
//   App buka → FutureBuilder cek SharedPreferences
//     → ada username tersimpan → langsung ke HomePage
//     → tidak ada            → ke LoginPage

import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'pages/login_page.dart';  // ← EDIT: pastikan path-nya benar
import 'pages/home_page.dart';   // ← EDIT: pastikan path-nya benar

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ← WAJIB ADA saat ada async sebelum runApp
  await NotificationService.init();          // inisialisasi notifikasi lokal & minta izin Android 13+
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spaceflight News',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 245, 246, 248), // ← EDIT: ganti warna tema utama
        ),
        useMaterial3: true,
      ),

      // ══════════════════════════════════════════════════════════
      // FITUR: LOGIN PERSIST (tidak perlu login ulang jika belum logout)
      // COPY: bagian FutureBuilder ini — UNIVERSAL
      // EDIT:
      //   - Ganti 'HomePage(username: loggedInUser)' dengan halaman utama kamu
      //   - Parameter 'username' dikirim agar HomePage bisa tampilkan "Hai, {username}!"
      //   - Ganti 'LoginPage()' dengan halaman login kamu
      // ══════════════════════════════════════════════════════════
      home: FutureBuilder<String?>(
        future: AuthService.getLoggedInUser(), // baca SharedPreferences
        builder: (context, snapshot) {

          // Saat masih membaca SharedPreferences → tampilkan loading spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final String? loggedInUser = snapshot.data;

          if (loggedInUser != null && loggedInUser.isNotEmpty) {
            // ── Ada user tersimpan → langsung ke HomePage tanpa login lagi
            return HomePage(username: loggedInUser); // ← EDIT: ganti nama class & parameter
          } else {
            // ── Tidak ada user → ke LoginPage
            return const LoginPage(); // ← EDIT: ganti nama class jika beda
          }
        },
      ),
      // ══════════════════════════════════════════════════════════
    );
  }
}
