
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ShlonkomApp());
}

class ShlonkomApp extends StatelessWidget {
  const ShlonkomApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شلونكم',
      theme: ThemeData(fontFamily: 'Cairo', primaryColor: const Color(0xFF0F5132), scaffoldBackgroundColor: Colors.white),
      home: const SplashScreen(),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}

// SPLASH - Thunkable style green
class SplashScreen extends StatefulWidget { const SplashScreen({super.key}); @override State<SplashScreen> createState() => _SplashState(); }
class _SplashState extends State<SplashScreen> {
  @override void initState() { super.initState(); Future.delayed(const Duration(seconds: 2), check); }
  Future<void> check() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    if (email != null && FirebaseAuth.instance.currentUser != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainChatHomeScreen(myEmail: email, myUsername: prefs.getString('saved_username') ?? 'شلونكم', myPin: prefs.getString('saved_personal_pin') ?? '')));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
    }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0F5132), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 120, height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)), child: const Icon(Icons.chat_bubble, size: 70, color: Color(0xFF0F5132))),
      const SizedBox(height: 20),
      const Text('شلونكم', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
      const Text('أول تطبيق مراسلة عراقي', style: TextStyle(color: Colors.white70, fontSize: 16)),
      const SizedBox(height: 10),
      const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.white54, fontSize: 12)),
    ])));
  }
}

// WELCOME
class WelcomeScreen extends StatelessWidget { const WelcomeScreen({super.key}); @override Widget build(BuildContext context) {
  return Scaffold(backgroundColor: const Color(0xFF0F5132), body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 130, height: 130, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(35)), child: const Icon(Icons.chat_bubble_outline, size: 80, color: Color(0xFF0F5132))),
    const SizedBox(height: 24),
    const Text('شلونكم', style: TextStyle(fontSize: 46, fontWeight: FontWeight.bold, color: Colors.white)),
    const Text('دردش واتصل ويا اصدقائك\nمجاناً 100% - عراقي 100%', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 17)),
    const SizedBox(height: 40),
    SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C950), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('ابدأ - Start', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)))),
    const SizedBox(height: 12),
    TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPinScreen())), child: const Text('عندي حساب - دخول بالرقم الشخصي', style: TextStyle(color: Colors.white))),
  ])))));
}}

// REGISTER EMAIL
class RegisterScreen extends StatefulWidget { const RegisterScreen({super.key}); @override State<RegisterScreen> createState() => _RegState(); }
class _RegState extends State<RegisterScreen> {
  final _email = TextEditingController(); final _pass = TextEditingController(); bool _loading = false; String _err = '';
  Future<void> _register() async {
    setState(() {_loading = true; _err = '';});
    try {
      var cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());
      await cred.user!.sendEmailVerification();
      Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyScreen(email: _email.text.trim())));
    } catch (e) { setState(() {_err = 'خطأ: $e';}); }
    setState(() {_loading = false;});
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white, appBar: AppBar(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, title: const Text('تسجيل جديد'), automaticallyImplyLeading: false), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 20),
      const Icon(Icons.email, size: 70, color: Color(0xFF0F5132)),
      const Text('سجل بايميلك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      TextField(controller: _email, decoration: InputDecoration(labelText: 'الايميل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
      const SizedBox(height: 12),
      TextField(controller: _pass, obscureText: true, decoration: InputDecoration(labelText: 'كلمة السر - 6 احرف على الاقل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
      if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _loading ? null : _register, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل وارسال رابط التفعيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
    ]))));
  }
}

// VERIFY
class VerifyScreen extends StatefulWidget { final String email; const VerifyScreen({super.key, required this.email}); @override State<VerifyScreen> createState() => _VerifyState(); }
class _VerifyState extends State<VerifyScreen> {
  Timer? _timer;
  @override void initState() { super.initState(); _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check()); }
  Future<void> _check() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      _timer?.cancel();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CreateProfileScreen(email: widget.email)));
    }
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white, appBar: AppBar(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, title: const Text('تفعيل الايميل'), automaticallyImplyLeading: false), body: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.mark_email_read, size: 80, color: Color(0xFF00C950)),
      const SizedBox(height: 16),
      Text('دزينا رابط تفعيل لـ\n${widget.email}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const Text('افتح ايميلك ودوس على الرابط، وراح ندخلك تلقائياً...', textAlign: TextAlign.center),
      const SizedBox(height: 20),
      const CircularProgressIndicator(color: Color(0xFF0F5132)),
      const SizedBox(height: 20),
      TextButton(onPressed: () async { await FirebaseAuth.instance.currentUser?.sendEmailVerification(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعادة ارسال الرابط'))); }, child: const Text('اعادة ارسال الرابط')),
    ]))));
  }
}

