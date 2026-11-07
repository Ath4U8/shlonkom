import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (e) { print('Firebase init failed: $e'); }
  runApp(const ShlonkomApp());
}

const Color kGreen = Color(0xFF0F5132);
const Color kAccent = Color(0xFF00C950);
const Color kCard = Color(0xFF17462F);
const Color kBg = Color(0xFF0F5132);

class ShlonkomApp extends StatelessWidget {
  const ShlonkomApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شلونكم',
      theme: ThemeData(primaryColor: kGreen, scaffoldBackgroundColor: kBg, fontFamily: 'Cairo'),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: kAccent)));
        }
        if (snap.data == null) return const LoginScreen();
        return const VerifyScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isSignup = false;
  bool _busy = false;
  String _err = '';
  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _err = 'اكمل البيانات');
      return;
    }
    setState(() { _busy = true; _err = ''; });
    try {
      if (_isSignup) {
        var cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());
        await cred.user!.sendEmailVerification();
        setState(() => _err = 'تم ارسال رابط التفعيل لبريدك - فعله وبعدين سجل دخول');
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') setState(() => _err = 'هذا الايميل مسجل من قبل - سجل دخول');
      else if (e.code == 'user-not-found') setState(() => _err = 'ماكو حساب بهذا الايميل');
      else if (e.code == 'wrong-password') setState(() => _err = 'كلمة المرور غلط');
      else setState(() => _err = e.message ?? 'خطأ');
    } catch (e) {
      setState(() => _err = e.toString());
    }
    setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/login_bg.png'), fit: BoxFit.cover)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('شلونكم', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('دردش واتصل بأهلك وأصدقائك', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 30),
                TextField(controller: _email, decoration: _dec('البريد الإلكتروني'), style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                TextField(controller: _pass, obscureText: true, decoration: _dec('كلمة المرور'), style: const TextStyle(color: Colors.white)),
                if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err, style: const TextStyle(color: Colors.yellow), textAlign: TextAlign.center)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _busy ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: Text(_isSignup ? 'إنشاء حساب' : 'تسجيل الدخول', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)))),
                TextButton(onPressed: () => setState(() => _isSignup = !_isSignup), child: Text(_isSignup ? 'عندي حساب - تسجيل الدخول' : 'إنشاء حساب جديد', style: const TextStyle(color: Colors.white))),
                TextButton(onPressed: () async {
                  if (_email.text.trim().isEmpty) { setState(() => _err = 'اكتب ايميلك أولا'); return; }
                  try { await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim()); setState(() => _err = 'دزينا رابط استرجاع لبريدك'); } catch (e) { setState(() => _err = 'تعذر ارسال الرابط'); }
                }, child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        ),
      ),
    );
  }
  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));
}

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});
  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  Timer? _t;
  @override
  void initState() { super.initState(); _t = Timer.periodic(const Duration(seconds: 3), (_) async { await FirebaseAuth.instance.currentUser?.reload(); if (mounted) setState(() {}); }); }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) return const ProfileGate();
    return Scaffold(
      backgroundColor: kBg,
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.email_outlined, size: 80, color: kAccent),
        const SizedBox(height: 16),
        const Text('يجب تفعيل بريدك أولاً!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('دزينا رابط على ${user?.email ?? ''} - افتح بريدك ودوس على الرابط', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () async { await user?.sendEmailVerification(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعادة ارسال الرابط'))); }, style: ElevatedButton.styleFrom(backgroundColor: kAccent), child: const Text('اعادة ارسال الرابط', style: TextStyle(color: Colors.black))),
        TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white70))),
      ]))),
    );
  }
}

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});
  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(), builder: (context, snap) {
      if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator(color: kAccent)));
      if (!snap.data!.exists) return const CreateProfileScreen();
      return const HomeScreen();
    });
  }
}

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});
  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _name = TextEditingController();
  String _base64Image = '';
  bool _busy = false;
  String _err = '';
  Future<void> _pick() async {
    var x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (x == null) return;
    var bytes = await x.readAsBytes();
    setState(() => _base64Image = base64Encode(bytes));
  }
  Future<void> _save() async {
    if (_name.text.trim().isEmpty) { setState(() => _err = 'اكتب اسم المستخدم'); return; }
    setState(() => _busy = true);
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var pin = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'username': _name.text.trim(),
      'photoBase64': _base64Image,
      'pin': pin,
      'email': FirebaseAuth.instance.currentUser!.email,
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
    setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: kBg, body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const Text('ملفك الشخصي', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      GestureDetector(onTap: _pick, child: CircleAvatar(radius: 55, backgroundColor: Colors.white24, backgroundImage: _base64Image.isNotEmpty ? MemoryImage(base64Decode(_base64Image)) : null, child: _base64Image.isEmpty ? const Icon(Icons.person, size: 60, color: Colors.white) : null)),
      const SizedBox(height: 8),
      const Text('دوس على الصورة لتغييرها', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 20),
      TextField(controller: _name, decoration: InputDecoration(hintText: 'اسم المستخدم', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err, style: const TextStyle(color: Colors.yellow))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _busy ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('حفظ - واخذ رقمي الشخصي', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
    ]))));
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _idx = 0;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _setOnline(true); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { if (s == AppLifecycleState.paused || s == AppLifecycleState.detached) _setOnline(false); else if (s == AppLifecycleState.resumed) _setOnline(true); }
  Future<void> _setOnline(bool v) async {
    var uid = FirebaseAuth.instance.currentUser?.uid; if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'isOnline': v, 'lastSeen': FieldValue.serverTimestamp()});
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(index: _idx, children: const [ChatListTab(), FriendsTab(), ProfileTab()]),
      bottomNavigationBar: BottomNavigationBar(currentIndex: _idx, onTap: (i) => setState(() => _idx = i), backgroundColor: kCard, selectedItemColor: kAccent, unselectedItemColor: Colors.white70, items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'الدردشات'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'الأصدقاء'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'ملفي'),
      ]),
    );
  }
}

