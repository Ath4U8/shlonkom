
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ShlonkomApp());
}

const Color kBlue = Color(0xFF1E5BFF);
const Color kBlueDark = Color(0xFF0A3DCC);
const Color kBlueLight = Color(0xFF4A90FF);
const Color kSky = Color(0xFF7EC8FF);

class ShlonkomApp extends StatelessWidget {
  const ShlonkomApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شلونكم',
      theme: ThemeData(fontFamily: 'Cairo'),
      home: const SplashScreen(),
    );
  }
}

// ---------- SPLASH ----------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }
  Future<void> _go() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    var prefs = await SharedPreferences.getInstance();
    var last = prefs.getInt('lastActive') ?? 0;
    var now = DateTime.now().millisecondsSinceEpoch;
    var diffDays = (now - last) / (1000 * 60 * 60 * 24);
    var logged = FirebaseAuth.instance.currentUser != null;
    // اول مرة او ترك اكثر من 6 ايام -> دخول
    if (!logged || last == 0 || diffDays > 6) {
      if (logged) await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    await prefs.setInt('lastActive', now);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainGate()));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A90FF), Color(0xFFBFE6FF), Color(0xFF1E5BFF)])),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(40)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.phone, color: Colors.white, size: 34),
                  SizedBox(width: 6),
                  Text('شلونكم', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 14),
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20)), child: const Text('اهلا وسهلا بكم في اول تطبيق اتصال عراقي', style: TextStyle(color: kBlueDark, fontWeight: FontWeight.bold))),
              const Spacer(),
              const Text('برج بغداد  |  نهر دجلة  |  العراق', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 10),
              const Text('جاري التحميل...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              Container(height: 60, decoration: const BoxDecoration(color: Color(0xFF0A3DCC), borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))), child: const Center(child: Text('شلونكم - عراقي 100%', style: TextStyle(color: Colors.white70)))),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- LOGIN ----------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String _err = '';
  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pin.text.trim().length != 8) { setState(() => _err = 'اكتب الايميل والرقم الشخصي 8 ارقام'); return; }
    setState(() { _busy = true; _err = ''; });
    try {
      var q = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: _email.text.trim()).where('pin', isEqualTo: _pin.text.trim()).limit(1).get();
      if (q.docs.isEmpty) { setState(() => _err = 'الايميل او الرقم الشخصي غلط'); _busy = false; return; }
      var uid = q.docs.first.id;
      var prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', uid);
      await prefs.setInt('lastActive', DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('myPin', _pin.text.trim());
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainGate()));
    } catch (e) { setState(() => _err = 'تعذر الدخول - تحقق من النت'); }
    setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A90FF), Color(0xFFD9EEFF), Colors.white])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('شلونكم', style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: kBlueDark)),
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(20)), child: const Text('اهلا وسهلا بكم في اول تطبيق اتصال عراقي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 40, height: 12, color: Colors.red), Container(width: 40, height: 12, color: Colors.white, child: const Center(child: Text('الله أكبر', style: TextStyle(fontSize: 7, color: Colors.green, fontWeight: FontWeight.bold)))), Container(width: 40, height: 12, color: Colors.black)]),
                const SizedBox(height: 24),
                _field(_email, 'البريد الإلكتروني', Icons.email_outlined, false),
                const SizedBox(height: 12),
                _field(_pin, 'الرقم الشخصي', Icons.phone_outlined, false, isNum: true),
                if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err, style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _busy ? null : _login, style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('تسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(width: 8), Icon(Icons.arrow_forward)]))),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, height: 54, child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAccountScreen())), style: OutlinedButton.styleFrom(side: const BorderSide(color: kBlue, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_add, color: kBlue), SizedBox(width: 8), Text('انشاء حساب جديد', style: TextStyle(color: kBlue, fontWeight: FontWeight.bold, fontSize: 16))]))),
                const SizedBox(height: 16),
                const Text('اول مرة: انشاء حساب  |  ثاني مرة: تسجيل الدخول', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _field(TextEditingController c, String h, IconData ic, bool obs, {bool isNum = false}) {
    return TextField(controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.emailAddress, maxLength: isNum ? 8 : null, decoration: InputDecoration(prefixIcon: Icon(ic, color: kBlue), hintText: h, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), counterText: ''));
  }
}

// ---------- CREATE ACCOUNT ----------
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});
  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}
