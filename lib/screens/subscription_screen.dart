import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart'; // For generating unique order IDs

class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid(); // For generating unique order IDs
  String _selectedCategory = 'Veg';
  String _selectedMealType = 'Lunch';
  String _selectedPlan = '1 Week';
  double _price = 0.0;
  bool _isStudentVerified = false;
  bool _isActiveSubscription = false;
  bool _isLoading = true;

  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  final List<String> _mealTypes = ['Lunch', 'Dinner', 'Both'];
  final List<String> _plans = ['1 Week', '3 Weeks', '4 Weeks'];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        print('Fetching data for user: ${user.uid}');
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get(GetOptions(source: Source.serverAndCache));

        if (doc.exists) {
          final userData = doc.data() as Map<String, dynamic>? ?? {};
          print('Raw Firestore data: $userData');

          _isStudentVerified =
              userData['studentDetails']?['isVerified'] ?? false;
          _isActiveSubscription = userData['activeSubscription'] ?? false;

          print('isStudentVerified: $_isStudentVerified');
          print('isActiveSubscription: $_isActiveSubscription');

          setState(() {
            _updatePrice();
            _isLoading = false;
          });
        } else {
          print('No document exists for user: ${user.uid}');
          setState(() {
            _isStudentVerified = false;
            _isActiveSubscription = false;
            _updatePrice();
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load user data: $e')));
        setState(() {
          _isStudentVerified = false;
          _isActiveSubscription = false;
          _updatePrice();
          _isLoading = false;
        });
      }
    } else {
      print('No user logged in');
      setState(() => _isLoading = false);
    }
  }

  void _updatePrice() {
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

    print('Base price before discount: $_price');
    if (_isStudentVerified) {
      _price *= 0.9; // Apply 10% student discount
      print('Applied 10% discount, new price: $_price');
    } else {
      print('No student discount applied');
    }
  }

  Future<void> _proceedToWhatsApp() async {
    if (_isActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You already have an active plan')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please log in to subscribe')));
      return;
    }

    final email = user.email ?? 'Unknown Email';
    final orderId = _uuid.v4(); // Generate unique order ID

    // Store pending order in Firestore
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pendingOrders')
          .doc(orderId)
          .set({
            'orderId': orderId,
            'activeSubscription': false, // Still false until admin activates
            'subscriptionPlan': _selectedPlan,
            'category': _selectedCategory,
            'mealType': _selectedMealType,
            'amount': _price,
            'isPaused': false,
            'createdAt': Timestamp.now(),
            'status': 'Pending Payment',
          });

      // Update main user document with subscription intent (not active yet)
      await _firestore.collection('users').doc(user.uid).set({
        'pendingOrderId': orderId, // Track the latest pending order
      }, SetOptions(merge: true));

      final message =
          'Subscription Request\nOrder ID: $orderId\nEmail: $email\nCategory: $_selectedCategory\nMeal Type: $_selectedMealType\nPlan: $_selectedPlan\nAmount: \$$_price';
      final whatsappUrl =
          'https://wa.me/+917034290370?text=${Uri.encodeComponent(message)}';

      await launchUrl(Uri.parse(whatsappUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order request sent via WhatsApp! Order ID: $orderId'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error processing order: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to process order: $e')));
    }
  }

  String _getCategoryDescription(String category) {
    switch (category) {
      case 'Veg':
        return 'This is pure vegetarian cuisine, perfect for those who prefer plant-based meals.';
      case 'South Indian':
        return 'Authentic South Indian flavors, featuring dishes like dosa, idli, and sambar.';
      case 'North Indian':
        return 'Rich and spicy North Indian cuisine, including curries, naan, and tandoori delights.';
      default:
        return '';
    }
  }

  String _getMealTypeDescription(String mealType) {
    switch (mealType) {
      case 'Lunch':
        return 'If you select this option, you only get lunch as a one-time meal each day.';
      case 'Dinner':
        return 'If you select this option, you only get dinner as a one-time meal each day.';
      case 'Both':
        return 'Enjoy both lunch and dinner daily with this option.';
      default:
        return '';
    }
  }

  String _getPlanDescription(String plan) {
    switch (plan) {
      case '1 Week':
        return 'You are subscribing for one week, with meals delivered for 7 days.';
      case '3 Weeks':
        return 'You are subscribing for three weeks, with meals delivered for 21 days.';
      case '4 Weeks':
        return 'You are subscribing for four weeks, with meals delivered for 28 days.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Subscribe to a Plan',
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Center(child: Text('Please log in to subscribe')),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Subscribe to a Plan',
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Subscribe to a Plan',
          style: TextStyle(
            color: Colors.blue.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
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
                        selectedColor: Colors.blue.shade900,
                        backgroundColor: Colors.blue.shade100,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color:
                              _selectedCategory == category
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 8),
              Text(
                _getCategoryDescription(_selectedCategory),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              SizedBox(height: 20),
              Text(
                'Choose Meal Type',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
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
                        selectedColor: Colors.blue.shade900,
                        backgroundColor: Colors.blue.shade100,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color:
                              _selectedMealType == mealType
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 8),
              Text(
                _getMealTypeDescription(_selectedMealType),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              SizedBox(height: 20),
              Text(
                'Choose Plan Duration',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
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
                        selectedColor: Colors.blue.shade900,
                        backgroundColor: Colors.blue.shade100,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color:
                              _selectedPlan == plan
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 8),
              Text(
                _getPlanDescription(_selectedPlan),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
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
                        'Total ${_isStudentVerified ? " (10% Student Discount)" : ""}:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$$_price',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: _isActiveSubscription ? null : _proceedToWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isActiveSubscription
                            ? Colors.grey
                            : Colors.blue.shade900,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isActiveSubscription
                        ? 'You Already Have a Plan'
                        : 'Add & Complete Payment',
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
