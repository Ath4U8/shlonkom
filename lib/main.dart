import 'dart:async';
import 'dart:io';
import 'dart:convert';
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
      theme: ThemeData(primaryColor: const Color(0xFF0F5132)),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }
  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    final username = prefs.getString('saved_username');
    final pin = prefs.getString('saved_personal_pin');
    final lastActive = prefs.getInt('last_active_time');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    if (email != null && username != null && pin != null && lastActive != null) {
      final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastActive));
      if (diff.inDays <= 6) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainChatHomeScreen(myEmail: email, myUsername: username, myPersonalPin: pin)));
        return;
      }
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterWithEmailScreen()));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0F5132), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 120, height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)), child: const Icon(Icons.chat, size: 70, color: Color(0xFF0F5132))), const SizedBox(height: 20), const Text('شلونكم', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 40), const CircularProgressIndicator(color: Colors.white)])));
  }
}

String _generateInternalSecret(String email) {
  return 'shlonkom_${email.hashCode}_secret_2024';
}

String _generateUniquePin() {
  final random = DateTime.now().millisecondsSinceEpoch % 900000 + 100000;
  return random.toString();
}

// Register
class RegisterWithEmailScreen extends StatefulWidget {
  const RegisterWithEmailScreen({super.key});
  @override
  State<RegisterWithEmailScreen> createState() => _RegisterWithEmailScreenState();
}

class _RegisterWithEmailScreenState extends State<RegisterWithEmailScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registerAndSendVerificationLink() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل بريد صحيح')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final existingUser = await FirebaseFirestore.instance.collection('users').doc(email).get();
      if (existingUser.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا البريد مسجل مسبقاً! سجل دخول برقمك الشخصي.'), backgroundColor: Colors.orange, duration: Duration(seconds: 4)));
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ReturningLoginScreen()));
        }
        return;
      }
      final tempCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: _generateInternalSecret(email));
      await tempCred.user!.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال رابط التفعيل لبريدك. افتح بريدك واضغط الرابط.'), duration: Duration(seconds: 5), backgroundColor: Colors.green));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VerifyEmailLinkScreen(email: email)));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا البريد مسجل مسبقاً. سجل دخول برقمك الشخصي.'), backgroundColor: Colors.orange));
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ReturningLoginScreen()));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.message}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('تسجيل حساب جديد', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0), child: Column(children: [
        CircleAvatar(radius: 45, backgroundColor: const Color(0xFF0F5132).withOpacity(0.08), child: const Icon(Icons.mark_email_unread_outlined, size: 50, color: Color(0xFF0F5132))),
        const SizedBox(height: 25),
        const Text('أدخل بريدك الإلكتروني لإرسال رابط تفعيل الحساب الرسمي:', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black87)),
        const SizedBox(height: 30),
        TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: 'name@example.com', contentPadding: EdgeInsets.symmetric(vertical: 12), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0F5132), width: 2)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF137547), width: 2.5)))),
        const SizedBox(height: 15),
        TextButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturningLoginScreen())); }, child: const Text('لديك حساب مسبقاً؟ تسجيل الدخول برقمك الشخصي', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold))),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _isLoading ? null : _registerAndSendVerificationLink, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('إرسال رابط التفعيل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 25),
        const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600))
      ])),
    );
  }
}

// Verify
class VerifyEmailLinkScreen extends StatefulWidget {
  final String email;
  const VerifyEmailLinkScreen({super.key, required this.email});
  @override
  State<VerifyEmailLinkScreen> createState() => _VerifyEmailLinkScreenState();
}

