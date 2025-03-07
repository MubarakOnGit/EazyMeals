import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ManagerMenuScreen extends StatefulWidget {
  @override
  _ManagerMenuScreenState createState() => _ManagerMenuScreenState();
}

class _ManagerMenuScreenState extends State<ManagerMenuScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedCategory;
  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  Map<String, bool> _editMode = {};

  @override
  void initState() {
    super.initState();
    _initializeEditMode();
    _scheduleDailyCleanup();
  }

  void _initializeEditMode() {
    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    for (var day in daysOfWeek) {
      _editMode['$day-Lunch'] = false;
      _editMode['$day-Dinner'] = false;
    }
    print('Edit mode initialized: $_editMode');
  }

  void _scheduleDailyCleanup() {
    final now = DateTime.now();
    var midnight = DateTime(
      now.year,
      now.month,
      now.day,
      0,
      0,
    ).add(Duration(days: 1));
    final duration = midnight.difference(now);

    Timer(duration, () async {
      await _cleanupOldMenus();
      if (mounted) _scheduleDailyCleanup();
    });
  }

  Future<void> _cleanupOldMenus() async {
    final now = DateTime.now();
    final cutoffWeek = now.subtract(Duration(days: 7)).weekOfYear;

    try {
      final snapshot =
          await _firestore
              .collection('menus')
              .where('weekNumber', isLessThan: cutoffWeek)
              .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('Cleaned up ${snapshot.docs.length} old menu documents');
    } catch (e) {
      print('Error cleaning up old menus: $e');
    }
  }

  void _toggleEditMode(
    String key,
    String docId,
    Map<String, dynamic>? item,
    TextEditingController itemController,
    TextEditingController imageUrlController,
  ) async {
    print('Toggling edit mode for $key, current state: ${_editMode[key]}');
    setState(() {
      _editMode[key] = !_editMode[key]!;
    });

    if (!_editMode[key]! && itemController.text.isNotEmpty) {
      final imageUrl = imageUrlController.text.trim();
      // Basic validation for image URL
      if (imageUrl.isNotEmpty &&
          !RegExp(
            r'\.(jpg|jpeg|png|gif|bmp)$',
            caseSensitive: false,
          ).hasMatch(imageUrl)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter a valid image URL (e.g., ending in .jpg, .png)',
            ),
          ),
        );
        return;
      }

      final updatedItem = {
        'item': itemController.text,
        'imageUrl': imageUrl.isEmpty ? null : imageUrl,
        'mealType': key.split('-')[1],
        'day': key.split('-')[0],
        'description': '',
      };

      try {
        final docRef = _firestore.collection('menus').doc(docId);
        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          if (item != null && item.isNotEmpty) {
            print('Updating existing item: $item');
            await docRef.update({
              'items': FieldValue.arrayRemove([item]),
            });
          }
          await docRef.update({
            'items': FieldValue.arrayUnion([updatedItem]),
          });
        } else {
          print('Creating new document for docId: $docId');
          await docRef.set({
            'items': [updatedItem],
            'weekNumber': docId.split('-').last.parseWeekNumber(),
            'category': _selectedCategory ?? 'Veg',
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Menu item saved')));
      } catch (e) {
        print('Error saving item: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu Management'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = null);
                  },
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color:
                        _selectedCategory == null ? Colors.white : Colors.black,
                  ),
                ),
                ..._categories.map((category) {
                  return ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      if (selected)
                        setState(() => _selectedCategory = category);
                    },
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color:
                          _selectedCategory == category
                              ? Colors.white
                              : Colors.black,
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection('menus')
                      .orderBy('weekNumber')
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final menus =
                    snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['docId'] = doc.id;
                      return data;
                    }).toList();
                print('Menus loaded: ${menus.length}');
                return _buildTimeline(menus);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> menus) {
    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final currentDate = DateTime.now();
    final allDays = List.generate(
      35,
      (index) => currentDate.add(Duration(days: index - 7)),
    );
    final weeks = List.generate(
      5,
      (weekIndex) => allDays.sublist(weekIndex * 7, (weekIndex + 1) * 7),
    );

    return ListView.builder(
      itemCount: weeks.length,
      itemBuilder: (context, weekIndex) {
        final weekLabel =
            weekIndex == 0 ? 'Previous Week' : 'Week ${weekIndex}';
        return Card(
          elevation: 4,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  weekLabel,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                ...weeks[weekIndex].map(
                  (date) =>
                      _buildDayItem(date, daysOfWeek[date.weekday - 1], menus),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayItem(
    DateTime date,
    String day,
    List<Map<String, dynamic>> menus,
  ) {
    final isPastDay = date.isBefore(DateTime.now());
    final isCurrentDay =
        date.day == DateTime.now().day &&
        date.month == DateTime.now().month &&
        date.year == DateTime.now().year;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$day\n${date.day}/${date.month}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isCurrentDay ? Colors.green : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildMealItem(
              date,
              day,
              'Lunch',
              isPastDay,
              isCurrentDay,
              menus,
            ),
          ),
          Container(
            width: 2,
            height: 120,
            color: Colors.grey[300],
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isCurrentDay)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildMealItem(
              date,
              day,
              'Dinner',
              isPastDay,
              isCurrentDay,
              menus,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealItem(
    DateTime date,
    String day,
    String mealType,
    bool isPastDay,
    bool isCurrentDay,
    List<Map<String, dynamic>> menus,
  ) {
    final menu = menus.firstWhere(
      (menu) =>
          menu['weekNumber'] == date.weekOfYear &&
          (_selectedCategory == null || menu['category'] == _selectedCategory),
      orElse:
          () => {
            'items': [],
            'docId': 'menu-${_selectedCategory ?? 'Veg'}-${date.weekOfYear}',
            'weekNumber': date.weekOfYear,
            'category': _selectedCategory ?? 'Veg',
          },
    );

    final items = menu['items'] as List<dynamic>? ?? [];
    final item = items.firstWhere(
      (item) => item['day'] == day && item['mealType'] == mealType,
      orElse: () => {},
    );

    final key = '$day-$mealType';
    final itemController = TextEditingController(
      text: item['item']?.toString() ?? '',
    );
    final imageUrlController = TextEditingController(
      text: item['imageUrl']?.toString() ?? '',
    );

    print('Building $key: item=$item, editMode=${_editMode[key]}');

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color:
            isPastDay
                ? Colors.grey[200]
                : isCurrentDay
                ? Colors.green[50]
                : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mealType,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color:
                      isPastDay
                          ? Colors.grey
                          : isCurrentDay
                          ? Colors.green[800]
                          : Colors.blue[800],
                ),
              ),
              IconButton(
                icon: Icon(
                  _editMode[key]! ? Icons.save : Icons.edit,
                  color: _editMode[key]! ? Colors.green : Colors.blue,
                ),
                onPressed:
                    () => _toggleEditMode(
                      key,
                      menu['docId'],
                      item.isNotEmpty ? item : null,
                      itemController,
                      imageUrlController,
                    ),
                tooltip: _editMode[key]! ? 'Save' : 'Edit',
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: itemController,
            enabled: _editMode[key]!,
            decoration: InputDecoration(
              labelText: 'Item Name',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: imageUrlController,
            enabled: _editMode[key]!,
            decoration: InputDecoration(
              labelText: 'Image URL (optional)',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          if (menu['category'] != null)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '(${menu['category']})',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

extension DateTimeExtension on DateTime {
  int get weekOfYear {
    final startOfYear = DateTime(year, 1, 1);
    final firstMonday = startOfYear.add(
      Duration(days: (8 - startOfYear.weekday) % 7),
    );
    return (difference(firstMonday).inDays / 7).floor() + 1;
  }
}

extension StringExtension on String {
  int parseWeekNumber() => int.parse(split('-').last);
}
