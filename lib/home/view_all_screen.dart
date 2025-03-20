import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewAllScreen extends StatefulWidget {
  @override
  _ViewAllScreenState createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<ViewAllScreen> {
  final ScrollController _scrollController = ScrollController();
  final int currentDayIndex = 7;
  String _selectedCategory = 'Veg';
  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(currentDayIndex * 150.0);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        leading: IconButton(
          color: Colors.white,
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Menu',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children:
                  _categories.map((category) {
                    return ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected:
                          (selected) =>
                              setState(() => _selectedCategory = category),
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color:
                            _selectedCategory == category
                                ? Colors.white
                                : Colors.black,
                      ),
                    );
                  }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('menus')
                      .where('category', isEqualTo: _selectedCategory)
                      .where(
                        'weekNumber',
                        isGreaterThanOrEqualTo:
                            _currentDate.subtract(Duration(days: 7)).weekOfYear,
                      )
                      .where(
                        'weekNumber',
                        isLessThanOrEqualTo:
                            _currentDate.add(Duration(days: 28)).weekOfYear,
                      )
                      .orderBy('weekNumber')
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final menus =
                    snapshot.data!.docs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .toList();

                return ListView.builder(
                  controller: _scrollController,
                  physics: BouncingScrollPhysics(),
                  itemCount: 35,
                  itemBuilder: (context, index) {
                    DateTime baseDate = DateTime.now();
                    DateTime startDate = baseDate.subtract(Duration(days: 7));
                    DateTime date = startDate.add(Duration(days: index));
                    final menu = menus.firstWhere(
                      (menu) => menu['weekNumber'] == date.weekOfYear,
                      orElse: () => {},
                    );
                    final items = menu['items'] as List<dynamic>? ?? [];
                    final lunchItem = items.firstWhere(
                      (item) =>
                          item['mealType'] == 'Lunch' &&
                          item['day'] == _getWeekday(date.weekday),
                      orElse: () => {'item': 'No item'},
                    );
                    final dinnerItem = items.firstWhere(
                      (item) =>
                          item['mealType'] == 'Dinner' &&
                          item['day'] == _getWeekday(date.weekday),
                      orElse: () => {'item': 'No item'},
                    );
                    Color cardColor = _getCardColor(index);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.day}/${date.month}',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                _buildSimpleCard(
                                  'Lunch',
                                  lunchItem['item'],
                                  cardColor,
                                ),
                                _buildSimpleCard(
                                  'Dinner',
                                  dinnerItem['item'],
                                  cardColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getCardColor(int index) {
    if (index == currentDayIndex)
      return Colors.blue.shade100;
    else if (index < currentDayIndex)
      return Colors.red.shade100;
    else
      return Colors.green.shade100;
  }

  Widget _buildSimpleCard(String meal, String item, Color cardColor) {
    return Card(
      elevation: 2,
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('$meal: $item')],
        ),
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
