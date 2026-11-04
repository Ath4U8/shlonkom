import 'dart:async';
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

String _generateUniquePin() {
  final random = Random();
  return (100000 + random.nextInt(900000)).toString();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل بريداً إلكترونياً صالحاً')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('رمز التحقق الخاص بك هو: $otp'),
            duration: const Duration(seconds: 8),
            backgroundColor: Colors.green[800],
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(email: email, sentOtp: otp),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء إرسال الرمز: $e')),
        );
      }
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
  bool _isLoading = false;

  void _verifyOtp() async {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رمز التحقق المكون من 6 أرقام')),
      );
      return;
    }

    if (enteredOtp == widget.sentOtp) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CreateProfileScreen(email: widget.email),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز التحقق غير صحيح، حاول مرة أخرى')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('التحقق من الرمز', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F5132)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'تم إرسال رمز التحقق إلى بريدك الإلكتروني.\nأدخل الرمز المكون من 6 أرقام أدناه:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '123456',
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0F5132), width: 2)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF137547), width: 2.5)),
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
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تأكيد الرمز والمتابعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
// 3. شاشة إنشاء الملف الشخصي (الاسم، اسم المستخدم، الصورة، الـ PIN التلقائي)
// -------------------------------------------------------------
class CreateProfileScreen extends StatefulWidget {
  final String email;

  const CreateProfileScreen({super.key, required this.email});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  late String _generatedPin;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generatedPin = _generateUniquePin();
    _usernameController.text = widget.email.split('@')[0];
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  void _saveProfileAndProceed() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();