class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pin = TextEditingController();
  String _b64 = '';
  bool _busy = false;
  String _err = '';
  Future<void> _pick() async {
    var x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (x == null) return;
    var b = await x.readAsBytes();
    setState(() => _b64 = base64Encode(b));
  }
  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _pin.text.trim().length != 8) { setState(() => _err = 'اكمل البيانات - الرقم 8 ارقام'); return; }
    setState(() { _busy = true; _err = ''; });
    try {
      var ex = await FirebaseFirestore.instance.collection('users').where('pin', isEqualTo: _pin.text.trim()).limit(1).get();
      if (ex.docs.isNotEmpty) { setState(() => _err = 'هذا الرقم مستخدم - اختر رقم ثاني'); _busy = false; return; }
      var doc = await FirebaseFirestore.instance.collection('users').add({'username': _name.text.trim(), 'email': _email.text.trim(), 'pin': _pin.text.trim(), 'photoBase64': _b64, 'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()});
      var prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', doc.id);
      await prefs.setInt('lastActive', DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('myPin', _pin.text.trim());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainGate()), (r) => false);
    } catch (e) { setState(() => _err = 'تعذر انشاء الحساب - تحقق من النت'); }
    setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A90FF), Color(0xFFD9EEFF), Colors.white])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(children: [IconButton(icon: const Icon(Icons.arrow_back, color: kBlueDark), onPressed: () => Navigator.pop(context)), const Expanded(child: Center(child: Text('شلونكم', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kBlueDark))))]),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(20)), child: const Text('اهلا وسهلا بكم في اول تطبيق اتصال عراقي', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(height: 20),
                GestureDetector(onTap: _pick, child: Stack(children: [CircleAvatar(radius: 55, backgroundColor: Colors.grey.shade300, backgroundImage: _b64.isNotEmpty ? MemoryImage(base64Decode(_b64)) : null, child: _b64.isEmpty ? const Icon(Icons.person, size: 60, color: Colors.grey) : null), Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 18)))])),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _pick, style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('تغيير الصورة')),
                const SizedBox(height: 16),
                _box('اسم المستخدم', 'مثال: حيدر العراقي', _name, false),
                const SizedBox(height: 12),
                _box('الايميل', 'example@gmail.com', _email, false),
                const SizedBox(height: 12),
                _box('الرقم الشخصي', '07812345678 - مثال فقط', _pin, true),
                const Row(children: [Icon(Icons.info_outline, size: 16, color: kBlue), SizedBox(width: 4), Text('مكون من 8 أرقام وهو ثابت ولايمكن تغييره', style: TextStyle(fontSize: 12, color: Colors.grey))]),
                if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err, style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _busy ? null : _create, style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.save), SizedBox(width: 8), Text('انشاء الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]))),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _box(String label, String hint, TextEditingController c, bool isNum) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: kBlueDark)),
      const SizedBox(height: 4),
      TextField(controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.text, maxLength: isNum ? 8 : null, decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), counterText: '', suffixIcon: isNum ? const Icon(Icons.lock_outline) : null)),
    ]);
  }
}

