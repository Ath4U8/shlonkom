import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent));
  runApp(const ShlonkomApp());
}

String _generateInternalSecret(String email) { return "Shlonkom_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}_2026"; }
String _generateUniquePin() { final random = Random(); return (100000 + random.nextInt(900000)).toString(); }

class ShlonkomApp extends StatelessWidget {
  const ShlonkomApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'شلونكم', debugShowCheckedModeBanner: false, theme: ThemeData(fontFamily: 'Cairo', colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F5132)), useMaterial3: true), home: const WelcomeSplashScreen());
  }
}

class WelcomeSplashScreen extends StatefulWidget { const WelcomeSplashScreen({super.key}); @override State<WelcomeSplashScreen> createState() => _WelcomeSplashScreenState(); }
class _WelcomeSplashScreenState extends State<WelcomeSplashScreen> {
  @override
  void initState() { super.initState(); Timer(const Duration(seconds: 2), () { _checkDeviceSession(); }); }
  Future<void> _checkDeviceSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email'); final savedUsername = prefs.getString('saved_username'); final savedPersonalPin = prefs.getString('saved_personal_pin'); final lastActiveMillis = prefs.getInt('last_active_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch; const sixDaysMillis = 6 * 24 * 60 * 60 * 1000;
    if (savedEmail != null && savedUsername != null && savedPersonalPin != null) {
      if (lastActiveMillis > 0 && (now - lastActiveMillis) > sixDaysMillis) { await prefs.clear(); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ReturningLoginScreen(lastEmail: savedEmail))); return; }
      await prefs.setInt('last_active_time', now);
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MainChatHomeScreen(myEmail: savedEmail, myUsername: savedUsername, myPersonalPin: savedPersonalPin)), (route) => false); return;
    }
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterWithEmailScreen()));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0F5132), body: Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Text('🇮🇶 العراق 🇮🇶', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))), const SizedBox(height: 35), const Text('أهلاً وسهلاً بك في تطبيق شلونكم للاتصالات والمراسلات العراقي', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 1.5)), const SizedBox(height: 50), const CircularProgressIndicator(color: Colors.white), const SizedBox(height: 40), const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))]))));
  }
}

class RegisterWithEmailScreen extends StatefulWidget { const RegisterWithEmailScreen({super.key}); @override State<RegisterWithEmailScreen> createState() => _RegisterWithEmailScreenState(); }
class _RegisterWithEmailScreenState extends State<RegisterWithEmailScreen> {
  final TextEditingController _emailController = TextEditingController(); bool _isLoading = false;
  void _registerAndSendVerificationLink() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل بريداً إلكترونياً صالحاً'))); return; }
    setState(() => _isLoading = true);
    try {
      final secret = _generateInternalSecret(email); UserCredential userCredential;
      try { userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: secret); }
      on FirebaseAuthException catch (e) { if (e.code == 'email-already-in-use') { userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: secret); } else { rethrow; } }
      final user = userCredential.user; if (user != null && !user.emailVerified) { await user.sendEmailVerification(); }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال رابط التفعيل إلى: $email'), backgroundColor: Colors.green[800])); Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyEmailLinkScreen(email: email))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء إرسال رابط التفعيل: $e'))); } finally { if (mounted) setState(() => _isLoading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(resizeToAvoidBottomInset: true, backgroundColor: Colors.white, appBar: AppBar(automaticallyImplyLeading: false, title: const Text('تسجيل حساب جديد', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)), backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0), child: Column(children: [CircleAvatar(radius: 45, backgroundColor: const Color(0xFF0F5132).withOpacity(0.08), child: const Icon(Icons.mark_email_unread_outlined, size: 50, color: Color(0xFF0F5132))), const SizedBox(height: 25), const Text('أدخل بريدك الإلكتروني لإرسال رابط تفعيل الحساب الرسمي:', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black87)), const SizedBox(height: 30), TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: 'name@example.com', contentPadding: EdgeInsets.symmetric(vertical: 12), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0F5132), width: 2)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF137547), width: 2.5)))), const SizedBox(height: 15), TextButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturningLoginScreen())); }, child: const Text('لديك حساب مسبقاً؟ تسجيل الدخول برقمك الشخصي', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold))), const SizedBox(height: 40), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _isLoading ? null : _registerAndSendVerificationLink, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('إرسال رابط التفعيل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))), const SizedBox(height: 25), const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600))]))); 
  }
}

