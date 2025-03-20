import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentVerificationSurvey extends StatefulWidget {
  @override
  _StudentVerificationSurveyState createState() =>
      _StudentVerificationSurveyState();
}

class _StudentVerificationSurveyState extends State<StudentVerificationSurvey> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _admissionYearController =
      TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _admissionYearController.dispose();
    _courseController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  bool _areAllFieldsFilled() {
    return _nameController.text.isNotEmpty &&
        _ageController.text.isNotEmpty &&
        _genderController.text.isNotEmpty &&
        _admissionYearController.text.isNotEmpty &&
        _courseController.text.isNotEmpty &&
        _universityController.text.isNotEmpty;
  }

  Future<void> _submitVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'studentDetails': {
          'name': _nameController.text.trim(),
          'age': _ageController.text.trim(),
          'gender': _genderController.text.trim(),
          'admissionYear': _admissionYearController.text.trim(),
          'course': _courseController.text.trim(),
          'university': _universityController.text.trim(),
          'isVerified': false,
        },
      });

      final message =
          'Hello, my registered email is: ${user.email}. Here is my university ID for verification.';
      final url = Uri.parse(
        'https://wa.me/+917034290370?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        Navigator.pop(context, {
          'name': _nameController.text.trim(),
          'age': _ageController.text.trim(),
          'gender': _genderController.text.trim(),
          'admissionYear': _admissionYearController.text.trim(),
          'course': _courseController.text.trim(),
          'university': _universityController.text.trim(),
          'isVerified': false,
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch WhatsApp')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save details: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade600),
          ),
          filled: true,
          fillColor: Colors.grey[800],
        ),
        style: TextStyle(color: Colors.white),
        keyboardType: keyboardType ?? TextInputType.text,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // Navigate back if possible
            } else {}
          },
        ),
        title: Text(
          'Student Verification',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your details below to verify your student status and unlock a 10% discount.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  SizedBox(height: 24),
                  _buildTextField(_nameController, 'Full Name'),
                  _buildTextField(
                    _ageController,
                    'Age',
                    keyboardType: TextInputType.number,
                  ),
                  _buildTextField(_genderController, 'Gender'),
                  _buildTextField(
                    _admissionYearController,
                    'Admission Year',
                    keyboardType: TextInputType.number,
                  ),
                  _buildTextField(_courseController, 'Course'),
                  _buildTextField(_universityController, 'University'),
                  SizedBox(height: 32),
                  Center(
                    child:
                        _isLoading
                            ? CircularProgressIndicator(
                              color: Colors.blue.shade900,
                            )
                            : ElevatedButton(
                              onPressed:
                                  _areAllFieldsFilled()
                                      ? _submitVerification
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade900,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Verify with University ID',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