// ---------- GATE ----------
class MainGate extends StatelessWidget {
  const MainGate({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(future: SharedPreferences.getInstance(), builder: (c, s) {
      if (!s.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      var uid = s.data!.getString('uid') ?? '';
      if (uid.isEmpty) return const LoginScreen();
      return HomeScreen(myUid: uid);
    });
  }
}

// ---------- HOME ----------
class HomeScreen extends StatefulWidget {
  final String myUid;
  const HomeScreen({super.key, required this.myUid});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  @override
  void initState() { super.initState(); _online(true); }
  Future<void> _online(bool v) async { try { await FirebaseFirestore.instance.collection('users').doc(widget.myUid).update({'isOnline': v, 'lastSeen': FieldValue.serverTimestamp()}); } catch (_) {} }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: [ContactsTab(myUid: widget.myUid), ChatsTab(myUid: widget.myUid), CallsTab(myUid: widget.myUid), SettingsTab(myUid: widget.myUid)]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx, onTap: (i) => setState(() => _idx = i), selectedItemColor: kBlue, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'جهات الاتصال'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'المحادثات'),
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: 'لوحة الاتصال'),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'المكالمات'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ---------- CONTACTS ----------
class ContactsTab extends StatefulWidget {
  final String myUid;
  const ContactsTab({super.key, required this.myUid});
  @override
  State<ContactsTab> createState() => _ContactsTabState();
}
class _ContactsTabState extends State<ContactsTab> {
  String _search = '';
  final _addPin = TextEditingController();
  String _msg = '';
  Future<void> _addFriend() async {
    if (_addPin.text.trim().length != 8) { setState(() => _msg = 'الرقم 8 ارقام'); return; }
    var q = await FirebaseFirestore.instance.collection('users').where('pin', isEqualTo: _addPin.text.trim()).limit(1).get();
    if (q.docs.isEmpty) { setState(() => _msg = 'ماكو صديق بهذا الرقم'); return; }
    if (q.docs.first.id == widget.myUid) { setState(() => _msg = 'هذا رقمك انت'); return; }
    var chatId = widget.myUid.compareTo(q.docs.first.id) < 0 ? '${widget.myUid}_${q.docs.first.id}' : '${q.docs.first.id}_${widget.myUid}';
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({'members': [widget.myUid, q.docs.first.id], 'lastMessage': '', 'lastTime': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    setState(() => _msg = 'تمت الاضافة');
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FF),
      appBar: AppBar(backgroundColor: kBlue, title: const Text('شلونكم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), actions: [IconButton(icon: const Icon(Icons.person_add, color: Colors.white), onPressed: () { showDialog(context: context, builder: (_) => AlertDialog(title: const Text('اضافة صديق بالرقم'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _addPin, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(hintText: 'الرقم الشخصي 8 ارقام')), if (_msg.isNotEmpty) Text(_msg)]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('الغاء')), ElevatedButton(onPressed: () async { await _addFriend(); if (mounted) Navigator.pop(context); }, child: const Text('اضافة'))])); })]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(hintText: 'البحث في جهات الاتصال...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))),
        Row(children: [Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), color: kBlue, child: const Center(child: Text('جهات الاتصال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))), Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), color: Colors.white, child: const Center(child: Text('المكالمات الأخيرة'))))]),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').snapshots(), builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snap.data!.docs.where((d) => d.id != widget.myUid).toList();
          docs = docs.where((d) { var m = d.data() as Map<String, dynamic>; return (m['username'] ?? '').toString().contains(_search) || _search.isEmpty; }).toList();
          if (docs.isEmpty) return const Center(child: Text('ماكو اصدقاء - اضف صديق برقمه الشخصي'));
          return ListView.builder(itemCount: docs.length, itemBuilder: (ctx, i) {
            var d = docs[i].data() as Map<String, dynamic>;
            bool on = d['isOnline'] == true;
            return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: ListTile(
              leading: Stack(children: [CircleAvatar(radius: 26, backgroundImage: (d['photoBase64'] ?? '').toString().isNotEmpty ? MemoryImage(base64Decode(d['photoBase64'])) : null, child: (d['photoBase64'] ?? '').toString().isEmpty ? const Icon(Icons.person) : null), Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: on ? Colors.green : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.white))))]),
              title: Text(d['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(on ? 'متصل الآن' : 'آخر ظهور', style: TextStyle(color: on ? Colors.green : Colors.grey, fontSize: 12)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.chat_bubble, color: kBlue), onPressed: () { var chatId = widget.myUid.compareTo(docs[i].id) < 0 ? '${widget.myUid}_${docs[i].id}' : '${docs[i].id}_${widget.myUid}'; Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myUid: widget.myUid, chatId: chatId, otherId: docs[i].id, otherName: d['username'] ?? ''))); }),
                IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IncomingCallScreen(name: d['username'] ?? '', photoB64: d['photoBase64'] ?? '')))),
              ]),
            ));
          });
        })),
      ]),
    );
  }
}

