.
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
      // فحص إذا ترك التطبيق أكثر من 6 أيام
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

      // تجديد توقيت آخر نشاط والدخول المباشر
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
class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String sentOtp;

  const OtpVerificationScreen({super.key, required this.email, required this.sentOtp});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          backgroundColor: const Color(0xFF0F5132),
          content: Text(
            'رمز التحقق الخاص بك (OTP) هو: ${widget.sentOtp}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      );
    });
  }

  void _verifyOtp() async {
    final entered = _otpController.text.trim();
    if (entered != widget.sentOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text('كود التحقق غير صحيح، يرجى إعادة المحاولة')),
      );
      return;
    }

    setState(() => _isChecking = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.email).get();

      if (doc.exists && doc.data()?['username'] != null) {
        final data = doc.data()!;
        final username = data['username'];
        final pin = (data['pin'] ?? '000000').toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', widget.email);
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_pin', pin);
        await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => MainChatHomeScreen(myEmail: widget.email, myUsername: username, myPin: pin),
),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SetupUserProfileScreen(email: widget.email),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('تأكيد رمز التحقق (OTP)', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F5132)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            Text(
              'أدخل الكود المكوّن من 6 أرقام المرسل إلى:\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF0F5132)),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '------',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0F5132), width: 2)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF137547), width: 2.5)),
              ),
              onChanged: (val) {
                if (val.length == 6) _verifyOtp();
              },
            ),
            const SizedBox(height: 30),
            if (_isChecking) const CircularProgressIndicator(color: Color(0xFF0F5132)),
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
                onPressed: _isChecking ? null : _verifyOtp,
                child: const Text('تأكيد والمتابعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. شاشة إنشاء الحساب: الاسم، الصورة، و PIN ثابت كالهاتف
// -------------------------------------------------------------
class SetupUserProfileScreen extends StatefulWidget {
  final String email;
  const SetupUserProfileScreen({super.key, required this.email});

  @override
  State<SetupUserProfileScreen> createState() => _SetupUserProfileScreenState();
}

class _SetupUserProfileScreenState extends State<SetupUserProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  late String _generatedPin;
  String? _avatarBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generatedPin = (100000 + Random().nextInt(900000)).toString();
  }
Future<void> _pickAvatar() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 30);
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      setState(() {
        _avatarBase64 = base64Encode(bytes);
      });
    }
  }

  void _completeRegistration() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();

    if (fullName.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة الاسم الكامل واسم المستخدم')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.email).set({
        'email': widget.email,
        'fullName': fullName,
        'username': username,
        'pin': _generatedPin,
        'avatar': _avatarBase64 ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('pins').doc(_generatedPin).set({
        'pin': _generatedPin,
        'email': widget.email,
        'username': username,
        'fullName': fullName,
        'avatar': _avatarBase64 ?? '',
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', widget.email);
      await prefs.setString('saved_username', username);
      await prefs.setString('saved_pin', _generatedPin);
      await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainChatHomeScreen(
              myEmail: widget.email,
              myUsername: username,
              myPin: _generatedPin,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('إعداد الملف الشخصي', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF0F5132).withOpacity(0.1),
                    backgroundImage: _avatarBase64 != null ? MemoryImage(base64Decode(_avatarBase64!)) : null,
                    child: _avatarBase64 == null ? const Icon(Icons.person, size: 60, color: Color(0xFF0F5132)) : null,
                  ),
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF0F5132),
                    child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  )
                ],
              ),
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade300)),
child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_generatedPin, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 2)),
                  const Text('رقم التعريف الشخصي (ثابت كالهاتف):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F5132))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _fullNameController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF0F5132)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _usernameController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'اسم المستخدم الفريد (Username)',
                prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF0F5132)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F5132),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: _isLoading ? null : _completeRegistration,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('إتمام الحساب والدخول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. تسجيل الدخول عند العودة بعد 6 أيام (بالبريد ورقم التعريف الشخصي)
// -------------------------------------------------------------
class ReturningLoginScreen extends StatefulWidget {
  final String? lastEmail;
  const ReturningLoginScreen({super.key, this.lastEmail});

  @override
  State<ReturningLoginScreen> createState() => _ReturningLoginScreenState();
}

class _ReturningLoginScreenState extends State<ReturningLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.lastEmail != null) {
      _emailController.text = widget.lastEmail!;
    }
  }

  void _login() async {
    final email = _emailController.text.trim().toLowerCase();
    final pin = _pinController.text.trim();

    if (email.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل البريد ورقم التعريف الشخصي')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحساب غير موجود، يرجى التسجيل أولاً')));
        return;
      }

      final data = doc.data()!;
      if (data['pin'] != pin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم التعريف الشخصي غير صحيح')));
        return;
      }