class _VerifyEmailLinkScreenState extends State<VerifyEmailLinkScreen> {
  bool _isChecking = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified(silent: true));
  }
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  Future<void> _checkEmailVerified({bool silent = false}) async {
    if (!silent) setState(() => _isChecking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final freshUser = FirebaseAuth.instance.currentUser;
        if (freshUser != null && freshUser.emailVerified) {
          _timer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التفعيل بنجاح!'), backgroundColor: Colors.green));
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CreateProfileScreen(email: widget.email)));
          }
          return;
        }
      }
      if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم الضغط على رابط التفعيل بعد. افتح ايميلك واضغط الرابط.')));
    } catch (e) {
      if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (!silent && mounted) setState(() => _isChecking = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('تفعيل البريد'), backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.mark_email_read, size: 80, color: Color(0xFF0F5132)),
        const SizedBox(height: 20),
        Text('أرسلنا رابط تفعيل إلى:\n${widget.email}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('افتح بريدك واضغط على الرابط حتى يتم تفعيل حسابك. التطبيق سينتقل تلقائياً بعد التفعيل.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 30),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white), onPressed: _isChecking ? null : () => _checkEmailVerified(silent: false), child: _isChecking ? const CircularProgressIndicator(color: Colors.white) : const Text('تحقق من التفعيل'))),
        const SizedBox(height: 15),
        TextButton(onPressed: () async { try { final user = FirebaseAuth.instance.currentUser; await user?.sendEmailVerification(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إعادة إرسال الرابط'), backgroundColor: Colors.green)); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); } }, child: const Text('إعادة إرسال الرابط'))
      ])),
    );
  }
}

// Create Profile - بدون اسم كامل + بصورة base64 + رقم ثابت
class CreateProfileScreen extends StatefulWidget {
  final String email;
  const CreateProfileScreen({super.key, required this.email});
  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  String? _permanentPersonalPin;
  File? _selectedImage;
  String? _base64Image;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.email.split('@')[0];
    _initializePermanentPin();
  }

  Future<void> _initializePermanentPin() async {
    final pin = _generateUniquePin();
    setState(() => _permanentPersonalPin = pin);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 600);
    if (picked != null) {
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      setState(() { _selectedImage = file; _base64Image = base64Str; });
    }
  }

  Future<void> _saveProfileAndProceed() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || _permanentPersonalPin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المستخدم')));
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final fresh = FirebaseAuth.instance.currentUser;
        if (fresh == null || !fresh.emailVerified) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تفعيل بريدك أولاً! افتح ايميلك واضغط رابط التفعيل.'), backgroundColor: Colors.red));
          return;
        }
      }
    } catch (_) {}

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.email).set({
        'email': widget.email,
        'username': username,
        'personalPin': _permanentPersonalPin,
        'photoBase64': _base64Image,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', widget.email);
      await prefs.setString('saved_username', username);
      await prefs.setString('saved_personal_pin', _permanentPersonalPin!);
      await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MainChatHomeScreen(myEmail: widget.email, myUsername: username, myPersonalPin: _permanentPersonalPin!)), (route) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء حفظ البيانات: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('إعداد الملف الشخصي'), backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/login_bg.png'), fit: BoxFit.cover)),
        child: Container(
          color: Colors.white.withOpacity(0.85),
          child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0), child: Column(children: [
        GestureDetector(onTap: _pickImage, child: Stack(alignment: Alignment.bottomRight, children: [
          CircleAvatar(radius: 60, backgroundColor: const Color(0xFF0F5132).withOpacity(0.1), backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null, child: _selectedImage == null ? const Icon(Icons.person, size: 80, color: Color(0xFF0F5132)) : null),
          const CircleAvatar(radius: 20, backgroundColor: Color(0xFF0F5132), child: Icon(Icons.camera_alt, size: 20, color: Colors.white))
        ])),
        const SizedBox(height: 25),
        TextField(controller: _usernameController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'اسم المستخدم', hintText: 'مثال: Ath4U', prefixIcon: Icon(Icons.alternate_email, color: Color(0xFF0F5132)), border: OutlineInputBorder())),
        const SizedBox(height: 20),
        if (_permanentPersonalPin != null) Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0F5132))), child: Column(children: [const Text('رقمك الشخصي الثابت (احفظه):', style: TextStyle(fontSize: 13, color: Colors.black54)), const SizedBox(height: 5), Text(_permanentPersonalPin!, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 5)), const Text('هذا الرقم ثابت لا يتغير', style: TextStyle(fontSize: 11, color: Colors.black45))])), 
        const SizedBox(height: 30),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _isLoading ? null : _saveProfileAndProceed, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ والدخول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
      ])),
        ),
      ),
    );
  }
}


class SeenTicks extends StatelessWidget {
  final bool seen; final bool isMe;
  const SeenTicks({super.key, required this.seen, required this.isMe});
  @override
  Widget build(BuildContext context) {
    if (!isMe) return const SizedBox();
    return Icon(seen ? Icons.done_all : Icons.done, size: 14, color: seen ? Colors.blue : Colors.grey);
  }
}

class FullImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullImageViewer({super.key, required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: Center(child: imageUrl.startsWith('data:image') ? Image.memory(Uri.parse(imageUrl).data!.contentAsBytes(), fit: BoxFit.contain) : Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (c,e,s)=> const Text('تعذر فتح الصورة', style: TextStyle(color: Colors.white)))),
    );
  }
}

// Returning Login
class ReturningLoginScreen extends StatefulWidget {
  const ReturningLoginScreen({super.key});
  @override
  State<ReturningLoginScreen> createState() => _ReturningLoginScreenState();
}

class _ReturningLoginScreenState extends State<ReturningLoginScreen> {
  final _emailController = TextEditingController();
  final _personalPinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _loginUser() async {
    final email = _emailController.text.trim().toLowerCase();
    final pin = _personalPinController.text.trim();
    if (email.isEmpty || pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال البريد ورقمك الشخصي المكون من 6 أرقام')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
      if (doc.exists && doc.data()?['personalPin'] == pin) {
        final username = doc.data()?['username'] ?? email.split('@')[0];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_personal_pin', pin);
        await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MainChatHomeScreen(myEmail: email, myUsername: username, myPersonalPin: pin)), (route) => false);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بيانات الدخول أو الرقم الشخصي غير صحيح')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recoverPin() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل بريدك أولاً')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
      if (doc.exists && doc.data()?['personalPin'] != null) {
        final pin = doc.data()!['personalPin'];
        if (mounted) showDialog(context: context, builder: (_) => AlertDialog(title: const Text('رقمك الشخصي', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)), content: Text('رقمك الشخصي هو:\n\n$pin\n\nاحفظه بمكان آمن!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام'))]));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على حساب بهذا البريد')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(automaticallyImplyLeading: false, leading: null, title: const Text('تسجيل الدخول', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        const SizedBox(height: 20),
        const Icon(Icons.login, size: 80, color: Color(0xFF0F5132)),
        const SizedBox(height: 20),
        TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
        const SizedBox(height: 15),
        TextField(controller: _personalPinController, decoration: const InputDecoration(labelText: 'الرقم الشخصي (6 أرقام)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)), keyboardType: TextInputType.number, maxLength: 6),
        const SizedBox(height: 10),
        TextButton(onPressed: _isLoading ? null : _recoverPin, child: const Text('نسيت رقمي الشخصي؟ اضغط هنا لاسترجاعه', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _isLoading ? null : _loginUser, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}

// Main Chat Home with Incoming Call Listener
class MainChatHomeScreen extends StatefulWidget {
  final String myEmail, myUsername, myPersonalPin;
  const MainChatHomeScreen({super.key, required this.myEmail, required this.myUsername, required this.myPersonalPin});
  @override
  State<MainChatHomeScreen> createState() => _MainChatHomeScreenState();
}

class _MainChatHomeScreenState extends State<MainChatHomeScreen> {
  final _friendPinController = TextEditingController();
  bool _isAddingFriend = false;

  Future<void> _addFriend() async {
    final pin = _friendPinController.text.trim();
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رقم شخصي مكون من 6 أرقام')));
      return;
    }
    setState(() => _isAddingFriend = true);
    try {
      final qs = await FirebaseFirestore.instance.collection('users').where('personalPin', isEqualTo: pin).limit(1).get();
      if (qs.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على هذا الرقم الشخصي. تأكد من الرقم.')));
        return;
      }
      final friendData = qs.docs.first.data();
      final friendEmail = friendData['email'] as String;
      if (friendEmail == widget.myEmail) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكنك إضافة نفسك')));
        return;
      }
      final sortedEmails = [widget.myEmail, friendEmail]..sort();
      final chatDocId = '${sortedEmails[0]}_${sortedEmails[1]}';
      await FirebaseFirestore.instance.collection('chats').doc(chatDocId).set({
        'participants': [widget.myEmail, friendEmail],
        'lastMessage': 'تم بدء المحادثة',
        'lastTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _friendPinController.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الصديق بنجاح!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('permission-denied')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ صلاحيات! روح Firebase > Firestore > Rules واجعلها allow read, write: if true;'), backgroundColor: Colors.red, duration: Duration(seconds: 5)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
        }
      }
    } finally {
      if (mounted) setState(() => _isAddingFriend = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RegisterWithEmailScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, automaticallyImplyLeading: false, title: Text('شلونكم - ${widget.myUsername}', style: const TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'تسجيل خروج')]),
      body: Column(children: [
        IncomingCallListener(myEmail: widget.myEmail),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(15), child: Column(children: [
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0F5132))), child: Column(children: [
            Text('رقمك الشخصي الثابت:', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 5),
            Text(widget.myPersonalPin, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 5))
          ])),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerRight, child: Text('إضافة صديق جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F5132)))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _friendPinController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(hintText: 'ادخل الرقم الشخصي للصديق', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_add), counterText: ''))),
            const SizedBox(width: 10),
            SizedBox(height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white), onPressed: _isAddingFriend ? null : _addFriend, child: _isAddingFriend ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('بحث'))),
          ]),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerRight, child: Text('المحادثات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: widget.myEmail).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Text('لا توجد محادثات');
              return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: docs.length, itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final participants = (data['participants'] as List).cast<String>();
                final friendEmail = participants.firstWhere((e) => e != widget.myEmail, orElse: () => '');
                final lastMessage = data['lastMessage'] ?? '';
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(friendEmail).get(),
                  builder: (context, userSnap) {
                    final friendName = userSnap.data?.data() != null ? (userSnap.data!.data() as Map<String, dynamic>)['username'] ?? friendEmail.split('@')[0] : friendEmail.split('@')[0];
                    final photoBase64 = userSnap.data?.data() != null ? (userSnap.data!.data() as Map<String, dynamic>)['photoBase64'] : null;
                    Widget avatar;
                    if (photoBase64 != null) {
                      try { avatar = CircleAvatar(backgroundImage: MemoryImage(base64Decode(photoBase64))); } catch (_) { avatar = CircleAvatar(backgroundColor: const Color(0xFF0F5132), child: Text(friendName[0].toUpperCase(), style: const TextStyle(color: Colors.white))); }
                    } else {
                      avatar = CircleAvatar(backgroundColor: const Color(0xFF0F5132), child: Text(friendName[0].toUpperCase(), style: const TextStyle(color: Colors.white)));
                    }
                    return Card(child: ListTile(leading: avatar, title: Text(friendName, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => IndividualChatScreen(myEmail: widget.myEmail, myUsername: widget.myUsername, friendEmail: friendEmail, friendName: friendName))); }));
                  },
                );
              });
            },
          )
        ]))),
      ]),
    );
  }
}

