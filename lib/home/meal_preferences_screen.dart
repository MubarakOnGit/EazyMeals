import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MealPreferencesScreen extends StatefulWidget {
  @override
  _MealPreferencesScreenState createState() => _MealPreferencesScreenState();
}

class _MealPreferencesScreenState extends State<MealPreferencesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedPlan = '1 Week'; // Default selected plan
  String _selectedMealType = '1 Time'; // Default selected meal type
  String _selectedCuisine = 'South Indian'; // Default selected cuisine
  List<Map<String, dynamic>> _menuItems = []; // List of menu items

  final List<String> _plans = ['1 Week', '2 Weeks', '4 Weeks'];
  final List<String> _mealTypes = ['1 Time', '2 Times'];
  final List<String> _cuisines = ['South Indian', 'North Indian', 'Veg'];

  @override
  void initState() {
    super.initState();
    _fetchMenuItems();
  }

  Future<void> _fetchMenuItems() async {
    try {
      QuerySnapshot querySnapshot =
          await _firestore
              .collection('menus')
              .where('category', isEqualTo: _selectedCuisine)
              .get();
      setState(() {
        _menuItems =
            querySnapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();
      });
    } catch (e) {
      print('Error fetching menu items: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load menu items: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meal Preferences'),
        backgroundColor: Colors.blue, // Match your app's theme
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Selection
            Text(
              'Select Plan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children:
                  _plans.map((plan) {
                    return ChoiceChip(
                      label: Text(plan),
                      selected: _selectedPlan == plan,
                      onSelected: (selected) {
                        setState(() => _selectedPlan = plan);
                      },
                      selectedColor: Colors.blue, // Match your app's theme
                    );
                  }).toList(),
            ),
            SizedBox(height: 20),

            // Meal Type Selection
            Text(
              'Select Meal Type',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children:
                  _mealTypes.map((mealType) {
                    return ChoiceChip(
                      label: Text(mealType),
                      selected: _selectedMealType == mealType,
                      onSelected: (selected) {
                        setState(() => _selectedMealType = mealType);
                      },
                      selectedColor: Colors.blue, // Match your app's theme
                    );
                  }).toList(),
            ),
            SizedBox(height: 20),

            // Cuisine Selection
            Text(
              'Select Cuisine',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children:
                  _cuisines.map((cuisine) {
                    return ChoiceChip(
                      label: Text(cuisine),
                      selected: _selectedCuisine == cuisine,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCuisine = cuisine;
                          _fetchMenuItems(); // Fetch menu items for the selected cuisine
                        });
                      },
                      selectedColor: Colors.blue, // Match your app's theme
                    );
                  }).toList(),
            ),
            SizedBox(height: 20),

            // Display Menu Items
            Text(
              'Menu Items',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            _buildMenuItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItems() {
    return Column(
      children:
          _menuItems.map((item) {
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              margin: EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(item['name']),
                subtitle: Text(item['description']),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue),
                onTap: () {
                  // Handle menu item selection
                },
              ),
            );
          }).toList(),
    );
  }
}