class VerifyEmailLinkScreen extends StatefulWidget { final String email; const VerifyEmailLinkScreen({super.key, required this.email}); @override State<VerifyEmailLinkScreen> createState() => _VerifyEmailLinkScreenState(); }
class _VerifyEmailLinkScreenState extends State<VerifyEmailLinkScreen> {
  bool _isChecking = false; Timer? _timer;
  @override
  void initState() { super.initState(); _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified(silent: true)); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  void _checkEmailVerified({bool silent = false}) async { if (!silent) setState(() => _isChecking = true); try { final user = FirebaseAuth.instance.currentUser; if (user != null) { await user.reload(); final freshUser = FirebaseAuth.instance.currentUser; if (freshUser != null && freshUser.emailVerified) { _timer?.cancel(); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التفعيل بنجاح!'), backgroundColor: Colors.green)); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CreateProfileScreen(email: widget.email))); } return; } } if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم الضغط على رابط التفعيل بعد. افتح ايميلك واضغط الرابط.'))); } catch (e) { if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); } finally { if (!silent && mounted) setState(() => _isChecking = false); } }
  @override
  Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.white, appBar: AppBar(automaticallyImplyLeading: false, title: const Text('تأكيد البريد الإلكتروني', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)), backgroundColor: Colors.white, elevation: 0, centerTitle: true), body: Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.mark_email_read, size: 80, color: Color(0xFF0F5132)), const SizedBox(height: 20), Text('تم إرسال رابط تفعيل الحساب إلى:\n${widget.email}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 10), const Text('يرجى فتح بريدك الإلكتروني والنقر على رابط التفعيل، ثم اضغط على زر التحقق أدناه للمتابعة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(height: 40), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _isChecking ? null : _checkEmailVerified, child: _isChecking ? const CircularProgressIndicator(color: Colors.white) : const Text('تحقق من تفعيل الحساب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))), const Spacer(), const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600))]))); }
}

class CreateProfileScreen extends StatefulWidget { final String email; const CreateProfileScreen({super.key, required this.email}); @override State<CreateProfileScreen> createState() => _CreateProfileScreenState(); }
class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final TextEditingController _usernameController = TextEditingController(); String? _permanentPersonalPin; File? _selectedImage; bool _isLoading = false;
  @override
  void initState() { super.initState(); _usernameController.text = widget.email.split('@')[0]; _initializePermanentPin(); }
  Future<void> _initializePermanentPin() async {
    // ولد رقم فوراً حتى لا تعلك الصفحة
    final newPin = _generateUniquePin();
    setState(() { _permanentPersonalPin = newPin; });
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.email);
      final doc = await docRef.get();
      if (doc.exists && doc.data()?['personalPin'] != null) {
        if (mounted) setState(() { _permanentPersonalPin = doc.data()?['personalPin']; });
      }
    } catch (e) {
      debugPrint('Pin load error: $e');
    }
  }
  Future<void> _pickImage() async { final picker = ImagePicker(); final picked = await picker.pickImage(source: ImageSource.gallery); if (picked != null) { setState(() { _selectedImage = File(picked.path); }); } }
  void _saveProfileAndProceed() async { final username = _usernameController.text.trim(); if (username.isEmpty || _permanentPersonalPin == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المستخدم'))); return; } setState(() => _isLoading = true); try { try { await FirebaseFirestore.instance.collection('users').doc(widget.email).set({'email': widget.email, 'username': username, 'personalPin': _permanentPersonalPin, 'createdAt': FieldValue.serverTimestamp(), 'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true)); } catch (e) { debugPrint('Save error but continue: $e'); } final prefs = await SharedPreferences.getInstance(); await prefs.setString('saved_email', widget.email); await prefs.setString('saved_username', username); await prefs.setString('saved_personal_pin', _permanentPersonalPin!); await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MainChatHomeScreen(myEmail: widget.email, myUsername: username, myPersonalPin: _permanentPersonalPin!)), (route) => false); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء حفظ البيانات: $e'))); } finally { if (mounted) setState(() => _isLoading = false); } }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white, appBar: AppBar(automaticallyImplyLeading: false, title: const Text('إعداد الملف الشخصي', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold, fontSize: 18)), backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0), child: Column(children: [GestureDetector(onTap: _pickImage, child: Stack(alignment: Alignment.bottomRight, children: [CircleAvatar(radius: 60, backgroundColor: const Color(0xFF0F5132).withOpacity(0.1), backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null, child: _selectedImage == null ? const Icon(Icons.person, size: 80, color: Color(0xFF0F5132)) : null), const CircleAvatar(radius: 20, backgroundColor: Color(0xFF0F5132), child: Icon(Icons.camera_alt, size: 20, color: Colors.white))])), const SizedBox(height: 25), TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'اسم المستخدم', hintText: 'مثال: Ath4U', prefixIcon: Icon(Icons.alternate_email, color: Color(0xFF0F5132)), border: OutlineInputBorder())), const SizedBox(height: 20), Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF0F5132).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0F5132).withOpacity(0.3))), child: Column(children: [const Text('رقمك الشخصي الثابت (بديل رقم الهاتف):', style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(_permanentPersonalPin ?? 'جاري التوليد...', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 4))])), const SizedBox(height: 30), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _isLoading ? null : _saveProfileAndProceed, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ والدخول والتفعيل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))), const SizedBox(height: 15), const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600))]))); 
  }
}