class ChatsTab extends StatelessWidget {
  final String myUid;
  const ChatsTab({super.key, required this.myUid});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(backgroundColor: kBlue, title: const Text('المحادثات', style: TextStyle(color: Colors.white))), body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').where('members', arrayContains: myUid).orderBy('lastTime', descending: true).snapshots(), builder: (c, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      if (snap.data!.docs.isEmpty) return const Center(child: Text('ماكو محادثات - اضف صديق'));
      return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) {
        var d = snap.data!.docs[i].data() as Map<String, dynamic>;
        var other = (d['members'] as List).firstWhere((e) => e != myUid, orElse: () => '');
        return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(other).get(), builder: (cc, us) { var u = us.data?.data() as Map<String, dynamic>? ?? {}; return ListTile(leading: CircleAvatar(backgroundImage: (u['photoBase64'] ?? '').toString().isNotEmpty ? MemoryImage(base64Decode(u['photoBase64'])) : null, child: (u['photoBase64'] ?? '').toString().isEmpty ? const Icon(Icons.person) : null), title: Text(u['username'] ?? ''), subtitle: Text(d['lastMessage'] ?? ''), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myUid: myUid, chatId: snap.data!.docs[i].id, otherId: other, otherName: u['username'] ?? '')))); });
      });
    }));
  }
}

class CallsTab extends StatelessWidget {
  final String myUid;
  const CallsTab({super.key, required this.myUid});
  @override
  Widget build(BuildContext context) { return Scaffold(appBar: AppBar(backgroundColor: kBlue, title: const Text('لوحة الاتصال', style: TextStyle(color: Colors.white))), body: const Center(child: Text('اتصل بصديقك من قائمة جهات الاتصال'))); }
}

class SettingsTab extends StatelessWidget {
  final String myUid;
  const SettingsTab({super.key, required this.myUid});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(backgroundColor: kBlue, title: const Text('الإعدادات', style: TextStyle(color: Colors.white))), body: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(), builder: (c, s) { var d = s.data?.data() as Map<String, dynamic>? ?? {}; return Padding(padding: const EdgeInsets.all(20), child: Column(children: [CircleAvatar(radius: 50, backgroundImage: (d['photoBase64'] ?? '').toString().isNotEmpty ? MemoryImage(base64Decode(d['photoBase64'])) : null, child: (d['photoBase64'] ?? '').toString().isEmpty ? const Icon(Icons.person, size: 50) : null), const SizedBox(height: 10), Text(d['username'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text('رقمي الشخصي: ${d['pin'] ?? ''}', style: const TextStyle(fontSize: 18, color: kBlueDark)), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { var p = await SharedPreferences.getInstance(); await p.clear(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('تسجيل الخروج')))])); }));
  }
}

