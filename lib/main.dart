import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, SocketException;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'firebase_options.dart';

// ============================================================
//  الثوابت
// ============================================================
const Color kBlue = Color(0xFF0B4ED8);
const Color kDarkBlue = Color(0xFF0A2E8A);
const Color kGreen = Color(0xFF00C950);

/// سيرفر شلونكم (Cloudflare Worker)
const String kApiBase = 'https://shlonkum-iq.a00072288.workers.dev';

const FlutterSecureStorage _storage = FlutterSecureStorage();
FirebaseAuth get _auth => FirebaseAuth.instance;
FirebaseFirestore get _db => FirebaseFirestore.instance;

/// اليوزر: حروف انكليزية صغيرة وارقام و . _ - (من 3 الى 20)
final RegExp usernameRe = RegExp(r'^[a-z0-9._-]{3,20}$');

// ============================================================
//  الخدمات (Auth + الكود الثابت)
// ============================================================
String _emailFor(String username) => '${username.trim().toLowerCase()}@shlonkum.app';

/// معرّف جهاز عشوائي - ينولد مرة وحدة ويتخزن بشكل آمن
Future<String> getDeviceId() async {
  var id = await _storage.read(key: 'device_id');
  if (id == null) {
    final r = Random.secure();
    id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: 'device_id', value: id);
  }
  return id;
}

/// نداء السيرفر مع اثبات الهوية (Firebase ID token)
Future<Map<String, dynamic>> _api(String path, Map<String, dynamic> body) async {
  final user = _auth.currentUser;
  if (user == null) throw Exception('سجّل دخول اول');
  final token = await user.getIdToken();
  if (token == null) throw Exception('سجّل دخول اول');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.postUrl(Uri.parse('$kApiBase$path'));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer $token');
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close().timeout(const Duration(seconds: 20));
    final text = await res.transform(utf8.decoder).join();
    Map<String, dynamic> data;
    try {
      data = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    if (res.statusCode == 200) return data;
    final err = data['error'];
    if (err == 'rate_limited') throw Exception('محاولات كثيرة - انتظر شوية وجرب');
    throw Exception('خطأ بالسيرفر (${res.statusCode}${err != null ? ' - $err' : ''})');
  } on SocketException {
    throw Exception('ما اكو انترنت');
  } on TimeoutException {
    throw Exception('السيرفر ما رد - جرب مرة ثانية');
  } finally {
    client.close();
  }
}

/// السيرفر ينشئ الكود (مرة وحدة لكل حساب) ويحدد الجهاز الفعال
Future<String> _ensureCode(String deviceId) async {
  final res = await _api('/ensure-code', {'deviceId': deviceId});
  final code = res['code'];
  if (code is! String || code.isEmpty) throw Exception('ما كدرنا ننشئ الكود - جرب مرة ثانية');
  return code;
}

Future<String> registerUser({required String username, required String password}) async {
  final name = username.trim().toLowerCase();
  final deviceId = await getDeviceId();
  final cred = await _auth.createUserWithEmailAndPassword(email: _emailFor(name), password: password);
  try {
    final code = await _ensureCode(deviceId);
    await _storage.write(key: 'iq_code', value: code);
    return code;
  } catch (e) {
    await cred.user!.delete(); // حتى ما يحترق اليوزر
    rethrow;
  }
}

Future<String> loginUser({required String username, required String password}) async {
  final deviceId = await getDeviceId();
  await _auth.signInWithEmailAndPassword(
    email: _emailFor(username.trim().toLowerCase()),
    password: password,
  );
  try {
    final code = await _ensureCode(deviceId); // ينقل الجهاز الفعال لهذا الجهاز
    await _storage.write(key: 'iq_code', value: code);
    return code;
  } catch (e) {
    await _auth.signOut();
    rethrow;
  }
}

String friendlyError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'هذا اليوزر ماخوذ - اختار يوزر ثاني';
      case 'weak-password':
        return 'كلمة المرور ضعيفة';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'اليوزر او كلمة المرور غلط';
      case 'network-request-failed':
        return 'ما اكو انترنت';
      case 'too-many-requests':
        return 'محاولات كثيرة - انتظر شوية وجرب';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بالايميل مو مفعل بـ Firebase';
    }
    return 'خطأ بالدخول: ${e.code}';
  }
  if (e is FirebaseException) return 'خطأ بقاعدة البيانات: ${e.code}';
  return e.toString().replaceFirst('Exception: ', '');
}

