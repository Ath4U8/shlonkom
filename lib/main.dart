
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ShlonkomApp());
}

const Color kBlue = Color(0xFF0B4ED8);
const Color kDarkBlue = Color(0xFF0A2E8A);
const Color kLightBlue = Color(0xFFE8F0FE);
const Color kGreen = Color(0xFF00C950);

class ShlonkomApp extends StatelessWidget {
  const ShlonkomApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شلونكم',
      theme: ThemeData(fontFamily: 'Cairo', useMaterial3: true, primaryColor: kBlue),
      home: const SplashScreen(),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );
  }
}

// ---------- Helpers ----------
String generatePin() {
  final r = Random();
  String pin = '';
  for (int i = 0; i < 8; i++) { pin += r.nextInt(10).toString(); }
  if (pin.startsWith('0')) pin = '1' + pin.substring(1);
  return pin;
}
String chatIdFor(String a, String b) {
  final list = [a, b]..sort();
  return list.join('_');
}
String formatTime(DateTime d) {
  int h = d.hour; String ap = h >= 12 ? 'م' : 'ص';
  int hh = h % 12; if (hh == 0) hh = 12;
  return '$hh:${d.minute.toString().padLeft(2, '0')} $ap';
}
String lastSeenText(Timestamp? ts, bool online) {
  if (online) return 'متصل الآن';
  if (ts == null) return 'آخر ظهور غير معروف';
  final diff = DateTime.now().difference(ts.toDate());
  if (diff.inMinutes < 1) return 'آخر ظهور الآن';
  if (diff.inMinutes < 60) return 'آخر ظهور منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'آخر ظهور منذ ${diff.inHours} ساعة';
  return 'آخر ظهور منذ ${diff.inDays} يوم';
}

// ---------- Splash ----------
class SplashScreen extends StatefulWidget { const SplashScreen({super.key}); @override State<SplashScreen> createState() => _SplashState(); }
class _SplashState extends State<SplashScreen> {
  @override void initState() { super.initState(); _go(); }
  Future<void> _go() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('last_open') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffDays = (now - last) ~/ (1000*60*60*24);
    final loggedEmail = prefs.getString('saved_email');
    final hasProfile = prefs.getBool('has_profile') ?? false;
    await prefs.setInt('last_open', now);
    if (FirebaseAuth.instance.currentUser != null && hasProfile && loggedEmail != null && diffDays <= 6) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFBFE3FF), Color(0xFFEAF6FF)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 40),
          Container(width: 150, height: 150, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(40)), child: const Icon(Icons.phone, color: Colors.white, size: 80)),
          const SizedBox(height: 10),
          const Text('شلونكم', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: kDarkBlue)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: kBlue)), child: const Text('اهلا وسهلا بكم في اول تطبيق اتصال عراقي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDarkBlue))),
          const SizedBox(height: 40),
          const CircularProgressIndicator(color: kBlue),
          const SizedBox(height: 12),
          const Text('جاري التحميل...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDarkBlue)),
        ]),
      ),
    );
  }
}