// CREATE PROFILE - ONLY username + photo, PIN fixed, login_bg.png background
class CreateProfileScreen extends StatefulWidget { final String email; const CreateProfileScreen({super.key, required this.email}); @override State<CreateProfileScreen> createState() => _ProfileState(); }
class _ProfileState extends State<CreateProfileScreen> {
  final _username = TextEditingController(); String? _base64Image; bool _loading = false; late String _pin;
  @override void initState() { super.initState(); _pin = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString(); }
  Future<void> _pickImage() async {
    final XFile? f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (f != null) { final bytes = await f.readAsBytes(); setState(() { _base64Image = base64Encode(bytes); }); }
  }
  Future<void> _save() async {
    if (_username.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسم المستخدم'))); return; }
    setState(() { _loading = true; });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', widget.email);
      await prefs.setString('saved_username', _username.text.trim());
      await prefs.setString('saved_personal_pin', _pin);
      await FirebaseFirestore.instance.collection('users').doc(widget.email).set({
        'email': widget.email, 'username': _username.text.trim(), 'personal_pin': _pin,
        'profile_photo_base64': _base64Image ?? '', 'isOnline': true, 'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainChatHomeScreen(myEmail: widget.email, myUsername: _username.text.trim(), myPin: _pin)));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
    setState(() { _loading = false; });
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, title: const Text('اعداد البروفايل'), automaticallyImplyLeading: false), body: Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/login_bg.png'), fit: BoxFit.cover)),
      child: Container(color: Colors.white.withOpacity(0.85), child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
        const SizedBox(height: 10),
        GestureDetector(onTap: _pickImage, child: CircleAvatar(radius: 60, backgroundColor: const Color(0xFF0F5132), backgroundImage: _base64Image != null ? MemoryImage(base64Decode(_base64Image!)) : null, child: _base64Image == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.white) : null)),
        const SizedBox(height: 8),
        const Text('دوس على الدائرة لاضافة صورتك', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        TextField(controller: _username, decoration: InputDecoration(labelText: 'اسم المستخدم', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white)),
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF00C950))), child: Column(children: [
          const Text('رقمك الشخصي - ثابت ما يتغير', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(_pin, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 8)),
          const Text('انطيه لاصدقائك حتى يضيفوك', style: TextStyle(color: Colors.grey)),
        ])),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _loading ? null : _save, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ والدخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)))),
      ])))),
    ));
  }
}

// LOGIN BY PIN
class LoginPinScreen extends StatefulWidget { const LoginPinScreen({super.key}); @override State<LoginPinScreen> createState() => _LoginPinState(); }
class _LoginPinState extends State<LoginPinScreen> {
  final _email = TextEditingController(); final _pin = TextEditingController(); bool _loading = false;
  Future<void> _login() async {
    setState(() { _loading = true; });
    try {
      var q = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: _email.text.trim()).where('personal_pin', isEqualTo: _pin.text.trim()).get();
      if (q.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الايميل او الرقم الشخصي خطأ'))); }
      else {
        var d = q.docs.first.data();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', _email.text.trim());
        await prefs.setString('saved_username', d['username'] ?? '');
        await prefs.setString('saved_personal_pin', d['personal_pin'] ?? '');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainChatHomeScreen(myEmail: _email.text.trim(), myUsername: d['username'] ?? '', myPin: d['personal_pin'] ?? '')));
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
    setState(() { _loading = false; });
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white, appBar: AppBar(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, title: const Text('دخول بالرقم الشخصي'), automaticallyImplyLeading: false), body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 20),
      const Icon(Icons.lock, size: 70, color: Color(0xFF0F5132)),
      const SizedBox(height: 20),
      TextField(controller: _email, decoration: InputDecoration(labelText: 'الايميل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
      const SizedBox(height: 12),
      TextField(controller: _pin, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: 'الرقم الشخصي - 6 ارقام', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _loading ? null : _login, child: const Text('دخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('ما عندي حساب - تسجيل جديد')),
    ]))));
  }
}

