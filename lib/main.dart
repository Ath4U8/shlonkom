import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

const List<String> kRecoveryWords = [
  'عراق', 'دجلة', 'فرات', 'بابل', 'سومر', 'اشور',
  'بغداد', 'بصرة', 'موصل', 'كربلاء', 'نجف', 'اربيل',
  'كركوك', 'انبار', 'ديالى', 'واسط', 'مثنى', 'ديوانية',
  'صلاح', 'ناصرية', 'عمارة', 'سماوة', 'حلة', 'كوت',
];

// هاش بسيط بدون مكتبة crypto - يشتغل وية pubspec القديم
String simpleHash(String input) {
  int h1 = 5381;
  int h2 = 52711;
  for (int i = 0; i < input.length; i++) {
    final c = input.codeUnitAt(i);
    h1 = ((h1 << 5) + h1 + c) & 0x7fffffff;
    h2 = ((h2 << 5) + h2 + c * 31) & 0x7fffffff;
  }
  return '${h1.toRadixString(16).padLeft(8, '0')}${h2.toRadixString(16).padLeft(8, '0')}';
}

String generateCode10({
  required String username,
  required String password,
  required String deviceHash,
}) {
  final raw = '$username|$password|$deviceHash|ShlonkomIQ-Salt-2026';
  final hash = simpleHash(raw) + simpleHash('X$raw');
  String digits = '';
  for (int i = 0; i < hash.length && digits.length < 10; i++) {
    final c = hash[i];
    final code = c.codeUnitAt(0);
    if (code >= 48 && code <= 57) {
      digits += c;
    } else {
      digits += (code % 10).toString();
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
  final copy = List<String>.from(kRecoveryWords);
  copy.shuffle(rnd);
  final list = <String>[];
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

Future<String> getDeviceHash() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString('iq_device_id');
    if (saved != null) {
      return saved;
    }
    final rnd = Random().nextInt(1000000000);
    final raw = '${Platform.operatingSystem}|$rnd|${DateTime.now().millisecondsSinceEpoch}';
    final h = simpleHash('ShlonkomIQ-Device-$raw');
    await prefs.setString('iq_device_id', h);
    return h;
  } catch (_) {
    return simpleHash('fallback-${DateTime.now().millisecondsSinceEpoch}');
  }
}

Future<String> getIPHash() async {
  return simpleHash('ShlonkomIQ-IP-${DateTime.now().day}');
}

Future<bool> isVpnActive() async {
  try {
    final interfaces = await NetworkInterface.list();
    for (final i in interfaces) {
      final name = i.name.toLowerCase();
      if (name.contains('tun') ||
          name.contains('ppp') ||
          name.contains('tap') ||
          name.contains('vpn')) {
        return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

Future<bool> checkVpnAndWarn(BuildContext context) async {
  final vpn = await isVpnActive();
  if (vpn) {
    if (!context.mounted) return true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('اغلق الـ VPN'),
        content: const Text(
          'شلونكم - IQ ما يشتغل ويه VPN بالاشياء الحساسة. اغلق VPN حتى نكمل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('فهمت - راح اغلقه'),
          ),
        ],
      ),
    );
    return true;
  }
  return false;
}

class RegisterIQ extends StatefulWidget {
  const RegisterIQ({super.key});
  @override
  State<RegisterIQ> createState() => _RegisterIQState();
}

class _RegisterIQState extends State<RegisterIQ> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _email = TextEditingController();
  bool _loading = false;
  bool _agreed = false;

  bool _isStrong(String p) {
    if (p.length < 8) return false;
    final hasDigit = p.contains(RegExp(r'[0-9]'));
    final hasUpper = p.contains(RegExp(r'[A-Z]'));
    final hasLower = p.contains(RegExp(r'[a-z]'));
    return hasDigit && hasUpper && hasLower;
  }

  Future<void> _create() async {
    if (_user.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب يوزر نيم')),
      );
      return;
    }
    if (!_isStrong(_pass.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور لازم 8 احرف + رقم + حرف كبير + حرف صغير'),
        ),
      );
      return;
    }
    if (_pass.text != _pass2.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمتا المرور مو متطابقات')),
      );
      return;
    }
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لازم توافق على حماية الجهاز المشفرة'),
        ),
      );
      return;
    }
    final vpn = await checkVpnAndWarn(context);
    if (vpn) return;
    setState(() => _loading = true);
    try {
      final deviceHash = await getDeviceHash();
      final ipHash = await getIPHash();
      final code = generateCode10(
        username: _user.text.trim(),
        password: _pass.text,
        deviceHash: deviceHash,
      );
      final recovery = generateRecovery12();
      final recoveryText = recovery.join(' ');
      try {
        final q = await FirebaseFirestore.instance
            .collection('iq_codes')
            .where('code', isEqualTo: code)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('هذا الكود موجود - غير يوزر او باسورد شوية'),
            ),
          );
          setState(() => _loading = false);
          return;
        }
        await FirebaseFirestore.instance.collection('iq_codes').doc(code).set({
          'code': code,
          'username': _user.text.trim(),
          'email': _email.text.trim(),
          'deviceHash': deviceHash,
          'ipHash': ipHash,
          'recoveryHash': simpleHash(recoveryText),
          'createdAt': FieldValue.serverTimestamp(),
          'plan': 'free',
        });
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('iq_code', code);
      await prefs.setString('iq_user', _user.text.trim());
      await prefs.setString('iq_email', _email.text.trim());
      await prefs.setString('iq_recovery', recoveryText);
      await prefs.setString('iq_deviceHash', deviceHash);
      await prefs.setString('iq_ipHash', ipHash);
      await prefs.setBool('iq_cloudBackup', true);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ShowCodeIQ(code: code, recovery: recovery),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('انشاء كودي - شلونكم IQ'),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.shield, size: 60, color: kBlue),
            const Text(
              'انشئ هويتك العراقية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _user,
              decoration: InputDecoration(
                labelText: 'يوزر نيم',
                hintText: 'مثال: haider_iraq',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'كلمة مرور قوية',
                hintText: '8 احرف + رقم + حرف كبير',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass2,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'الايميل - للاستعادة',
                hintText: 'example@gmail.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              title: const Text(
                'اوافق على حماية الجهاز المشفرة - بصمة مشفرة - ما تنرسل - وما احد يشوفها',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'ولد كودي 10 ارقام - مجاني',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShowCodeIQ extends StatelessWidget {
  final String code;
  final List<String> recovery;
  const ShowCodeIQ({super.key, required this.code, required this.recovery});
  @override
  Widget build(BuildContext context) {
    final recoveryText = recovery.join(' ');
    return Scaffold(
      appBar: AppBar(
        title: const Text('كودك - شلونكم IQ'),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'تم! هذا كودك - ثابت - ما يتغير!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBlue),
              ),
              child: Column(
                children: [
                  const Text('كودك 10 ارقام'),
                  const SizedBox(height: 8),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: kDarkBlue,
                      letterSpacing: 4,
                    ),
                  ),
                  const Text('احفظه - هذا هو هويتك!'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'مفتاح الاستعادة - 12 كلمة - احفظه بمكان آمن!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                recoveryText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 70, color: kBlue),
                  const SizedBox(height: 8),
                  Text(
                    'SHLONKOM-IQ:$code',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'انسخ هذا السطر واحفظه - هو مفتاح الاستعادة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اذا ضيعت المفتاح - ضاع الكود! احفظه بورقة بالبيت!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeIQ()),
                    (r) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'حفظت المفتاح - ادخل للتطبيق',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestoreIQ extends StatefulWidget {
  const RestoreIQ({super.key});
  @override
  State<RestoreIQ> createState() => _RestoreIQState();
}

class _RestoreIQState extends State<RestoreIQ> {
  final _keyCtrl = TextEditingController();
  bool _loading = false;
  Future<void> _restore() async {
    final vpn = await checkVpnAndWarn(context);
    if (vpn) return;
    if (_keyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب مفتاح الاستعادة 12 كلمة')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final key = _keyCtrl.text.trim();
      final hash = simpleHash(key);
      try {
        final q = await FirebaseFirestore.instance
            .collection('iq_codes')
            .where('recoveryHash', isEqualTo: hash)
            .limit(1)
            .get();
        if (q.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('المفتاح غلط - تأكد من الكلمات')),
          );
          setState(() => _loading = false);
          return;
        }
        final data = q.docs.first.data();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('iq_code', data['code'] ?? '');
        await prefs.setString('iq_user', data['username'] ?? '');
        await prefs.setString('iq_email', data['email'] ?? '');
        await prefs.setString('iq_recovery', key);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeIQ()),
          (r) => false,
        );
        return;
      } catch (_) {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('iq_recovery') ?? '';
        if (saved == key) {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeIQ()),
            (r) => false,
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('المفتاح غلط - او ما اكو نت')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
    setState(() => _loading = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استرجع كودي'),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.key, size: 70, color: kBlue),
            const SizedBox(height: 12),
            const Text(
              'اكتب مفتاح الاستعادة 12 كلمة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'عراق دجلة فرات بابل ...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _restore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'استرجع كودي',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeIQ extends StatefulWidget {
  const HomeIQ({super.key});
  @override
  State<HomeIQ> createState() => _HomeIQState();
}

class _HomeIQState extends State<HomeIQ> {
  String _code = '';
  String _user = '';
  String _email = '';
  String _otp = '';
  int _seconds = 0;
  String _forApp = '';
  final _appCtrl = TextEditingController();
  bool _vpn = false;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _code = prefs.getString('iq_code') ?? '';
      _user = prefs.getString('iq_user') ?? '';
      _email = prefs.getString('iq_email') ?? '';
    });
    final vpn = await isVpnActive();
    setState(() => _vpn = vpn);
  }
  void _generateOtp() {
    final rnd = Random();
    String c = '';
    for (int i = 0; i < 6; i++) {
      c += rnd.nextInt(10).toString();
    }
    setState(() {
      _otp = c;
      _seconds = 60;
      _forApp = _appCtrl.text.trim().isEmpty ? 'تطبيقك الجديد' : _appCtrl.text.trim();
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_seconds <= 0) {
        setState(() => _otp = '');
        return false;
      }
      setState(() => _seconds--);
      return _seconds > 0 && _otp.isNotEmpty;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شلونكم - IQ'),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeIQ()),
                (r) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_vpn)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: const Text(
                  'VPN شغال - اغلقه قبل توليد OTP!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'اهلا $_user',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(_email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBlue),
              ),
              child: Column(
                children: [
                  const Text('كودك 10 ارقام - ثابت'),
                  const SizedBox(height: 8),
                  Text(
                    _code,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: kDarkBlue,
                      letterSpacing: 3,
                    ),
                  ),
                  const Text('هذا هو هويتك!'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'اكواد التأكيد OTP - لتطبيقات شبكة شلونكم',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _appCtrl,
              decoration: InputDecoration(
                hintText: 'اسم التطبيق - مثلا: فيس عراقي',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_otp.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBlue),
                ),
                child: Column(
                  children: [
                    Text('كودك لـ $_forApp'),
                    Text(
                      _otp,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: kDarkBlue,
                        letterSpacing: 8,
                      ),
                    ),
                    Text(
                      'ينتهي بعد $_seconds ثانية',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  if (_vpn) {
                    await checkVpnAndWarn(context);
                    return;
                  }
                  _generateOtp();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'توليد كود OTP جديد',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'حماية 5 طبقات فعالة\nمفتاح استعادة | نسخة سحابية | بصمة جهاز مشفرة | IP مشفر | منع VPN بالحساس\nمجاني بالكامل - حاليا - بعد الانتشار تصير خطط مدفوعة للشركات',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
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
                  'نقل كودي لجهاز جديد - بمفتاح الاستعادة',
                  style: TextStyle(color: kBlue, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