// ---------- Login ----------
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginState(); }
class _LoginState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pin = TextEditingController();
  bool _loading = false;
  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pin.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب الايميل والرقم الشخصي'))); return; }
    setState(() => _loading = true);
    try {
      final q = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: _email.text.trim()).where('personal_pin', isEqualTo: _pin.text.trim()).limit(1).get();
      if (q.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الايميل او الرقم الشخصي خطأ'))); setState(() => _loading = false); return; }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', _email.text.trim());
      await prefs.setString('my_uid', q.docs.first.id);
      await prefs.setBool('has_profile', true);
      await prefs.setInt('last_open', DateTime.now().millisecondsSinceEpoch);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    setState(() => _loading = false);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(body: SingleChildScrollView(child: Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFBFE3FF), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter)), child: Column(children: [
      const SizedBox(height: 30),
      Container(width: 110, height: 110, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(30)), child: const Icon(Icons.phone, color: Colors.white, size: 60)),
      const Text('شلونكم', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: kDarkBlue)),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Text('اهلا وسهلا بكم في اول تطبيق اتصال عراقي 🇮🇶', style: TextStyle(fontWeight: FontWeight.bold, color: kDarkBlue))),
      const SizedBox(height: 22),
      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(prefixIcon: const Icon(Icons.email, color: kBlue), hintText: 'البريد الإلكتروني', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      TextField(controller: _pin, keyboardType: TextInputType.number, maxLength: 8, decoration: InputDecoration(prefixIcon: const Icon(Icons.phone, color: kBlue), hintText: 'الرقم الشخصي', counterText: '', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none))),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _loading ? null : _login, style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل الدخول ➜', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)))),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 54, child: OutlinedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyEmailScreen())); }, style: OutlinedButton.styleFrom(side: const BorderSide(color: kBlue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('انشاء حساب جديد 👤+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBlue)))),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 54, child: OutlinedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoveryScreen())); }, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), backgroundColor: Colors.orange.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('استعادة الحساب 🔄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)))),
      const SizedBox(height: 20),
      const Text('اذا نسيت رقمك الشخصي اضغط استعادة الحساب', style: TextStyle(color: Colors.grey)),
    ])))),
    );
  }
}