// FULL IMAGE VIEWER - tap to open
class FullImageViewer extends StatelessWidget {
  final String imageUrl; const FullImageViewer({super.key, required this.imageUrl});
  @override Widget build(BuildContext context) {
    Widget img;
    if (imageUrl.startsWith('data:image')) {
      try { img = Image.memory(base64Decode(imageUrl.split(',').last), fit: BoxFit.contain); } catch (_) { img = const Text('تعذر فتح الصورة', style: TextStyle(color: Colors.white)); }
    } else { img = Image.network(imageUrl, fit: BoxFit.contain); }
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))), body: Center(child: img));
  }
}

// MAIN CHAT HOME - Thunkable style
class MainChatHomeScreen extends StatefulWidget {
  final String myEmail; final String myUsername; final String myPin;
  const MainChatHomeScreen({super.key, required this.myEmail, required this.myUsername, required this.myPin});
  @override State<MainChatHomeScreen> createState() => _HomeState();
}
class _HomeState extends State<MainChatHomeScreen> with WidgetsBindingObserver {
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); updatePresence(true); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); updatePresence(false); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) updatePresence(true);
    else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) updatePresence(false);
  }
  Future<void> updatePresence(bool online) async {
    try { await FirebaseFirestore.instance.collection('users').doc(widget.myEmail).set({'isOnline': online, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true)); } catch (_) {}
  }
  String _lastSeenText(Timestamp? ts, bool? online) {
    if (online == true) return 'متصل';
    if (ts == null) return 'غير متصل';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'آخر ظهور قبل قليل';
    if (diff.inMinutes < 60) return 'آخر ظهور قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'آخر ظهور قبل ${diff.inHours} ساعة';
    return 'آخر ظهور قبل ${diff.inDays} يوم';
  }
  Future<void> _addFriendByPin() async {
    final pinCtrl = TextEditingController();
    final pin = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('اضافة صديق بالرقم الشخصي'), content: TextField(controller: pinCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(hintText: 'اكتب الرقم الشخصي - 6 ارقام')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('الغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, pinCtrl.text.trim()), child: const Text('بحث'))]));
    if (pin == null || pin.isEmpty) return;
    try {
      var q = await FirebaseFirestore.instance.collection('users').where('personal_pin', isEqualTo: pin).get();
      if (q.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما لگينا احد بهذا الرقم'))); return; }
      var friend = q.docs.first.data();
      if (friend['email'] == widget.myEmail) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا رقمك انت!'))); return; }
      List<String> parts = [widget.myEmail, friend['email']]; parts.sort();
      String chatId = parts.join('_');
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({'participants': parts, 'lastMessage': '', 'lastTimestamp': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت اضافة ${friend['username']}')));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, automaticallyImplyLeading: false, title: Row(children: [
        CircleAvatar(backgroundColor: Colors.white, child: Text(widget.myUsername.isNotEmpty ? widget.myUsername[0] : 'ش', style: const TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold))),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.myUsername, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), Text('رقمك: ${widget.myPin}', style: const TextStyle(fontSize: 12, color: Colors.white70))]),
      ]), actions: [IconButton(icon: const Icon(Icons.person_add), onPressed: _addFriendByPin), IconButton(icon: const Icon(Icons.logout), onPressed: () async { await FirebaseAuth.instance.signOut(); final p = await SharedPreferences.getInstance(); await p.clear(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen())); })]),
      floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xFF00C950), onPressed: _addFriendByPin, child: const Icon(Icons.add, color: Colors.white)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: widget.myEmail).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF0F5132)));
          if (!snap.hasData || snap.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey), const SizedBox(height: 12), const Text('لا توجد محادثات بعد', style: TextStyle(fontSize: 18, color: Colors.grey)), const SizedBox(height: 8), const Text('دوس + واضف صديق برقمه الشخصي'), const SizedBox(height: 16), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)), onPressed: _addFriendByPin, child: const Text('اضافة صديق', style: TextStyle(color: Colors.white))) ]));
          var docs = snap.data!.docs.toList();
          docs.sort((a, b) { var ta = (a.data() as Map)['lastTimestamp'] as Timestamp?; var tb = (b.data() as Map)['lastTimestamp'] as Timestamp?; if (ta == null) return 1; if (tb == null) return -1; return tb.compareTo(ta); });
          return ListView.builder(itemCount: docs.length, itemBuilder: (context, i) {
            var data = docs[i].data() as Map<String, dynamic>;
            List parts = data['participants'] ?? [];
            String friendEmail = parts.firstWhere((e) => e != widget.myEmail, orElse: () => '');
            return StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(friendEmail).snapshots(), builder: (context, usnap) {
              var u = usnap.data?.data() as Map<String, dynamic>?;
              String fname = u?['username'] ?? friendEmail;
              String fpin = u?['personal_pin'] ?? '';
              String photo = u?['profile_photo_base64'] ?? '';
              bool online = u?['isOnline'] == true;
              Timestamp? lastSeen = u?['lastSeen'] as Timestamp?;
              return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: ListTile(
                leading: Stack(children: [CircleAvatar(radius: 28, backgroundColor: const Color(0xFF0F5132), backgroundImage: photo.isNotEmpty ? MemoryImage(base64Decode(photo)) : null, child: photo.isEmpty ? Text(fname.isNotEmpty ? fname[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null), Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: online ? Colors.green : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))))]),
                title: Text(fname, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis), Text(_lastSeenText(lastSeen, online), style: TextStyle(color: online ? const Color(0xFF00C950) : Colors.grey, fontSize: 12))]),
                trailing: Column(children: [Text(fpin.isNotEmpty ? 'PIN: $fpin' : '', style: const TextStyle(fontSize: 11, color: Colors.grey)), const Icon(Icons.chat, color: Color(0xFF0F5132))]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IndividualChatScreen(chatId: docs[i].id, myEmail: widget.myEmail, myUsername: widget.myUsername, friendEmail: friendEmail, friendName: fname, friendPhoto: photo))),
              ));
            });
          });
        },
      ),
    );
  }
}

