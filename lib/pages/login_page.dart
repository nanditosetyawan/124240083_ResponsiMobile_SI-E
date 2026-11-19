

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_page.dart'; // ← EDIT: path ke RegisterPage kamu
import 'home_page.dart';     // ← EDIT: path ke HomePage kamu

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
 
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();


  bool _isLoading = false;


  Future<void> _doLogin() async {
    final String username = _usernameCtrl.text.trim();
    final String password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Username dan Password tidak boleh kosong.'); // ← EDIT: teks boleh diganti
      return;
    }

    setState(() => _isLoading = true);
    final String? error = await AuthService.login(username, password);
    setState(() => _isLoading = false);

    if (error != null) {
      _showErrorSnackBar(error); // ← FITUR: snackbar merah saat error
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(username: username), // ← EDIT: ganti nama class & parameter
        ),
      );
    }
  }


  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red, 
        duration: const Duration(seconds: 3),
      ),
    );
  }
  // ══════════════════════════════════════════════════════════════

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
        title: const Text(
          'Login'), 
        backgroundColor: const Color.fromARGB(255, 93, 207, 112), 
        foregroundColor: const Color.fromARGB(255, 172, 218, 187),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Judul halaman
            const Text(
              'Silakan Login', // ← EDIT: teks judul
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

           
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username', // ← EDIT: label
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
          

       
            TextField(
              controller: _passwordCtrl,
              obscureText: true, // ← JANGAN HAPUS untuk password
              decoration: const InputDecoration(
                labelText: 'Password', // ← EDIT: label
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _doLogin(),
            ),
            const SizedBox(height: 24),
       
            ElevatedButton(
              onPressed: _isLoading ? null : _doLogin, // null = disabled saat loading
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 141, 210, 165), // ← EDIT: warna tombol
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Login'), 
            ),


            const SizedBox(height: 16),

         
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()), // ← EDIT: nama class
                );
              },
              child: const Text(' ',), // ← EDIT: teks
            ),
         
          ],
        ),
      ),
    );
  }
}
