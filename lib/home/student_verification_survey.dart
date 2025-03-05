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

  // Check if all fields are filled
  bool _areAllFieldsFilled() {
    return _nameController.text.isNotEmpty &&
        _ageController.text.isNotEmpty &&
        _genderController.text.isNotEmpty &&
        _admissionYearController.text.isNotEmpty &&
        _courseController.text.isNotEmpty &&
        _universityController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Verification')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Full Name'),
              onChanged: (_) => setState(() {}), // Rebuild UI on text change
            ),
            TextField(
              controller: _ageController,
              decoration: InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}), // Rebuild UI on text change
            ),
            TextField(
              controller: _genderController,
              decoration: InputDecoration(labelText: 'Gender'),
              onChanged: (_) => setState(() {}), // Rebuild UI on text change
            ),
            TextField(
              controller: _admissionYearController,
              decoration: InputDecoration(labelText: 'Admission Year'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}), // Rebuild UI on text change
            ),
            TextField(
              controller: _courseController,
              decoration: InputDecoration(labelText: 'Course'),
              onChanged: (_) => setState(() {}), // Rebuild UI on text change
            ),
            TextField(
              controller: _universityController,
              decoration: InputDecoration(labelText: 'University'),
              onChanged: (_) => setState(() {}), // Rebuild UI on text change
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                  child: Text('Verify with University ID'),
                  onPressed:
                      _areAllFieldsFilled()
                          ? () async {
                            final user = _auth.currentUser;
                            if (user != null) {
                              setState(() => _isLoading = true);

                              // Save survey details to Firestore
                              try {
                                await _firestore
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({
                                      'studentDetails': {
                                        'name': _nameController.text,
                                        'age': _ageController.text,
                                        'gender': _genderController.text,
                                        'admissionYear':
                                            _admissionYearController.text,
                                        'course': _courseController.text,
                                        'university':
                                            _universityController.text,
                                        'isVerified':
                                            false, // Initially set to false
                                      },
                                    });

                                // Redirect to WhatsApp
                                final message =
                                    'Hello, my registered email is: ${user.email}. Here is my university ID for verification.';
                                final url = Uri.parse(
                                  'https://wa.me/+917034290370?text=${Uri.encodeComponent(message)}',
                                );

                                if (await canLaunchUrl(url)) {
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not launch WhatsApp.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save details: $e'),
                                  ),
                                );
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            }
                          }
                          : null, // Disable button if fields are not filled
                ),
          ],
        ),
      ),
    );
  }
}
