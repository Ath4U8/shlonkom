import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_view/photo_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init: $e');
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ShlonkomApp());
}

String _generateInternalSecret(String email) {
  return "Shlonkom_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}_2026";
}

class ShlonkomApp extends StatelessWidget {
  const ShlonkomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شلونكم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F5132)),
        useMaterial3: true,
      ),
      home: const AutoLoginSplash(),
    );
  }
}

// -------------------------------------------------------------
// التحقق من الجلسة وفحص شرط الـ 6 أيام
// -------------------------------------------------------------
class AutoLoginSplash extends StatefulWidget {
  const AutoLoginSplash({super.key});

  @override
  State<AutoLoginSplash> createState() => _AutoLoginSplashState();
}

class _AutoLoginSplashState extends State<AutoLoginSplash> {
  @override
  void initState() {
    super.initState();
    _checkDeviceSession();
  }

  Future<void> _checkDeviceSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedUsername = prefs.getString('saved_username');
    final savedPin = prefs.getString('saved_pin');
    final lastActiveMillis = prefs.getInt('last_active_time') ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    const sixDaysMillis = 6 * 24 * 60 * 60 * 1000;

    if (savedEmail != null && savedUsername != null && savedPin != null) {
      if (lastActiveMillis > 0 && (now - lastActiveMillis) > sixDaysMillis) {
        await prefs.remove('saved_email');
        await prefs.remove('saved_username');
        await prefs.remove('saved_pin');

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ReturningLoginScreen(lastEmail: savedEmail),
            ),
          );
        }
        return;
      }

      await prefs.setInt('last_active_time', now);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainChatHomeScreen(
              myEmail: savedEmail,
              myUsername: savedUsername,
              myPin: savedPin,
            ),
          ),
          (route) => false,
        );
        return;
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegisterWithEmailScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F5132),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// -------------------------------------------------------------
// 1. شاشة تسجيل جديد بالإيميل فقط (لأول مرة)
// -------------------------------------------------------------
class RegisterWithEmailScreen extends StatefulWidget {
  const RegisterWithEmailScreen({super.key});

  @override
  State<RegisterWithEmailScreen> createState() => _RegisterWithEmailScreenState();
}

class _RegisterWithEmailScreenState extends State<RegisterWithEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  String _generateOtp() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  void _sendOtpCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل بريداً إلكترونياً صالحاً')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final otp = _generateOtp();

      await FirebaseFirestore.instance.collection('otp_codes').doc(email).set({
        'code': otp,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final secret = _generateInternalSecret(email);
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: secret);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: secret);
        }
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(email: email, sentOtp: otp),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء إرسال الرمز: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('تسجيل حساب جديد', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 45,
              backgroundColor: const Color(0xFF0F5132).withOpacity(0.08),
              child: const Icon(Icons.mark_email_unread_outlined, size: 50, color: Color(0xFF0F5132)),
            ),
            const SizedBox(height: 25),
            const Text(
              'أدخل بريدك الإلكتروني لتصلك رسالة التأكيد ورمز التحقق (OTP):',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'name@example.com',
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0F5132), width: 2)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF137547), width: 2.5)),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturningLoginScreen()));
              },
              child: const Text('لديك حساب مسبقاً؟ تسجيل الدخول برقم التعريف', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F5132),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: _isLoading ? null : _sendOtpCode,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال كود التأكيد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. شاشة التحقق من كود الـ OTP
// -------------------------------------------------------------
class OtpVerificationScreen extends StatelessWidget {
  final String email;
  final String sentOtp;

  const OtpVerificationScreen({super.key, required this.email, required this.sentOtp});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من الرمز')),
      body: Center(
        child: Text('شاشة التحقق للإيميل: $email'),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. شاشة تسجيل الدخول للعائدين
// -------------------------------------------------------------
class ReturningLoginScreen extends StatelessWidget {
  final String? lastEmail;

  const ReturningLoginScreen({super.key, this.lastEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Center(
        child: Text('شاشة العائدين - الإيميل الأخير: ${lastEmail ?? "غير متوفر"}'),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. الشاشة الرئيسية للدردشة
// -------------------------------------------------------------
class MainChatHomeScreen extends StatelessWidget {
  final String myEmail;
  final String myUsername;
  final String myPin;

  const MainChatHomeScreen({
    super.key,
    required this.myEmail,
    required this.myUsername,
    required this.myPin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية')),
      body: Center(
        child: Text('مرحباً بك يا $myUsername'),
      ),
    );
  }
}
