import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  String _selectedCategory = 'Veg';
  String _selectedMealType = 'Lunch';
  String _selectedPlan = '1 Week';
  double _price = 0.0;
  bool _isStudentVerified = false;
  bool _isActiveSubscription = false;
  bool _isLoading = true;

  // Updated price structure with exact prices
  static const Map<String, Map<String, Map<String, double>>> _mealPrices = {
    'Veg': {
      '1 Week': {
        'Lunch': 21.5,
        'Dinner': 21.5,
        'Both': 35.0,
      },
      '2 Weeks': {
        'Lunch': 35.0,
        'Dinner': 35.0,
        'Both': 60.0,
      },
      '4 Weeks': {
        'Lunch': 60.0,
        'Dinner': 60.0,
        'Both': 110.0,
      },
    },
    'South Indian': {
      '1 Week': {
        'Lunch': 22.5,
        'Dinner': 22.5,
        'Both': 37.5,
      },
      '2 Weeks': {
        'Lunch': 37.5,
        'Dinner': 37.5,
        'Both': 65.0,
      },
      '4 Weeks': {
        'Lunch': 65.0,
        'Dinner': 65.0,
        'Both': 120.0,
      },
    },
    'North Indian': {
      '1 Week': {
        'Lunch': 22.5,
        'Dinner': 22.5,
        'Both': 37.5,
      },
      '2 Weeks': {
        'Lunch': 37.5,
        'Dinner': 37.5,
        'Both': 65.0,
      },
      '4 Weeks': {
        'Lunch': 65.0,
        'Dinner': 65.0,
        'Both': 120.0,
      },
    },
  };

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (mounted) {
        setState(() {
          _isStudentVerified =
              data?['studentDetails']?['isVerified'] as bool? ?? false;
          _isActiveSubscription = data?['activeSubscription'] as bool? ?? false;
          _updatePrice();
          _isLoading = false;
        });
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updatePrice() {
    // Get price based on category, plan, and meal type
    final categoryPrices = _mealPrices[_selectedCategory];
    if (categoryPrices == null) {
      _price = 0.0;
      return;
    }

    final planPrices = categoryPrices[_selectedPlan];
    if (planPrices == null) {
      _price = 0.0;
      return;
    }

    final mealType = _selectedMealType == 'Both' ? 'Both' : 'Lunch';
    final price = planPrices[mealType];
    if (price == null) {
      _price = 0.0;
      return;
    }

    _price = price;

    // Apply only student discount (10%)
    if (_isStudentVerified) _price *= 0.9;
  }

  Future<void> _proceedToWhatsApp() async {
    if (_isActiveSubscription || _auth.currentUser == null) return;

    final user = _auth.currentUser!;
    final orderId = _uuid.v4();

    final message =
        'Subscription Request\n'
            'Order ID: $orderId\n'
            'Email: ${user.email}\n'
            'Category: $_selectedCategory\n'
            'Meal Type: $_selectedMealType\n'
            'Plan: $_selectedPlan\n'
            'Amount: \$${_price.toStringAsFixed(2)}' +
        (_selectedMealType == 'Both'
            ? '\nNote: Includes separate Lunch and Dinner orders daily'
            : '');

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
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.blue[900]),
              )
              : _auth.currentUser == null
              ? _buildEmptyState('Please log in to subscribe')
              : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customize Your Plan',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildDropdownCard(
                            'Cuisine',
                            'Choose your preferred food style',
                            const ['Veg', 'South Indian', 'North Indian'],
                            _selectedCategory,
                            (val) => _selectedCategory = val,
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownCard(
                            'Meal Type',
                            'Select your daily meals',
                            const ['Lunch', 'Dinner', 'Both'],
                            _selectedMealType,
                            (val) => _selectedMealType = val,
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownCard(
                            'Plan Duration',
                            'Pick your subscription length',
                            const ['1 Week', '2 Weeks', '4 Weeks'],
                            _selectedPlan,
                            (val) => _selectedPlan = val,
                          ),
                          const SizedBox(height: 32),
                          _buildPriceCard(),
                          const SizedBox(height: 20),
                          _buildConfirmButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[900]!, Colors.blue[700]!],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Meal Subscription',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Craft your perfect meal plan',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withAlpha(179),
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

  Widget _buildDropdownCard(
    String title,
    String description,
    List<String> items,
    String value,
    Function(String) onChanged,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[900]!.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForTitle(title),
                  color: Colors.blue[900],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: Colors.blue[900]),
              items:
                  items
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item,
                            style: TextStyle(color: Colors.blue[900]),
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  (val) => setState(() {
                    onChanged(val!);
                    _updatePrice();
                  }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isActiveSubscription
                    ? 'Subscription Active'
                    : 'Confirm to proceed',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(179),
                ),
              ),
            ],
          ),
          Text(
            '\$${_price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: ElevatedButton(
          onPressed: _isActiveSubscription ? null : _proceedToWhatsApp,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor:
                _isActiveSubscription ? Colors.grey[600] : Colors.blue[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            shadowColor: Colors.blue.withAlpha(77),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isActiveSubscription ? Icons.lock : Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isActiveSubscription ? 'Active Subscription' : 'Confirm Order',
                style: const TextStyle(
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

  IconData _getIconForTitle(String title) => switch (title) {
    'Cuisine' => Icons.restaurant,
    'Meal Type' => Icons.fastfood,
    'Plan Duration' => Icons.calendar_today,
    _ => Icons.info,
  };

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