class ChatListTab extends StatelessWidget {
  const ChatListTab({super.key});
  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(backgroundColor: kBg, appBar: AppBar(backgroundColor: kBg, title: const Text('الدردشات', style: TextStyle(color: Colors.white)), automaticallyImplyLeading: false),
      body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').where('members', arrayContains: uid).orderBy('lastTime', descending: true).snapshots(), builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kAccent));
        if (snap.data!.docs.isEmpty) return const Center(child: Text('ابدأ محادثة - اضف صديق برقمه الشخصي', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center));
        return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c, i) {
          var d = snap.data!.docs[i].data() as Map<String, dynamic>;
          var otherId = (d['members'] as List).firstWhere((e) => e != uid, orElse: () => '');
          return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(otherId).get(), builder: (ctx, us) {
            var u = us.data?.data() as Map<String, dynamic>? ?? {};
            return ListTile(leading: CircleAvatar(backgroundImage: (u['photoBase64'] ?? '').toString().isNotEmpty ? MemoryImage(base64Decode(u['photoBase64'])) : null, child: (u['photoBase64'] ?? '').toString().isEmpty ? const Icon(Icons.person) : null), title: Text(u['username'] ?? 'صديق', style: const TextStyle(color: Colors.white)), subtitle: Text(d['lastMessage'] ?? '', style: const TextStyle(color: Colors.white60), maxLines: 1), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: snap.data!.docs[i].id, otherId: otherId, otherName: u['username'] ?? 'صديق'))));
          });
        });
      }));
  }
}

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});
  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final _pinCtrl = TextEditingController();
  String _msg = '';
  Future<void> _search() async {
    var pin = _pinCtrl.text.trim();
    if (pin.length != 6) { setState(() => _msg = 'الرمز 6 ارقام'); return; }
    var q = await FirebaseFirestore.instance.collection('users').where('pin', isEqualTo: pin).limit(1).get();
    if (q.docs.isEmpty) { setState(() => _msg = 'لم نعثر على صديق بهذا الرمز'); return; }
    var doc = q.docs.first;
    var myUid = FirebaseAuth.instance.currentUser!.uid;
    if (doc.id == myUid) { setState(() => _msg = 'هذا رمزك انت!'); return; }
    var chatId = myUid.compareTo(doc.id) < 0 ? '${myUid}_${doc.id}' : '${doc.id}_$myUid';
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({'members': [myUid, doc.id], 'lastMessage': '', 'lastTime': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    setState(() => _msg = 'تمت الاضافة - روح للدردشات');
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: kBg, appBar: AppBar(backgroundColor: kBg, title: const Text('إضافة صديق', style: TextStyle(color: Colors.white)), automaticallyImplyLeading: false), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const Text('ادخل رمز صديقك المكون من 6 ارقام', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 16),
      TextField(controller: _pinCtrl, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, letterSpacing: 10), decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _search, style: ElevatedButton.styleFrom(backgroundColor: kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('بحث وإضافة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
      if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg, style: const TextStyle(color: Colors.yellow))),
    ])));
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(backgroundColor: kBg, appBar: AppBar(backgroundColor: kBg, title: const Text('ملفي', style: TextStyle(color: Colors.white)), automaticallyImplyLeading: false), body: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(), builder: (ctx, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kAccent));
      var d = snap.data!.data() as Map<String, dynamic>? ?? {};
      return Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        CircleAvatar(radius: 55, backgroundImage: (d['photoBase64'] ?? '').toString().isNotEmpty ? MemoryImage(base64Decode(d['photoBase64'])) : null, child: (d['photoBase64'] ?? '').toString().isEmpty ? const Icon(Icons.person, size: 50) : null),
        const SizedBox(height: 12),
        Text(d['username'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('رقمي الشخصي', style: TextStyle(color: Colors.white70)), Text(d['pin'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4))])),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => FirebaseAuth.instance.signOut(), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)))),
      ]));
    }));
  }
}

