import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerScreen extends StatefulWidget {
  @override
  _ManagerScreenState createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Form fields for menu
  int _weekNumber = 1;
  String _category = 'Veg';
  final List<Map<String, String>> _items = [];
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  String _mealType = 'Lunch';
  String _day = 'Monday';

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  final List<String> _plans = ['1 Week', '3 Weeks', '4 Weeks'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manager Dashboard')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Clients
            Text(
              'Active Clients',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                }
                final clients = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    final data = client.data() as Map<String, dynamic>;
                    final isActive = data['activeSubscription'] ?? false;
                    final isPaused = data['isPaused'] ?? false;
                    final endDate =
                        data['subscriptionEndDate'] != null
                            ? (data['subscriptionEndDate'] as Timestamp)
                                .toDate()
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
                                      ? _deactivateSubscription(client.id)
                                      : _activateSubscription(client.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isActive ? Colors.red : Colors.green,
                          ),
                          child: Text(isActive ? 'Deactivate' : 'Activate'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            SizedBox(height: 20),

            // Add Weekly Menu
            Text(
              'Add Weekly Menu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Week Number'),
                    keyboardType: TextInputType.number,
                    onSaved: (value) {
                      _weekNumber = int.parse(value!);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the week number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(labelText: 'Category'),
                    items:
                        _categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() => _category = value!);
                    },
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _itemController,
                    decoration: InputDecoration(labelText: 'Item Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the item name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(labelText: 'Description'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the description';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: InputDecoration(
                      labelText: 'Image URL (optional)',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _mealType,
                    decoration: InputDecoration(labelText: 'Meal Type'),
                    items:
                        ['Lunch', 'Dinner']
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() => _mealType = value!);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: _day,
                    decoration: InputDecoration(labelText: 'Day'),
                    items:
                        _daysOfWeek
                            .map(
                              (day) => DropdownMenuItem(
                                value: day,
                                child: Text(day),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() => _day = value!);
                    },
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(onPressed: _addItem, child: Text('Add Item')),
                  SizedBox(height: 20),
                  Text(
                    'Added Items',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  _items.isEmpty
                      ? Text('No items added yet')
                      : Column(
                        children:
                            _items.map((item) {
                              return ListTile(
                                title: Text(item['item']!),
                                subtitle: Text(
                                  '${item['day']} - ${item['mealType']}',
                                ),
                                trailing: Text(item['description']!),
                              );
                            }).toList(),
                      ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitMenu,
                    child: Text('Submit Menu'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addItem() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _items.add({
          'item': _itemController.text,
          'description': _descriptionController.text,
          'imageUrl': _imageUrlController.text,
          'mealType': _mealType,
          'day': _day,
        });
        _itemController.clear();
        _descriptionController.clear();
        _imageUrlController.clear();
      });
    }
  }

  void _submitMenu() async {
    if (_formKey.currentState!.validate() && _items.isNotEmpty) {
      _formKey.currentState!.save();

      try {
        await _firestore.collection('menus').add({
          'weekNumber': _weekNumber,
          'category': _category,
          'items': _items,
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Menu added successfully!')));

        setState(() {
          _weekNumber = 1;
          _category = 'Veg';
          _items.clear();
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add menu: $e')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please add at least one item')));
    }
  }

  void _activateSubscription(String userId) {
    String? selectedCategory;
    String? selectedPlan;

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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCategory != null && selectedPlan != null) {
                    final now = DateTime.now();
                    final endDate = now.add(
                      Duration(
                        days:
                            selectedPlan == '1 Week'
                                ? 7
                                : selectedPlan == '3 Weeks'
                                ? 21
                                : 28,
                      ),
                    );
                    await _firestore.collection('users').doc(userId).update({
                      'activeSubscription': true,
                      'subscriptionPlan': selectedPlan,
                      'category': selectedCategory,
                      'subscriptionStartDate': Timestamp.fromDate(now),
                      'subscriptionEndDate': Timestamp.fromDate(endDate),
                      'isPaused': false,
                    });
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select category and plan'),
                      ),
                    );
                  }
                },
                child: Text('Activate'),
              ),
            ],
          ),
    );
  }

  void _deactivateSubscription(String userId) {
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
                  await _firestore.collection('users').doc(userId).update({
                    'activeSubscription': false,
                    'subscriptionPlan': FieldValue.delete(),
                    'subscriptionStartDate': FieldValue.delete(),
                    'subscriptionEndDate': FieldValue.delete(),
                    'isPaused': FieldValue.delete(),
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
