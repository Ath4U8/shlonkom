import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // ملء كامل الشاشة وإلغاء الفراغ الأبيض خلف أشرطة النظام
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
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF0F5132),
      ),
    );
  }

  // الانتقال للشاشة الرئيسية مباشرة
  void _goToHome(String name, String email) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(userName: name, userEmail: email),
      ),
    );
  }

  // تسجيل حساب جديد
  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || name.isEmpty) {
      _showMessage('يرجى كتابة البريد الإلكتروني والاسم أولاً', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      // حفظ بيانات المستخدم
      FirebaseFirestore.instance.collection('users').doc(email).set({
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});

      _showMessage('تم التسجيل بنجاح! أهلاً بك $name');
      _goToHome(name, email);
    } catch (e) {
      _goToHome(name, email);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // تسجيل الدخول
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty) {
      _showMessage('يرجى إدخال البريد الإلكتروني للدخول', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      String displayName = name.isNotEmpty ? name : 'مستخدم شلونكم';

      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(email).get().timeout(const Duration(seconds: 3));
        if (doc.exists && doc.data()?['name'] != null) {
          displayName = doc.data()!['name'];
        }
      } catch (_) {}

      _showMessage('تم تسجيل الدخول بنجاح');
      _goToHome(displayName, email);
    } catch (e) {
      _goToHome(name.isNotEmpty ? name : 'مستخدم شلونكم', email);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // نافذة استعادة حسابي
  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'استعادة حسابي',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5132)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل بريدك الإلكتروني المسجل لاسترجاع بياناتك:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'البريد الإلكتروني',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0F5132)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F5132),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) {
                  _showMessage('يرجى كتابة البريد الإلكتروني', isError: true);
                  return;
                }
                Navigator.pop(ctx);

                try {
                  final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
                  if (doc.exists && doc.data() != null) {
                    final foundName = doc.data()?['name'] ?? 'مستخدم';
                    _emailController.text = email;
                    _nameController.text = foundName;
                    _showMessage('تم استرجاع الحساب باسم: $foundName');
                  } else {
                    _emailController.text = email;
                    _showMessage('تم تثبيت بريدك، يرجى كتابة اسمك واضغط تسجيل جديد وتأكيد');
                  }
                } catch (e) {
                  _emailController.text = email;
                  _showMessage('تم تثبيت بريدك، يمكنك المتابعة الآن');
                }
              },
              child: const Text('استعادة الآن', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06331D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // قراءة ملف الصورة الصحيح من assets/images/login_bg.png
          Image.asset(
            'assets/images/login_bg.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/app_icon.png',
              fit: BoxFit.contain,
            ),
          ),

          // واجهة الحقول والأزرار
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 330),

                  // حقل البريد
                  _buildInputField(
                    controller: _emailController,
                    hint: 'البريد الإلكتروني',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // حقل الاسم
                  _buildInputField(
                    controller: _nameController,
                    hint: 'الاسم',
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 20),

                  // زر الدخول
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137547),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      icon: const Icon(Icons.login),
                      label: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // زر تسجيل جديد وتأكيد
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.95),
                        foregroundColor: const Color(0xFF0F5132),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('تسجيل جديد وتأكيد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // زر استعادة حسابي
                  TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text(
                      'استعادة حسابي',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),
                  const Text(
                    'Designed by: Atheer Sami',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: const Color(0xFF0F5132)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String userName;
  final String userEmail;

  const HomeScreen({super.key, required this.userName, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      appBar: AppBar(
        title: const Text('شلونكم', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F5132),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFF0F5132),
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'أهلاً بك، $userName',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F5132)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userEmail,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                  ),
                  const Divider(height: 35),
                  const Text(
                    'تم تسجيل دخولك بنجاح في تطبيق شلونكم.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