class ChatScreen extends StatefulWidget {
  final String chatId; final String otherId; final String otherName;
  const ChatScreen({super.key, required this.chatId, required this.otherId, required this.otherName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _picker = ImagePicker();
  Future<void> _sendText() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var txt = _msgCtrl.text.trim(); _msgCtrl.clear();
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({'sender': uid, 'text': txt, 'type': 'text', 'time': FieldValue.serverTimestamp(), 'seen': false});
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({'lastMessage': txt, 'lastTime': FieldValue.serverTimestamp()});
  }
  Future<void> _sendImage() async {
    var x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (x == null) return;
    var bytes = await x.readAsBytes();
    var uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({'sender': uid, 'text': '', 'imageBase64': base64Encode(bytes), 'type': 'image', 'time': FieldValue.serverTimestamp(), 'seen': false});
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({'lastMessage': 'صورة', 'lastTime': FieldValue.serverTimestamp()});
  }
  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(backgroundColor: kBg, appBar: AppBar(backgroundColor: kCard, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)), title: Text(widget.otherName, style: const TextStyle(color: Colors.white))),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').orderBy('time').snapshots(), builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kAccent));
          for (var doc in snap.data!.docs) {
            var dd = doc.data() as Map<String, dynamic>;
            if (dd['sender'] != uid && dd['seen'] != true) doc.reference.update({'seen': true});
          }
          return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c, i) {
            var d = snap.data!.docs[i].data() as Map<String, dynamic>;
            bool me = d['sender'] == uid;
            bool isImg = d['type'] == 'image';
            return Align(alignment: me ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: me ? kAccent : kCard, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (isImg) GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewScreen(b64: d['imageBase64'] ?? ''))), child: Image.memory(base64Decode(d['imageBase64']), width: 200, height: 180, fit: BoxFit.cover)),
              if (!isImg) Text(d['text'] ?? '', style: TextStyle(color: me ? Colors.black : Colors.white, fontSize: 16)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [if (me) Icon(d['seen'] == true ? Icons.done_all : Icons.done, size: 14, color: d['seen'] == true ? Colors.blue : Colors.black54)]),
            ])));
          });
        })),
        Container(padding: const EdgeInsets.all(8), color: kCard, child: Row(children: [
          IconButton(icon: const Icon(Icons.image, color: kAccent), onPressed: _sendImage),
          Expanded(child: TextField(controller: _msgCtrl, decoration: InputDecoration(hintText: 'اكتب رسالة', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)))),
          IconButton(icon: const Icon(Icons.send, color: kAccent), onPressed: _sendText),
        ])),
      ]));
  }
}

class ImageViewScreen extends StatelessWidget {
  final String b64; const ImageViewScreen({super.key, required this.b64});
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))), body: Center(child: b64.isNotEmpty ? Image.memory(base64Decode(b64)) : const Text('لا توجد صورة', style: TextStyle(color: Colors.white))));
  }
}