// ============================================================
//  عناصر واجهة مشتركة
// ============================================================
void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

InputDecoration deco(String label, {String? hint, Widget? suffix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
    );

Widget bigButton(String text, VoidCallback? onPressed, {Color color = kBlue, bool loading = false}) => SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );

Widget codeBox(String code) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBlue),
      ),
      child: Column(children: [
        const Text('كودك 10 ارقام - ثابت'),
        const SizedBox(height: 8),
        Text(code.isEmpty ? '...' : code,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: kDarkBlue, letterSpacing: 3)),
        const Text('هذا هو هويتك!'),
      ]),
    );

// ============================================================
//  التطبيق
// ============================================================
Object? _initError;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') _initError = e;
  } catch (e) {
    _initError = e;
  }
  runApp(const ShlonkomIQApp());
}

class ShlonkomIQApp extends StatelessWidget {
  const ShlonkomIQApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شلونكم - IQ',
      home: _initError != null ? ErrorIQ(error: _initError!) : const SplashIQ(),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}

class ErrorIQ extends StatelessWidget {
  final Object error;
  const ErrorIQ({super.key, required this.error});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('تعذر الاتصال بـ Firebase:\n$error', textAlign: TextAlign.center)),
      ),
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
    User? user;
    try {
      user = await _auth.authStateChanges().first.timeout(const Duration(seconds: 5));
    } catch (_) {
      user = _auth.currentUser;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => user != null ? const HomeIQ() : const WelcomeIQ()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFEAF6FF),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.shield, color: kBlue, size: 90),
          SizedBox(height: 12),
          Text('شلونكم - IQ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: kDarkBlue)),
          SizedBox(height: 8),
          Text('كودك هو هويتك - وهويتك عراقية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDarkBlue)),
          SizedBox(height: 24),
          CircularProgressIndicator(color: kBlue),
        ]),
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
        child: Column(children: [
          const SizedBox(height: 40),
          const Icon(Icons.shield, color: kBlue, size: 80),
          const Text('شلونكم - IQ', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: kDarkBlue)),
          const Text('كودك هو هويتك - وهويتك عراقية',
              style: TextStyle(fontWeight: FontWeight.bold, color: kDarkBlue)),
          const SizedBox(height: 20),
          const Text('كود واحد 10 ارقام - ثابت - يفتح كل تطبيقات شبكة شلونكم', textAlign: TextAlign.center),
          const SizedBox(height: 28),
          bigButton('انشاء كودي - مجاني', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterIQ()));
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginIQ()));
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('عندي حساب - تسجيل دخول',
                  style: TextStyle(color: kBlue, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================
//  انشاء حساب
// ============================================================
class RegisterIQ extends StatefulWidget {
  const RegisterIQ({super.key});
  @override
  State<RegisterIQ> createState() => _RegisterIQState();
}

class _RegisterIQState extends State<RegisterIQ> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _pass.addListener(_refresh);
    _pass2.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  bool _isStrong(String p) =>
      p.length >= 8 && p.contains(RegExp(r'[0-9]')) && p.contains(RegExp(r'[A-Z]')) && p.contains(RegExp(r'[a-z]'));

  Future<void> _create() async {
    final name = _user.text.trim().toLowerCase();
    if (!usernameRe.hasMatch(name)) {
      snack(context, 'اليوزر: 3 الى 20 حرف انكليزي صغير او رقم او . _ -');
      return;
    }
    if (!_isStrong(_pass.text)) {
      snack(context, 'كلمة المرور لازم 8 احرف + رقم + حرف كبير + حرف صغير');
      return;
    }
    if (_pass.text != _pass2.text) {
      snack(context, 'كلمتا المرور مو متطابقات!');
      return;
    }
    setState(() => _loading = true);
    try {
      final code = await registerUser(username: name, password: _pass.text);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ShowCodeIQ(code: code)));
      return;
    } catch (e) {
      if (mounted) snack(context, friendlyError(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final match = _pass2.text.isNotEmpty && _pass.text == _pass2.text;
    final mismatch = _pass2.text.isNotEmpty && _pass.text != _pass2.text;
    return Scaffold(
      appBar: AppBar(
        title: const Text('انشاء كودي - شلونكم IQ'),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.shield, size: 60, color: kBlue),
          const Text('انشئ هويتك العراقية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('بدون ايميل - بدون رقم تلفون - بس يوزر + باسورد',
              style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _user, decoration: deco('يوزر نيم', hint: 'مثال: haider_iraq')),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: deco('كلمة مرور قوية', hint: '8 احرف + رقم + حرف كبير'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass2,
            obscureText: true,
            decoration: deco(
              'تأكيد كلمة المرور',
              suffix: match
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : mismatch
                      ? const Icon(Icons.error, color: Colors.red)
                      : null,
            ),
          ),
          if (mismatch)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('كلمتا المرور مو متطابقات!',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text(
              'انتبه: احفظ اليوزر والباسورد بمكان آمن. حالياً ما اكو استعادة اذا نسيت الباسورد.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          bigButton('ولد كودي 10 ارقام - مجاني', _loading ? null : _create, loading: _loading),
        ]),
      ),
    );
  }
}

class ShowCodeIQ extends StatelessWidget {
  final String code;
  const ShowCodeIQ({super.key, required this.code});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كودك - شلونكم IQ'),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Text('تم! هذا كودك - ثابت - ما يتغير!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          codeBox(code),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              snack(context, 'تم نسخ الكود');
            },
            icon: const Icon(Icons.copy),
            label: const Text('نسخ الكود'),
          ),
          const SizedBox(height: 20),
          bigButton('ادخل للتطبيق', () {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeIQ()), (r) => false);
          }, color: kGreen),
        ]),
      ),
    );
  }
}

