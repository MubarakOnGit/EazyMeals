import 'package:flutter/material.dart';
import 'package:eazy_meals/utils/menu_utils.dart'; // Adjust path

class ViewAllScreen extends StatefulWidget {
  @override
  _ViewAllScreenState createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<ViewAllScreen> {
  final ScrollController _scrollController = ScrollController();
  final int currentDayIndex = 7;
  String _selectedCategory = 'Veg';
  final List<String> _categories = ['Veg', 'South Indian', 'North Indian'];
  DateTime _baseDate = DateTime.now().subtract(Duration(days: 7));
  Map<String, Map<String, dynamic>> _menuCache = {};

  @override
  void initState() {
    super.initState();
    _fetchMenuData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(currentDayIndex * 160.0);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMenuData() async {
    _menuCache = await MenuUtils.fetchMenuData(baseDate: _baseDate);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Soft off-white background
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Colors.indigo[900],
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
              splashRadius: 20,
            ),
            title: Text(
              'Explore Menus',
              style: TextStyle(
                color: Colors.indigo[900],
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _categories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: FilterChip(
                                label: Text(category),
                                selected: _selectedCategory == category,
                                onSelected:
                                    (selected) => setState(
                                      () => _selectedCategory = category,
                                    ),
                                backgroundColor: Colors.indigo[50],
                                selectedColor: Colors.indigo[600],
                                checkmarkColor: Colors.white,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                labelStyle: TextStyle(
                                  color:
                                      _selectedCategory == category
                                          ? Colors.white
                                          : Colors.indigo[800],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  side: BorderSide(
                                    color: Colors.indigo[200]!,
                                    width: 1,
                                  ),
                                ),
                                elevation:
                                    _selectedCategory == category ? 3 : 0,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                DateTime date = _baseDate.add(Duration(days: index));
                final menu = _menuCache[_selectedCategory] ?? {};
                final items = menu['items'] as List<dynamic>? ?? [];
                final dateStr = MenuUtils.getDateString(date);
                final lunchItem = items.firstWhere(
                  (item) =>
                      item['mealType'] == 'Lunch' && item['date'] == dateStr,
                  orElse: () => {'item': 'Not Available'},
                );
                final dinnerItem = items.firstWhere(
                  (item) =>
                      item['mealType'] == 'Dinner' && item['date'] == dateStr,
                  orElse: () => {'item': 'Not Available'},
                );
                print(
                  'ViewAllScreen Lunch for $_selectedCategory on $dateStr: ${lunchItem['item']}',
                );
                print(
                  'ViewAllScreen Dinner for $_selectedCategory on $dateStr: ${dinnerItem['item']}',
                );

                return _buildDaySection(
                  dateStr,
                  lunchItem['item'],
                  dinnerItem['item'],
                  index,
                );
              }, childCount: 35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(
    String dateStr,
    String lunchItem,
    String dinnerItem,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.indigo[900],
            ),
          ),
          const SizedBox(height: 12),
          _buildMealCard('Lunch', lunchItem, index),
          const SizedBox(height: 12),
          _buildMealCard('Dinner', dinnerItem, index),
        ],
      ),
    );
  }

  Widget _buildMealCard(String meal, String item, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade700, // Changed to blue shade 700
                Colors.blue.shade900, // Changed to blue shade 900
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  meal == 'Lunch' ? Icons.wb_sunny : Icons.nightlight,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          meal,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                index == currentDayIndex
                                    ? Colors.blue[200]
                                    : index < currentDayIndex
                                    ? Colors.red[200]
                                    : Colors.green[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            index == currentDayIndex
                                ? 'Today'
                                : index < currentDayIndex
                                ? 'Past'
                                : 'Upcoming',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