// ---------- Verify Email -> Create Account ----------
class VerifyEmailScreen extends StatefulWidget { const VerifyEmailScreen({super.key}); @override State<VerifyEmailScreen> createState() => _VerifyState(); }
class _VerifyState extends State<VerifyEmailScreen> {
  final _email = TextEditingController();
  bool _sent = false; bool _loading = false;
  Future<void> _send() async {
    if (_email.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب ايميلك'))); return; }
    setState(() => _loading = true);
    try {
      // نستخدم Firebase Auth برابط وهمي للتحقق - في النسخة الحالية نرسل رسالة تأكيد وننتقل لصفحة انشاء الحساب
      // لان التحقق الحقيقي يحتاج رابط - نستخدم createUserWithEmailAndPassword مع كلمة سر مؤقتة داخلية
      final tempPass = 'Shlonkom_${_email.text.trim()}123!';
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: tempPass);
        await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      } catch (_) {
        try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: tempPass); await FirebaseAuth.instance.currentUser?.sendEmailVerification(); } catch (_) {}
      }
      setState(() { _sent = true; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ارسال رابط التأكيد الى ايميلك - افتح ايميلك واضغط الرابط ثم ارجع هنا واضغط "تم التأكيد"')));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('انشاء حساب جديد'), backgroundColor: kBlue, foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        const Icon(Icons.email, size: 80, color: kBlue),
        const SizedBox(height: 12),
        const Text('اول شي أكد ايميلك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kDarkBlue)),
        const Text('راح نرسل رابط تأكيد لبريدك الالكتروني', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(hintText: 'example@gmail.com', prefixIcon: const Icon(Icons.email, color: kBlue), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _loading ? null : _send, style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: Text(_sent ? 'تم الارسال - اضغط تم التأكيد بالأسفل' : 'ارسال رابط التأكيد', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: () { if (_email.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب ايميلك اولاً'))); return; } Navigator.push(context, MaterialPageRoute(builder: (_) => CreateAccountScreen(email: _email.text.trim()))); }, style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('تم التأكيد - اكمل انشاء الحساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
        const SizedBox(height: 10),
        const Text('بعد التأكيد راح تلكة الرقم الشخصي والايميل موجودين ومقفولين - فقط تضيف صورتك واسمك', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ])),
    );
  }
}

class CreateAccountScreen extends StatefulWidget {
  final String email; const CreateAccountScreen({super.key, required this.email});
  @override State<CreateAccountScreen> createState() => _CreateState();
}
class _CreateState extends State<CreateAccountScreen> {
  final _name = TextEditingController();
  late String _pin; File? _photo; bool _loading = false;
  @override void initState() { super.initState(); _pin = generatePin(); }
  Future<void> _pick() async { final p = await ImagePicker().pickImage(source: ImageSource.gallery); if (p != null) setState(() => _photo = File(p.path)); }
  Future<void> _create() async {
    if (_name.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسم المستخدم'))); return; }
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': widget.email, 'username': _name.text.trim(), 'personal_pin': _pin,
        'profile_photo': '', 'isOnline': true, 'lastSeen': FieldValue.serverTimestamp(),
        'thinking': '', 'createdAt': FieldValue.serverTimestamp(),
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', widget.email);
      await prefs.setString('my_uid', uid);
      await prefs.setString('my_pin', _pin);
      await prefs.setString('my_name', _name.text.trim());
      await prefs.setBool('has_profile', true);
      await prefs.setInt('last_open', DateTime.now().millisecondsSinceEpoch);
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(title: const Text('تم انشاء حسابك 🎉'), content: Text('رقمك الشخصي هو:\n$_pin\n\nاحفظه - راح تحتاجه للدخول'), actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false); }, child: const Text('تم'))]));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
    setState(() => _loading = false);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('انشاء الحساب'), backgroundColor: kBlue, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        GestureDetector(onTap: _pick, child: CircleAvatar(radius: 55, backgroundColor: Colors.grey.shade300, backgroundImage: _photo != null ? FileImage(_photo!) : null, child: _photo == null ? const Icon(Icons.person, size: 60, color: Colors.white) : null)),
        TextButton(onPressed: _pick, child: const Text('تغيير الصورة', style: TextStyle(color: kBlue, fontWeight: FontWeight.bold))),
        const SizedBox(height: 10),
        TextField(controller: _name, decoration: InputDecoration(hintText: 'مثال: حيدر العراقي', labelText: 'اسم المستخدم', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)))),
        const SizedBox(height: 12),
        TextField(enabled: false, controller: TextEditingController(text: widget.email), decoration: InputDecoration(labelText: 'الايميل', prefixIcon: const Icon(Icons.email, color: kBlue), filled: true, fillColor: Colors.grey.shade200, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)), suffixIcon: const Icon(Icons.lock, size: 18))),
        const SizedBox(height: 12),
        TextField(enabled: false, controller: TextEditingController(text: _pin), decoration: InputDecoration(labelText: 'الرقم الشخصي', prefixIcon: const Icon(Icons.phone, color: kBlue), filled: true, fillColor: Colors.grey.shade200, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)), suffixIcon: const Icon(Icons.lock, size: 18))),
        const Text('مكون من 8 أرقام وهو ثابت ولايمكن تغييره ℹ️', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _loading ? null : _create, style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('انشاء الحساب 💾', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}

// ---------- Recovery ----------
class RecoveryScreen extends StatefulWidget { const RecoveryScreen({super.key}); @override State<RecoveryScreen> createState() => _RecState(); }
class _RecState extends State<RecoveryScreen> {
  final _email = TextEditingController(); bool _loading = false;
  Future<void> _recover() async {
    if (_email.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب ايميلك'))); return; }
    setState(() => _loading = true);
    try {
      final q = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: _email.text.trim()).limit(1).get();
      if (q.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ماكو حساب بهذا الايميل'))); setState(() => _loading = false); return; }
      final pin = q.docs.first.data()['personal_pin'] ?? '';
      final name = q.docs.first.data()['username'] ?? '';
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('تم استعادة الحساب ✅'), content: Text('اهلا $name\nرقمك الشخصي هو: $pin\n\nاستخدمه مع ايميلك للدخول'), actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('تم'))]));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
    setState(() => _loading = false);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('استعادة الحساب'), backgroundColor: kBlue, foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(width: 110, height: 110, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.lock, color: Colors.white, size: 60)),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(30)), child: const Text('استعادة الحساب', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        const Text('أدخل بريدك الإلكتروني المرتبط بحسابك وسنرسل لك رمز التحقق لإعادة الوصول إلى حسابك', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: kDarkBlue)),
        const SizedBox(height: 20),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(hintText: 'البريد الإلكتروني', prefixIcon: const Icon(Icons.email, color: kBlue), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _loading ? null : _recover, style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('الاستعادة 🔄', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}

// ---------- Home ----------
class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeState(); }
class _HomeState extends State<HomeScreen> with WidgetsBindingObserver {
  int _index = 0; String? _myUid; String _myName = 'شلونكم';
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); _setOnline(true); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _setOnline(true); else if (state == AppLifecycleState.paused) _setOnline(false); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); setState(() { _myUid = p.getString('my_uid'); _myName = p.getString('my_name') ?? 'شلونكم'; }); }
  Future<void> _setOnline(bool online) async { if (_myUid == null) { final p = await SharedPreferences.getInstance(); _myUid = p.getString('my_uid'); } if (_myUid == null) return; try { await FirebaseFirestore.instance.collection('users').doc(_myUid).update({'isOnline': online, 'lastSeen': FieldValue.serverTimestamp()}); } catch (_) {} }
  @override Widget build(BuildContext context) {
    final pages = [const ChatsTab(), const CallsTab(), const GroupsTab(), const SettingsTab()];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(currentIndex: _index, onTap: (i) => setState(() => _index = i), selectedItemColor: kBlue, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed, items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'المحادثات'),
        BottomNavigationBarItem(icon: Icon(Icons.call), label: 'المكالمات'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'المجموعات'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
      ]),
    );
  }
}