class ReturningLoginScreen extends StatefulWidget { final String? lastEmail; const ReturningLoginScreen({super.key, this.lastEmail}); @override State<ReturningLoginScreen> createState() => _ReturningLoginScreenState(); }
class _ReturningLoginScreenState extends State<ReturningLoginScreen> {
  late TextEditingController _emailController; final TextEditingController _personalPinController = TextEditingController(); bool _isLoading = false;
  @override
  void initState() { super.initState(); _emailController = TextEditingController(text: widget.lastEmail ?? ''); }
  void _loginUser() async {
    final email = _emailController.text.trim().toLowerCase(); final pin = _personalPinController.text.trim();
    if (email.isEmpty || pin.length != 6) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال البريد ورقمك الشخصي المكون من 6 أرقام'))); return; }
    setState(() => _isLoading = true);
    try { final doc = await FirebaseFirestore.instance.collection('users').doc(email).get(); if (doc.exists && doc.data()?['personalPin'] == pin) { final username = doc.data()?['username'] ?? email.split('@')[0]; final prefs = await SharedPreferences.getInstance(); await prefs.setString('saved_email', email); await prefs.setString('saved_username', username); await prefs.setString('saved_personal_pin', pin); await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MainChatHomeScreen(myEmail: email, myUsername: username, myPersonalPin: pin)), (route) => false); } else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بيانات الدخول أو الرقم الشخصي غير صحيح'))); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); } finally { if (mounted) setState(() => _isLoading = false); }
  }
  void _recoverPin() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل بريدك أولاً'))); return; }
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
    } finally { if (mounted) setState(() => _isLoading = false); }
  }
  @override
  Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.white, appBar: AppBar(automaticallyImplyLeading: false, leading: null, title: const Text('تسجيل الدخول', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, centerTitle: true), body: Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0), child: Column(children: [const SizedBox(height: 20), TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF0F5132)), border: OutlineInputBorder())), const SizedBox(height: 15), TextField(controller: _personalPinController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'الرقم الشخصي الثابت (6 أرقام)', prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF0F5132)), border: OutlineInputBorder(), counterText: '')), const Spacer(), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), onPressed: _isLoading ? null : _loginUser, child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل الدخول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))), const SizedBox(height: 15), const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600))]))); }
}

