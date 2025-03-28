import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class ProfileController extends GetxController {
  final Rx<File?> profileImage = Rx<File?>(null);

  Future<void> loadProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      final file = File(imagePath);
      if (await file.exists()) {
        profileImage.value = file;
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  Future<void> updateProfileImage(File newImage) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_image.jpg';
      await newImage.copy(imagePath);
      profileImage.value = File(imagePath);
    } catch (e) {
      print('Error updating profile image: $e');
    }
  }
} 