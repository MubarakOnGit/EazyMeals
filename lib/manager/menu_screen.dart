import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerMenuScreen extends StatefulWidget {
  @override
  _ManagerMenuScreenState createState() => _ManagerMenuScreenState();
}

class _ManagerMenuScreenState extends State<ManagerMenuScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40),
          Center(
            child: Text(
              'Menu Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 20),
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
                    if (value == null || value.isEmpty)
                      return 'Please enter the week number';
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
                    if (value == null || value.isEmpty)
                      return 'Please enter the item name';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter the description';
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
                            (day) =>
                                DropdownMenuItem(value: day, child: Text(day)),
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
}