// ============================================================
//  تسجيل دخول
// ============================================================
class LoginIQ extends StatefulWidget {
  const LoginIQ({super.key});
  @override
  State<LoginIQ> createState() => _LoginIQState();
}

class _LoginIQState extends State<LoginIQ> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      snack(context, 'اكتب اليوزر وكلمة المرور');
      return;
    }
    setState(() => _loading = true);
    try {
      await loginUser(username: _user.text, password: _pass.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeIQ()), (r) => false);
      return;
    } catch (e) {
      if (mounted) snack(context, friendlyError(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل دخول'), backgroundColor: kBlue, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.lock, size: 70, color: kBlue),
          const SizedBox(height: 16),
          TextField(controller: _user, decoration: deco('يوزر نيم')),
          const SizedBox(height: 12),
          TextField(controller: _pass, obscureText: true, decoration: deco('كلمة المرور')),
          const SizedBox(height: 16),
          const Text(
            'اذا دخلت من جهاز جديد، الجهاز القديم يطلع تلقائياً.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          bigButton('دخول', _loading ? null : _login, loading: _loading),
        ]),
      ),
    );
  }
}

// ============================================================
//  الشاشة الرئيسية
// ============================================================
class HomeIQ extends StatefulWidget {
  const HomeIQ({super.key});
  @override
  State<HomeIQ> createState() => _HomeIQState();
}

