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
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ShlonkomApp());
}

String _generateInternalSecret(String email) => "Shlonkom_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}_2026";
String _generateUniquePin() => (100000 + Random().nextInt(900000)).toString();

class ShlonkomApp extends StatelessWidget {
  const ShlonkomApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'شلونكم', debugShowCheckedModeBanner: false, home: const WelcomeSplashScreen());
  }
}

// ... باقي شاشاتك القديمة نفسها - WelcomeSplashScreen, RegisterWithEmailScreen, VerifyEmailLinkScreen, CreateProfileScreen, ReturningLoginScreen, MainChatHomeScreen
// انسخ شاشاتك القديمة من الملف السابق والصقها هنا
// حتى لا اطول عليك، اهم شي شاشة المحادثة صارت بيها زر اتصال:

// في IndividualChatScreen اضف هذا الزر في الـ AppBar:
// IconButton(icon: Icon(Icons.call, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(myEmail: widget.myEmail, friendEmail: widget.friendEmail, friendName: widget.friendName, chatDocId: _chatDocId))))

class VoiceCallScreen extends StatefulWidget {
  final String myEmail, friendEmail, friendName, chatDocId;
  const VoiceCallScreen({super.key, required this.myEmail, required this.friendEmail, required this.friendName, required this.chatDocId});
  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  bool _inCall = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await [Permission.microphone].request();
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _pc = await createPeerConnection({'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]});
    _pc!.onTrack = (e) => setState(() => _remoteRenderer.srcObject = e.streams[0]);
    _pc!.onIceCandidate = (c) => FirebaseFirestore.instance.collection('calls').doc(widget.chatDocId).collection('candidates').add(c.toMap());
    final stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _localRenderer.srcObject = stream;
    stream.getTracks().forEach((t) => _pc!.addTrack(t, stream));
    
    final callDoc = FirebaseFirestore.instance.collection('calls').doc(widget.chatDocId);
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await callDoc.set({'offer': offer.toMap(), 'caller': widget.myEmail});
    
    callDoc.snapshots().listen((s) async {
      if (s.data()?['answer'] != null && _pc!.getRemoteDescription() == null) {
        await _pc!.setRemoteDescription(RTCSessionDescription(s.data()!['answer']['sdp'], s.data()!['answer']['type']));
        setState(() => _inCall = true);
      }
    });
    
    callDoc.collection('candidates').snapshots().listen((s) {
      for (var c in s.docChanges) {
        if (c.type == DocumentChangeType.added) _pc!.addCandidate(RTCIceCandidate(c.doc['candidate'], c.doc['sdpMid'], c.doc['sdpMLineIndex']));
      }
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose(); _remoteRenderer.dispose(); _pc?.close();
    FirebaseFirestore.instance.collection('calls').doc(widget.chatDocId).delete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFF0F5132), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircleAvatar(radius: 50, child: Text(widget.friendName[0], style: TextStyle(fontSize: 40))),
      SizedBox(height: 20),
      Text(widget.friendName, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(_inCall ? 'متصل - مجاني 100%' : 'جاري الاتصال...', style: TextStyle(color: Colors.white70)),
      SizedBox(height: 60),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FloatingActionButton(backgroundColor: Colors.red, onPressed: () => Navigator.pop(context), child: Icon(Icons.call_end)),
      ])
    ])));
  }
}
