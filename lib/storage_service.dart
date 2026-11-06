import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
final _storage = FirebaseStorage.instance;
final _auth = FirebaseAuth.instance;

Future<String?> pickAndUploadChatImage() async {
final picker = ImagePicker();
final XFile? image = await picker.pickImage(
source: ImageSource.gallery,
imageQuality: 70, // تقليل الحجم
);

if (image == null) return null;

File file = File(image.path);
String userId = _auth.currentUser!.uid;
String fileName = DateTime.now().millisecondsSinceEpoch.toString();

// يرفع في المسار: chat_images/USER_ID/fileName.jpg
Reference ref = _storage.ref().child('chat_images/$userId/$fileName.jpg');

UploadTask task = ref.putFile(file);
TaskSnapshot snap = await task;

// يرجع رابط الصورة
String downloadUrl = await snap.ref.getDownloadURL();
return downloadUrl;
}
}