// ---------- CHAT ----------
class ChatScreen extends StatefulWidget {
  final String myUid; final String chatId; final String otherId; final String otherName;
  const ChatScreen({super.key, required this.myUid, required this.chatId, required this.otherId, required this.otherName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    var txt = _ctrl.text.trim(); _ctrl.clear();
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({'sender': widget.myUid, 'text': txt, 'type': 'text', 'time': FieldValue.serverTimestamp(), 'seen': false});
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({'members': [widget.myUid, widget.otherId], 'lastMessage': txt, 'lastTime': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
  Future<void> _sendImg() async {
    var x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (x == null) return;
    var b = await x.readAsBytes();
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({'sender': widget.myUid, 'text': '', 'imageBase64': base64Encode(b), 'type': 'image', 'time': FieldValue.serverTimestamp(), 'seen': false});
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({'members': [widget.myUid, widget.otherId], 'lastMessage': 'صورة', 'lastTime': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBlue,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.otherId).snapshots(),
          builder: (c, s) {
            var d = s.data?.data() as Map<String, dynamic>? ?? {};
            bool on = d['isOnline'] == true;
            return Row(children: [
              CircleAvatar(radius: 18, backgroundImage: (d['photoBase64'] ?? '').toString().isNotEmpty ? MemoryImage(base64Decode(d['photoBase64'])) : null, child: (d['photoBase64'] ?? '').toString().isEmpty ? const Icon(Icons.person, size: 18) : null),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.otherName, style: const TextStyle(color: Colors.white, fontSize: 16)), Text(on ? 'متصل الآن' : 'آخر ظهور', style: const TextStyle(color: Colors.white70, fontSize: 11))]),
            ]);
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IncomingCallScreen(name: widget.otherName, photoB64: '')))),
          IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD9EEFF), Colors.white])),
        child: Column(children: [
          Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Text('اليوم', style: TextStyle(color: Colors.grey))),
          Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').orderBy('time').snapshots(), builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            for (var doc in snap.data!.docs) { var dd = doc.data() as Map<String, dynamic>; if (dd['sender'] != widget.myUid && dd['seen'] != true) doc.reference.update({'seen': true}); }
            if (snap.data!.docs.isEmpty) return const Center(child: Text('ابدأ المحادثة - اكتب اول رسالة'));
            return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) {
              var d = snap.data!.docs[i].data() as Map<String, dynamic>;
              bool me = d['sender'] == widget.myUid;
              bool isImg = d['type'] == 'image';
              return Align(alignment: me ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: me ? kBlue : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (isImg) GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullImage(b64: d['imageBase64'] ?? ''))), child: Image.memory(base64Decode(d['imageBase64']), width: 200, height: 180, fit: BoxFit.cover)),
                if (!isImg) Text(d['text'] ?? '', style: TextStyle(color: me ? Colors.white : Colors.black, fontSize: 16)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [Text('الآن', style: TextStyle(fontSize: 10, color: me ? Colors.white70 : Colors.grey)), const SizedBox(width: 4), if (me) Icon(d['seen'] == true ? Icons.done_all : Icons.done, size: 14, color: d['seen'] == true ? Colors.lightBlueAccent : Colors.white70)]),
              ])));
            });
          })),
          Container(padding: const EdgeInsets.all(8), color: Colors.white, child: Row(children: [
            IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: () {}),
            Expanded(child: TextField(controller: _ctrl, decoration: InputDecoration(hintText: 'اكتب رسالة...', filled: true, fillColor: const Color(0xFFF2F7FF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))),
            IconButton(icon: const Icon(Icons.image, color: kBlue), onPressed: _sendImg),
            IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _sendImg),
            Container(decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.mic, color: Colors.white), onPressed: () {})),
            const SizedBox(width: 4),
            Container(decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _send)),
          ])),
        ]),
      ),
    );
  }
}

class FullImage extends StatelessWidget {
  final String b64;
  const FullImage({super.key, required this.b64});
  @override
  Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))), body: Center(child: b64.isNotEmpty ? Image.memory(base64Decode(b64)) : const Text('لا توجد صورة', style: TextStyle(color: Colors.white)))); }
}

// ---------- INCOMING CALL ----------
class IncomingCallScreen extends StatelessWidget {
  final String name; final String photoB64;
  const IncomingCallScreen({super.key, required this.name, required this.photoB64});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A90FF), Color(0xFF1E5BFF), Color(0xFF0A3DCC)])),
        child: SafeArea(
          child: Column(
            children: [
              const Text('شلونكم', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: CircleAvatar(radius: 90, backgroundImage: photoB64.isNotEmpty ? MemoryImage(base64Decode(photoB64)) : null, child: photoB64.isEmpty ? const Icon(Icons.person, size: 90) : null)),
              const SizedBox(height: 20),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.call, color: Colors.white), SizedBox(width: 8), Text('مكالمة واردة...', style: TextStyle(color: Colors.white, fontSize: 20))]),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Column(children: [Container(decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.call_end, color: Colors.white, size: 40), onPressed: () => Navigator.pop(context))), const SizedBox(height: 6), const Text('رفض', style: TextStyle(color: Colors.white, fontSize: 18))]),
                const Icon(Icons.keyboard_double_arrow_up, color: Colors.white54, size: 40),
                Column(children: [Container(decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.call, color: Colors.white, size: 40), onPressed: () => Navigator.pop(context))), const SizedBox(height: 6), const Text('قبول', style: TextStyle(color: Colors.white, fontSize: 18))]),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