    if (fullName.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.email).set({
        'email': widget.email,
        'fullName': fullName,
        'username': username,
        'pin': _generatedPin,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء حفظ البيانات: $e')),
        );
      }
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
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF0F5132).withOpacity(0.1),
                    backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                    child: _selectedImage == null
                        ? const Icon(Icons.person, size: 60, color: Color(0xFF0F5132))
                        : null,
                  ),
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF0F5132),
                    child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF0F5132)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                prefixIcon: Icon(Icons.alternate_email, color: Color(0xFF0F5132)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF0F5132).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0F5132).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('رقم التعريف الشخصي (PIN) الخاص بك:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  const SizedBox(height: 5),
                  Text(_generatedPin, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 4)),
                  const SizedBox(height: 5),
                  const Text('ملاحظة: هذا الرقم ثابت وبمثابة رقم هاتفك الدائم داخل التطبيق.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F5132),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: _isLoading ? null : _saveProfileAndProceed,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('حفظ والدخول والتفعيل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
// 4. شاشة تسجيل الدخول للعائدين (مع زر "نسيت بياناتك؟")
// -------------------------------------------------------------
class ReturningLoginScreen extends StatefulWidget {
  final String? lastEmail;

  const ReturningLoginScreen({super.key, this.lastEmail});

  @override
  State<ReturningLoginScreen> createState() => _ReturningLoginScreenState();
}

class _ReturningLoginScreenState extends State<ReturningLoginScreen> {
  late TextEditingController _emailController;
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.lastEmail ?? '');
  }

  void _loginUser() async {
    final email = _emailController.text.trim().toLowerCase();
    final pin = _pinController.text.trim();

    if (email.isEmpty || pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال البريد ورقم الـ PIN المكون من 6 أرقام')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();

      if (doc.exists && doc.data()?['pin'] == pin) {
        final username = doc.data()?['username'] ?? email.split('@')[0];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_pin', pin);
        await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => MainChatHomeScreen(
                myEmail: email,
                myUsername: username,
                myPin: pin,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('بيانات الدخول غير صحيحة')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final forgotEmailController = TextEditingController();
    final forgotOtpController = TextEditingController();
    String? generatedOtp;
    bool otpSent = false;
    bool otpVerified = false;
    String? retrievedPin;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('استعادة البيانات', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!otpSent) ...[
                    const Text('أدخل بريدك الإلكتروني لاستعادة رقم التعريف الخاص بك:'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: forgotEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    ),
                  ] else if (otpSent && !otpVerified) ...[
                    Text('تم إرسال رمز الـ OTP إلى: ${forgotEmailController.text}'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: forgotOtpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'رمز التحقق (OTP)'),
                    ),
                  ] else if (otpVerified) ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 50),
                    const SizedBox(height: 10),
                    Text('البريد: ${forgotEmailController.text}'),
                    const SizedBox(height: 5),
                    Text('رقم PIN الخاص بك: $retrievedPin', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F5132))),
                  ],
                ],
              ),
              actions: [
                if (!otpSent)
                  ElevatedButton(
                    onPressed: () async {
                      final email = forgotEmailController.text.trim().toLowerCase();
                      if (email.contains('@')) {
                        generatedOtp = (100000 + Random().nextInt(900000)).toString();
                        setDialogState(() {
                          otpSent = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('رمز الـ OTP للاستعادة: $generatedOtp')),
                        );
                      }
                    },
                    child: const Text('إرسال الرمز'),
                  )
                else if (otpSent && !otpVerified)
                  ElevatedButton(
                    onPressed: () async {
                      if (forgotOtpController.text.trim() == generatedOtp) {
                        final email = forgotEmailController.text.trim().toLowerCase();
                        final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
                        if (doc.exists) {
                          setDialogState(() {
                            retrievedPin = doc.data()?['pin'] ?? 'غير متوفر';
                            otpVerified = true;
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('الحساب غير موجود')),
                          );
                        }
                      }
                    },
                    child: const Text('تأكيد الرمز'),
                  )
                else if (otpVerified)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
                    onPressed: () {
                      _emailController.text = forgotEmailController.text.trim();
                      _pinController.text = retrievedPin ?? '';
                      Navigator.pop(context);
                    },
                    child: const Text('تعبئة بعدها دخول'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('تسجيل الدخول', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF0F5132)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'رقم التعريف الشخصي (PIN)',
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF0F5132)),
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text('نسيت بياناتك؟', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
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
                onPressed: _isLoading ? null : _loginUser,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تسجيل الدخول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
// 5. الشاشة الرئيسية للدردشة (مع حقل إضافة صديق بالـ PIN وحذف زر الخروج الخاطئ)
// -------------------------------------------------------------
class MainChatHomeScreen extends StatefulWidget {
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
  State<MainChatHomeScreen> createState() => _MainChatHomeScreenState();
}

class _MainChatHomeScreenState extends State<MainChatHomeScreen> {
  final TextEditingController _friendPinController = TextEditingController();
  bool _isSearching = false;

  void _searchAndAddFriend() async {
    final targetPin = _friendPinController.text.trim();
    if (targetPin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رقم PIN صحيح مكون من 6 أرقام')),
      );
      return;
    }

    if (targetPin == widget.myPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك إضافة نفسك كصديق')),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('pin', isEqualTo: targetPin)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final friendData = querySnapshot.docs.first.data();
        final friendEmail = friendData['email'];
        final friendName = friendData['username'] ?? 'صديق';

        if (mounted) {
          _friendPinController.clear();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IndividualChatScreen(
                myEmail: widget.myEmail,
                friendEmail: friendEmail,
                friendName: friendName,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم العثور على أي مستخدم بهذا الـ PIN')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء البحث: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterWithEmailScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // منع الخروج العشوائي عند الضغط على زر الرجوع في الهاتف
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // تم حذف سهم الرجوع المزعج تماماً
          title: Text('شلونكم - ${widget.myUsername}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: const Color(0xFF0F5132),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: _confirmLogout,
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة معلومات حسابي ورقم الـ PIN
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F5132).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF0F5132).withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Text('رقم التعريف الشخصي (PIN) الخاص بك:', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 5),
                    Text(widget.myPin, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 3)),
                    const SizedBox(height: 3),
                    const Text('شارك هذا الرقم مع أصدقائك ليتمكنوا من مراسلتك.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              
              // قسم إضافة صديق برقم الـ PIN
              const Text('إضافة صديق جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F5132))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _friendPinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'أدخل رقم PIN الخاص للصديق (6 أرقام)',
                        prefixIcon: Icon(Icons.person_add_alt_1, color: Color(0xFF0F5132)),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5132),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSearching ? null : _searchAndAddFriend,
                      child: _isSearching
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('بحث ومراسلة', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              
              // قائمة المحادثات
              const Text('المحادثات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F5132))),
              const SizedBox(height: 10),
              const Expanded(
                child: Center(
                  child: Text('لا توجد محادثات نشطة حالياً.\nأضف صديقاً باستخدام رقم الـ PIN أعلاه لبدء المراسلة!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 6. شاشة المحادثة الفردية وشريط المحادثة العلوي مع السمايل التفاعلي
// -------------------------------------------------------------
class IndividualChatScreen extends StatefulWidget {
  final String myEmail;
  final String friendEmail;
  final String friendName;

  const IndividualChatScreen({
    super.key,
    required this.myEmail,
    required this.friendEmail,
    required this.friendName,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> with WidgetsBindingObserver {
  bool _isFriendInChat = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _isFriendInChat = true);
    } else {
      setState(() => _isFriendInChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F5132),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(widget.friendName[0], style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.friendName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(
                      _isFriendInChat ? '🟢😄' : '💤😴',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isFriendInChat ? 'متواجد الآن' : 'غير متواجد',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Text('منطقة الرسائل والمحادثة التفاعلية'),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF0F5132),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () {},
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
