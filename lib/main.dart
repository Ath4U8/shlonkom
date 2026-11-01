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
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شلونكم',
      theme: ThemeData(primarySwatch: Colors.green),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (c, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snap.hasData) return ChatHome();
        return LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  String error = "";
  bool loading = false;

  Future<void> login() async {
    if (!codeCtrl.text.trim().startsWith('@athir_')) {
      setState(() => error = "الكود الخاص لازم يبدأ بـ @athir_");
      return;
    }
    setState(() { loading = true; error = ""; });
    try {
      if (emailCtrl.text.contains('@')) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
      }
      await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).set({
        'email': emailCtrl.text.trim(),
        'privateCode': codeCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      setState(() => error = e.toString());
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0E7A3E),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 60),
              Text("🇮🇶", style: TextStyle(fontSize: 60)),
              Text("شلونكم", style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
              Text("دردشة عراقية", style: TextStyle(color: Colors.white70, fontSize: 18)),
              SizedBox(height: 30),
              TextField(controller: emailCtrl, decoration: InputDecoration(hintText: "الايميل", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 12),
              TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(hintText: "الباسورد", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 12),
              TextField(controller: codeCtrl, decoration: InputDecoration(hintText: "الكود الخاص @athir_...", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 15),
              if (error.isNotEmpty) Text(error, style: TextStyle(color: Colors.redAccent, backgroundColor: Colors.white)),
              SizedBox(height: 10),
              ElevatedButton(onPressed: loading ? null : login, child: loading ? CircularProgressIndicator() : Text("دخول"), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50))),
              SizedBox(height: 20),
              Text("Created by Atheer Sami - Basra 🇮🇶", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatHome extends StatefulWidget {
  @override
  _ChatHomeState createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> {
  final msgCtrl = TextEditingController();
  bool muted = false;
  int seconds = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text("شلونكم 🇮🇶 - ${user?.email}"),
        backgroundColor: Color(0xFF0E7A3E),
        actions: [
          IconButton(icon: Icon(muted ? Icons.volume_off : Icons.volume_up), onPressed: () => setState(() => muted = !muted)),
          IconButton(icon: Icon(Icons.videocam), onPressed: () => _openCall(context, true)),
          IconButton(icon: Icon(Icons.call), onPressed: () => _openCall(context, false)),
          IconButton(icon: Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('messages').orderBy('time', descending: true).limit(30).snapshots(),
              builder: (c, snap) {
                if (!snap.hasData) return Center(child: CircularProgressIndicator());
                return ListView.builder(
                  reverse: true,
                  itemCount: snap.data!.docs.length,
                  itemBuilder: (c, i) {
                    var d = snap.data!.docs[i];
                    bool isMe = d['uid'] == user?.uid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.all(6),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(color: isMe ? Colors.green[100] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['email'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text(d['text'] ?? ''),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Text("🇮🇶 😂 😍 🔥 👍"),
                Expanded(child: TextField(controller: msgCtrl, decoration: InputDecoration(hintText: "اكتب رسالة..."))),
                IconButton(icon: Icon(Icons.send, color: Colors.green), onPressed: _send),
              ],
            ),
          ),
          Text("Created by Atheer Sami - Basra", style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  void _send() async {
    if (msgCtrl.text.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('messages').add({
      'text': msgCtrl.text.trim(),
      'uid': FirebaseAuth.instance.currentUser!.uid,
      'email': FirebaseAuth.instance.currentUser!.email,
      'time': FieldValue.serverTimestamp(),
    });
    msgCtrl.clear();
  }

  void _openCall(BuildContext context, bool video) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallPage(isVideo: video)));
  }
}

class CallPage extends StatefulWidget {
  final bool isVideo;
  CallPage({required this.isVideo});
  @override
  _CallPageState createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  bool muted = false;
  int sec = 0;
  @override
  void initState() {
    super.initState();
    Stream.periodic(Duration(seconds: 1), (i) => i).listen((_) { if(mounted) setState(() => sec++); });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.isVideo ? Icons.videocam : Icons.call, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(widget.isVideo ? "📹 مكالمة فيديو" : "📞 مكالمة صوتية", style: TextStyle(color: Colors.white, fontSize: 24)),
            SizedBox(height: 10),
            Text("${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}", style: TextStyle(color: Colors.white, fontSize: 20)),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(onPressed: () => setState(() => muted = !muted), child: Icon(muted ? Icons.mic_off : Icons.mic), backgroundColor: muted ? Colors.red : Colors.grey),
                SizedBox(width: 20),
                FloatingActionButton(onPressed: () => Navigator.pop(context), child: Icon(Icons.call_end), backgroundColor: Colors.red),
              ],
            ),
            SizedBox(height: 20),
            Text("Created by Atheer Sami - Basra 🇮🇶", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
