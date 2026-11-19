
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  
  Future<void> _doRegister() async {
    final String username = _usernameCtrl.text.trim();
    final String password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Username dan Password tidak boleh kosong.'); // ← EDIT: teks
      return;
    }
    if (password.length < 1) {
      _showErrorSnackBar('Password minimal 1 karakter.'); 
      return;
    }

    setState(() => _isLoading = true);
    final String? error = await AuthService.register(username, password);
    setState(() => _isLoading = false);

    if (error != null) {
      _showErrorSnackBar(error); // ← FITUR: snackbar merah saat error
    } else {
      if (!mounted) return;
      // Snackbar hijau untuk sukses (bukan merah)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registrasi berhasil! Silakan login.'), // ← EDIT: teks
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // kembali ke LoginPage
    }
  }

  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red, // ← INI YANG MEMBUAT MERAH
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'), // ← EDIT
        backgroundColor: const Color(0xFF5C6BC0), // ← EDIT: warna
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Daftar Akun Baru', // ← EDIT: teks judul
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username', // ← EDIT
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password', // ← EDIT
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _doRegister(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _doRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C6BC0), // ← EDIT: warna
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Daftar'), // ← EDIT: teks tombol
            ),
          ],
        ),
      ),
    );
  }
}
