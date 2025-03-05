// lib/manager/customers_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomersScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: Text(
            'Customers',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              final clients = snapshot.data!.docs;
              return ListView.builder(
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  final data = client.data() as Map<String, dynamic>;
                  final isActive = data['activeSubscription'] ?? false;
                  final isPaused = data['isPaused'] ?? false;
                  final endDate =
                      data['subscriptionEndDate'] != null
                          ? (data['subscriptionEndDate'] as Timestamp).toDate()
                          : null;
                  final remainingTime =
                      endDate != null
                          ? endDate.difference(DateTime.now())
                          : Duration.zero;
                  final remainingDays = remainingTime.inDays;

                  return Card(
                    child: ListTile(
                      title: Text(data['name'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email: ${data['email'] ?? 'N/A'}'),
                          Text('Address: ${data['activeAddress'] ?? 'N/A'}'),
                          Text('Paused: ${isPaused ? 'Yes' : 'No'}'),
                          Text(
                            'Timer: ${remainingDays > 0 ? '$remainingDays days' : 'Expired or Not Active'}',
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed:
                            () =>
                                isActive
                                    ? _deactivateSubscription(
                                      context,
                                      client.id,
                                    )
                                    : _activateSubscription(context, client.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive ? Colors.red : Colors.green,
                        ),
                        child: Text(isActive ? 'Deactivate' : 'Activate'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _activateSubscription(BuildContext context, String userId) {
    String? selectedCategory;
    String? selectedPlan;
    String? selectedMealType;
    final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
    final List<String> _plans = ['1 Week', '3 Weeks', '4 Weeks'];
    final List<String> _mealTypes = ['Lunch', 'Dinner', 'Both'];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Activate Subscription'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Category'),
                  items:
                      _categories
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                  onChanged: (value) => selectedCategory = value,
                ),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Plan'),
                  items:
                      _plans
                          .map(
                            (plan) => DropdownMenuItem(
                              value: plan,
                              child: Text(plan),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => selectedPlan = value,
                ),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Meal Type'),
                  items:
                      _mealTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => selectedMealType = value,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCategory != null &&
                      selectedPlan != null &&
                      selectedMealType != null) {
                    final now = DateTime.now();
                    final days =
                        selectedPlan == '1 Week'
                            ? 7
                            : selectedPlan == '3 Weeks'
                            ? 21
                            : 28;
                    final endDate = now.add(Duration(days: days));

                    // Update user subscription
                    await _firestore.collection('users').doc(userId).update({
                      'activeSubscription': true,
                      'subscriptionPlan': selectedPlan,
                      'category': selectedCategory,
                      'mealType': selectedMealType,
                      'subscriptionStartDate': Timestamp.fromDate(now),
                      'subscriptionEndDate': Timestamp.fromDate(endDate),
                      'isPaused': false,
                      'pausedAt': FieldValue.delete(),
                    });

                    // Generate daily orders only for non-paused days
                    List<String> meals =
                        selectedMealType == 'Both'
                            ? ['Lunch', 'Dinner']
                            : [selectedMealType!];
                    for (int i = 0; i < days; i++) {
                      DateTime orderDate = now.add(Duration(days: i));
                      for (String meal in meals) {
                        await _firestore.collection('orders').add({
                          'userId': userId,
                          'mealType': meal,
                          'date': Timestamp.fromDate(orderDate),
                          'status': 'Pending Delivery',
                          'category': selectedCategory,
                        });
                      }
                    }

                    print(
                      'Subscription activated and orders generated for $userId',
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please select all fields')),
                    );
                  }
                },
                child: Text('Activate'),
              ),
            ],
          ),
    );
  }

  void _deactivateSubscription(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Deactivation'),
            content: Text(
              'Are you sure you want to deactivate this subscription?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                        'activeSubscription': false,
                        'subscriptionPlan': FieldValue.delete(),
                        'subscriptionStartDate': FieldValue.delete(),
                        'subscriptionEndDate': FieldValue.delete(),
                        'isPaused': FieldValue.delete(),
                        'pausedAt': FieldValue.delete(),
                      });
                  Navigator.pop(context);
                },
                child: Text('Deactivate'),
              ),
            ],
          ),
    );
  }
}
