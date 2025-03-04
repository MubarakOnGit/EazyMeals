// import 'package:flutter/cupertino.dart';
// import 'package:get/get.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
//
// class LoginController extends GetxController {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final GoogleSignIn _googleSignIn = GoogleSignIn();
//
//   // Observables
//   var isLoading = false.obs;
//   var obscurePassword = true.obs;
//
//   // Text controllers
//   final emailController = TextEditingController();
//   final passwordController = TextEditingController();
//
//   // Sign in with email and password
//   Future<void> signInWithEmailAndPassword() async {
//     if (emailController.text.isEmpty || passwordController.text.isEmpty) {
//       Get.snackbar('Error', 'Please fill in all fields');
//       return;
//     }
//
//     isLoading.value = true;
//
//     try {
//       final UserCredential userCredential = await _auth
//           .signInWithEmailAndPassword(
//             email: emailController.text.trim(),
//             password: passwordController.text.trim(),
//           );
//
//       if (userCredential.user != null) {
//         Get.offNamed('/home'); // Navigate to home screen
//       }
//     } on FirebaseAuthException catch (e) {
//       Get.snackbar('Error', 'Failed to sign in: ${e.message}');
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   // Sign in with Google
//   Future<void> signInWithGoogle() async {
//     isLoading.value = true;
//
//     try {
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//       if (googleUser == null) return;
//
//       final GoogleSignInAuthentication googleAuth =
//           await googleUser.authentication;
//
//       final OAuthCredential credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );
//
//       final UserCredential userCredential = await _auth.signInWithCredential(
//         credential,
//       );
//
//       if (userCredential.user != null) {
//         Get.offNamed('/home'); // Navigate to home screen
//       }
//     } catch (e) {
//       Get.snackbar('Error', 'Failed to sign in with Google: $e');
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   // Toggle password visibility
//   void togglePasswordVisibility() {
//     obscurePassword.value = !obscurePassword.value;
//   }
// }