final username = data['username'] ?? '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_username', username);
      await prefs.setString('saved_pin', pin);
      await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainChatHomeScreen(myEmail: email, myUsername: username, myPin: pin),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // شاشة زر النسيان واسترجاع البيانات بـ OTP 6 أرقام
  void _openForgotDialog() {
    final TextEditingController recoverEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('استعادة الحساب', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5132))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل بريدك الإلكتروني لإرسال كود التحقق (OTP) واستعادة رقم التعريف الشخصي:', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
            const SizedBox(height: 15),
            TextField(
              controller: recoverEmailController,
              keyboardType: TextInputType.emailAddress,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'name@example.com',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                prefixIcon: const Icon(Icons.email, color: Color(0xFF0F5132)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
            onPressed: () async {
              final em = recoverEmailController.text.trim().toLowerCase();
              if (em.isEmpty) return;
              Navigator.pop(ctx);

              final doc = await FirebaseFirestore.instance.collection('users').doc(em).get();
              if (!doc.exists) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا البريد غير مسجل مسبقاً')));
                return;
              }

              final otp = (100000 + Random().nextInt(900000)).toString();
              await FirebaseFirestore.instance.collection('otp_codes').doc(em).set({'code': otp});

              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecoveryOtpVerifyScreen(
                      email: em,
                      sentOtp: otp,
                      onAutoFill: (userEmail, userPin) {
                        _emailController.text = userEmail;
                        _pinController.text = userPin;
                        _login();
                      },
                    ),
                  ),
                );
              }
            },
            child: const Text('إرسال الرمز', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('تسجيل الدخول', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)),
backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            const Text(
              'نظراً لمرور أكثر من 6 أيام على عدم فتح التطبيق، يرجى تأكيد الدخول ببريدك ورقم التعريف الشخصي:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0F5132)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'رقم التعريف الشخصي (PIN)',
                prefixIcon: const Icon(Icons.tag, color: Color(0xFF0F5132)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openForgotDialog,
                child: const Text('نسيت بياناتك؟ استعادة برمز OTP', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
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
                onPressed: _isLoading ? null : _login,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('دخول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// التحقق من OTP عند استرجاع البيانات المنسية
// -------------------------------------------------------------
class RecoveryOtpVerifyScreen extends StatefulWidget {
  final String email;
  final String sentOtp;
  final Function(String email, String pin) onAutoFill;

  const RecoveryOtpVerifyScreen({super.key, required this.email, required this.sentOtp, required this.onAutoFill});

  @override
  State<RecoveryOtpVerifyScreen> createState() => _RecoveryOtpVerifyScreenState();
}

class _RecoveryOtpVerifyScreenState extends State<RecoveryOtpVerifyScreen> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          backgroundColor: const Color(0xFF0F5132),
          content: Text(
            'رمز استعادة الحساب هو: ${widget.sentOtp}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      );
    });
  }
void _verifyRecoveryOtp() async {
    final entered = _otpController.text.trim();
    if (entered != widget.sentOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز التأكيد غير صحيح')));
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.email).get();
    if (doc.exists) {
      final pin = (doc.data()?['pin'] ?? '').toString();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('بيانات حسابك المسترجعة', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('البريد: ${widget.email}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('رقم التعريف الشخصي: $pin', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  widget.onAutoFill(widget.email, pin);
                },
                child: const Text('تعبئة بعدها دخول', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('تأكيد رمز الاستعادة'), backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F5132), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('أدخل الرمز المكوّن من 6 أرقام لتأكيد الاستعادة:', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 35),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF0F5132)),
              decoration: const InputDecoration(counterText: '', hintText: '------'),
              onChanged: (val) {
                if (val.length == 6) _verifyRecoveryOtp();
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
                onPressed: _verifyRecoveryOtp,
                child: const Text('تأكيد وإظهار البيانات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. الشاشة الرئيسية: جهات الاتصال والمحادثات
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
  StreamSubscription? _callSubscription;
  StreamSubscription? _messagesNotificationSubscription;
@override
  void initState() {
    super.initState();
    _listenForCalls();
    _listenForIncomingMessages();
    _touchActivity();
  }

  // تحديث وقت النشاط باستمرار لضمان احتساب الـ 6 أيام بدقة
  void _touchActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _messagesNotificationSubscription?.cancel();
    super.dispose();
  }

  void _listenForIncomingMessages() {
    _messagesNotificationSubscription = FirebaseFirestore.instance
        .collectionGroup('messages')
        .where('targetPin', isEqualTo: widget.myPin)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.vibrate();
        }
      }
    });
  }

  void _listenForCalls() {
    _callSubscription = FirebaseFirestore.instance
        .collection('active_calls')
        .where('targetPin', isEqualTo: widget.myPin)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final callId = change.doc.id;
          final callerName = data['callerName'] ?? 'صديق';
          final isVideo = data['isVideo'] ?? false;

          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.vibrate();

          _showIncomingCallDialog(callId, callerName, isVideo);
        }
      }
    });
  }

  void _showIncomingCallDialog(String callId, String callerName, bool isVideo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF042414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isVideo ? 'مكالمة فيديو واردة...' : 'مكالمة صوتية واردة...', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 40, backgroundColor: const Color(0xFF0F5132), child: Icon(isVideo ? Icons.videocam : Icons.call, size: 45, color: Colors.white)),
            const SizedBox(height: 15),
            Text(callerName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'reject',
                backgroundColor: Colors.red,
                onPressed: () {
                  FirebaseFirestore.instance.collection('active_calls').doc(callId).update({'status': 'rejected'});
                  Navigator.pop(ctx);
                },
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
              FloatingActionButton(
                heroTag: 'accept',
                backgroundColor: Colors.green,
                onPressed: () {
                  FirebaseFirestore.instance.collection('active_calls').doc(callId).update({'status': 'connected'});
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveCallUI(callId: callId, friendName: callerName, isVideo: isVideo),
                    ),
                  );
                },
                child: const Icon(Icons.call, color: Colors.white),
              ),
            ],
          )
        ],
      ),
    );
  }
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
                  const Text('أدخل رقم التعريف الشخصي للصديق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                      label: isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('بحث'),
                      onPressed: searchPinController.text.trim().isEmpty || isSearching
                          ? null
                          : () async {
                              final pin = searchPinController.text.trim();
                              if (pin == widget.myPin) {
                                setDialogState(() {
                                  searchError = 'هذا هو رقمك الشخصي!';
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
                                    searchError = 'لم يتم العثور على هذا الرقم';
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
                          Text('الاسم: ${foundUser!['username']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('رقم التعريف: ${foundUser!['pin']}', style: const TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF137547), foregroundColor: Colors.white),
                            icon: const Icon(Icons.person_add),
                            label: const Text('تثبيت وبدء المحادثة فوراً'),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('users').doc(widget.myEmail).collection('contacts').doc(foundUser!['pin']).set(foundUser!);

                              final friendEmail = foundUser!['email'];
                              if (friendEmail != null && friendEmail.isNotEmpty) {
                                await FirebaseFirestore.instance.collection('users').doc(friendEmail).collection('contacts').doc(widget.myPin).set({
                                  'username': widget.myUsername,
                                  'email': widget.myEmail,
                                  'pin': widget.myPin,
                                });
                              }

                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإضافة بنجاح ويمكنكما التراسل الآن!')));
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

  String _getChatId(String pin1, String pin2) {
    List<String> pins = [pin1, pin2];
    pins.sort();
    return "${pins[0]}_${pins[1]}";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F5),
        appBar: AppBar(
          automaticallyImplyLeading: false,
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
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterWithEmailScreen()),
                  (route) => false,
                );
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
                final friendPin = contact['pin'] ?? '';
                final friendName = contact['username'] ?? '';
                final chatId = _getChatId(widget.myPin, friendPin);

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').where('senderPin', isEqualTo: friendPin).where('isRead', isEqualTo: false).snapshots(),
                  builder: (context, unreadSnapshot) {
                    final unreadCount = unreadSnapshot.hasData ? unreadSnapshot.data!.docs.length : 0;

                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Stack(
                        children: [
                          const CircleAvatar(backgroundColor: Color(0xFF0F5132), child: Icon(Icons.person, color: Colors.white)),
                          if (unreadCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            )
                        ],
                      ),
                      title: Text(friendName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text('رقم التعريف: $friendPin', style: const TextStyle(color: Color(0xFF0F5132))),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (unreadCount > 0)
Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(12)),
                              child: const Text('رسالة جديدة', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatConversationScreen(
                              myEmail: widget.myEmail,
                              myUsername: widget.myUsername,
                              myPin: widget.myPin,
                              friendEmail: contact['email'] ?? '',
                              friendUsername: friendName,
                              friendPin: friendPin,
                            ),
                          ),
                        );
                      },
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
      ),
    );
  }
}

