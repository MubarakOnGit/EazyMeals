import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<void>>((ref) {
      return ProfileNotifier();
    });

class ProfileNotifier extends StateNotifier<AsyncValue<void>> {
  ProfileNotifier() : super(const AsyncValue.data(null));

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  String userName = '';
  String phoneNumber = '';
  String activeAddress = 'Add Your Address and Set Active';
  bool _isVerified = false;
  File? _profileImage;

  Future<void> loadUserData() async {
    state = const AsyncValue.loading();
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          userName = data['name'] ?? 'User';
          phoneNumber = data['phoneNumber'] ?? '';
          _isVerified =
              data.containsKey('studentDetails')
                  ? (data['studentDetails']['isVerified'] ?? false)
                  : false;
          activeAddress = data['activeAddress'] ?? '12 Food Street, Metro City';
        }
      }
      await _loadLocalProfileImage();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> _loadLocalProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final file = File(imagePath);
      if (await file.exists()) {
        _profileImage = file;
      }
    } catch (e) {
      print('Error loading local image: $e');
    }
  }

  Future<void> pickProfileImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = '${directory.path}/profile_image.jpg';
        final file = File(pickedFile.path);
        await file.copy(imagePath);
        _profileImage = File(imagePath);
        state = const AsyncValue.data(null); // Trigger rebuild
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateProfile(String name, String phoneNumber) async {
    state = const AsyncValue.loading();
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': name,
          'phoneNumber': phoneNumber,
        });
        userName = name;
        this.phoneNumber = phoneNumber;
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  String get getUserName => userName;
  String get getPhoneNumber => phoneNumber;
  String get getActiveAddress => activeAddress;
  bool get isVerified => _isVerified;
  File? get profileImage => _profileImage;
}