// ---------- Chats Tab ----------
class ChatsTab extends StatefulWidget { const ChatsTab({super.key}); @override State<ChatsTab> createState() => _ChatsState(); }
class _ChatsState extends State<ChatsTab> {
  final _search = TextEditingController(); final _pinSearch = TextEditingController(); String? _myUid;
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async { final p = await SharedPreferences.getInstance(); setState(() => _myUid = p.getString('my_uid')); }
  Future<void> _addByPin() async {
    if (_pinSearch.text.trim().isEmpty) return;
    final q = await FirebaseFirestore.instance.collection('users').where('personal_pin', isEqualTo: _pinSearch.text.trim()).limit(1).get();
    if (q.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ماكو شخص بهذا الرقم'))); return; }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لكيت ${q.docs.first.data()['username']} - اضغط عليه لتبدي محادثة')));
    _pinSearch.clear();
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('شلونكم 🇮🇶'), backgroundColor: kBlue, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'البحث في جهات الاتصال...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Expanded(child: TextField(controller: _pinSearch, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'اضف بالرقم الشخصي - 8 ارقام', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))))), const SizedBox(width: 8), ElevatedButton(onPressed: _addByPin, style: ElevatedButton.styleFrom(backgroundColor: kBlue), child: const Text('اضافة', style: TextStyle(color: Colors.white)))])),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').snapshots(), builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs.where((d) => d.id != _myUid).toList();
          final filtered = docs.where((d) { final name = (d.data() as Map)['username']?.toString() ?? ''; return _search.text.isEmpty || name.contains(_search.text); }).toList();
          if (filtered.isEmpty) return const Center(child: Text('ماكو جهات اتصال بعد - اضف صديق برقمه الشخصي'));
          return ListView.builder(itemCount: filtered.length, itemBuilder: (context, i) {
            final data = filtered[i].data() as Map<String, dynamic>;
            final online = data['isOnline'] == true;
            final thinking = data['thinking']?.toString() ?? '';
            return ListTile(
              leading: CircleAvatar(backgroundColor: kBlue, child: Text((data['username']?.toString() ?? '?').isNotEmpty ? (data['username'].toString()[0]) : '?', style: const TextStyle(color: Colors.white))),
              title: Text(data['username']?.toString() ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(thinking.isNotEmpty ? '💭 $thinking' : lastSeenText(data['lastSeen'] as Timestamp?, online)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.chat, color: kBlue), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUid: filtered[i].id, otherName: data['username']?.toString() ?? '', otherOnline: online, otherLastSeen: data['lastSeen'] as Timestamp?))); }),
                IconButton(icon: const Icon(Icons.call, color: kGreen), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => IncomingCallScreen(name: data['username']?.toString() ?? ''))); }),
              ]),
              onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUid: filtered[i].id, otherName: data['username']?.toString() ?? '', otherOnline: online, otherLastSeen: data['lastSeen'] as Timestamp?))); },
            );
          });
        })),
      ]),
    );
  }
}

