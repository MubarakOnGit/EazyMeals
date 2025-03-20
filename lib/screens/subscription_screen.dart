import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();
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
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final userData = doc.data() as Map<String, dynamic>? ?? {};
          setState(() {
            _isStudentVerified =
                userData.containsKey('studentDetails')
                    ? (userData['studentDetails']['isVerified'] ?? false)
                    : false;
            _isActiveSubscription = userData['activeSubscription'] ?? false;
            _updatePrice();
            _isLoading = false;
          });
        } else {
          setState(() {
            _updatePrice();
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
        setState(() {
          _updatePrice();
          _isLoading = false;
        });
      }
    } else {
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

    if (_isStudentVerified) _price *= 0.9;
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
    final orderId = _uuid.v4();

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pendingOrders')
          .doc(orderId)
          .set({
            'orderId': orderId,
            'activeSubscription': false,
            'subscriptionPlan': _selectedPlan,
            'category': _selectedCategory,
            'mealType': _selectedMealType,
            'amount': _price,
            'isPaused': false,
            'createdAt': Timestamp.now(),
            'status': 'Pending Payment',
          });

      await _firestore.collection('users').doc(user.uid).set({
        'pendingOrderId': orderId,
      }, SetOptions(merge: true));

      final message =
          'Subscription Request\nOrder ID: $orderId\nEmail: $email\nCategory: $_selectedCategory\nMeal Type: $_selectedMealType\nPlan: $_selectedPlan\nAmount: \$$_price';
      final whatsappUrl =
          'https://wa.me/+917034290370?text=${Uri.encodeComponent(message)}';

      await launchUrl(Uri.parse(whatsappUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order request sent! Order ID: $orderId')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error processing order: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to process order: $e')));
    }
  }

  String _getDescription(String type, String value) {
    switch (type) {
      case 'category':
        switch (value) {
          case 'Veg':
            return 'Pure vegetarian cuisine for plant-based lovers.';
          case 'South Indian':
            return 'Authentic dosa, idli, and sambar flavors.';
          case 'North Indian':
            return 'Rich curries, naan, and tandoori delights.';
          default:
            return '';
        }
      case 'mealType':
        switch (value) {
          case 'Lunch':
            return 'Daily lunch delivery.';
          case 'Dinner':
            return 'Daily dinner delivery.';
          case 'Both':
            return 'Lunch and dinner every day.';
          default:
            return '';
        }
      case 'plan':
        switch (value) {
          case '1 Week':
            return '7 days of meals.';
          case '3 Weeks':
            return '21 days with a 10% discount.';
          case '4 Weeks':
            return '28 days with a 15% discount.';
          default:
            return '';
        }
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: Center(
          child: Text(
            'Please log in to subscribe',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue.shade900),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context); // Navigate back if possible
            } else {}
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          'Choose Your Plan',
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: 'Category',
                    items: _categories,
                    selected: _selectedCategory,
                    onSelected: (value) {
                      setState(() {
                        _selectedCategory = value;
                        _updatePrice();
                      });
                    },
                    description: _getDescription('category', _selectedCategory),
                  ),
                  SizedBox(height: 24),
                  _buildSection(
                    title: 'Meal Type',
                    items: _mealTypes,
                    selected: _selectedMealType,
                    onSelected: (value) {
                      setState(() {
                        _selectedMealType = value;
                        _updatePrice();
                      });
                    },
                    description: _getDescription('mealType', _selectedMealType),
                  ),
                  SizedBox(height: 24),
                  _buildSection(
                    title: 'Plan Duration',
                    items: _plans,
                    selected: _selectedPlan,
                    onSelected: (value) {
                      setState(() {
                        _selectedPlan = value;
                        _updatePrice();
                      });
                    },
                    description: _getDescription('plan', _selectedPlan),
                  ),
                  SizedBox(height: 32),
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.grey[850],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total${_isStudentVerified ? " (10% Off)" : ""}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '\$${_price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  Center(
                    child: ElevatedButton(
                      onPressed:
                          _isActiveSubscription ? null : _proceedToWhatsApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isActiveSubscription
                                ? Colors.grey[700]
                                : Colors.blue.shade900,
                        padding: EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        _isActiveSubscription
                            ? 'You Already Subscribed'
                            : 'Proceed to Pay',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> items,
    required String selected,
    required Function(String) onSelected,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getIconForSection(title),
              color: Colors.white, // Automatically white
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children:
              items.map((item) {
                return ChoiceChip(
                  label: Text(item),
                  selected: selected == item,
                  onSelected: (isSelected) => onSelected(item),
                  selectedColor: Colors.blue.shade600,
                  backgroundColor: Colors.grey[800],
                  labelStyle: TextStyle(
                    color: selected == item ? Colors.white : Colors.grey[300],
                    fontWeight: FontWeight.w600,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
        ),
        SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
        ),
      ],
    );
  }

  IconData _getIconForSection(String title) {
    switch (title) {
      case 'Category':
        return Icons.fastfood;
      case 'Meal Type':
        return Icons.restaurant;
      case 'Plan Duration':
        return Icons.calendar_today;
      default:
        return Icons.info;
    }
  }
}
