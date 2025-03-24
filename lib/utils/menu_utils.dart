import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class MenuUtils {
  static Future<Map<String, Map<String, dynamic>>> fetchMenuData({
    required DateTime baseDate,
    String? dateFilter, // Optional: Filter by specific date (MenuScreen)
    int daysRange = 35, // Default: 35 days for ViewAllScreen
  }) async {
    Map<String, Map<String, dynamic>> menuCache = {};

    // Load local menu file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/menu.json';
    final file = File(filePath);

    Map<String, dynamic> menuData;
    try {
      if (await file.exists()) {
        String jsonString = await file.readAsString();
        menuData = jsonDecode(jsonString);
      } else {
        menuData = {'version': '0.00', 'menus': []};
      }
    } catch (e) {
      print('Error loading local menu: $e');
      menuData = {'version': '0.00', 'menus': []};
    }

    List<dynamic> menus = menuData['menus'] ?? [];

    for (var menu in menus) {
      if (dateFilter != null) {
        // MenuScreen: Filter by specific date
        menuCache[menu['category']] = {
          'items':
              (menu['items'] as List<dynamic>)
                  .where((item) => item['date'] == dateFilter)
                  .toList(),
        };
        print('MenuScreen Cached ${menu['category']} for date $dateFilter');
      } else {
        // ViewAllScreen: Cache all items for the 35-day range
        for (int i = 0; i < daysRange; i++) {
          DateTime date = baseDate.add(Duration(days: i));
          String dateStr = _formatDate(date);
          menuCache[menu['category']] = {'items': menu['items']};
          print('ViewAllScreen Cached ${menu['category']} for date $dateStr');
        }
      }
    }

    return menuCache;
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String getDateString(DateTime date) {
    return _formatDate(date);
  }
}