class MainChatHomeScreen extends StatefulWidget { final String myEmail, myUsername, myPersonalPin; const MainChatHomeScreen({super.key, required this.myEmail, required this.myUsername, required this.myPersonalPin}); @override State<MainChatHomeScreen> createState() => _MainChatHomeScreenState(); }
class _MainChatHomeScreenState extends State<MainChatHomeScreen> {
  final TextEditingController _friendPinController = TextEditingController(); bool _isSearching = false;
  void _searchAndAddFriend() async { final targetPin = _friendPinController.text.trim(); if (targetPin.length != 6) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رقم شخصي صحيح'))); return; } if (targetPin == widget.myPersonalPin) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكنك إضافة نفسك'))); return; } setState(() => _isSearching = true); try { final querySnapshot = await FirebaseFirestore.instance.collection('users').where('personalPin', isEqualTo: targetPin).get(); if (querySnapshot.docs.isNotEmpty) { final friendData = querySnapshot.docs.first.data(); final friendEmail = friendData['email']; final friendName = friendData['username'] ?? 'صديق'; if (mounted) { _friendPinController.clear(); Navigator.push(context, MaterialPageRoute(builder: (_) => IndividualChatScreen(myEmail: widget.myEmail, myUsername: widget.myUsername, friendEmail: friendEmail, friendName: friendName))); } } else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على مستخدم بهذا الرقم'))); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); } finally { if (mounted) setState(() => _isSearching = false); } }
  void _confirmLogout() { showDialog(context: context, builder: (context) => AlertDialog(title: const Text('تسجيل الخروج', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.bold)), content: const Text('هل أنت متأكد؟'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.clear(); if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RegisterWithEmailScreen()), (route) => false); }, child: const Text('خروج'))])); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(automaticallyImplyLeading: false, title: Text('شلونكم - ${widget.myUsername}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _confirmLogout)]),
      body: Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF0F5132).withOpacity(0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF0F5132).withOpacity(0.2))), child: Column(children: [const Text('رقمك الشخصي الثابت:'), const SizedBox(height: 5), Text(widget.myPersonalPin, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F5132), letterSpacing: 3))])), const SizedBox(height: 25), const Text('إضافة صديق جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F5132))), const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: _friendPinController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(counterText: '', hintText: 'أدخل الرقم الشخصي للصديق', prefixIcon: Icon(Icons.person_add_alt_1, color: Color(0xFF0F5132)), border: OutlineInputBorder()))), const SizedBox(width: 10), SizedBox(height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _isSearching ? null : _searchAndAddFriend, child: _isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('بحث')))]), const SizedBox(height: 30), const Text('المحادثات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F5132))), const SizedBox(height: 10), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: widget.myEmail).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return const Center(child: Text('لا توجد محادثات.\nأضف صديقاً برقمة الشخصي!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14))); } final chatDocs = snapshot.data!.docs; return ListView.builder(itemCount: chatDocs.length, itemBuilder: (context, index) { final chatData = chatDocs[index].data() as Map<String, dynamic>; final List participants = chatData['participants'] ?? []; final friendEmail = participants.firstWhere((e) => e != widget.myEmail, orElse: () => 'غير معروف'); final lastMessage = chatData['lastMessage'] ?? 'بدء محادثة'; return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(friendEmail).get(), builder: (context, userSnapshot) { String friendName = friendEmail; if (userSnapshot.hasData && userSnapshot.data!.exists) { friendName = userSnapshot.data!['username'] ?? friendEmail; } return ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF0F5132), child: Text(friendName[0].toUpperCase(), style: const TextStyle(color: Colors.white))), title: Text(friendName, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => IndividualChatScreen(myEmail: widget.myEmail, myUsername: widget.myUsername, friendEmail: friendEmail, friendName: friendName))); }); }); }); })), const Center(child: Padding(padding: EdgeInsets.only(top: 10), child: Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600))))]))); 
  }
}

