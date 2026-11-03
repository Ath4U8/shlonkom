import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const ShlonkomApp());
}

class ShlonkomApp extends StatelessWidget {
  const ShlonkomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'شلونكم',
      theme: ThemeData(
        fontFamily: 'sans-serif',
        primaryColor: const Color(0xFF0F7A3E),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _currentUser = user;
            _userData = doc.data();
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}
    }
    setState(() {
      _currentUser = null;
      _userData = null;
      _isLoading = false;
    });
  }

  void _onLoginSuccess(User user, Map<String, dynamic> data) {
    setState(() {
      _currentUser = user;
      _userData = data;
    });
  }

  void _onLogout() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      _currentUser = null;
      _userData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF064E24),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_currentUser != null && _userData != null) {
      return HomeScreen(userData: _userData!, onLogout: _onLogout);
    }
    return LoginScreen(onLoginSuccess: _onLoginSuccess);
  }
}

class LoginScreen extends StatefulWidget {
  final Function(User, Map<String, dynamic>) onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  void _showNotice(String text, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'sans-serif')),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF0F7A3E),
      ),
    );
  }

  // جلب عنوان IP عبر مكتبة HttpClient المدمجة بدون حزم خارجية
  Future<String?> _getDeviceIp() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('https://api.ipify.org?format=json'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        return data['ip'];
      }
    } catch (_) {}
    return null;
  }

  Future<String> _generateUniquePin() async {
    final random = Random();
    while (true) {
      String pin = (100000 + random.nextInt(900000)).toString();
      final check = await FirebaseFirestore.instance.collection('users').where('pin', isEqualTo: pin).limit(1).get();
      if (check.docs.isEmpty) return pin;
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final username = _usernameController.text.trim();

    if (email.isEmpty || username.isEmpty) {
      _showNotice('يرجى كتابة البريد الإلكتروني واسم المستخدم');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showNotice('البريد أو اسم المستخدم غير مطابق للبيانات');
        setState(() => _isLoading = false);
        return;
      }

      final userData = query.docs.first.data();
      final userCred = await FirebaseAuth.instance.signInAnonymously();
      widget.onLoginSuccess(userCred.user!, userData);
    } catch (e) {
      _showNotice('حدث خطأ أثناء تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim().toLowerCase();
    final username = _usernameController.text.trim();

    if (email.isEmpty || username.isEmpty) {
      _showNotice('يرجى إدخال البريد واسم المستخدم للتسجيل');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showNotice('صيغة البريد الإلكتروني غير صحيحة');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        _showNotice('اسم المستخدم محجوز بالفعل، اختر اسماً آخر');
        setState(() => _isLoading = false);
        return;
      }

      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        _showNotice('البريد الإلكتروني مسجل مسبقاً، يمكنك الدخول به');
        setState(() => _isLoading = false);
        return;
      }

      final currentIp = await _getDeviceIp();
      if (currentIp != null) {
        final ipCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('device_ip', isEqualTo: currentIp)
            .limit(1)
            .get();

        if (ipCheck.docs.isNotEmpty) {
          _showNotice('تم إنشاء حساب مسبقاً من هذا الجهاز/الشبكة');
          setState(() => _isLoading = false);
          return;
        }
      }

      final pin = await _generateUniquePin();
      final userCred = await FirebaseAuth.instance.signInAnonymously();

      final newUserData = {
        'uid': userCred.user!.uid,
        'email': email,
        'username': username,
        'pin': pin,
        'device_ip': currentIp ?? 'unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'contacts': [],
      };

      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set(newUserData);

      _showNotice('تم إنشاء الحساب! رقم التعريف الخاص بك: $pin', isError: false);
      widget.onLoginSuccess(userCred.user!, newUserData);
    } catch (e) {
      _showNotice('تعذر إكمال التسجيل: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://raw.githubusercontent.com/Ath4U8/shlonkom/main/assets/images/login_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF064E24)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.53),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'البريد الإلكتروني',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                        prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF0F7A3E)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: TextField(
                      controller: _usernameController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'اسم المستخدم',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                        prefixIcon: Icon(Icons.person_outline, color: Color(0xFF0F7A3E)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F7A3E),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Color(0xFF27AE60), width: 1.2),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login, size: 22),
                                SizedBox(width: 8),
                                Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.95),
                        foregroundColor: const Color(0xFF0F7A3E),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: _isLoading ? null : _handleRegister,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_alt_1, size: 22, color: Color(0xFF0F7A3E)),
                          SizedBox(width: 8),
                          Text('تسجيل جديد وتأكيد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.userData, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _pinSearchController = TextEditingController();
  List<dynamic> _contacts = [];

  @override
  void initState() {
    super.initState();
    _contacts = widget.userData['contacts'] ?? [];
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إضافة جهة اتصال', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رقم التعريف الشخصي (PIN):', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _pinSearchController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'مثال: 111111',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _pinSearchController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F7A3E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final pin = _pinSearchController.text.trim();
              if (pin.isEmpty) return;

              if (pin == widget.userData['pin']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا يمكنك إضافة رقم التعريف الخاص بك')),
                );
                return;
              }

              final res = await FirebaseFirestore.instance.collection('users').where('pin', isEqualTo: pin).limit(1).get();
              if (res.docs.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لم يتم العثور على مشترك بهذا الرقم')),
                  );
                }
              } else {
                final friendData = res.docs.first.data();
                final contactEntry = {
                  'pin': friendData['pin'],
                  'username': friendData['username'],
                  'uid': res.docs.first.id,
                };

                await FirebaseFirestore.instance.collection('users').doc(widget.userData['uid']).update({
                  'contacts': FieldValue.arrayUnion([contactEntry])
                });

                setState(() {
                  _contacts.add(contactEntry);
                });

                _pinSearchController.clear();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تمت إضافة ${friendData['username']} بنجاح!')),
                  );
                }
              }
            },
            child: const Text('بحث وإضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myPin = widget.userData['pin'] ?? '------';
    final myName = widget.userData['username'] ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7A3E),
        title: Column(
          children: [
            Text('شلونكم - $myName', style: const TextStyle(fontSize: 18)),
            Text('رقم التعريف الشخصي: $myPin', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ],
      ),
      body: _contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 14),
                  const Text('لا توجد جهات اتصال حتى الآن', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('شارك رقم التعريف الخاص بك ($myPin) مع أصدقائك', style: const TextStyle(color: Color(0xFF0F7A3E))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _contacts.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0F7A3E),
                    child: Text(
                      contact['username'] != null && contact['username'].isNotEmpty
                          ? contact['username'][0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(contact['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('PIN: ${contact['pin']}'),
                  trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF0F7A3E)),
                  onTap: () {},
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F7A3E),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة جهة اتصال'),
        onPressed: _showAddContactDialog,
      ),
    );
  }
}
