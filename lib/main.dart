import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ShlonkomApp());
}

class ShlonkomApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, title: 'شلونكم', home: AuthGate());
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (c, snap) {
      if (snap.connectionState == ConnectionState.waiting) return Scaffold(body: Center(child: CircularProgressIndicator()));
      if (!snap.hasData) return LoginPage();
      var user = snap.data!;
      if (!user.emailVerified) return VerifyEmailPage(username: '', displayName: '');
      return StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(), builder: (c, docSnap) {
        if (!docSnap.hasData) return Center(child: CircularProgressIndicator());
        if (!docSnap.data!.exists) return VerifyEmailPage(username: '', displayName: '', isOldUser: true);
        return UsersListPage();
      });
    });
  }
}

class VerifyEmailPage extends StatefulWidget {
  final String username; final String displayName; final bool isOldUser;
  VerifyEmailPage({required this.username, required this.displayName, this.isOldUser = false});
  @override _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool loading = false;
  @override
  Widget build(BuildContext context) {
    var email = FirebaseAuth.instance.currentUser!.email ?? '';
    return Scaffold(backgroundColor: Color(0xFF0E7A3E), body: Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.mark_email_read, size: 90, color: Colors.white), SizedBox(height: 20),
      Text("تأكيد الايميل", style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
      SizedBox(height: 12),
      Text("دزينا رابط الى:\n$email\n\n1. افتح Gmail\n2. دوس الرابط الازرق\n3. ارجع ودوس تأكدت\n\nاذا وهمي ما يوصل!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14)),
      SizedBox(height: 25),
      ElevatedButton(onPressed: loading ? null : () async {
        setState(() => loading = true);
        try {
          await FirebaseAuth.instance.currentUser!.reload();
          var freshUser = FirebaseAuth.instance.currentUser!;
          if (!freshUser.emailVerified) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("بعدك ما مأكد - افتح ايميلك")));
            setState(() => loading = false); return;
          }
          if (widget.username.isNotEmpty) {
            await FirebaseFirestore.instance.collection('users').doc(freshUser.uid).set({
              'username': widget.username.toLowerCase(),
              'displayName': widget.displayName,
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'متصل 🇮🇶'
            }, SetOptions(merge: true));
          }
        } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
        setState(() => loading = false);
      }, child: loading ? CircularProgressIndicator() : Text("تأكدت - سوي حسابي الرسمي", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55), backgroundColor: Colors.white, foregroundColor: Color(0xFF0E7A3E))),
      SizedBox(height: 12),
      OutlinedButton(onPressed: () async { await FirebaseAuth.instance.currentUser!.sendEmailVerification(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم الارسال"))); }, child: Text("اعادة ارسال الرابط", style: TextStyle(color: Colors.white)), style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 50), side: BorderSide(color: Colors.white))),
      SizedBox(height: 20), TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: Text("خروج", style: TextStyle(color: Colors.white54))),
    ]))));
  }
}

class LoginPage extends StatefulWidget { @override _LoginPageState createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController(); final passCtrl = TextEditingController(); final usernameCtrl = TextEditingController();
  String error = ""; bool loading = false;

