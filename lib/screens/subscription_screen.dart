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

  final Map<String, double> _mealPrices = {
    'Lunch': 100.0,
    'Dinner': 120.0,
    'Both': 200.0,
  };

  final Map<String, double> _planMultipliers = {
    '1 Week': 1.0,
    '3 Weeks': 2.7, // 10% discount for 3 weeks
    '4 Weeks': 3.4, // 15% discount for 4 weeks
  };

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _isStudentVerified =
            (doc.data()
                as Map<String, dynamic>?)?['studentDetails']?['isVerified'] ??
            false;
        _isActiveSubscription = doc.get('activeSubscription') ?? false;
        _updatePrice();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _updatePrice() {
    _price = _mealPrices[_selectedMealType]! * _planMultipliers[_selectedPlan]!;
    if (_isStudentVerified) _price *= 0.9; // Apply 10% student discount
  }

  Future<void> _proceedToWhatsApp() async {
    if (_isActiveSubscription || _auth.currentUser == null) return;

    final user = _auth.currentUser!;
    final orderId = _uuid.v4();
    final message =
        'Subscription Request\nOrder ID: $orderId\nEmail: ${user.email}\n'
        'Category: $_selectedCategory\nMeal Type: $_selectedMealType\nPlan: $_selectedPlan\n'
        'Amount: \$${_price.toStringAsFixed(2)}';

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pendingOrders')
        .doc(orderId)
        .set({
          'orderId': orderId,
          'subscriptionPlan': _selectedPlan,
          'category': _selectedCategory,
          'mealType': _selectedMealType,
          'amount': _price,
          'createdAt': Timestamp.now(),
          'status': 'Pending Payment',
        });

    final whatsappUrl =
        'https://wa.me/+995500900095?text=${Uri.encodeComponent(message)}';
    await launchUrl(Uri.parse(whatsappUrl));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.blue.shade900),
              )
              : _auth.currentUser == null
              ? _buildEmptyState('Please log in to subscribe')
              : CustomScrollView(
                physics: BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customize Your Plan',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          SizedBox(height: 24),
                          _buildDropdownCard(
                            'Cuisine',
                            'Choose your preferred food style',
                            ['Veg', 'South Indian', 'North Indian'],
                            _selectedCategory,
                            (val) => _selectedCategory = val,
                          ),
                          SizedBox(height: 16),
                          _buildDropdownCard(
                            'Meal Type',
                            'Select your daily meals',
                            ['Lunch', 'Dinner', 'Both'],
                            _selectedMealType,
                            (val) => _selectedMealType = val,
                          ),
                          SizedBox(height: 16),
                          _buildDropdownCard(
                            'Plan Duration',
                            'Pick your subscription length',
                            ['1 Week', '3 Weeks', '4 Weeks'],
                            _selectedPlan,
                            (val) => _selectedPlan = val,
                          ),
                          SizedBox(height: 32),
                          _buildPriceCard(),
                          SizedBox(height: 20),
                          _buildConfirmButton(),
                        ],
                      ),
                    ),
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
                  'Meal Subscription',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Craft your perfect meal plan',
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

  // Dropdown card with description and modern design
  Widget _buildDropdownCard(
    String title,
    String description,
    List<String> items,
    String value,
    Function(String) onChanged,
  ) {
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
                child: Icon(
                  _getIconForTitle(title),
                  color: Colors.blue.shade900,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade900),
              items:
                  items
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item,
                            style: TextStyle(color: Colors.blue.shade900),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (val) {
                setState(() {
                  onChanged(val!);
                  _updatePrice();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // Price card with gradient and discount indication
  Widget _buildPriceCard() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
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
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
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
                'Total${_isStudentVerified ? ' (10% Student Discount)' : ''}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                _isActiveSubscription
                    ? 'Subscription Active'
                    : 'Confirm to proceed',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          Text(
            '\$${_price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Confirm button with modern styling and animation
  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        child: ElevatedButton(
          onPressed: _isActiveSubscription ? null : _proceedToWhatsApp,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 18),
            backgroundColor:
                _isActiveSubscription
                    ? Colors.grey.shade600
                    : Colors.blue.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            shadowColor: Colors.blue.withOpacity(0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isActiveSubscription ? Icons.lock : Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                _isActiveSubscription ? 'Active Subscription' : 'Confirm Order',
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

  // Helper to assign icons based on title
  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Cuisine':
        return Icons.restaurant;
      case 'Meal Type':
        return Icons.fastfood;
      case 'Plan Duration':
        return Icons.calendar_today;
      default:
        return Icons.info;
    }
  }

  // Empty state widget for unauthenticated users
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 60, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