// Incoming Call Listener
class IncomingCallListener extends StatelessWidget {
  final String myEmail;
  const IncomingCallListener({super.key, required this.myEmail});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('calls').where('callee', isEqualTo: myEmail).where('status', isEqualTo: 'ringing').orderBy('timestamp', descending: true).limit(1).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final call = snapshot.data!.docs.first;
        final data = call.data() as Map<String, dynamic>;
        final caller = data['caller'] as String;
        final callerName = data['callerName'] ?? caller.split('@')[0];
        final chatDocId = data['chatDocId'] ?? '';
        return Container(
          color: const Color(0xFF0F5132),
          padding: const EdgeInsets.all(15),
          child: SafeArea(
            child: Row(
              children: [
                const Icon(Icons.call, color: Colors.white, size: 30),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$callerName يتصل بك...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const Text('مكالمة صوتية مجانية', style: TextStyle(color: Colors.white70, fontSize: 12))])),
                IconButton(icon: const Icon(Icons.call_end, color: Colors.white), style: IconButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await FirebaseFirestore.instance.collection('calls').doc(call.id).update({'status': 'ended'}); }),
                const SizedBox(width: 10),
                IconButton(icon: const Icon(Icons.call, color: Colors.white), style: IconButton.styleFrom(backgroundColor: Colors.green), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(myEmail: myEmail, myUsername: myEmail.split('@')[0], friendEmail: caller, friendName: callerName, chatDocId: chatDocId, isIncoming: true, incomingCallId: call.id))); }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Individual Chat with typing + online + last seen + base64 images