class IndividualChatScreen extends StatefulWidget { final String myEmail, myUsername, friendEmail, friendName; const IndividualChatScreen({super.key, required this.myEmail, required this.myUsername, required this.friendEmail, required this.friendName}); @override State<IndividualChatScreen> createState() => _IndividualChatScreenState(); }
class _IndividualChatScreenState extends State<IndividualChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController(); late String _chatDocId; bool _isUploadingImage = false; Timer? _typingTimer; bool _isFriendTyping = false; String _friendStatus = 'متصل'; 
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); final sortedEmails = [widget.myEmail, widget.friendEmail]..sort(); _chatDocId = '${sortedEmails[0]}_${sortedEmails[1]}'; _listenFriendTyping(); _listenFriendStatus(); _messageController.addListener(_onTyping); }
  void _listenFriendTyping() { FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.friendEmail).snapshots().listen((doc) { if (doc.exists) { final data = doc.data(); final isTyping = data?['isTyping'] == true; final time = (data?['timestamp'] as Timestamp?)?.toDate(); final now = DateTime.now(); if (isTyping && time != null && now.difference(time).inSeconds < 5) { if (mounted) setState(() { _isFriendTyping = true; }); } else { if (mounted) setState(() { _isFriendTyping = false; }); } } }); }
  void _listenFriendStatus() { FirebaseFirestore.instance.collection('users').doc(widget.friendEmail).snapshots().listen((doc) { if (doc.exists) { final isOnline = doc.data()?['isOnline'] == true; final lastSeen = (doc.data()?['lastSeen'] as Timestamp?)?.toDate(); if (mounted) setState(() { if (isOnline) { _friendStatus = 'متصل'; } else if (lastSeen != null) { final diff = DateTime.now().difference(lastSeen); if (diff.inMinutes < 1) _friendStatus = 'آخر ظهور الآن'; else if (diff.inMinutes < 60) _friendStatus = 'آخر ظهور قبل ${diff.inMinutes} دقيقة'; else if (diff.inHours < 24) _friendStatus = 'آخر ظهور قبل ${diff.inHours} ساعة'; else _friendStatus = 'غير متصل'; } else { _friendStatus = 'غير متصل'; } }); } }); }
  void _onTyping() { if (_messageController.text.isNotEmpty) { FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.myEmail).set({'isTyping': true, 'timestamp': FieldValue.serverTimestamp()}); _typingTimer?.cancel(); _typingTimer = Timer(const Duration(seconds: 3), () { FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.myEmail).set({'isTyping': false, 'timestamp': FieldValue.serverTimestamp()}); }); } else { FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.myEmail).set({'isTyping': false, 'timestamp': FieldValue.serverTimestamp()}); } }
  @override
  void dispose() { _typingTimer?.cancel(); _messageController.removeListener(_onTyping); FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('typing').doc(widget.myEmail).set({'isTyping': false, 'timestamp': FieldValue.serverTimestamp()}); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  void _sendMessage({required String text, String messageType = 'text', String mediaUrl = ''}) async {
    if (text.isEmpty && mediaUrl.isEmpty) return; if (messageType == 'text') _messageController.clear();
    final messageData = {'senderEmail': widget.myEmail, 'text': text, 'type': messageType, 'mediaUrl': mediaUrl, 'status': 'delivered', 'timestamp': FieldValue.serverTimestamp()};
    try { await FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('messages').add(messageData); await FirebaseFirestore.instance.collection('chats').doc(_chatDocId).set({'participants': [widget.myEmail, widget.friendEmail], 'lastMessage': messageType == 'image' ? '📸 صورة' : text, 'lastTimestamp': FieldValue.serverTimestamp()}, SetOptions(merge: true)); } catch (e) { debugPrint('Error: $e'); }
  }
  Future<void> _pickAndUploadImage(ImageSource source) async {
    try { final picker = ImagePicker(); final pickedFile = await picker.pickImage(source: source, imageQuality: 70); if (pickedFile == null) return; setState(() => _isUploadingImage = true); File file = File(pickedFile.path); String fileName = 'chat_images/${_chatDocId}_${DateTime.now().millisecondsSinceEpoch}.jpg'; Reference storageRef = FirebaseStorage.instance.ref().child(fileName); UploadTask uploadTask = storageRef.putFile(file); TaskSnapshot snapshot = await uploadTask; String downloadUrl = await snapshot.ref.getDownloadURL(); setState(() => _isUploadingImage = false); _sendMessage(text: '📸 صورة', messageType: 'image', mediaUrl: downloadUrl); } catch (e) { setState(() => _isUploadingImage = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
  }
  void _showAttachmentSheet() { showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('إرسال صورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F5132))), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildAttachOption(Icons.image, 'المعرض', () { Navigator.pop(context); _pickAndUploadImage(ImageSource.gallery); }), _buildAttachOption(Icons.camera_alt, 'الكاميرا', () { Navigator.pop(context); _pickAndUploadImage(ImageSource.camera); })])]))); }
  Widget _buildAttachOption(IconData icon, String label, VoidCallback onTap) { return GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 28, backgroundColor: const Color(0xFF0F5132).withOpacity(0.1), child: Icon(icon, color: const Color(0xFF0F5132), size: 26)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))])); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white, title: Row(children: [CircleAvatar(backgroundColor: Colors.white24, child: Text(widget.friendName[0].toUpperCase(), style: const TextStyle(color: Colors.white))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.friendName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), Text(_isFriendTyping ? 'جاري الكتابة...' : _friendStatus, style: TextStyle(fontSize: 10, color: _isFriendTyping ? Colors.yellowAccent : Colors.white70, fontWeight: _isFriendTyping ? FontWeight.bold : FontWeight.normal))]))]), actions: [IconButton(icon: const Icon(Icons.call, color: Colors.white), tooltip: 'اتصال صوتي مجاني', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(myEmail: widget.myEmail, friendEmail: widget.friendEmail, friendName: widget.friendName, chatDocId: _chatDocId))); }), IconButton(icon: const Icon(Icons.arrow_forward, size: 22), tooltip: 'رجوع', onPressed: () => Navigator.pop(context))]),
      body: Container(color: const Color(0xFFF7F5F0), child: Column(children: [if (_isFriendTyping) Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6), color: const Color(0xFFD1E7DD).withOpacity(0.5), child: Text('${widget.friendName} جاري الكتابة...', style: const TextStyle(fontSize: 12, color: Color(0xFF0F5132), fontStyle: FontStyle.italic))), if (_isUploadingImage) LinearProgressIndicator(backgroundColor: Colors.green[100], color: const Color(0xFF0F5132)), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('chats').doc(_chatDocId).collection('messages').orderBy('timestamp', descending: true).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); final docs = snapshot.data!.docs; if (docs.isEmpty) return const Center(child: Text('لا توجد رسائل بعد. ابدأ الآن!', style: TextStyle(color: Colors.grey))); return ListView.builder(reverse: true, itemCount: docs.length, itemBuilder: (context, index) { final msg = docs[index].data() as Map<String, dynamic>; final isMe = msg['senderEmail'] == widget.myEmail; final text = msg['text'] ?? ''; final type = msg['type'] ?? 'text'; final mediaUrl = msg['mediaUrl'] ?? ''; final status = msg['status'] ?? 'delivered'; return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isMe ? const Color(0xFFD1E7DD) : Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [if (type == 'image' && mediaUrl.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(mediaUrl, width: 200, height: 150, fit: BoxFit.cover, loadingBuilder: (c, child, p) { if (p == null) return child; return const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2))); })), if (type != 'image') Text(text, style: TextStyle(color: isMe ? const Color(0xFF0F5132) : Colors.black87, fontSize: 15)), const SizedBox(height: 4), if (isMe) Icon(status == 'read' ? Icons.done_all : Icons.done, size: 14, color: status == 'read' ? Colors.blue : Colors.grey)]))); }); })), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), color: Colors.white, child: Row(children: [IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF0F5132), size: 28), onPressed: _showAttachmentSheet), Expanded(child: TextField(controller: _messageController, decoration: InputDecoration(hintText: 'اكتب رسالة...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), filled: true, fillColor: Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10)))), const SizedBox(width: 5), CircleAvatar(backgroundColor: const Color(0xFF0F5132), child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: () => _sendMessage(text: _messageController.text.trim()))) ])) ])));
  }
}

class VoiceCallScreen extends StatefulWidget { final String myEmail, friendEmail, friendName, chatDocId; const VoiceCallScreen({super.key, required this.myEmail, required this.friendEmail, required this.friendName, required this.chatDocId}); @override State<VoiceCallScreen> createState() => _VoiceCallScreenState(); }
class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final _localRenderer = RTCVideoRenderer(); final _remoteRenderer = RTCVideoRenderer(); RTCPeerConnection? _pc; bool _inCall = false; bool _isCaller = true;
  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    await Permission.microphone.request(); await _localRenderer.initialize(); await _remoteRenderer.initialize();
    _pc = await createPeerConnection({'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}, {'urls': 'stun:stun1.l.google.com:19302'}]});
    _pc!.onTrack = (e) { if (mounted) setState(() { _remoteRenderer.srcObject = e.streams[0]; _inCall = true; }); };
    _pc!.onIceCandidate = (c) { if (c.candidate != null) FirebaseFirestore.instance.collection('calls').doc(widget.chatDocId).collection('candidates').add(c.toMap()); };
    try {
      var stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false}); _localRenderer.srcObject = stream; for (var t in stream.getTracks()) { await _pc!.addTrack(t, stream); }
      var callDoc = FirebaseFirestore.instance.collection('calls').doc(widget.chatDocId); var existing = await callDoc.get();
      if (!existing.exists || existing.data()?['offer'] == null) {
        var offer = await _pc!.createOffer(); await _pc!.setLocalDescription(offer); await callDoc.set({'offer': offer.toMap(), 'caller': widget.myEmail, 'callee': widget.friendEmail, 'started': FieldValue.serverTimestamp()});
        _isCaller = true;
      } else {
        _isCaller = false; await _pc!.setRemoteDescription(RTCSessionDescription(existing.data()!['offer']['sdp'], existing.data()!['offer']['type'])); var answer = await _pc!.createAnswer(); await _pc!.setLocalDescription(answer); await callDoc.update({'answer': answer.toMap()});
      }
      callDoc.snapshots().listen((s) async { if (s.data()?['answer'] != null && _pc!.getRemoteDescription() == null && _isCaller) { await _pc!.setRemoteDescription(RTCSessionDescription(s.data()!['answer']['sdp'], s.data()!['answer']['type'])); if (mounted) setState(() => _inCall = true); } });
      callDoc.collection('candidates').snapshots().listen((snap) { for (var change in snap.docChanges) { if (change.type == DocumentChangeType.added) { var data = change.doc.data(); if (data != null) { _pc!.addCandidate(RTCIceCandidate(data['candidate'] as String?, data['sdpMid'] as String?, data['sdpMLineIndex'] as int?)); } } } });
    } catch (e) { debugPrint('WebRTC error: $e'); }
  }
  @override
  void dispose() { _localRenderer.dispose(); _remoteRenderer.dispose(); _pc?.close(); try { FirebaseFirestore.instance.collection('calls').doc(widget.chatDocId).delete(); } catch (_) {} super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0F5132), body: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(height: 60), CircleAvatar(radius: 60, backgroundColor: Colors.white, child: Text(widget.friendName[0].toUpperCase(), style: const TextStyle(fontSize: 50, color: Color(0xFF0F5132), fontWeight: FontWeight.bold))), const SizedBox(height: 20), Text(widget.friendName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text(_inCall ? 'متصل الآن - مجاني 100% 🔥' : 'جاري الاتصال بـ ${widget.friendName}...', style: const TextStyle(color: Colors.white70, fontSize: 14)), const Spacer(), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [FloatingActionButton(backgroundColor: Colors.white24, onPressed: () {}, child: const Icon(Icons.mic, color: Colors.white)), FloatingActionButton.large(backgroundColor: Colors.red, onPressed: () => Navigator.pop(context), child: const Icon(Icons.call_end, size: 35, color: Colors.white)), FloatingActionButton(backgroundColor: Colors.white24, onPressed: () {}, child: const Icon(Icons.volume_up, color: Colors.white))]), const SizedBox(height: 50), const Text('Designed by: Atheer Sami', style: TextStyle(color: Colors.white54, fontSize: 12))]))));
  }
}
