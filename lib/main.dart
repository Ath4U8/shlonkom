import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ShlonkomApp());
}

class ShlonkomApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: 'شلونكم', home: AuthGate());
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
        if (!snap.hasData) return LoginPage();
        var user = snap.data!;
        if (!user.emailVerified) return VerifyPage();
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (c, docSnap) {
            if (!docSnap.hasData) return Center(child: CircularProgressIndicator());
            if (!docSnap.data!.exists) return CreateAccountPage(email: user.email ?? '', uid: user.uid);
            return UsersListPage();
          },
        );
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
  final userCtrl = TextEditingController();
  String error = "";
  bool loading = false;

  String genPass(String username) {
    return username.toLowerCase() + "_IQ_111111_shlonkom";
  }

  Future<void> register() async {
    var email = emailCtrl.text.trim().toLowerCase();
    var username = userCtrl.text.trim().toLowerCase();
    if (email.isEmpty || username.length < 3) {
      setState(() => error = "اكتب الايميل واسم المستخدم (3 حروف)");
      return;
    }
    setState(() { loading = true; error = ""; });
    try {
      var eQ = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).get();
      if (eQ.docs.isNotEmpty) {
        setState(() { error = "الايميل مسجل - سوي دخول"; loading = false; });
        return;
      }
      var uQ = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: username).get();
      if (uQ.docs.isNotEmpty) {
        setState(() { error = "اسم المستخدم مأخوذ - ماكو تكرار"; loading = false; });
        return;
      }
      var pass = genPass(username);
      var cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      await cred.user!.sendEmailVerification();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VerifyPage()));
    } catch (e) {
      setState(() => error = e.toString());
    }
    setState(() => loading = false);
  }

  Future<void> login() async {
    var email = emailCtrl.text.trim().toLowerCase();
    var username = userCtrl.text.trim().toLowerCase();
    if (email.isEmpty || username.isEmpty) {
      setState(() => error = "اكتب الايميل واسم المستخدم");
      return;
    }
    setState(() { loading = true; error = ""; });
    try {
      var pass = genPass(username);
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      var uid = FirebaseAuth.instance.currentUser!.uid;
      var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        setState(() { error = "الحساب ما كامل - سجل من جديد"; loading = false; });
        return;
      }
      if (doc.data()!['username'] != username) {
        await FirebaseAuth.instance.signOut();
        setState(() { error = "الايميل واسم المستخدم غير متطابقين"; loading = false; });
        return;
      }
    } catch (e) {
      setState(() => error = "الايميل او اسم المستخدم غلط");
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
              Text("🇮🇶", style: TextStyle(fontSize: 50)),
              Text("شلونكم", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Amiri')),
              Text("اول تطبيق اتصال ومراسلة عراقي", style: TextStyle(color: Colors.white70, fontSize: 16)),
              SizedBox(height: 30),
              TextField(controller: emailCtrl, decoration: InputDecoration(hintText: "الايميل", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 12),
              TextField(controller: userCtrl, decoration: InputDecoration(hintText: "اسم المستخدم", prefixText: "@", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 15),
              if (error.isNotEmpty) Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(error, style: TextStyle(color: Colors.red, fontSize: 12))),
              SizedBox(height: 15),
              ElevatedButton(onPressed: loading ? null : login, child: Text("دخول", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55), backgroundColor: Colors.white, foregroundColor: Color(0xFF0E7A3E))),
              SizedBox(height: 12),
              OutlinedButton(onPressed: loading ? null : register, child: Text("تسجيل جديد - رابط مرة وحدة", style: TextStyle(fontSize: 14, color: Colors.white)), style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 55), side: BorderSide(color: Colors.white, width: 2))),
              SizedBox(height: 40),
              Text("Designed by: Atheer Sami", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class VerifyPage extends StatefulWidget {
  @override
  _VerifyPageState createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  bool loading = false;
  @override
  Widget build(BuildContext context) {
    var email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: Color(0xFF0E7A3E),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_read, size: 90, color: Colors.white),
              SizedBox(height: 20),
              Text("تأكيد الايميل - مرة وحدة", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text("دزينا رابط الى:\n$email", textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: loading ? null : () async {
                  setState(() => loading = true);
                  await FirebaseAuth.instance.currentUser!.reload();
                  await FirebaseAuth.instance.currentUser!.getIdToken(true);
                  var f = FirebaseAuth.instance.currentUser!;
                  if (!f.emailVerified) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("بعدك ما مأكد")));
                    setState(() => loading = false);
                    return;
                  }
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => CreateAccountPage(email: f.email ?? '', uid: f.uid)), (r) => false);
                },
                child: loading ? CircularProgressIndicator() : Text("تأكدت - انشئ حسابي"),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55), backgroundColor: Colors.white, foregroundColor: Color(0xFF0E7A3E)),
              ),
              SizedBox(height: 12),
              OutlinedButton(onPressed: () async { await FirebaseAuth.instance.currentUser!.sendEmailVerification(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم الارسال"))); }, child: Text("اعادة ارسال", style: TextStyle(color: Colors.white)), style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white))),
              TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: Text("خروج", style: TextStyle(color: Colors.white54))),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateAccountPage extends StatefulWidget {
  final String email;
  final String uid;
  CreateAccountPage({required this.email, required this.uid});
  @override
  _CreateAccountPageState createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  bool loading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0E7A3E),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("انشاء حسابك الرسمي", style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              TextField(controller: TextEditingController(text: widget.email), readOnly: true, decoration: InputDecoration(labelText: "الايميل ثابت 🔒", filled: true, fillColor: Colors.grey[300], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 12),
              TextField(controller: TextEditingController(text: widget.email.split('@')[0]), readOnly: true, decoration: InputDecoration(labelText: "اسم المستخدم ثابت 🔒", prefixText: "@", filled: true, fillColor: Colors.grey[300], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: loading ? null : () async {
                  setState(() => loading = true);
                  var counterRef = FirebaseFirestore.instance.collection('counters').doc('users');
                  var snap = await counterRef.get();
                  int newNumber = 111112;
                  if (!snap.exists) {
                    await counterRef.set({'count': 111111});
                    newNumber = 111112;
                    await counterRef.update({'count': newNumber});
                  } else {
                    int cur = snap.data()!['count'] as int;
                    newNumber = cur + 1;
                    await counterRef.update({'count': newNumber});
                  }
                  var email = widget.email;
                  var uname = email.split('@')[0].toLowerCase();
                  var existing = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: uname).get();
                  if (existing.docs.isNotEmpty) {
                    uname = uname + newNumber.toString();
                  }
                  await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
                    'username': uname,
                    'displayName': uname,
                    'email': widget.email,
                    'shortId': newNumber,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => UsersListPage()), (r) => false);
                  setState(() => loading = false);
                },
                child: loading ? CircularProgressIndicator() : Text("تأكيد وانشاء حسابي ✅", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 55), backgroundColor: Colors.white, foregroundColor: Color(0xFF0E7A3E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UsersListPage extends StatefulWidget {
  @override
  _UsersListPageState createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  final searchCtrl = TextEditingController();
  final addCtrl = TextEditingController();
  List<DocumentSnapshot> searchResults = [];
  int? myId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      setState(() { myId = doc.data()!['shortId']; });
    }
  }

  Future<void> search() async {
    var v = searchCtrl.text.trim();
    if (v.isEmpty) {
      setState(() { searchResults = []; });
      return;
    }
    int? id = int.tryParse(v);
    if (id == null) return;
    var q = await FirebaseFirestore.instance.collection('users').where('shortId', isEqualTo: id).get();
    setState(() { searchResults = q.docs; });
  }

  void showAddDialog() {
    DocumentSnapshot? found;
    String msg = "";
    bool searching = false;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              title: Text("اضف رقم التعريف الشخصي"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: addCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: "مثال: 111111", labelText: "رقم التعريف", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  SizedBox(height: 8),
                  if (msg.isNotEmpty) Text(msg, style: TextStyle(color: Colors.red, fontSize: 12)),
                  if (found != null)
                    Card(
                      child: ListTile(
                        title: Text("@${(found!.data() as Map<String, dynamic>)['username']}"),
                        subtitle: Text("رقم التعريف: ${(found!.data() as Map<String, dynamic>)['shortId']}"),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("الغاء")),
                ElevatedButton(
                  onPressed: searching ? null : () async {
                    var val = addCtrl.text.trim();
                    int? id = int.tryParse(val);
                    if (id == null) {
                      setD(() { msg = "اكتب رقم"; });
                      return;
                    }
                    setD(() { searching = true; msg = ""; });
                    var q = await FirebaseFirestore.instance.collection('users').where('shortId', isEqualTo: id).get();
                    if (q.docs.isEmpty) {
                      setD(() { msg = "ما لقينا"; searching = false; found = null; });
                    } else {
                      var d = q.docs.first;
                      if (d.id == FirebaseAuth.instance.currentUser!.uid) {
                        setD(() { msg = "هذا انت!"; searching = false; });
                      } else {
                        setD(() { found = d; searching = false; });
                      }
                    }
                  },
                  child: searching ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text("بحث 🔍"),
                ),
                if (found != null)
                  ElevatedButton(
                    onPressed: () async {
                      var myUid = FirebaseAuth.instance.currentUser!.uid;
                      await FirebaseFirestore.instance.collection('users').doc(myUid).collection('contacts').doc(found!.id).set({
                        'username': (found!.data() as Map<String, dynamic>)['username'],
                        'shortId': (found!.data() as Map<String, dynamic>)['shortId'],
                        'addedAt': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تمت الاضافة ✅")));
                      addCtrl.clear();
                    },
                    child: Text("تثبيت كجهة اتصال ✅"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("شلونكم 🇮🇶"), backgroundColor: Color(0xFF0E7A3E), actions: [IconButton(icon: Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]),
      floatingActionButton: FloatingActionButton.extended(onPressed: showAddDialog, label: Text("اضافة جهة اتصال"), icon: Icon(Icons.person_add), backgroundColor: Color(0xFF0E7A3E)),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.green[50],
            child: Column(
              children: [
                if (myId != null)
                  Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(0xFF0E7A3E))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.badge, color: Color(0xFF0E7A3E)), SizedBox(width: 8), Text("رقم التعريف الشخصي: $myId", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E7A3E)))])),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: searchCtrl, keyboardType: TextInputType.number, onSubmitted: (_) => search(), decoration: InputDecoration(hintText: "مثال: 111111", labelText: "ابحث برقم التعريف", prefixIcon: Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                    SizedBox(width: 8),
                    ElevatedButton(onPressed: search, child: Text("بحث 🔍"), style: ElevatedButton.styleFrom(minimumSize: Size(90, 56), backgroundColor: Color(0xFF0E7A3E), foregroundColor: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: searchResults.isNotEmpty
                ? ListView.builder(itemCount: searchResults.length, itemBuilder: (c, i) {
                    var doc = searchResults[i];
                    if (doc.id == FirebaseAuth.instance.currentUser!.uid) return SizedBox();
                    var d = doc.data() as Map<String, dynamic>;
                    return Card(margin: EdgeInsets.all(8), child: ListTile(title: Text("@${d['username']}"), subtitle: Text("رقم التعريف: ${d['shortId']} - لا يتكرر ✅"), trailing: ElevatedButton(child: Text("دردشة"), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(otherUid: doc.id, otherName: d['username'], otherShortId: d['shortId']))))));
                  })
                : StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).collection('contacts').snapshots(), builder: (c, snap) {
                    if (snap.hasData && snap.data!.docs.isNotEmpty) {
                      return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c, i) {
                        var doc = snap.data!.docs[i];
                        var d = doc.data() as Map<String, dynamic>;
                        return ListTile(title: Text("@${d['username']}"), subtitle: Text("رقم التعريف: ${d['shortId']}"), trailing: Icon(Icons.chat, color: Colors.green), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(otherUid: doc.id, otherName: d['username'], otherShortId: d['shortId']))));
                      });
                    }
                    return Center(child: Text("دوس 'اضافة جهة اتصال' واكتب 111111"));
                  }),
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String otherUid;
  final String otherName;
  final int otherShortId;
  ChatPage({required this.otherUid, required this.otherName, required this.otherShortId});
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final msgCtrl = TextEditingController();
  String get chatId {
    var ids = [FirebaseAuth.instance.currentUser!.uid, widget.otherUid]..sort();
    return ids.join("_");
  }
  void send(String t) async {
    if (t.trim().isEmpty) return;
    var txt = t.trim();
    msgCtrl.clear();
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({'text': txt, 'uid': FirebaseAuth.instance.currentUser!.uid, 'time': FieldValue.serverTimestamp()});
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0E7A3E),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("@${widget.otherName}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text("رقم التعريف الشخصي: ${widget.otherShortId}", style: TextStyle(fontSize: 12, color: Colors.white70))]),
      ),
      body: Column(
        children: [
          Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').orderBy('time', descending: true).snapshots(), builder: (c, snap) { if (!snap.hasData) return Center(child: CircularProgressIndicator()); var docs = snap.data!.docs; return ListView.builder(reverse: true, itemCount: docs.length, itemBuilder: (c, i) { var dd = docs[i].data() as Map<String, dynamic>; bool isMe = dd['uid'] == FirebaseAuth.instance.currentUser!.uid; return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: EdgeInsets.all(6), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: isMe ? Colors.green[100] : Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(dd['text'] ?? ''))); }); })),
          Padding(padding: EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: msgCtrl, onSubmitted: send, decoration: InputDecoration(hintText: "اكتب...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))))), SizedBox(width: 8), FloatingActionButton(mini: true, onPressed: () => send(msgCtrl.text), child: Icon(Icons.send))]))
        ],
      ),
    );
  }
}