// CHAT SCREEN
class IndividualChatScreen extends StatefulWidget {
  final String chatId; final String myEmail; final String myUsername; final String friendEmail; final String friendName; final String friendPhoto;
  const IndividualChatScreen({super.key, required this.chatId, required this.myEmail, required this.myUsername, required this.friendEmail, required this.friendName, required this.friendPhoto});
  @override State<IndividualChatScreen> createState() => _ChatState();
}
class _ChatState extends State<IndividualChatScreen> {
  final _msgCtrl = TextEditingController(); final _scroll = ScrollController(); bool _isTyping = false; Timer? _typingTimer;
  @override void initState() { super.initState(); markAsSeen(); }
  Future<void> markAsSeen() async {
    try {
      var snap = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').where('sender', isEqualTo: widget.friendEmail).where('seen', isEqualTo: false).get();
      for (var d in snap.docs) { await d.reference.update({'seen': true}); }
    } catch (_) {}
  }
  Future<void> _updateTyping(bool typing) async {
    try { await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({'typing_${widget.myEmail}': typing}, SetOptions(merge: true)); } catch (_) {}
  }
  Future<void> _sendText() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    String text = _msgCtrl.text.trim(); _msgCtrl.clear(); _updateTyping(false);
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({'text': text, 'sender': widget.myEmail, 'type': 'text', 'timestamp': FieldValue.serverTimestamp(), 'seen': false});
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({'lastMessage': text, 'lastTimestamp': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }
  Future<void> _sendImage() async {
    final XFile? f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    String b64 = base64Encode(bytes);
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({'imageBase64': b64, 'sender': widget.myEmail, 'type': 'image', 'timestamp': FieldValue.serverTimestamp(), 'seen': false});
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({'lastMessage': '📷 صورة', 'lastTimestamp': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
  void _openCall(bool isVideo) async {
    var mic = await Permission.microphone.request();
    var cam = isVideo ? await Permission.camera.request() : PermissionStatus.granted;
    if (!mic.isGranted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لازم تسمح بالميكروفون'))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(chatId: widget.chatId, myEmail: widget.myEmail, friendEmail: widget.friendEmail, friendName: widget.friendName, isVideo: isVideo)));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEAE2),
      appBar: AppBar(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)), title: Row(children: [
        CircleAvatar(backgroundColor: Colors.white, backgroundImage: widget.friendPhoto.isNotEmpty ? MemoryImage(base64Decode(widget.friendPhoto)) : null, child: widget.friendPhoto.isEmpty ? Text(widget.friendName.isNotEmpty ? widget.friendName[0] : '?', style: const TextStyle(color: Color(0xFF0F5132))) : null),
        const SizedBox(width: 8),
        Expanded(child: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(widget.friendEmail).snapshots(), builder: (context, snap) {
          var u = snap.data?.data() as Map<String, dynamic>?;
          bool online = u?['isOnline'] == true;
          Timestamp? lastSeen = u?['lastSeen'] as Timestamp?;
          String status = online ? 'متصل' : (lastSeen != null ? 'آخر ظهور قبل ${DateTime.now().difference(lastSeen.toDate()).inMinutes} دقيقة' : 'غير متصل');
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.friendName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(), builder: (context, csnap) {
            bool friendTyping = (csnap.data?.data() as Map<String, dynamic>?)?['typing_${widget.friendEmail}'] == true;
            if (friendTyping) return const Text('جاري الكتابة...', style: TextStyle(fontSize: 12, color: Color(0xFF00C950)));
            return Text(status, style: const TextStyle(fontSize: 12, color: Colors.white70));
          })]);
        })),
      ]), actions: [IconButton(icon: const Icon(Icons.videocam), onPressed: () => _openCall(true)), IconButton(icon: const Icon(Icons.call), onPressed: () => _openCall(false))]),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(), builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF0F5132)));
          var docs = snap.data!.docs;
          if (docs.isNotEmpty) { Future.microtask(() => markAsSeen()); }
          return ListView.builder(reverse: true, controller: _scroll, itemCount: docs.length, itemBuilder: (context, i) {
            var msg = docs[i].data() as Map<String, dynamic>;
            bool isMe = msg['sender'] == widget.myEmail;
            bool isImage = msg['type'] == 'image';
            bool seen = msg['seen'] == true;
            return Align(alignment: isMe ? Alignment.centerLeft : Alignment.centerRight, child: Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isMe ? const Color(0xFFDCF8C6) : Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (isImage && msg['imageBase64'] != null) GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullImageViewer(imageUrl: 'data:image/jpeg;base64,${msg['imageBase64']}'))), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(msg['imageBase64']), width: 200, height: 200, fit: BoxFit.cover))),
              if (!isImage) Text(msg['text'] ?? '', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [Text((msg['timestamp'] as Timestamp?) != null ? '${(msg['timestamp'] as Timestamp).toDate().hour}:${(msg['timestamp'] as Timestamp).toDate().minute.toString().padLeft(2, '0')}' : '', style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(width: 4), if (isMe) Icon(seen ? Icons.done_all : Icons.done, size: 14, color: seen ? Colors.blue : Colors.grey)]),
            ]))));
          });
        })),
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Row(children: [
          IconButton(icon: const Icon(Icons.image, color: Color(0xFF0F5132)), onPressed: _sendImage),
          IconButton(icon: const Icon(Icons.mic, color: Color(0xFF0F5132)), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اضغط مطولاً لتسجيل رسالة صوتية - قريباً'))); }),
          Expanded(child: TextField(controller: _msgCtrl, onChanged: (v) { if (!_isTyping) { _isTyping = true; _updateTyping(true); } _typingTimer?.cancel(); _typingTimer = Timer(const Duration(seconds: 2), () { _isTyping = false; _updateTyping(false); }); }, decoration: InputDecoration(hintText: 'اكتب رسالة...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)))),
          const SizedBox(width: 6),
          CircleAvatar(backgroundColor: const Color(0xFF00C950), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendText)),
        ])),
      ]),
    );
  }
}