  Future<void> login() async {
    setState(() { loading = true; error = ""; });
    try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim()); }
    catch (e) { setState(() => error = "الايميل او كلمة المرور غلط"); }
    setState(() => loading = false);
  }

  Future<void> register() async {
    var username = usernameCtrl.text.trim().toLowerCase();
    var display = usernameCtrl.text.trim();
    if (username.length < 3) { setState(() => error = "اسم المستخدم 3 حروف"); return; }
    if (username.contains(" ")) { setState(() => error = "بدون مسافات"); return; }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) { setState(() => error = "انكليزي وارقام و _ فقط"); return; }
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.trim().length < 6) { setState(() => error = "الايميل والباسورد مطلوبين (6 حروف)"); return; }
    setState(() { loading = true; error = ""; });
    try {
      var cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
      await cred.user!.sendEmailVerification();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VerifyEmailPage(username: username, displayName: display)));
    } catch (e) { setState(() => error = e.toString()); }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Color(0xFF0E7A3E), body: Padding(padding: EdgeInsets.all(20), child: SingleChildScrollView(child: Column(children: [
    SizedBox(height: 50), Text("🇮🇶", style: TextStyle(fontSize: 50)), SizedBox(height: 10),
    Text("شلونكم", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Amiri', height: 1.2)),
    SizedBox(height: 8), Text("اول تطبيق اتصال ومراسلة عراقي", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Amiri')),
    SizedBox(height: 30),
    TextField(controller: emailCtrl, decoration: InputDecoration(hintText: "الايميل", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    SizedBox(height: 12), TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(hintText: "كلمة المرور", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    SizedBox(height: 12), TextField(controller: usernameCtrl, decoration: InputDecoration(hintText: "اسم المستخدم", prefixText: "@", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    SizedBox(height: 15), if (error.isNotEmpty) Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(error, style: TextStyle(color: Colors.red, fontSize: 12))),
    SizedBox(height: 15),
    ElevatedButton(onPressed: loading ? null : login, child: Text("دخول", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55), backgroundColor: Colors.white, foregroundColor: Color(0xFF0E7A3E))),
    SizedBox(height: 12),
    OutlinedButton(onPressed: loading ? null : register, child: Text("تسجيل جديد", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 55), side: BorderSide(color: Colors.white, width: 2))),
  ]))));
}

class UsersListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text("شلونكم 🇮🇶", style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Color(0xFF0E7A3E), actions: [IconButton(icon: Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]), body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(), builder: (c, snap) {
    if (!snap.hasData) return Center(child: CircularProgressIndicator());
    if (snap.data!.docs.isEmpty) return Center(child: Text("لا يوجد مستخدمين - انت اول واحد! 🇮🇶"));
    return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c, i) {
      var doc = snap.data!.docs[i]; if (doc.id == FirebaseAuth.instance.currentUser!.uid) return SizedBox();
      var d = doc.data() as Map<String,dynamic>; var u = d['username'] ?? 'مستخدم';
      return ListTile(leading: CircleAvatar(child: Text(u[0].toUpperCase())), title: Text("@$u", style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(d['status'] ?? 'متصل'), trailing: Icon(Icons.chat, color: Colors.green), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(otherUid: doc.id, otherName: u))));
    });
  }));
}

class ChatPage extends StatefulWidget { final String otherUid; final String otherName; ChatPage({required this.otherUid, required this.otherName}); @override _ChatPageState createState() => _ChatPageState(); }
class _ChatPageState extends State<ChatPage> {
  final msgCtrl = TextEditingController();
  String get chatId { var ids = [FirebaseAuth.instance.currentUser!.uid, widget.otherUid]..sort(); return ids.join("_"); }
  void send(String txt) async { if (txt.trim().isEmpty) return; var t = txt.trim(); msgCtrl.clear(); await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({'text': t, 'uid': FirebaseAuth.instance.currentUser!.uid, 'time': FieldValue.serverTimestamp()}); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text("@${widget.otherName}"), backgroundColor: Color(0xFF0E7A3E)), body: Column(children: [Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('time', descending: true).snapshots(), builder: (c, snap) { if (!snap.hasData) return Center(child: CircularProgressIndicator()); var docs = snap.data!.docs; return ListView.builder(reverse: true, itemCount: docs.length, itemBuilder: (c, i) { var dd = docs[i].data() as Map<String,dynamic>; bool isMe = dd['uid'] == FirebaseAuth.instance.currentUser!.uid; return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: EdgeInsets.all(6), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: isMe ? Colors.green[100] : Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(dd['text'] ?? ''))); }); })), Padding(padding: EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: msgCtrl, decoration: InputDecoration(hintText: "اكتب...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))), onSubmitted: send)), SizedBox(width: 8), FloatingActionButton(mini: true, onPressed: () => send(msgCtrl.text), child: Icon(Icons.send))]))]));
}
