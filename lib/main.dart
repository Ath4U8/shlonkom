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
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, title: 'شلونكم', theme: ThemeData(primarySwatch: Colors.green), home: AuthGate());
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (c, snap) {
      if (snap.connectionState == ConnectionState.waiting) return Scaffold(body: Center(child: CircularProgressIndicator()));
      if (!snap.hasData) return LoginPage();
      if (!snap.data!.emailVerified) return VerifyEmailPage();
      return UsersListPage();
    });
  }
}

class VerifyEmailPage extends StatefulWidget { @override _VerifyEmailPageState createState() => _VerifyEmailPageState(); }
class _VerifyEmailPageState extends State<VerifyEmailPage> {
  @override
  Widget build(BuildContext context) {
    var email = FirebaseAuth.instance.currentUser!.email;
    return Scaffold(backgroundColor: Color(0xFF0E7A3E), body: Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.mark_email_read, size: 90, color: Colors.white), SizedBox(height: 20),
      Text("تأكيد الايميل", style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
      SizedBox(height: 12), Text("دزينا رابط تأكيد الى:\n$email\n\nافتح Gmail ودوس الرابط.\nاذا ايميل وهمي ما يوصل وما تدخل!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15)),
      SizedBox(height: 25),
      ElevatedButton(onPressed: () async { await FirebaseAuth.instance.currentUser!.reload(); if (!FirebaseAuth.instance.currentUser!.emailVerified) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("بعدك ما مأكد - افتح ايميلك"))); } else { setState(() {}); } }, child: Text("تأكدت - حدث", style: TextStyle(fontSize: 18)), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.white, foregroundColor: Color(0xFF0E7A3E))),
      SizedBox(height: 12), OutlinedButton(onPressed: () async { await FirebaseAuth.instance.currentUser!.sendEmailVerification(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم اعادة الارسال"))); }, child: Text("اعادة ارسال", style: TextStyle(color: Colors.white)), style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white))),
      SizedBox(height: 20), TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: Text("خروج", style: TextStyle(color: Colors.white54))),
    ]))));
  }
}

class LoginPage extends StatefulWidget { @override _LoginPageState createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController(); final passCtrl = TextEditingController(); final usernameCtrl = TextEditingController();
  String error = ""; bool loading = false;
  Future<void> login() async {
    var username = usernameCtrl.text.trim().toLowerCase();
    if (username.length < 3) { setState(() => error = "الاسم 3 حروف على الاقل"); return; }
    if (username.contains(" ")) { setState(() => error = "بدون مسافات - استخدم _"); return; }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) { setState(() => error = "انكليزي وارقام و _ فقط"); return; }
    setState(() { loading = true; error = ""; });
    try {
      UserCredential cred;
      try {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({'username': username, 'displayName': usernameCtrl.text.trim()}, SetOptions(merge: true));
      } catch (_) {
        var check = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: username).get();
        if (check.docs.isNotEmpty) { setState(() { error = "@$username محجوز - جرب ثاني"; loading = false; }); return; }
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
        await cred.user!.sendEmailVerification();
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({'username': username, 'displayName': usernameCtrl.text.trim(), 'createdAt': FieldValue.serverTimestamp(), 'status': 'متصل 🇮🇶'});
      }
    } catch (e) { setState(() => error = e.toString()); }
    setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: Color(0xFF0E7A3E), body: Padding(padding: EdgeInsets.all(20), child: SingleChildScrollView(child: Column(children: [
    SizedBox(height: 60), Text("🇮🇶", style: TextStyle(fontSize: 70)), Text("شلونكم", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)), Text("اسم حر + ايميل حقيقي", style: TextStyle(color: Colors.white70)), SizedBox(height: 30),
    TextField(controller: emailCtrl, decoration: InputDecoration(hintText: "ايميلك الحقيقي", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    SizedBox(height: 12), TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(hintText: "الباسورد", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    SizedBox(height: 12), TextField(controller: usernameCtrl, decoration: InputDecoration(hintText: "اسمك - مثلا ahmed_basra", prefixText: "@", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    SizedBox(height: 15), if (error.isNotEmpty) Container(padding: EdgeInsets.all(8), color: Colors.white, child: Text(error, style: TextStyle(color: Colors.red, fontSize: 12))),
    SizedBox(height: 10), ElevatedButton(onPressed: loading ? null : login, child: loading ? CircularProgressIndicator() : Text("دخول / تسجيل", style: TextStyle(fontSize: 18)), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55), backgroundColor: Colors.white, foregroundColor: Color(0xFF0E7A3E))),
    SizedBox(height: 12), Text("اذا ايميل وهمي ما راح يدخل - لازم تأكيد 🔒", style: TextStyle(color: Colors.white70, fontSize: 12)),
  ]))));
}

class UsersListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text("شلونكم 🇮🇶"), backgroundColor: Color(0xFF0E7A3E), actions: [IconButton(icon: Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]), body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(), builder: (c, snap) {
    if (!snap.hasData) return Center(child: CircularProgressIndicator());
    if (snap.data!.docs.isEmpty) return Center(child: Text("لا يوجد مستخدمين بعد - انت اول واحد! 🇮🇶"));
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
