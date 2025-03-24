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
        'https://wa.me/+995500900095?text=${Uri.encodeComponent(message)}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          // Background gradient for subtle depth
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade900.withOpacity(0.05),
                  Colors.grey.shade100,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionCard(),
                      SizedBox(height: 24),
                      _buildTextFieldCard(
                        _nameController,
                        'Full Name',
                        'Enter your full name as per university records',
                        Icons.person,
                      ),
                      SizedBox(height: 16),
                      _buildTextFieldCard(
                        _ageController,
                        'Age',
                        'Your current age',
                        Icons.cake,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16),
                      _buildTextFieldCard(
                        _genderController,
                        'Gender',
                        'Specify your gender',
                        Icons.people,
                      ),
                      SizedBox(height: 16),
                      _buildTextFieldCard(
                        _admissionYearController,
                        'Admission Year',
                        'Year you joined the university',
                        Icons.calendar_today,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16),
                      _buildTextFieldCard(
                        _courseController,
                        'Course',
                        'Your field of study',
                        Icons.book,
                      ),
                      SizedBox(height: 16),
                      _buildTextFieldCard(
                        _universityController,
                        'University',
                        'Name of your university',
                        Icons.school,
                      ),
                      SizedBox(height: 32),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // SliverAppBar with gradient and modern styling
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Student Verification',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Unlock your 10% discount',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Instruction card with description
  Widget _buildInstructionCard() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade900.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info, color: Colors.blue.shade900, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enter your details below to verify your student status and unlock a 10% discount. You’ll need to send your university ID via WhatsApp.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // Text field card with icon and description
  Widget _buildTextFieldCard(
    TextEditingController controller,
    String label,
    String description,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.blue.shade900, size: 20),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
            ),
            style: TextStyle(color: Colors.blue.shade900),
            keyboardType: keyboardType ?? TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // Submit button with animation and modern styling
  Widget _buildSubmitButton() {
    return Center(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        child:
            _isLoading
                ? CircularProgressIndicator(color: Colors.blue.shade900)
                : ElevatedButton(
                  onPressed: _areAllFieldsFilled() ? _submitVerification : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    backgroundColor: Colors.blue.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: Colors.blue.withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Verify with University ID',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
