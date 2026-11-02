import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShlonkomApp());
}

class ShlonkomApp extends StatelessWidget {
  const ShlonkomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شلونكم',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const ShlonkomHome(),
    );
  }
}

class ShlonkomHome extends StatelessWidget {
  const ShlonkomHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00C853),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              'شلونكم',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              'اهلا بيك بتطبيق شلونكم',
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Color(0xFF00C853)),
              child: const Text('ابدأ الدردشة'),
            ),
          ],
        ),
      ),
    );
  }
}
