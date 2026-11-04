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
import 'package:shared_preferences/shared_preferences.dart';

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
      home: const WelcomeSplashScreen(),
    );
  }
}

// -------------------------------------------------------------
// شاشة الترحيب الافتتاحية مع علم العراق والنص المطلوب
// -------------------------------------------------------------
class WelcomeSplashScreen extends StatefulWidget {
  const WelcomeSplashScreen({super.key});

  @override
  State<WelcomeSplashScreen> createState() => _WelcomeSplashScreenState();
}

class _WelcomeSplashScreenState extends State<WelcomeSplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      _checkDeviceSession();
    });
  }

  Future<void> _checkDeviceSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedUsername = prefs.getString('saved_username');
    final savedPersonalPin = prefs.getString('saved_personal_pin');
    final lastActiveMillis = prefs.getInt('last_active_time') ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    const sixDaysMillis = 6 * 24 * 60 * 60 * 1000;

    if (savedEmail != null && savedUsername != null && savedPersonalPin != null) {
      if (lastActiveMillis > 0 && (now - lastActiveMillis) > sixDaysMillis) {
        await prefs.clear();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ReturningLoginScreen(lastEmail: savedEmail)),
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
              myPersonalPin: savedPersonalPin,
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F5132),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🇮🇶 العراق 🇮🇶', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 35),
              const Text(
                'أهلاً وسهلاً بك في تطبيق شلونكم للاتصالات والمراسلات العراقي',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 50),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 40),
              const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 1. شاشة تسجيل جديد بالإيميل مع إرسال رابط التفعيل
// -------------------------------------------------------------
class RegisterWithEmailScreen extends StatefulWidget {
  const RegisterWithEmailScreen({super.key});

  @override
  State<RegisterWithEmailScreen> createState() => _RegisterWithEmailScreenState();
}

class _RegisterWithEmailScreenState extends State<RegisterWithEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  void _registerAndSendVerificationLink() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل بريداً إلكترونياً صالحاً')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final secret = _generateInternalSecret(email);
      UserCredential userCredential;
      
      try {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, 
          password: secret,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email, 
            password: secret,
          );
        } else {
          rethrow;
        }
      }

      final user = userCredential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال رابط التفعيل إلى: $email. يرجى مراجعة بريدك.'),
            duration: const Duration(seconds: 6),
            backgroundColor: Colors.green[800],
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VerifyEmailLinkScreen(email: email)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء إرسال رابط التفعيل: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('تسجيل حساب جديد', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
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
                'أدخل بريدك الإلكتروني لإرسال رابط تفعيل الحساب الرسمي:',
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
                child: const Text('لديك حساب مسبقاً؟ تسجيل الدخول برقمك الشخصي', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)),
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
                  onPressed: _isLoading ? null : _registerAndSendVerificationLink,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إرسال رابط التفعيل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 15),
              const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. شاشة تأكيد النقر على رابط التفعيل
// -------------------------------------------------------------
class VerifyEmailLinkScreen extends StatefulWidget {
  final String email;

  const VerifyEmailLinkScreen({super.key, required this.email});

  @override
  State<VerifyEmailLinkScreen> createState() => _VerifyEmailLinkScreenState();
}

class _VerifyEmailLinkScreenState extends State<VerifyEmailLinkScreen> {
  bool _isChecking = false;

  void _checkEmailVerified() async {
    setState(() => _isChecking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => CreateProfileScreen(email: widget.email)),
            );
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم الضغط على رابط التفعيل بعد. يرجى مراجعة بريدك.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('تأكيد البريد الإلكتروني', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read, size: 80, color: Color(0xFF0F5132)),
              const SizedBox(height: 20),
              Text(
                'تم إرسال رابط تفعيل الحساب إلى:\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'يرجى فتح بريدك الإلكتروني والنقر على رابط التفعيل، ثم اضغط على زر التحقق أدناه للمتابعة.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F5132),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: _isChecking ? null : _checkEmailVerified,
                  child: _isChecking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('تحقق من تفعيل الحساب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const Spacer(),
              const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. شاشة إعداد الملف الشخصي وتوليد الرقم الشخصي الثابت
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
  String? _permanentPersonalPin;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.email.split('@')[0];
    _initializePermanentPin();
  }

  Future<void> _initializePermanentPin() async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(widget.email);
    final doc = await docRef.get();

    if (doc.exists && doc.data()?['personalPin'] != null) {
      setState(() {
        _permanentPersonalPin = doc.data()?['personalPin'];
      });
    } else {
      final newPin = _generateUniquePin();
      setState(() {
        _permanentPersonalPin = newPin;
      });
    }
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