// -------------------------------------------------------------
// 6. شاشة المحادثة: مع السمايل الأخضر التفاعلي (يضحك أو ينام)
// -------------------------------------------------------------
class ChatConversationScreen extends StatefulWidget {
  final String myEmail;
  final String myUsername;
  final String myPin;
  final String friendEmail;
  final String friendUsername;
  final String friendPin;

  const ChatConversationScreen({
    super.key,
    required this.myEmail,
    required this.myUsername,
    required this.myPin,
    required this.friendEmail,
    required this.friendUsername,
    required this.friendPin,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String get _chatId {
    List<String> pins = [widget.myPin, widget.friendPin];
    pins.sort();
    return "${pins[0]}_${pins[1]}";
  }

  @override
  void initState() {
    super.initState();
    _updatePresence(true);
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _updatePresence(false);
    super.dispose();
  }

  void _updatePresence(bool inChat) {
    FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('presence')
        .doc(widget.myPin)
        .set({'inChat': inChat, 'lastSeen': FieldValue.serverTimestamp()});
  }

  void _markMessagesAsRead() async {
    final query = await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').where('senderPin', isEqualTo: widget.friendPin).where('isRead', isEqualTo: false).get();

    for (var doc in query.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  void _sendTextMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').add({
      'sender': widget.myUsername,
      'senderPin': widget.myPin,
      'targetPin': widget.friendPin,
      'type': 'text',
      'content': text,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
Future<void> _pickAndSendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 35);
    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();
    final base64String = base64Encode(bytes);

    FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').add({
      'sender': widget.myUsername,
      'senderPin': widget.myPin,
      'targetPin': widget.friendPin,
      'type': 'image',
      'content': base64String,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickAndSendDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final base64Doc = base64Encode(bytes);
      final fileName = result.files.single.name;
      final extension = result.files.single.extension?.toLowerCase() ?? '';
      final isAudio = ['mp3', 'm4a', 'wav', 'aac', 'ogg'].contains(extension);

      FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').add({
        'sender': widget.myUsername,
        'senderPin': widget.myPin,
        'targetPin': widget.friendPin,
        'type': isAudio ? 'audio' : 'file',
        'fileName': fileName,
        'content': base64Doc,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void _startCall({required bool isVideo}) async {
    await Permission.microphone.request();
    if (isVideo) await Permission.camera.request();

    final callDoc = FirebaseFirestore.instance.collection('active_calls').doc();
    await callDoc.set({
      'callerPin': widget.myPin,
      'callerName': widget.myUsername,
      'targetPin': widget.friendPin,
      'isVideo': isVideo,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OutgoingRingingScreen(callId: callDoc.id, friendName: widget.friendUsername, isVideo: isVideo),
        ),
      );
    }
  }

  void _openFullScreenImage(String base64Content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('عرض الصورة'),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'حفظ في الجهاز',
                onPressed: () async {
                  try {
                    final bytes = base64Decode(base64Content);
                    final dir = Directory('/storage/emulated/0/Download');
                    if (await dir.exists()) {
                      final file = File('${dir.path}/shlonkom_${DateTime.now().millisecondsSinceEpoch}.jpg');
                      await file.writeAsBytes(bytes);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الصورة في مجلد التنزيلات (Download)')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنزيل الصورة')));
                  }
                },
              )
            ],
          ),
          body: PhotoView(
            imageProvider: MemoryImage(base64Decode(base64Content)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3.0,
          ),
        ),
      ),
    );
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F5132),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.friendUsername, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('رقم التعريف: ${widget.friendPin}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            // السمايل الأخضر التفاعلي (يضحك أو ينام)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('presence')
                  .doc(widget.friendPin)
                  .snapshots(),
              builder: (context, presenceSnap) {
                bool isFriendInChat = false;
                if (presenceSnap.hasData && presenceSnap.data!.exists) {
                  final pData = presenceSnap.data!.data() as Map<String, dynamic>?;
                  isFriendInChat = pData?['inChat'] ?? false;
                }

                if (isFriendInChat) {
                  return const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🟢😄', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 4),
                      Text('متصل وياك', style: TextStyle(fontSize: 11, color: Color(0xFFA3E635), fontWeight: FontWeight.bold)),
                    ],
                  );
                } else {
                  return const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('💤😴', style: TextStyle(fontSize: 15)),
                      SizedBox(width: 4),
                      Text('غائب', style: TextStyle(fontSize: 11, color: Colors.white60)),
                    ],
                  );
                }
              },
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.call, color: Colors.white), tooltip: 'اتصال صوتي', onPressed: () => _startCall(isVideo: false)),
          IconButton(icon: const Icon(Icons.videocam, color: Colors.white), tooltip: 'مكالمة فيديو', onPressed: () => _startCall(isVideo: true)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                _markMessagesAsRead();

                if (docs.isEmpty) {
                  return Center(child: Text('ابدأ المحادثة مع ${widget.friendUsername}', style: const TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg = docs[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderPin'] == widget.myPin;
                    final isRead = msg['isRead'] ?? false;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF137547) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildMessageContent(msg, isMe),
                            const SizedBox(height: 4),
                            if (isMe)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.done_all, size: 16, color: isRead ? const Color(0xFFA3E635) : Colors.white70),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF0F5132)), onPressed: _sendTextMessage),
                Expanded(
                  child: TextField(controller: _msgController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: InputBorder.none)),
                ),
                IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _pickAndSendDocument),
                IconButton(icon: const Icon(Icons.image, color: Colors.grey), onPressed: _pickAndSendImage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> msg, bool isMe) {
    final type = msg['type'] ?? 'text';
    final textColor = isMe ? Colors.white : Colors.black87;

    if (type == 'image') {
      try {
        final bytes = base64Decode(msg['content']);
        return GestureDetector(
          onTap: () => _openFullScreenImage(msg['content']),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image.memory(bytes, fit: BoxFit.cover, width: 220, height: 220),
                Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        );
      } catch (_) {
        return Text('فشل عرض الصورة', style: TextStyle(color: textColor));
      }
    } else if (type == 'audio') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.audiotrack, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(msg['fileName'] ?? 'ملف صوتي', style: TextStyle(color: textColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: Icon(Icons.play_circle_fill, color: textColor, size: 30),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استلام الملف الصوتي')));
            },
          )
        ],
      );
    } else if (type == 'file') {
return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(msg['fileName'] ?? 'مستند مرفق', style: TextStyle(color: textColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }

    return Text(msg['content'] ?? '', style: TextStyle(color: textColor, fontSize: 15));
  }
}