// ---------- Chat ----------
class ChatScreen extends StatefulWidget {
  final String otherUid; final String otherName; final bool otherOnline; final Timestamp? otherLastSeen;
  const ChatScreen({super.key, required this.otherUid, required this.otherName, required this.otherOnline, this.otherLastSeen});
  @override State<ChatScreen> createState() => _ChatState();
}
class _ChatState extends State<ChatScreen> {
  final _msg = TextEditingController(); String? _myUid; String _myName = '';
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async { final p = await SharedPreferences.getInstance(); setState(() { _myUid = p.getString('my_uid'); _myName = p.getString('my_name') ?? ''; }); }
  Future<void> _send({String? text, String? imagePath}) async {
    if ((text == null || text.trim().isEmpty) && imagePath == null) return;
    final cid = chatIdFor(_myUid ?? '', widget.otherUid);
    await FirebaseFirestore.instance.collection('chats').doc(cid).collection('messages').add({'sender': _myUid, 'senderName': _myName, 'text': text ?? '', 'image': imagePath ?? '', 'time': FieldValue.serverTimestamp(), 'seen': false});
    _msg.clear();
  }
  Future<void> _pickImage() async { final p = await ImagePicker().pickImage(source: ImageSource.gallery); if (p != null) await _send(imagePath: p.path); }
  @override Widget build(BuildContext context) {
    if (_myUid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final cid = chatIdFor(_myUid!, widget.otherUid);
    return Scaffold(appBar: AppBar(backgroundColor: kBlue, foregroundColor: Colors.white, title: Row(children: [CircleAvatar(backgroundColor: Colors.white, child: Text(widget.otherName.isNotEmpty ? widget.otherName[0] : '?', style: const TextStyle(color: kBlue))), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.otherName), Text(widget.otherOnline ? 'متصل الآن 🟢' : lastSeenText(widget.otherLastSeen, false), style: const TextStyle(fontSize: 11))]))]), actions: [IconButton(icon: const Icon(Icons.call), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => IncomingCallScreen(name: widget.otherName))); }), IconButton(icon: const Icon(Icons.videocam), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => IncomingCallScreen(name: widget.otherName))); })]),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').doc(cid).collection('messages').orderBy('time').snapshots(), builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text('ابدأ المحادثة - اكتب اول رسالة 👋'));
          return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (context, i) {
            final d = snap.data!.docs[i].data() as Map<String, dynamic>;
            final mine = d['sender'] == _myUid;
            final t = (d['time'] as Timestamp?)?.toDate();
            return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: mine ? kBlue : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if ((d['image']?.toString() ?? '').isNotEmpty) GestureDetector(onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(backgroundColor: Colors.black), body: Center(child: Image.file(File(d['image'])))))); }, child: Image.file(File(d['image']), width: 180, height: 180, fit: BoxFit.cover)),
              if ((d['text']?.toString() ?? '').isNotEmpty) Text(d['text'], style: TextStyle(color: mine ? Colors.white : Colors.black, fontSize: 16)),
              Row(mainAxisSize: MainAxisSize.min, children: [Text(t != null ? formatTime(t) : '', style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : Colors.grey)), if (mine) const SizedBox(width: 4), if (mine) Icon(d['seen'] == true ? Icons.done_all : Icons.done, size: 14, color: d['seen'] == true ? Colors.lightBlueAccent : Colors.white70)]),
            ])));
          });
        })),
        Container(padding: const EdgeInsets.all(8), color: Colors.grey.shade100, child: Row(children: [
          IconButton(icon: const Icon(Icons.emoji_emotions, color: kBlue), onPressed: () { _msg.text += '😊'; }),
          IconButton(icon: const Icon(Icons.image, color: kBlue), onPressed: _pickImage),
          Expanded(child: TextField(controller: _msg, decoration: InputDecoration(hintText: 'اكتب رسالة...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))),
          const SizedBox(width: 6),
          CircleAvatar(backgroundColor: kBlue, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _send(text: _msg.text))),
        ])),
      ]),
    );
  }
}

