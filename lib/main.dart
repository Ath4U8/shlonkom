import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // تمديد الشاشة بالكامل ومنع الفراغ الأبيض السفلي
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

  // الانتقال للشاشة الرئيسية بعد نجاح الدخول
  void _navigateToHome(String userName, String userEmail) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(userName: userName, userEmail: userEmail),
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
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      final userId = userCredential.user?.uid ?? email.replaceAll('.', '_');

      // حفظ الحساب في Firestore
      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'uid': userId,
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showMessage('تم التسجيل بنجاح! أهلاً بك $name');
      _navigateToHome(name, email);
    } catch (e) {
      _showMessage('حدث خطأ أثناء التسجيل: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // تسجيل الدخول والانتقال فوراً للشاشة الرئيسية
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

      // التحقق من بيانات المستخدم من Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
      String displayName = name.isNotEmpty ? name : 'مستخدم شلونكم';

      if (doc.exists && doc.data() != null && doc.data()!['name'] != null) {
        displayName = doc.data()!['name'];
      }

      _showMessage('تم تسجيل الدخول بنجاح');
      _navigateToHome(displayName, email);
    } catch (e) {
      _showMessage('حدث خطأ أثناء تسجيل الدخول: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // نافذة استعادة الحساب
  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (context) {
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
                'أدخل بريدك الإلكتروني المسجل للتحقق من وجود الحساب واستعادته:',
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
              onPressed: () => Navigator.pop(context),
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
                Navigator.pop(context);

                try {
                  final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
                  if (doc.exists) {
                    final registeredName = doc.data()?['name'] ?? 'المستخدم';
                    _showMessage('تم العثور على الحساب باسم: $registeredName. يمكنك تسجيل الدخول الآن.');
                    _emailController.text = email;
                    _nameController.text = registeredName;
                  } else {
                    _showMessage('هذا البريد غير مسجل مسبقاً، يرجى الضغط على تسجيل جديد', isError: true);
                  }
                } catch (e) {
                  _showMessage('تعذر التحقق من الحساب: $e', isError: true);
                }
              },
              child: const Text('استعادة', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3B24),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // الخلفية الرئيسية ممتدة لكامل الأبعاد
          Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/background.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, err, st) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF06331D), Color(0xFF021B0F)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // تدرج لوني خفيف فوق الصورة لضمان وضوح الحقول
          Container(
            color: Colors.black.withOpacity(0.15),
          ),

          SafeArea(
            bottom: false,
            top: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 340),

                  // حقل البريد الإلكتروني
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

                  // زر الدخول الأخضر
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137547),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      icon: const Icon(Icons.login),
                      label: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'دخول',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // زر تسجيل جديد وتأكيد الأبيض
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.95),
                        foregroundColor: const Color(0xFF0F5132),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text(
                        'تسجيل جديد وتأكيد',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
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

// الشاشة الرئيسية للتطبيق التي يفتح عليها المستخدم فور الدخول
class HomeScreen extends StatelessWidget {
  final String userName;
  final String userEmail;

  const HomeScreen({super.key, required this.userName, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شلونكم', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F5132),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF0F5132), size: 90),
              const SizedBox(height: 20),
              Text(
                'أهلاً بك، $userName!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F5132)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                userEmail,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 30),
              const Text(
                'تم تسجيل دخولك بنجاح في تطبيق شلونكم.',
                style: TextStyle(fontSize: 15, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
