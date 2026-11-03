import 'dart:async';
import 'dart:math';
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

// دالة توليد كلمة سر داخلية ثابتة لتجنيب المستخدم إدخال أو حفظ أي كلمة مرور
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
      home: const LoginScreen(),
    );
  }
}

// -------------------------------------------------------------
// 1. شاشة تسجيل الدخول والواجهة الرئيسية (إيميل + اسم مستخدم فقط)
// -------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  void _msg(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF0F5132),
      ),
    );
  }

  // تسجيل الدخول بدون كلمة مرور
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final username = _usernameController.text.trim();

    if (email.isEmpty || username.isEmpty) {
      _msg('يرجى إدخال البريد الإلكتروني واسم المستخدم معاً', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();

      if (!doc.exists) {
        _msg('هذا الحساب غير مسجل، يرجى إنشاء حساب جديد أولاً', isError: true);
        return;
      }

      final data = doc.data()!;
      if (data['username'] != username) {
        _msg('اسم المستخدم غير متطابق مع هذا البريد الإلكتروني', isError: true);
        return;
      }

      // تسجيل دخول خلفي بدون علم المستخدم
      final secret = _generateInternalSecret(email);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: secret);
      } catch (_) {}

      final userPin = data['pin'] ?? '000000';

      _msg('تم تسجيل الدخول بنجاح! أهلاً بك');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainChatHomeScreen(
            myEmail: email,
            myUsername: username,
            myPin: userPin.toString(),
          ),
        ),
      );
    } catch (e) {
      _msg('تعذر تسجيل الدخول: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // استعادة الحساب بواسطة البريد الإلكتروني
  void _showRecoverDialog() {
    final TextEditingController recoverEmail = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('استعادة حسابي', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5132))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل بريدك الإلكتروني لاسترجاع اسم المستخدم ورقم التعريف الشخصي:', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
            const SizedBox(height: 15),
            TextField(
              controller: recoverEmail,
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
            onPressed: () async {
              final em = recoverEmail.text.trim().toLowerCase();
              if (em.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final doc = await FirebaseFirestore.instance.collection('users').doc(em).get();
                if (doc.exists) {
                  final uName = doc.data()?['username'] ?? '';
                  final uPin = doc.data()?['pin'] ?? '';

                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: em);
                  } catch (_) {}

                  _showRecoveryDetails(em, uName, uPin.toString());
                } else {
                  _msg('هذا البريد غير مسجل مسبقاً', isError: true);
                }
              } catch (e) {
                _msg('حدث خطأ أثناء الاسترجاع: $e', isError: true);
              }
            },
            child: const Text('استرجاع', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRecoveryDetails(String email, String username, String pin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('بيانات حسابك المسترجعة', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5132))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('البريد: $email', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('اسم المستخدم: $username', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 8),
            Text('رقم التعريف الشخصي: $pin', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
            onPressed: () {
              Navigator.pop(ctx);
              _emailController.text = email;
              _usernameController.text = username;
            },
            child: const Text('تعبئة والدخول', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06331D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F5132)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 330),
                  _inputCard(
                    controller: _emailController,
                    hint: 'البريد الإلكتروني',
                    icon: Icons.email_outlined,
                    type: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _inputCard(
                    controller: _usernameController,
                    hint: 'اسم المستخدم',
                    icon: Icons.person_outline,
                    type: TextInputType.text,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137547),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      icon: const Icon(Icons.login),
                      label: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VerifyEmailForRegistrationScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.95),
                        foregroundColor: const Color(0xFF0F5132),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('تسجيل جديد وتأكيد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  TextButton(
                    onPressed: _showRecoverDialog,
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
                  const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard({required TextEditingController controller, required String hint, required IconData icon, required TextInputType type}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF0F5132)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. خطوة تأكيد الإيميل لمرة واحدة فقط قبل التسجيل
// -------------------------------------------------------------
class VerifyEmailForRegistrationScreen extends StatefulWidget {
  const VerifyEmailForRegistrationScreen({super.key});

  @override
  State<VerifyEmailForRegistrationScreen> createState() => _VerifyEmailForRegistrationScreenState();
}

class _VerifyEmailForRegistrationScreenState extends State<VerifyEmailForRegistrationScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _emailSent = false;
  bool _isLoading = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sendVerification() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل بريداً إلكترونياً صالحاً')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
      if (doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا البريد مسجل مسبقاً، سجل الدخول مباشرة')));
        setState(() => _isLoading = false);
        return;
      }

      final secret = _generateInternalSecret(email);
      UserCredential userCred;
      try {
        userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: secret);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: secret);
        } else {
          rethrow;
        }
      }

      await userCred.user?.sendEmailVerification();

      setState(() {
        _emailSent = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Color(0xFF0F5132), content: Text('تم إرسال رابط التأكيد إلى بريدك الإلكتروني! تفقد صندوق الوارد أو البريد غير المرغوب فيه.')),
      );

      _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        await FirebaseAuth.instance.currentUser?.reload();
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.emailVerified) {
          timer.cancel();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CompleteRegistrationScreen(confirmedEmail: email),
              ),
            );
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء إرسال التأكيد: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد البريد الإلكتروني'), backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 80, color: Color(0xFF0F5132)),
            const SizedBox(height: 20),
            const Text(
              'التأكيد مطلوب لمرة واحدة فقط أثناء إنشاء الحساب',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_emailSent,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'أدخل بريدك الإلكتروني',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                prefixIcon: const Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 25),
            if (!_emailSent)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
                  onPressed: _isLoading ? null : _sendVerification,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('إرسال رابط تأكيد البريد'),
                ),
              ),
            if (_emailSent) ...[
              const Card(
                color: Color(0xFFE8F5E9),
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'تم إرسال رابط التحقق إلى بريدك الإلكتروني.\nيرجى فتح إيميلك والضغط على الرابط، وسيقوم التطبيق بنقلك تلقائياً للخطوة التالية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF137547), foregroundColor: Colors.white),
                  onPressed: () async {
                    await FirebaseAuth.instance.currentUser?.reload();
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null && user.emailVerified) {
                      _timer?.cancel();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompleteRegistrationScreen(confirmedEmail: _emailController.text.trim().toLowerCase()),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('لم يتم تأكيد الرابط بعد، يرجى الضغط عليه في رسالة بريدك الإلكتروني')),
                      );
                    }
                  },
                  child: const Text('أكدت الرابط، اضغط للمتابعة'),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. شاشة إنشاء الحساب (البريد ثابت + اسم مستخدم فريد + رقم PIN)
