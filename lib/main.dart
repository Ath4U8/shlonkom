import 'package:flutter/material.dart';

void main() {
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
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  void _login() {
    String email = _emailController.text.trim();
    String username = _usernameController.text.trim();

    if (email.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة البريد واسم المستخدم', textAlign: TextAlign.center),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(username: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // خلفية الصورة الأصلية مباشرة من المستودع
          Positioned.fill(
            child: Image.network(
              'https://raw.githubusercontent.com/Ath4U8/shlonkom/main/assets/images/login_bg.png',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: const Color(0xFF0F7A3E),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(color: const Color(0xFF0F7A3E));
              },
            ),
          ),

          // واجهة الحقول والأزرار التفاعلية
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.48),

                  // حقل البريد الإلكتروني
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'البريد الإلكتروني',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.grey),
                        suffixIcon: Padding(
                          padding: EdgeInsets.only(right: 12.0),
                          child: Icon(Icons.alternate_email, color: Colors.grey),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // حقل اسم المستخدم
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _usernameController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'اسم المستخدم',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                        prefixIcon: Icon(Icons.person_outline, color: Colors.grey),
                        suffixIcon: Padding(
                          padding: EdgeInsets.only(right: 12.0),
                          child: Icon(Icons.alternate_email, color: Colors.grey),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // زر الدخول
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F7A3E),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(35),
                          side: const BorderSide(color: Color(0xFF27AE60), width: 1.5),
                        ),
                      ),
                      onPressed: _login,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'دخول',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // زر تسجيل جديد
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F7A3E),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(35),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('شاشة التسجيل الجديد قيد التطوير')),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add_alt_1, size: 24, color: Color(0xFF0F7A3E)),
                          SizedBox(width: 10),
                          Text(
                            'تسجيل جديد',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// شاشة المحادثات الرئيسية
class HomeScreen extends StatelessWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('أهلاً بك، $username'),
        backgroundColor: const Color(0xFF0F7A3E),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'قائمة محادثات شلونكم',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