class IndividualChatScreen extends StatefulWidget {
  final String myEmail, myUsername, friendEmail, friendName;
  const IndividualChatScreen({super.key, required this.myEmail, required this.myUsername, required this.friendEmail, required this.friendName});
  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

void playNotificationSound() async {
  try {
    // Use system sound - will be replaced by audioplayers in pubspec
    // For now use Haptic feedback as fallback
    // ignore: avoid_print
    print('notification sound');
  } catch (_) {}
}

class _IndividualChatScreenState extends State<IndividualChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  late String _chatDocId;
  bool _isUploadingImage = false;
  Timer? _typingTimer;
  bool _isFriendTyping = false;
  String _friendStatus = 'متصل';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final sortedEmails = [widget.myEmail, widget.friendEmail]..sort();
    _chatDocId = '${sortedEmails[0]}_${sortedEmails[1]}';
    _listenFriendTyping();
    _listenFriendStatus();
    _messageController.addListener(_onTyping);
  }

  void _listenFriendTyping() {
    FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.friendEmail).snapshots().listen((doc) {
      if (doc.exists) {
        final data = doc.data();
        final isTyping = data?['isTyping'] == true;
        final time = (data?['timestamp'] as Timestamp?)?.toDate();
        final now = DateTime.now();
        if (isTyping && time != null && now.difference(time).inSeconds < 5) {
          if (mounted) setState(() => _isFriendTyping = true);
        } else {
          if (mounted) setState(() => _isFriendTyping = false);
        }
      }
    });
  }

  void _listenFriendStatus() {
    FirebaseFirestore.instance.collection('users').doc(widget.friendEmail).snapshots().listen((doc) {
      if (doc.exists) {
        final isOnline = doc.data()?['isOnline'] == true;
        final lastSeen = (doc.data()?['lastSeen'] as Timestamp?)?.toDate();
        if (mounted) setState(() {
          if (isOnline) { _friendStatus = 'متصل'; }
          else if (lastSeen != null) {
            final diff = DateTime.now().difference(lastSeen);
            if (diff.inMinutes < 1) _friendStatus = 'آخر ظهور الآن';
            else if (diff.inMinutes < 60) _friendStatus = 'آخر ظهور قبل ${diff.inMinutes} دقيقة';
            else if (diff.inHours < 24) _friendStatus = 'آخر ظهور قبل ${diff.inHours} ساعة';
            else _friendStatus = 'غير متصل';
          } else { _friendStatus = 'غير متصل'; }
        });
      }
    });
  }

  void _onTyping() {
    if (_messageController.text.isNotEmpty) {
      FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.myEmail).set({'isTyping': true, 'timestamp': FieldValue.serverTimestamp()});
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.myEmail).set({'isTyping': false, 'timestamp': FieldValue.serverTimestamp()});
      });
    } else {
      FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.myEmail).set({'isTyping': false, 'timestamp': FieldValue.serverTimestamp()});
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.removeListener(_onTyping);
    FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.myEmail).set({'isTyping': false, 'timestamp': FieldValue.serverTimestamp()});
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.myEmail).set({'isTyping': false, 'timestamp': FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('messages').add({
      'sender': widget.myEmail,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });
    await FirebaseFirestore.instance.collection('chats').doc(_chatDocId).set({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [widget.myEmail, widget.friendEmail],
    }, SetOptions(merge: true));
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 800);
    if (picked == null) return;
    setState(() => _isUploadingImage = true);
    try {
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final base64Img = base64Encode(bytes);
      await FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('messages').add({
        'sender': widget.myEmail,
        'imageBase64': base64Img,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'image',
      });
      await FirebaseFirestore.instance.collection('chats').doc(_chatDocId).set({
        'lastMessage': '📷 صورة',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'participants': [widget.myEmail, widget.friendEmail],
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ رفع الصورة: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, title: Row(children: [
        CircleAvatar(backgroundColor: Colors.white24, child: Text(widget.friendName[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.friendName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(_isFriendTyping ? 'جاري الكتابة...' : _friendStatus, style: TextStyle(fontSize: 10, color: _isFriendTyping ? Colors.yellowAccent : Colors.white70, fontWeight: _isFriendTyping ? FontWeight.bold : FontWeight.normal))
        ]))
      ]), actions: [
        IconButton(icon: const Icon(Icons.call, color: Colors.white), tooltip: 'اتصال صوتي مجاني', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(myEmail: widget.myEmail, myUsername: widget.myUsername, friendEmail: widget.friendEmail, friendName: widget.friendName, chatDocId: _chatDocId))); }),
        IconButton(icon: const Icon(Icons.arrow_forward, size: 22), tooltip: 'رجوع', onPressed: () => Navigator.pop(context))
      ]),
      body: Container(
        color: const Color(0xFFF7F5F0),
        child: Column(children: [
          if (_isFriendTyping) Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6), color: const Color(0xFFD1E7DD).withOpacity(0.5), child: Text('${widget.friendName} جاري الكتابة...', style: const TextStyle(fontSize: 12, color: Color(0xFF0F5132), fontStyle: FontStyle.italic))),
          if (_isUploadingImage) LinearProgressIndicator(backgroundColor: Colors.green[100], color: const Color(0xFF0F5132)),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              return ListView.builder(reverse: true, itemCount: docs.length, itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final isMe = data['sender'] == widget.myEmail;
                final isImage = data['type'] == 'image';
                if (isImage) {
                  final imageBase64 = data['imageBase64'] as String?;
                  Widget imgWidget;
                  if (imageBase64 != null) {
                    try { imgWidget = Image.memory(base64Decode(imageBase64), width: 200, fit: BoxFit.cover); } catch (_) { imgWidget = Container(width: 200, height: 150, color: Colors.grey[300], child: const Icon(Icons.broken_image)); }
                  } else { imgWidget = Container(width: 200, height: 150, color: Colors.grey[300], child: const Icon(Icons.broken_image)); }
                  return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: imgWidget)));
                }
                final text = data['text'] ?? '';
                return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isMe ? const Color(0xFF0F5132) : Colors.white, borderRadius: BorderRadius.circular(18)), child: Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87))));
              });
            },
          )),
          Container(padding: const EdgeInsets.all(8), color: Colors.white, child: Row(children: [
            IconButton(icon: const Icon(Icons.photo, color: Color(0xFF0F5132)), onPressed: _uploadImage),
            Expanded(child: TextField(controller: _messageController, decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(25))), contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10)))),
            const SizedBox(width: 8),
            CircleAvatar(backgroundColor: const Color(0xFF0F5132), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage)),
          ]))
        ]),
      ),
    );
  }
}