// VOICE / VIDEO CALL - WebRTC real signaling via Firestore
class VoiceCallScreen extends StatefulWidget {
  final String chatId; final String myEmail; final String friendEmail; final String friendName; final bool isVideo;
  const VoiceCallScreen({super.key, required this.chatId, required this.myEmail, required this.friendEmail, required this.friendName, required this.isVideo});
  @override State<VoiceCallScreen> createState() => _CallState();
}
class _CallState extends State<VoiceCallScreen> {
  RTCPeerConnection? _pc; final _local = RTCVideoRenderer(); final _remote = RTCVideoRenderer(); bool _muted = false; bool _connected = false; String _status = 'جاري الاتصال...';
  @override void initState() { super.initState(); _local.initialize(); _remote.initialize(); _start(); }
  Future<void> _start() async {
    try {
      var stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': widget.isVideo});
      _local.srcObject = stream;
      _pc = await createPeerConnection({'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]});
      _pc!.onTrack = (e) { if (e.streams.isNotEmpty) { setState(() { _remote.srcObject = e.streams[0]; _connected = true; _status = 'متصل الآن - مجاني 100%'; }); } };
      _pc!.onIceCandidate = (c) { if (c.candidate != null) FirebaseFirestore.instance.collection('calls').doc(widget.chatId).collection('candidates').add({'from': widget.myEmail, 'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex}); };
      stream.getTracks().forEach((t) => _pc!.addTrack(t, stream));
      var offer = await _pc!.createOffer(); await _pc!.setLocalDescription(offer);
      await FirebaseFirestore.instance.collection('calls').doc(widget.chatId).set({'offer': offer.toMap(), 'caller': widget.myEmail, 'callee': widget.friendEmail, 'isVideo': widget.isVideo, 'timestamp': FieldValue.serverTimestamp()});
      FirebaseFirestore.instance.collection('calls').doc(widget.chatId).snapshots().listen((snap) async {
        var d = snap.data(); if (d == null) return;
        if (d['answer'] != null && _pc?.getRemoteDescription() == null) { await _pc!.setRemoteDescription(RTCSessionDescription(d['answer']['sdp'], d['answer']['type'])); setState(() { _connected = true; _status = 'متصل الآن'; }); }
      });
      FirebaseFirestore.instance.collection('calls').doc(widget.chatId).collection('candidates').snapshots().listen((snap) { for (var doc in snap.docs) { var cd = doc.data(); if (cd['from'] != widget.myEmail) { _pc!.addCandidate(RTCIceCandidate(cd['candidate'], cd['sdpMid'], cd['sdpMLineIndex'])); } } });
    } catch (e) { setState(() { _status = 'خطأ: $e'; }); }
  }
  @override void dispose() { _local.dispose(); _remote.dispose(); _pc?.close(); FirebaseFirestore.instance.collection('calls').doc(widget.chatId).delete(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: SafeArea(child: Column(children: [
      const SizedBox(height: 20),
      Text(widget.friendName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      Text(_status, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 20),
      Expanded(child: Stack(children: [Center(child: widget.isVideo ? RTCVideoView(_remote, mirror: true) : const Icon(Icons.account_circle, size: 150, color: Colors.white30)), Positioned(bottom: 10, right: 10, width: 110, height: 150, child: widget.isVideo ? RTCVideoView(_local, mirror: true) : Container())])),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        FloatingActionButton(backgroundColor: _muted ? Colors.red : Colors.white, onPressed: () { setState(() { _muted = !_muted; }); _local.srcObject?.getAudioTracks().forEach((t) => t.enabled = !_muted); }, child: Icon(_muted ? Icons.mic_off : Icons.mic, color: _muted ? Colors.white : Colors.black)),
        FloatingActionButton(backgroundColor: Colors.red, onPressed: () => Navigator.pop(context), child: const Icon(Icons.call_end, color: Colors.white)),
        FloatingActionButton(backgroundColor: Colors.white, onPressed: () {}, child: const Icon(Icons.volume_up, color: Colors.black)),
      ]),
      const SizedBox(height: 30),
    ]))));
  }
}
