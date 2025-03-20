import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  final List<String> _mealTypes = ['Lunch', 'Dinner', 'Both'];
  final List<String> _plans = ['1 Week', '3 Weeks', '4 Weeks'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _fetchInitialData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Craft Your Meal Plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        title: 'Cuisine Style',
                        items: _categories,
                        selected: _selectedCategory,
                        onSelected: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _updatePrice();
                          });
                        },
                        description: _getDescription(
                          'category',
                          _selectedCategory,
                        ),
                      ),
                      SizedBox(height: 30),
                      _buildSection(
                        title: 'Meal Preference',
                        items: _mealTypes,
                        selected: _selectedMealType,
                        onSelected: (value) {
                          setState(() {
                            _selectedMealType = value;
                            _updatePrice();
                          });
                        },
                        description: _getDescription(
                          'mealType',
                          _selectedMealType,
                        ),
                      ),
                      SizedBox(height: 30),
                      _buildSection(
                        title: 'Subscription Length',
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
                      SizedBox(height: 40),
                      _buildPriceCard(),
                      SizedBox(height: 40),
                      _buildActionButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850]!.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
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
              Icon(
                _getIconForSection(title),
                color: Colors.blue.shade400,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                items.map((item) {
                  bool isSelected = selected == item;
                  return GestureDetector(
                    onTap: () => onSelected(item),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient:
                            isSelected
                                ? LinearGradient(
                                  colors: [
                                    Colors.blue.shade700,
                                    Colors.blue.shade400,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                                : null,
                        color: isSelected ? null : Colors.grey[800],
                        borderRadius: BorderRadius.circular(15),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                                : null,
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Total',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_isStudentVerified)
                Text(
                  'Student Discount Applied (10%)',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
            ],
          ),
          Text(
            '\$${_price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Center(
      child: GestureDetector(
        onTap: _isActiveSubscription ? null : _proceedToWhatsApp,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: 60, vertical: 18),
          decoration: BoxDecoration(
            gradient:
                _isActiveSubscription
                    ? LinearGradient(
                      colors: [Colors.grey[700]!, Colors.grey[600]!],
                    )
                    : LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            _isActiveSubscription ? 'Active Plan' : 'Confirm & Pay',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForSection(String title) {
    switch (title) {
      case 'Cuisine Style':
        return Icons.fastfood;
      case 'Meal Preference':
        return Icons.restaurant_menu;
      case 'Subscription Length':
        return Icons.calendar_month;
      default:
        return Icons.info;
    }
  }
}