// -------------------------------------------------------------
// 7. شاشات المكالمات
// -------------------------------------------------------------
class OutgoingRingingScreen extends StatefulWidget {
  final String callId;
  final String friendName;
  final bool isVideo;

  const OutgoingRingingScreen({super.key, required this.callId, required this.friendName, required this.isVideo});

  @override
  State<OutgoingRingingScreen> createState() => _OutgoingRingingScreenState();
}

class _OutgoingRingingScreenState extends State<OutgoingRingingScreen> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance.collection('active_calls').doc(widget.callId).snapshots().listen((snap) {
      if (snap.exists) {
        final status = snap.data()?['status'];
        if (status == 'connected' && mounted) {
          _sub?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ActiveCallUI(callId: widget.callId, friendName: widget.friendName, isVideo: widget.isVideo),
            ),
          );
        } else if ((status == 'rejected' || status == 'ended') && mounted) {
          _sub?.cancel();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنهاء المكالمة')));
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF042414),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF0F5132),
                  child: Icon(widget.isVideo ? Icons.videocam : Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(widget.friendName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('جارٍ الاتصال والرنين...', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
            FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: () {
                FirebaseFirestore.instance.collection('active_calls').doc(widget.callId).update({'status': 'ended'});
                Navigator.pop(context);
              },
              child: const Icon(Icons.call_end, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class ActiveCallUI extends StatefulWidget {
  final String callId;
  final String friendName;
  final bool isVideo;

  const ActiveCallUI({super.key, required this.callId, required this.friendName, required this.isVideo});

  @override
  State<ActiveCallUI> createState() => _ActiveCallUIState();
}

class _ActiveCallUIState extends State<ActiveCallUI> {
  bool _isMuted = false;
  bool _isSpeaker = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance.collection('active_calls').doc(widget.callId).snapshots().listen((snap) {
      if (snap.exists && snap.data()?['status'] == 'ended' && mounted) {
        Navigator.pop(context);
      }
    });
  }
@override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF042414),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 50.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: const Color(0xFF0F5132),
                    child: Icon(widget.isVideo ? Icons.videocam : Icons.person, size: 65, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(widget.friendName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    widget.isVideo ? 'مكالمة فيديو متصلة' : 'مكالمة صوتية مباشرة متصلة',
                    style: const TextStyle(color: Color(0xFFA3E635), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 40,
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                  ),
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: () {
                      FirebaseFirestore.instance.collection('active_calls').doc(widget.callId).update({'status': 'ended'});
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                  ),
                  IconButton(
                    iconSize: 40,
                    icon: Icon(_isSpeaker ? Icons.volume_up : Icons.volume_down, color: Colors.white),
                    onPressed: () => setState(() => _isSpeaker = !_isSpeaker),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


