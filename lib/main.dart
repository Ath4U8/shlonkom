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
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasData) return UsersListPage();
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
      setState(() => error = "الكود لازم يبدأ @athir_ - مثلا @athir_123");
      return;
    }
    setState(() {
      loading = true;
      error = "";
    });
    try {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: emailCtrl.text.trim(),
            password: passCtrl.text.trim());
      } catch (_) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: emailCtrl.text.trim(),
            password: passCtrl.text.trim());
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set({
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
            children: [
              SizedBox(height: 60),
              Text("🇮🇶", style: TextStyle(fontSize: 70)),
              Text("شلونكم",
                  style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text("دردشة عراقية - البصرة",
                  style: TextStyle(color: Colors.white70, fontSize: 18)),
              SizedBox(height: 30),
              TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                      hintText: "الايميل الحقيقي",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 12),
              TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                      hintText: "الباسورد",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 12),
              TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                      hintText: "الكود الخاص @athir_...",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 15),
              if (error.isNotEmpty)
                Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.white,
                    child: Text(error,
                        style: TextStyle(color: Colors.red, fontSize: 12))),
              SizedBox(height: 10),
              ElevatedButton(
                  onPressed: loading ? null : login,
                  child: loading
                      ? CircularProgressIndicator()
                      : Text("دخول", style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 55),
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF0E7A3E))),
              SizedBox(height: 12),
              OutlinedButton(
                  onPressed: loading ? null : login,
                  child: Text("تسجيل جديد",
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 55),
                      side: BorderSide(color: Colors.white, width: 2))),
              SizedBox(height: 30),
              Text("Created by Atheer Sami - Basra 🇮🇶",
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class UsersListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("شلونكم 🇮🇶 - 30 شخص"),
          backgroundColor: Color(0xFF0E7A3E),
          actions: [
            IconButton(
                icon: Icon(Icons.logout),
                onPressed: () => FirebaseAuth.instance.signOut())
          ]),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .limit(30)
              .snapshots(),
          builder: (c, snap) {
            if (!snap.hasData)
              return Center(child: CircularProgressIndicator());
            return ListView.builder(
                itemCount: snap.data!.docs.length,
                itemBuilder: (c, i) {
                  var doc = snap.data!.docs[i];
                  if (doc.id == FirebaseAuth.instance.currentUser!.uid)
                    return SizedBox();
                  return ListTile(
                      leading: CircleAvatar(child: Text("🇮🇶")),
                      title: Text(doc['email'] ?? ''),
                      subtitle: Text(doc['privateCode'] ?? 'اضغط للدردشة'),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call, color: Colors.green),
                            SizedBox(width: 10),
                            Icon(Icons.videocam, color: Colors.blue)
                          ]),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatPage(
                                  otherUid: doc.id,
                                  otherEmail: doc['email']))));
                });
          }),
      bottomNavigationBar: Container(
          padding: EdgeInsets.all(10),
          child: Text("Created by Atheer Sami - Basra 🇮🇶",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey))),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String otherUid;
  final String otherEmail;
  ChatPage({required this.otherUid, required this.otherEmail});
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final msgCtrl = TextEditingController();
  final stickers = [
    "🇮🇶",
    "😂",
    "😍",
    "🔥",
    "👍",
    "هلا",
    "شلونك",
    "تمام",
    "الله يساعدك"
  ];
  bool muted = false;
  String get chatId {
    var ids = [FirebaseAuth.instance.currentUser!.uid, widget.otherUid]
      ..sort();
    return ids.join("_");
  }

  void send(String txt) async {
    if (txt.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'text': txt.trim(),
      'uid': FirebaseAuth.instance.currentUser!.uid,
      'email': FirebaseAuth.instance.currentUser!.email,
      'time': FieldValue.serverTimestamp()
    });
    msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.otherEmail),
            backgroundColor: Color(0xFF0E7A3E),
            actions: [
              IconButton(
                  icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
                  onPressed: () => setState(() => muted = !muted)),
              IconButton(
                  icon: Icon(Icons.videocam),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CallPage(isVideo: true)))),
              IconButton(
                  icon: Icon(Icons.call),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CallPage(isVideo: false))))
            ]),
        body: Column(children: [
          Expanded(
              child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .orderBy('time', descending: true)
                      .limit(30)
                      .snapshots(),
                  builder: (c, snap) {
                    if (!snap.hasData)
                      return Center(child: CircularProgressIndicator());
                    return ListView.builder(
                        reverse: true,
                        itemCount: snap.data!.docs.length,
                        itemBuilder: (c, i) {
                          var d = snap.data!.docs[i];
                          bool isMe =
                              d['uid'] == FirebaseAuth.instance.currentUser!.uid;
                          return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                  margin: EdgeInsets.all(6),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: isMe
                                          ? Colors.green[100]
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(d['text'] ?? '')));
                        });
                  })),
          Container(
              height: 50,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: stickers
                      .map((s) => Padding(
                          padding: EdgeInsets.all(4),
                          child: ActionChip(
                              label: Text(s), onPressed: () => send(s))))
                      .toList())),
          Padding(
              padding: EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: msgCtrl,
                        decoration: InputDecoration(hintText: "اكتب..."))),
                IconButton(
                    icon: Icon(Icons.send, color: Colors.green),
                    onPressed: () => send(msgCtrl.text))
              ])),
          Text("Created by Atheer Sami - Basra 🇮🇶",
              style: TextStyle(fontSize: 10, color: Colors.grey))
        ]));
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
    Stream.periodic(Duration(seconds: 1), (i) => i).listen((_) {
      if (mounted) setState(() => sec++);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Icon(widget.isVideo ? Icons.videocam : Icons.call,
                  size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(widget.isVideo ? "📹 فيديو" : "📞 صوت",
                  style: TextStyle(color: Colors.white, fontSize: 24)),
              Text("${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}",
                  style: TextStyle(color: Colors.white, fontSize: 22)),
              SizedBox(height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                FloatingActionButton(
                    onPressed: () => setState(() => muted = !muted),
                    child: Icon(muted ? Icons.mic_off : Icons.mic),
                    backgroundColor: muted ? Colors.red : Colors.grey),
                SizedBox(width: 20),
                FloatingActionButton(
                    onPressed: () => Navigator.pop(context),
                    child: Icon(Icons.call_end),
                    backgroundColor: Colors.red)
              ])
            ])));
  }
}
