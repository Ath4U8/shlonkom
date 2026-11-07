import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
  runApp(const ShlonkomIQApp());
}

const Color kBlue = Color(0xFF0B4ED8);
const Color kDarkBlue = Color(0xFF0A2E8A);
const Color kGreen = Color(0xFF00C950);
const Color kOrange = Color(0xFFFF8C00);

// كلمات الاستعادة - عراقية
const List<String> kRecoveryWords = [
  'عراق',
  'دجلة',
  'فرات',
  'بابل',
  'سومر',
  'اشور',
  'بغداد',
  'بصرة',
  'موصل',
  'كربلاء',
  'نجف',
  'اربيل',
  'كركوك',
  'انبار',
  'ديالى',
  'واسط',
  'مثنى',
  'ديوانية',
  'بابل2',
  'صلاح',
  'ناصرية',
  'عمارة',
  'سماوة',
  'حلة',
];

String sha256Hash(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

// توليد كود 10 ارقام من يوزر + باسورد + بصمة جهاز
String generateCode10({
  required String username,
  required String password,
  required String deviceHash,
}) {
  final raw = '$username|$password|$deviceHash|ShlonkomIQ-Salt-2026';
  final hash = sha256Hash(raw);
  // ناخذ ارقام فقط من الهاش
  String digits = '';
  for (int i = 0; i < hash.length && digits.length < 10; i++) {
    final c = hash[i];
    if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
      digits += c;
    } else {
      // نحول الحرف لرقم
      digits += (c.codeUnitAt(0) % 10).toString();
    }
  }
  while (digits.length < 10) {
    digits += Random().nextInt(10).toString();
  }
  digits = digits.substring(0, 10);
  if (digits.startsWith('0')) {
    digits = '1' + digits.substring(1);
  }
  return digits;
}

List<String> generateRecovery12() {
  final rnd = Random();
  final list = <String>[];
  final copy = List<String>.from(kRecoveryWords);
  copy.shuffle(rnd);
  for (int i = 0; i < 12; i++) {
    list.add(copy[i]);
  }
  return list;
}

class ShlonkomIQApp extends StatelessWidget {
  const ShlonkomIQApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شلونكم - IQ',
      home: const SplashIQ(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}

class SplashIQ extends StatefulWidget {
  const SplashIQ({super.key});
  @override
  State<SplashIQ> createState() => _SplashIQState();
}

class _SplashIQState extends State<SplashIQ> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final hasCode = prefs.getString('iq_code') != null;
    if (hasCode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeIQ()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeIQ()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.shield, color: kBlue, size: 90),
            SizedBox(height: 12),
            Text(
              'شلونكم - IQ',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: kDarkBlue,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'كودك هو هويتك - وهويتك عراقية',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kDarkBlue,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'مجاني بالكامل',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kGreen,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: kBlue),
          ],
        ),
      ),
    );
  }
}

class WelcomeIQ extends StatelessWidget {
  const WelcomeIQ({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.shield, color: kBlue, size: 80),
            const Text(
              'شلونكم - IQ',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: kDarkBlue,
              ),
            ),
            const Text(
              'كودك هو هويتك - وهويتك عراقية',
              style: TextStyle(fontWeight: FontWeight.bold, color: kDarkBlue),
            ),
            const SizedBox(height: 20),
            const Text(
              'كود واحد 10 ارقام - ثابت - يفتح كل تطبيقات شبكة شلونكم',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterIQ()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'انشاء كودي - مجاني',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RestoreIQ()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'عندي مفتاح استعادة - استرجع كودي',
                  style: TextStyle(
                    color: kBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'حماية 5 طبقات: مفتاح استعادة + نسخة سحابية + بصمة جهاز مشفرة + IP مشفر + منع VPN بالاشياء الحساسة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
