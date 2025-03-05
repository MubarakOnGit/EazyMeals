import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategory = 'Veg';
  String _selectedMealType = 'Lunch';
  String _selectedPlan = '1 Week';
  double _price = 0.0;
  bool _isStudentVerified = false;
  bool _isActiveSubscription = false;

  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  final List<String> _mealTypes = ['Lunch', 'Dinner', 'Both'];
  final List<String> _plans = ['1 Week', '3 Weeks', '4 Weeks'];

  @override
  void initState() {
    super.initState();
    _fetchStudentAndSubscriptionStatus();
    _updatePrice();
  }

  Future<void> _fetchStudentAndSubscriptionStatus() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _isStudentVerified = doc['studentDetails']?['isVerified'] ?? false;
          _isActiveSubscription = doc['activeSubscription'] ?? false;
        });
      }
    }
  }

  void _updatePrice() {
    setState(() {
      double basePrice;
      switch (_selectedMealType) {
        case 'Lunch':
          basePrice = 100.0;
          break;
        case 'Dinner':
          basePrice = 120.0;
          break;
        case 'Both':
          basePrice = 200.0;
          break;
        default:
          basePrice = 0.0;
      }

      switch (_selectedPlan) {
        case '1 Week':
          _price = basePrice * 1;
          break;
        case '3 Weeks':
          _price = basePrice * 3 * 0.9;
          break;
        case '4 Weeks':
          _price = basePrice * 4 * 0.85;
          break;
      }

      if (_isStudentVerified) {
        _price *= 0.9;
      }
    });
  }

  void _proceedToWhatsApp() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please log in to subscribe')));
      return;
    }

    final email = user.email ?? 'Unknown Email';

    // Save pending subscription request without dates
    await _firestore.collection('users').doc(user.uid).set({
      'activeSubscription': false,
      'subscriptionPlan': _selectedPlan,
      'category': _selectedCategory,
      'mealType': _selectedMealType,
      'amount': _price,
      'isPaused': false,
    }, SetOptions(merge: true));

    final message =
        'Subscription Request\nEmail: $email\nCategory: $_selectedCategory\nMeal Type: $_selectedMealType\nPlan: $_selectedPlan\nAmount: ₹$_price';
    final whatsappUrl =
        'https://wa.me/+1234567890?text=${Uri.encodeComponent(message)}'; // Replace with admin number

    try {
      await launchUrl(Uri.parse(whatsappUrl));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open WhatsApp: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscribe to a Plan'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Category',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children:
                    _categories.map((category) {
                      return ChoiceChip(
                        label: Text(category),
                        selected: _selectedCategory == category,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                            _updatePrice();
                          });
                        },
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color:
                              _selectedCategory == category
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 20),
              Text(
                'Choose Meal Type',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children:
                    _mealTypes.map((mealType) {
                      return ChoiceChip(
                        label: Text(mealType),
                        selected: _selectedMealType == mealType,
                        onSelected: (selected) {
                          setState(() {
                            _selectedMealType = mealType;
                            _updatePrice();
                          });
                        },
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color:
                              _selectedMealType == mealType
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 20),
              Text(
                'Choose Plan Duration',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children:
                    _plans.map((plan) {
                      return ChoiceChip(
                        label: Text(plan),
                        selected: _selectedPlan == plan,
                        onSelected: (selected) {
                          setState(() {
                            _selectedPlan = plan;
                            _updatePrice();
                          });
                        },
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color:
                              _selectedPlan == plan
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount${_isStudentVerified ? " (10% Student Discount)" : ""}:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹$_price',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed:
                      _isActiveSubscription
                          ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'You already have an active plan',
                                ),
                              ),
                            );
                          }
                          : _proceedToWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isActiveSubscription ? Colors.grey : Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Add & Complete Payment',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
