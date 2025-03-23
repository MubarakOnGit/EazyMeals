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
    '3 Weeks': 2.7, // 3 * 0.9 discount
    '4 Weeks': 3.4, // 4 * 0.85 discount
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
    if (_isStudentVerified) _price *= 0.9;
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
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_auth.currentUser == null) {
      return Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Meal Subscription',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildDropdownSection(
                      'Cuisine',
                      ['Veg', 'South Indian', 'North Indian'],
                      _selectedCategory,
                      (val) => _selectedCategory = val,
                    ),
                    SizedBox(height: 24),
                    _buildDropdownSection(
                      'Meal Type',
                      ['Lunch', 'Dinner', 'Both'],
                      _selectedMealType,
                      (val) => _selectedMealType = val,
                    ),
                    SizedBox(height: 24),
                    _buildDropdownSection(
                      'Plan',
                      ['1 Week', '3 Weeks', '4 Weeks'],
                      _selectedPlan,
                      (val) => _selectedPlan = val,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildPriceSection(),
            SizedBox(height: 16),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSection(
    String title,
    List<String> items,
    String value,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: SizedBox(),
            items:
                items
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
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
    );
  }

  Widget _buildPriceSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total${_isStudentVerified ? ' (10% off)' : ''}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            '\$${_price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isActiveSubscription ? null : _proceedToWhatsApp,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          backgroundColor: _isActiveSubscription ? Colors.grey : Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _isActiveSubscription ? 'Active Subscription' : 'Confirm Order',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}