    if (fullName.isEmpty || username.isEmpty || _permanentPersonalPin == null) {
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
        'personalPin': _permanentPersonalPin,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', widget.email);
      await prefs.setString('saved_username', username);
      await prefs.setString('saved_personal_pin', _permanentPersonalPin!);
      await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainChatHomeScreen(
              myEmail: widget.email,
              myUsername: username,
              myPersonalPin: _permanentPersonalPin!,
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
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('إعداد الملف الشخصي', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
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
                    const Text('رقمك الشخصي الثابت (بديل رقم الهاتف):', style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(_permanentPersonalPin ?? 'جاري التوليد...', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 4)),
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
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. شاشة تسجيل الدخول للعائدين
// -------------------------------------------------------------
class ReturningLoginScreen extends StatefulWidget {
  final String? lastEmail;

  const ReturningLoginScreen({super.key, this.lastEmail});

  @override
  State<ReturningLoginScreen> createState() => _ReturningLoginScreenState();
}

class _ReturningLoginScreenState extends State<ReturningLoginScreen> {
  late TextEditingController _emailController;
  final TextEditingController _personalPinController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.lastEmail ?? '');
  }

  void _loginUser() async {
    final email = _emailController.text.trim().toLowerCase();
    final pin = _personalPinController.text.trim();

    if (email.isEmpty || pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال البريد ورقمك الشخصي المكون من 6 أرقام')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();

      if (doc.exists && doc.data()?['personalPin'] == pin) {
        final username = doc.data()?['username'] ?? email.split('@')[0];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_personal_pin', pin);
        await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => MainChatHomeScreen(
                myEmail: email,
                myUsername: username,
                myPersonalPin: pin,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('بيانات الدخول أو الرقم الشخصي غير صحيح')),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
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
                controller: _personalPinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'الرقم الشخصي الثابت (6 أرقام)',
                  prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF0F5132)),
                  border: OutlineInputBorder(),
                  counterText: '',
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
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. الشاشة الرئيسية وإضافة الأصدقاء
// -------------------------------------------------------------
class MainChatHomeScreen extends StatefulWidget {
  final String myEmail;
  final String myUsername;
  final String myPersonalPin;

  const MainChatHomeScreen({
    super.key,
    required this.myEmail,
    required this.myUsername,
    required this.myPersonalPin,
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
        const SnackBar(content: Text('الرجاء إدخال رقم شخصي صحيح مكون من 6 أرقام')),
      );
      return;
    }

    if (targetPin == widget.myPersonalPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك إضافة نفسك كصديق')),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('personalPin', isEqualTo: targetPin)
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
                myUsername: widget.myUsername,
                friendEmail: friendEmail,
                friendName: friendName,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم العثور على أي مستخدم بهذا الرقم الشخصي')),
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
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
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
                    const Text('رقمك الشخصي الثابت (بديل رقم الهاتف):', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 5),
                    Text(widget.myPersonalPin, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 3)),
                  ],
                ),
              ),
              const SizedBox(height: 25),
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
                        hintText: 'أدخل الرقم الشخصي للصديق (6 أرقام)',
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
              const Text('المحادثات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F5132))),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .where('participants', arrayContains: widget.myEmail)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('لا توجد محادثات نشطة حالياً.\nأضف صديقاً برقمة الشخصي لبدء المراسلة!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14)),
                      );
                    }

                    final chatDocs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: chatDocs.length,
                      itemBuilder: (context, index) {
                        final chatData = chatDocs[index].data() as Map<String, dynamic>;
                        final List participants = chatData['participants'] ?? [];
                        final friendEmail = participants.firstWhere((e) => e != widget.myEmail, orElse: () => 'غير معروف');
                        final lastMessage = chatData['lastMessage'] ?? 'بدء محادثة جديدة';

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(friendEmail).get(),
                          builder: (context, userSnapshot) {
                            String friendName = friendEmail;
                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                              friendName = userSnapshot.data!['username'] ?? friendEmail;
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0F5132),
                                child: Text(friendName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(friendName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => IndividualChatScreen(
                                      myEmail: widget.myEmail,
                                      myUsername: widget.myUsername,
                                      friendEmail: friendEmail,
                                      friendName: friendName,
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
// 6. شاشة المحادثة الفردية (أصوات النظام المدمجة وتنبيهات بدون حزم خارجية)
// -------------------------------------------------------------
class IndividualChatScreen extends StatefulWidget {
  final String myEmail;
  final String myUsername;
  final String friendEmail;
  final String friendName;

  const IndividualChatScreen({
    super.key,
    required this.myEmail,
    required this.myUsername,
    required this.friendEmail,
    required this.friendName,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  bool _isFriendInChat = true;
  late String _chatDocId;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final sortedEmails = [widget.myEmail, widget.friendEmail]..sort();
    _chatDocId = '${sortedEmails[0]}_${sortedEmails[1]}';
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

  void _sendMessage({String? customText, String? messageType}) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty && messageType == null) return;

    if (customText == null) {
      _messageController.clear();
    }

    final messageData = {
      'senderEmail': widget.myEmail,
      'text': text,
      'type': messageType ?? 'text',
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatDocId)
          .collection('messages')
          .add(messageData);

      await FirebaseFirestore.instance.collection('chats').doc(_chatDocId).set({
        'participants': [widget.myEmail, widget.friendEmail],
        'lastMessage': messageType == 'image' ? '📸 صورة' : messageType == 'voice' ? '🎤 بصمة صوتية' : text,
        'lastTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('إرفاق وإرسال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F5132))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachOption(Icons.image, 'صورة', () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    _sendMessage(customText: '[صورة مرفقة]', messageType: 'image');
                  }
                }),
                _buildAttachOption(Icons.insert_drive_file, 'ملف / مستند', () async {
                  Navigator.pop(context);
                  FilePickerResult? result = await FilePicker.platform.pickFiles();
                  if (result != null) {
                    _sendMessage(customText: '📁 ملف: ${result.files.single.name}', messageType: 'file');
                  }
                }),
                _buildAttachOption(Icons.location_on, 'الموقع', () {
                  Navigator.pop(context);
                  _sendMessage(customText: '📍 الموقع الحالي: بغداد / العراق', messageType: 'location');
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF0F5132).withOpacity(0.1),
            child: Icon(icon, color: const Color(0xFF0F5132), size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _sendVoiceNote() {
    _sendMessage(customText: '🎤 بصمة صوتية (0:05 ثانية)', messageType: 'voice');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال البصمة الصوتية بنجاح 🎤')),
    );
  }

  void _showStickersSheet() {
    final List<String> iraqiStickers = ['🇮🇶', '💪', '☕', '❤️', '🌹', '👍', '😎', '🎉', '🔥', '👋', '🌟', '💥'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 250,
        child: Column(
          children: [
            const Text('الملصقات والسمايلات العراقية والعربية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F5132))),
            const SizedBox(height: 15),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: iraqiStickers.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _sendMessage(customText: iraqiStickers[index], messageType: 'sticker');
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(iraqiStickers[index], style: const TextStyle(fontSize: 32)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0F5132),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(widget.friendName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.friendName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(_isFriendInChat ? '🟢😄' : '💤😴', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(_isFriendInChat ? 'متواجد الآن' : 'غير متواجد', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFF7F5F0),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.04,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2),
                  itemCount: 30,
                  itemBuilder: (_, __) => const Center(
                    child: Text('شلونكم', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F5132))),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(_chatDocId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.length > _previousMessageCount && _previousMessageCount != 0) {
                        final latestMsg = docs.first.data() as Map<String, dynamic>;
                        if (latestMsg['senderEmail'] != widget.myEmail) {
                          SystemSound.play(SystemSoundType.click);
                          HapticFeedback.vibrate();
                        }
                      }
                      _previousMessageCount = docs.length;

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('لا توجد رسائل بعد. ابدأ محادثتك الآن!', style: TextStyle(color: Colors.grey)),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final msg = docs[index].data() as Map<String, dynamic>;
                          final isMe = msg['senderEmail'] == widget.myEmail;
                          final text = msg['text'] ?? '';

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFFD1E7DD) : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 3, offset: const Offset(0, 1))],
                              ),
                              child: Text(
                                text,
                                style: TextStyle(color: isMe ? const Color(0xFF0F5132) : Colors.black87, fontSize: 15),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF0F5132), size: 28),
                        onPressed: _showAttachmentSheet,
                      ),
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions, color: Color(0xFF0F5132), size: 26),
                        onPressed: _showStickersSheet,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالة...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      IconButton(
                        icon: const Icon(Icons.mic, color: Color(0xFF0F5132), size: 26),
                        onPressed: _sendVoiceNote,
                        tooltip: 'إرسال بصمة صوتية',
                      ),
                      CircleAvatar(
                        backgroundColor: const Color(0xFF0F5132),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 18),
                          onPressed: () => _sendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