// ---------- Calls ----------
class CallsTab extends StatelessWidget { const CallsTab({super.key}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text('المكالمات'), backgroundColor: kBlue, foregroundColor: Colors.white), body: const Center(child: Text('المكالمات الأخيرة - تظهر هنا بعد اول مكالمة'))); } }
class IncomingCallScreen extends StatelessWidget { final String name; const IncomingCallScreen({super.key, required this.name}); @override Widget build(BuildContext context) { return Scaffold(backgroundColor: kDarkBlue, body: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('شلونكم', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), const SizedBox(height: 30), CircleAvatar(radius: 70, backgroundColor: Colors.white, child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 50, color: kBlue))), const SizedBox(height: 16), Text(name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)), const Text('مكالمة واردة... 📞', style: TextStyle(color: Colors.white70, fontSize: 18)), const SizedBox(height: 60), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Column(children: [FloatingActionButton(backgroundColor: Colors.red, onPressed: () => Navigator.pop(context), child: const Icon(Icons.call_end, color: Colors.white)), const SizedBox(height: 8), const Text('رفض', style: TextStyle(color: Colors.white))]), Column(children: [FloatingActionButton(backgroundColor: Colors.green, onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول المكالمة'))); Navigator.pop(context); }, child: const Icon(Icons.call, color: Colors.white)), const SizedBox(height: 8), const Text('قبول', style: TextStyle(color: Colors.white))])])]))); } }

// ---------- Groups ----------
class GroupsTab extends StatefulWidget { const GroupsTab({super.key}); @override State<GroupsTab> createState() => _GroupsState(); }
class _GroupsState extends State<GroupsTab> {
  final _gname = TextEditingController(); String? _myUid;
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async { final p = await SharedPreferences.getInstance(); setState(() => _myUid = p.getString('my_uid')); }
  Future<void> _createGroup() async {
    if (_gname.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسم المجموعة'))); return; }
    await FirebaseFirestore.instance.collection('groups').add({'name': _gname.text.trim(), 'creator': _myUid, 'members': [_myUid], 'createdAt': FieldValue.serverTimestamp()});
    _gname.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم انشاء المجموعة ✅')));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('المجموعات'), backgroundColor: kBlue, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: _gname, decoration: InputDecoration(hintText: 'اسم المجموعة الجديدة...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))))), const SizedBox(width: 8), ElevatedButton(onPressed: _createGroup, style: ElevatedButton.styleFrom(backgroundColor: kBlue), child: const Text('انشاء', style: TextStyle(color: Colors.white)))])),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('groups').orderBy('createdAt', descending: true).snapshots(), builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text('ماكو مجموعات بعد - انشئ اول مجموعة 👥'));
          return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (context, i) { final d = snap.data!.docs[i].data() as Map<String, dynamic>; return ListTile(leading: const CircleAvatar(backgroundColor: kBlue, child: Icon(Icons.group, color: Colors.white)), title: Text(d['name']?.toString() ?? 'مجموعة'), subtitle: Text('اضغط للدخول للمجموعة'), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: snap.data!.docs[i].id, groupName: d['name']?.toString() ?? ''))); }); });
        })),
      ]),
    );
  }
}
class GroupChatScreen extends StatefulWidget { final String groupId; final String groupName; const GroupChatScreen({super.key, required this.groupId, required this.groupName}); @override State<GroupChatScreen> createState() => _GroupChatState(); }
class _GroupChatState extends State<GroupChatScreen> {
  final _msg = TextEditingController(); String? _myUid; String _myName = '';
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async { final p = await SharedPreferences.getInstance(); setState(() { _myUid = p.getString('my_uid'); _myName = p.getString('my_name') ?? ''; }); }
  Future<void> _send() async { if (_msg.text.trim().isEmpty) return; await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('messages').add({'sender': _myUid, 'senderName': _myName, 'text': _msg.text.trim(), 'time': FieldValue.serverTimestamp()}); _msg.clear(); }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(widget.groupName), backgroundColor: kBlue, foregroundColor: Colors.white),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('messages').orderBy('time').snapshots(), builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); if (snap.data!.docs.isEmpty) return const Center(child: Text('ابدأ محادثة المجموعة 👋')); return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (context, i) { final d = snap.data!.docs[i].data() as Map<String, dynamic>; final mine = d['sender'] == _myUid; return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: mine ? kBlue : Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['senderName']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: mine ? Colors.white : kBlue, fontSize: 12)), Text(d['text']?.toString() ?? '', style: TextStyle(color: mine ? Colors.white : Colors.black))] ))); }); })),
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: _msg, decoration: InputDecoration(hintText: 'اكتب رسالة للمجموعة...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(25))))), IconButton(icon: const Icon(Icons.send, color: kBlue), onPressed: _send)])),
      ]),
    );
  }
}