// -------------------------------------------------------------
class CompleteRegistrationScreen extends StatefulWidget {
  final String confirmedEmail;
  const CompleteRegistrationScreen({super.key, required this.confirmedEmail});

  @override
  State<CompleteRegistrationScreen> createState() => _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState extends State<CompleteRegistrationScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  String _generatePIN() {
    final random = Random();
    int number = 100000 + random.nextInt(900000);
    return number.toString();
  }

  Future<void> _createAccount() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المستخدم')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (query.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.red, content: Text('اسم المستخدم هذا محجوز لشخص آخر، اختر اسماً آخر')),
        );
        return;
      }

      final pin = _generatePIN();

      await FirebaseFirestore.instance.collection('users').doc(widget.confirmedEmail).set({
        'email': widget.confirmedEmail,
        'username': username,
        'pin': pin,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('pins').doc(pin).set({
        'pin': pin,
        'email': widget.confirmedEmail,
        'username': username,
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تم إنشاء الحساب بنجاح!', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('رقم التعريف الشخصي الخاص بك هو:', textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF0F5132).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: Text(pin, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3, color: Color(0xFF0F5132))),
              ),
              const SizedBox(height: 10),
              const Text('هذا الرقم مخصص لإضافة الأصدقاء والبحث عنك.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MainChatHomeScreen(
                      myEmail: widget.confirmedEmail,
                      myUsername: username,
                      myPin: pin,
                    ),
                  ),
                );
              },
              child: const Text('دخول للتطبيق', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء الحساب الدائم'), backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('البريد الإلكتروني المؤكد (ثابت غير قابل للتغيير):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: TextEditingController(text: widget.confirmedEmail),
              enabled: false,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 20),
            const Text('اختر اسم المستخدم (فريد وغير قابل للتكرار):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _usernameController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'مثال: atheer99',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _createAccount,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تأكيد وحجز الحساب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. الشاشة الرئيسية للتطبيق وقائمة جهات الاتصال
// -------------------------------------------------------------
class MainChatHomeScreen extends StatefulWidget {
  final String myEmail;
  final String myUsername;
  final String myPin;

  const MainChatHomeScreen({super.key, required this.myEmail, required this.myUsername, required this.myPin});

  @override
  State<MainChatHomeScreen> createState() => _MainChatHomeScreenState();
}

class _MainChatHomeScreenState extends State<MainChatHomeScreen> {
  void _showAddContactDialog() {
    final TextEditingController searchPinController = TextEditingController();
    Map<String, dynamic>? foundUser;
    bool isSearching = false;
    String searchError = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('إضافة جهة اتصال', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5132))),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('أضف رقم التعريف الشخصي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchPinController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(letterSpacing: 2, fontSize: 18, fontWeight: FontWeight.bold),
                    onChanged: (val) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'مثال: 111111',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
                      icon: const Icon(Icons.search),
                      label: isSearching
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('بحث'),
                      onPressed: searchPinController.text.trim().isEmpty || isSearching
                          ? null
                          : () async {
                              final pin = searchPinController.text.trim();
                              if (pin == widget.myPin) {
                                setDialogState(() {
                                  searchError = 'هذا هو رقم التعريف الشخصي الخاص بك!';
                                  foundUser = null;
                                });
                                return;
                              }

                              setDialogState(() {
                                isSearching = true;
                                searchError = '';
                                foundUser = null;
                              });

                              try {
                                final doc = await FirebaseFirestore.instance.collection('pins').doc(pin).get();
                                if (doc.exists && doc.data() != null) {
                                  setDialogState(() {
                                    foundUser = doc.data()!;
                                    isSearching = false;
                                  });
                                } else {
                                  setDialogState(() {
                                    searchError = 'لم يتم العثور على مشترك بهذا الرقم';
                                    isSearching = false;
                                  });
                                }
                              } catch (e) {
                                setDialogState(() {
                                  searchError = 'خطأ أثناء البحث';
                                  isSearching = false;
                                });
                              }
                            },
                    ),
                  ),
                  if (searchError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(searchError, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                  if (foundUser != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green)),
                      child: Column(
                        children: [
                          Text('اسم المستخدم: ${foundUser!['username']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('رقم التعريف الشخصي: ${foundUser!['pin']}', style: const TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF137547), foregroundColor: Colors.white),
                            icon: const Icon(Icons.person_add),
                            label: const Text('تثبيت كجهة اتصال'),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.myEmail)
                                  .collection('contacts')
                                  .doc(foundUser!['pin'])
                                  .set(foundUser!);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تثبيت جهة الاتصال بنجاح')));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      appBar: AppBar(
        title: Column(
          children: [
            const Text('شلونكم', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
            Text('رقمي الشخصي: ${widget.myPin}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0F5132),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.myEmail).collection('contacts').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('لا توجد جهات اتصال مثبتة بعد', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('اضغط على "إضافة جهة اتصال" في الأسفل', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final contact = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const CircleAvatar(backgroundColor: Color(0xFF0F5132), child: Icon(Icons.person, color: Colors.white)),
                title: Text(contact['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('رقم التعريف: ${contact['pin']}', style: const TextStyle(color: Color(0xFF0F5132))),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatConversationScreen(
                        friendUsername: contact['username'],
                        friendPin: contact['pin'],
                        myUsername: widget.myUsername,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        backgroundColor: const Color(0xFF0F5132),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('إضافة جهة اتصال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. شاشة الدردشة والمحادثة مع الصديق
// -------------------------------------------------------------
class ChatConversationScreen extends StatelessWidget {
  final String friendUsername;
  final String friendPin;
  final String myUsername;

  const ChatConversationScreen({
    super.key,
    required this.friendUsername,
    required this.friendPin,
    required this.myUsername,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F5132),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(friendUsername, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'رقم التعريف الشخصي: $friendPin',
              style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                'المحادثة مع $friendUsername\n(رقم التعريف الشخصي: $friendPin)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF0F5132)), onPressed: () {}),
                const Expanded(
                  child: TextField(
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(hintText: 'اكتب رسالة...', border: InputBorder.none),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