class _HomeIQState extends State<HomeIQ> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reqSub;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _requests = [];
  Timer? _tick;
  String _code = '';
  String _user = '';
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reqSub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final u = _auth.currentUser;
    if (u == null) {
      _goWelcome();
      return;
    }
    _user = (u.email ?? '').split('@').first;
    final cached = await _storage.read(key: 'iq_code');
    if (mounted) setState(() => _code = cached ?? '');
    final myId = await getDeviceId();
    _sub = _db.doc('users/${u.uid}').snapshots().listen((s) async {
      final data = s.data();
      if (data == null) return;
      if (data['activeDeviceId'] != myId) {
        await _kickedOut();
        return;
      }
      final code = (data['code'] as String?) ?? '';
      await _storage.write(key: 'iq_code', value: code);
      if (mounted) setState(() => _code = code);
    }, onError: (_) {});

    // طلبات الدخول من تطبيقات شبكة شلونكم
    _reqSub = _db
        .collection('loginRequests')
        .where('uid', isEqualTo: u.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((q) {
      if (mounted) setState(() => _requests = q.docs);
    }, onError: (_) {});
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  bool _alive(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final exp = d.data()['expiresAt'];
    return exp is int && exp > DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _answer(QueryDocumentSnapshot<Map<String, dynamic>> d, bool approve) async {
    try {
      await d.reference.update({'status': approve ? 'approved' : 'denied'});
      if (mounted) snack(context, approve ? 'تمت الموافقة' : 'تم الرفض');
    } catch (e) {
      if (mounted) snack(context, friendlyError(e));
    }
  }

  Widget _requestCard(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final app = (d.data()['appName'] as String?) ?? 'تطبيق';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(children: [
        const Icon(Icons.login, color: kDarkBlue, size: 36),
        const SizedBox(height: 6),
        Text('$app يريد الدخول بحسابك',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('اذا مو انت اللي تحاول تدخل، اضغط رفض.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _answer(d, true),
              style: ElevatedButton.styleFrom(backgroundColor: kGreen),
              child: const Text('موافق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _answer(d, false),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('رفض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }

  void _goWelcome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeIQ()), (r) => false);
  }

  Future<void> _kickedOut() async {
    if (_handled) return;
    _handled = true;
    await _sub?.cancel();
    await _reqSub?.cancel();
    await _auth.signOut();
    await _storage.delete(key: 'iq_code');
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تم نقل كودك!'),
        content: const Text('دخلت من جهاز ثاني - هذا الجهاز انغلق للحماية.'),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('فهمت'))],
      ),
    );
    _goWelcome();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خروج؟'),
        content: const Text('راح تحتاج اليوزر والباسورد حتى ترجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('اي - خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _handled = true;
    await _sub?.cancel();
    await _reqSub?.cancel();
    await _auth.signOut();
    await _storage.delete(key: 'iq_code');
    _goWelcome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شلونكم - IQ'),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 12),
          Text('اهلا $_user', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          for (final d in _requests.where(_alive)) _requestCard(d),
          codeBox(_code),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _code.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: _code));
                    snack(context, 'تم نسخ الكود');
                  },
            icon: const Icon(Icons.copy),
            label: const Text('نسخ الكود'),
          ),
          const SizedBox(height: 20),
          bigButton('ابحث عن صديق بالكود', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchIQ()));
          }),
        ]),
      ),
    );
  }
}

// ============================================================
//  البحث بالكود
// ============================================================
class SearchIQ extends StatefulWidget {
  const SearchIQ({super.key});
  @override
  State<SearchIQ> createState() => _SearchIQState();
}

class _SearchIQState extends State<SearchIQ> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _foundCode;
  String? _foundName;
  String? _message;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _ctrl.text.trim();
    setState(() {
      _foundCode = null;
      _foundName = null;
      _message = null;
    });
    if (!RegExp(r'^[1-9][0-9]{9}$').hasMatch(code)) {
      setState(() => _message = 'الكود لازم 10 ارقام وما يبدأ بصفر');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await _api('/search', {'code': code});
      if (res['found'] == true) {
        _foundCode = code;
        _foundName = (res['username'] as String?) ?? '';
      } else {
        _message = 'ما اكو احد بهذا الكود';
      }
    } catch (e) {
      _message = friendlyError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ابحث عن صديق'),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.search, size: 60, color: kBlue),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: deco('كود الصديق', hint: '10 ارقام'),
          ),
          const SizedBox(height: 8),
          bigButton('ابحث', _loading ? null : _search, loading: _loading),
          const SizedBox(height: 20),
          if (_message != null)
            Text(_message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          if (_foundCode != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kGreen),
              ),
              child: Column(children: [
                const Icon(Icons.person, size: 50, color: kDarkBlue),
                const SizedBox(height: 8),
                Text(
                  (_foundName == null || _foundName!.isEmpty) ? 'مستخدم شلونكم' : _foundName!,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kDarkBlue),
                ),
                const SizedBox(height: 4),
                Text(_foundCode!, style: const TextStyle(fontSize: 18, letterSpacing: 2)),
                if (_foundName == null || _foundName!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('هذا الحساب ما أضاف اسمه بعد - يظهر بعد ما يسجل دخول بالنسخة الجديدة',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}