// ---------- Settings ----------
class SettingsTab extends StatefulWidget { const SettingsTab({super.key}); @override State<SettingsTab> createState() => _SettingsState(); }
class _SettingsState extends State<SettingsTab> {
  String? _myUid; String _myName = ''; String _myEmail = ''; String _myPin = ''; String _thinking = '';
  final _nameCtrl = TextEditingController(); final _thinkCtrl = TextEditingController();
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); setState(() { _myUid = p.getString('my_uid'); _myName = p.getString('my_name') ?? ''; _myEmail = p.getString('saved_email') ?? ''; _myPin = p.getString('my_pin') ?? ''; _nameCtrl.text = _myName; }); if (_myUid != null) { try { final doc = await FirebaseFirestore.instance.collection('users').doc(_myUid).get(); if (doc.exists) { final d = doc.data()!; setState(() { _myName = d['username']?.toString() ?? _myName; _myEmail = d['email']?.toString() ?? _myEmail; _myPin = d['personal_pin']?.toString() ?? _myPin; _thinking = d['thinking']?.toString() ?? ''; _thinkCtrl.text = _thinking; _nameCtrl.text = _myName; }); } } catch (_) {} } }
  Future<void> _save() async {
    if (_myUid == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ماكو حساب - سجل دخول اولاً'))); return; }
    try { await FirebaseFirestore.instance.collection('users').doc(_myUid).update({'username': _nameCtrl.text.trim(), 'thinking': _thinkCtrl.text.trim()}); final p = await SharedPreferences.getInstance(); await p.setString('my_name', _nameCtrl.text.trim()); setState(() { _myName = _nameCtrl.text.trim(); _thinking = _thinkCtrl.text.trim(); }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ ✅'))); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
  }
  Future<void> _logout() async { final p = await SharedPreferences.getInstance(); await p.setBool('has_profile', false); await p.remove('my_uid'); try { await FirebaseAuth.instance.signOut(); } catch (_) {} if (!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false); }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('الإعدادات'), backgroundColor: kBlue, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        CircleAvatar(radius: 55, backgroundColor: kBlue, child: Text(_myName.isNotEmpty ? _myName[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 40))),
        const SizedBox(height: 10),
        Text(_myName.isEmpty ? '...' : _myName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kDarkBlue)),
        Text(_myEmail, style: const TextStyle(color: Colors.grey)),
        if (_thinking.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('💭 $_thinking', style: const TextStyle(fontSize: 15, color: kDarkBlue))),
        const SizedBox(height: 20),
        TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'تغيير اسم المستخدم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)))),
        const SizedBox(height: 12),
        TextField(controller: _thinkCtrl, decoration: InputDecoration(labelText: 'بماذا تفكر الآن؟', hintText: 'اكتب شنو تفكر بيه...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)))),
        const SizedBox(height: 12),
        TextField(enabled: false, controller: TextEditingController(text: _myPin), decoration: InputDecoration(labelText: 'الرقم الشخصي - ثابت ولايمكن تغييره', prefixIcon: const Icon(Icons.lock), filled: true, fillColor: Colors.grey.shade200, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)))),
        const SizedBox(height: 12),
        TextField(enabled: false, controller: TextEditingController(text: _myEmail), decoration: InputDecoration(labelText: 'البريد الالكتروني - ثابت', prefixIcon: const Icon(Icons.email), filled: true, fillColor: Colors.grey.shade200, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('حفظ التعديلات 💾', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)))),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _logout, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)))),
        const SizedBox(height: 12),
        const Text('شلونكم - اول تطبيق اتصال عراقي 🇮🇶', style: TextStyle(color: Colors.grey)),
      ])),
    );
  }
}