// Voice Call Screen - REAL FREE CALL
class VoiceCallScreen extends StatefulWidget {
  final String myEmail;
  final String myUsername;
  final String friendEmail, friendName, chatDocId;
  final bool isIncoming;
  final String? incomingCallId;
  const VoiceCallScreen({super.key, required this.myEmail, this.myUsername = '', required this.friendEmail, required this.friendName, required this.chatDocId, this.isIncoming = false, this.incomingCallId});
  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  String _status = 'جاري الاتصال...';
  String? _callDocId;

  final Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _initRenderers();
    if (widget.isIncoming) {
      _callDocId = widget.incomingCallId;
      _status = 'مكالمة واردة من ${widget.friendName}';
      _answerCall();
    } else {
      _startCall();
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _startCall() async {
    try {
      await [Permission.microphone].request();
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      _localRenderer.srcObject = _localStream;
      _peerConnection = await createPeerConnection(_config);
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
      _peerConnection!.onIceCandidate = (candidate) {
        if (_callDocId != null && candidate.candidate != null) {
          FirebaseFirestore.instance.collection('calls').doc(_callDocId).collection('candidates').add({...candidate.toMap(), 'sender': widget.myEmail});
        }
      };
      _peerConnection!.onConnectionState = (state) {
        if (mounted) setState(() {
          if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) { _isConnected = true; _status = 'متصل - ${widget.friendName}'; }
          else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) { _status = 'فشل الاتصال'; }
        });
      };
      _peerConnection!.onTrack = (event) { if (event.streams.isNotEmpty) { _remoteRenderer.srcObject = event.streams[0]; } };

      final callRef = FirebaseFirestore.instance.collection('calls').doc();
      _callDocId = callRef.id;
      await callRef.set({'caller': widget.myEmail, 'callee': widget.friendEmail, 'callerName': widget.myEmail.split('@')[0], 'calleeName': widget.friendName, 'status': 'ringing', 'timestamp': FieldValue.serverTimestamp(), 'chatDocId': widget.chatDocId});
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      await callRef.update({'offer': offer.toMap()});

      callRef.snapshots().listen((doc) async {
        if (doc.exists && doc.data()?['answer'] != null && mounted) {
          final answerData = doc.data()!['answer'];
          final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
          await _peerConnection!.setRemoteDescription(answer);
        }
        if (doc.data()?['status'] == 'ended' && mounted) { _endCall(); }
      });

      FirebaseFirestore.instance.collection('calls').doc(_callDocId).collection('candidates').where('sender', isEqualTo: widget.friendEmail).snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final d = change.doc.data()!;
            if (d['candidate'] != null) {
              final candidate = RTCIceCandidate(d['candidate'], d['sdpMid'], d['sdpMLineIndex']);
              _peerConnection!.addCandidate(candidate);
            }
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'خطأ: $e');
    }
  }

  Future<void> _answerCall() async {
    try {
      await [Permission.microphone].request();
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      _localRenderer.srcObject = _localStream;
      _peerConnection = await createPeerConnection(_config);
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          FirebaseFirestore.instance.collection('calls').doc(_callDocId).collection('candidates').add({...candidate.toMap(), 'sender': widget.myEmail});
        }
      };
      _peerConnection!.onConnectionState = (state) { if (mounted) setState(() { if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) { _isConnected = true; _status = 'متصل - ${widget.friendName}'; } }); };
      _peerConnection!.onTrack = (event) { if (event.streams.isNotEmpty) { _remoteRenderer.srcObject = event.streams[0]; } };

      final callDoc = await FirebaseFirestore.instance.collection('calls').doc(_callDocId).get();
      final offerData = callDoc.data()?['offer'];
      if (offerData != null) {
        final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
        await _peerConnection!.setRemoteDescription(offer);
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        await FirebaseFirestore.instance.collection('calls').doc(_callDocId).update({'answer': answer.toMap(), 'status': 'connected'});
      }

      FirebaseFirestore.instance.collection('calls').doc(_callDocId).collection('candidates').where('sender', isEqualTo: widget.friendEmail).snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final d = change.doc.data()!;
            if (d['candidate'] != null) {
              final candidate = RTCIceCandidate(d['candidate'], d['sdpMid'], d['sdpMLineIndex']);
              _peerConnection!.addCandidate(candidate);
            }
          }
        }
      });

      FirebaseFirestore.instance.collection('calls').doc(_callDocId).snapshots().listen((doc) { if (doc.data()?['status'] == 'ended' && mounted) { _endCall(); } });
    } catch (e) {
      if (mounted) setState(() => _status = 'خطأ: $e');
    }
  }

  Future<void> _endCall() async {
    try {
      if (_callDocId != null) { await FirebaseFirestore.instance.collection('calls').doc(_callDocId).update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()}); }
      await _localStream?.dispose();
      await _peerConnection?.close();
      await _localRenderer.dispose();
      await _remoteRenderer.dispose();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  void _toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      setState(() { _isMuted = !_isMuted; audioTrack.enabled = !_isMuted; });
    }
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  @override
  void dispose() {
    _localStream?.dispose();
    _peerConnection?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F5132),
      body: SafeArea(child: Column(children: [
        const SizedBox(height: 60),
        CircleAvatar(radius: 60, backgroundColor: Colors.white24, child: Text(widget.friendName[0].toUpperCase(), style: const TextStyle(fontSize: 50, color: Colors.white))),
        const SizedBox(height: 20),
        Text(widget.friendName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const Spacer(),
        if (widget.isIncoming && !_isConnected) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          FloatingActionButton.large(backgroundColor: Colors.red, onPressed: _endCall, child: const Icon(Icons.call_end, size: 40)),
          FloatingActionButton.large(backgroundColor: Colors.green, onPressed: () { setState(() { _isConnected = true; _status = 'جاري الاتصال...'; }); }, child: const Icon(Icons.call, size: 40)),
        ]),
        if (!widget.isIncoming || _isConnected) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton.filledTonal(onPressed: _toggleMute, icon: Icon(_isMuted ? Icons.mic_off : Icons.mic), style: IconButton.styleFrom(backgroundColor: _isMuted ? Colors.red : Colors.white24, foregroundColor: Colors.white, iconSize: 28, padding: const EdgeInsets.all(15))),
          FloatingActionButton.large(backgroundColor: Colors.red, onPressed: _endCall, child: const Icon(Icons.call_end, size: 40)),
          IconButton.filledTonal(onPressed: _toggleSpeaker, icon: Icon(_isSpeakerOn ? Icons.volume_up : Icons.volume_down), style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white, iconSize: 28, padding: const EdgeInsets.all(15))),
        ]),
        const SizedBox(height: 50),
      ])),
    );
  }
}
