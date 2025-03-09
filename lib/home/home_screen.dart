import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:hidden_drawer_menu/hidden_drawer_menu.dart';
import 'package:iconsax/iconsax.dart';
import '../controllers/banner_controller.dart';
import 'employee_login_screen.dart';
import 'menu_screen.dart';

class HomeScreen extends StatelessWidget {
  final BannerController bannerController = Get.put(BannerController());

  @override
  Widget build(BuildContext context) {
    RxBool isSwitched = false.obs;
    RxBool isChecked = false.obs;

    List<Map<String, dynamic>> categories = [
      {
        'title': 'North Indian',
        'description':
            'Savor the rich flavors of North India with our authentic curries and tandoori dishes',
        'image': 'assets/pic1.png',
      },
      {
        'title': 'South Indian',
        'description':
            'Enjoy traditional South Indian delicacies like dosas, idlis, and sambar',
        'image': 'assets/pic1.png',
      },
      {
        'title': 'Veg',
        'description': 'Fresh and healthy vegetarian options for every meal',
        'image': 'assets/pic.png',
      },
    ];

    List<Map<String, dynamic>> items = [
      {
        'title': 'Pause and Play',
        'subtitle': 'Currently not subscribed',
        'description':
            'You can pause and play your subscription according to your wishes this way you can save the money and the dish',
        'icon': Iconsax.play,
        'secondaryIcon': null,
        'extraWidget': Obx(
          () => Switch(
            value: isSwitched.value,
            onChanged: (value) {
              isSwitched.value = value;
            },
            activeColor: Colors.blue.shade200,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.blue.shade900,
          ),
        ),
      },
      {
        'title': 'Today\'s Order',
        'subtitle': 'You are not subscribed any plan yet',
        'description':
            'You can see the current days order status from here you can also check the orders page for more information',
        'icon': null,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': Obx(
          () => Checkbox(
            value: isChecked.value,
            onChanged: (value) {
              isChecked.value = value!;
            },
            activeColor: Colors.blue.shade200,
            checkColor: Colors.blue.shade900,
            side: BorderSide(
              color: isChecked.value ? Colors.blue.shade200 : Colors.orange,
              width: 1.5,
            ),
            fillColor: MaterialStateProperty.resolveWith((states) {
              if (!states.contains(MaterialState.selected)) {
                return Colors.blue.shade900;
              }
              return null;
            }),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity(horizontal: 0, vertical: 0),
          ),
        ),
      },
      {
        'title': '3 Days Left',
        'subtitle': 'Your plan automatically unsubscribe after 3 days',
        'description': 'Check the orders section for more details',
        'icon': null,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: 0.4,
                strokeWidth: 5,
                backgroundColor: Colors.white30,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            Text('40%', style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      },
      {
        'title': 'Student Verification',
        'subtitle': 'Complete your student verification to get 10% discount',
        'description':
            'Complete your student verification with your university ID to get 10% discount',
        'icon': Iconsax.user_edit,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': null,
      },
      {
        'title': 'Your Active Address',
        'subtitle': '123 Food Street, Flavor Town, FT 12345',
        'description':
            'You can add multiple addresses and set to an active address then our team can easily reach you in your place',
        'icon': Iconsax.location,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': null,
      },
      {
        'title': 'Support Us',
        'subtitle': 'Report bugs as well as inform your feedback',
        'description':
            'Please feel free to inform your ideas and feedbacks, also don\'t forget to report an issue if you find anything',
        'icon': Iconsax.heart,
        'secondaryIcon': Iconsax.arrow_circle_right,
        'extraWidget': null,
      },
    ];

    List<String> banners = [
      'assets/pic1.png',
      'assets/pic1.png',
      'assets/pic1.png',
    ];

    bannerController.setBanners(banners);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.blue[900]),
          onPressed: () {
            Scaffold.of(context).openDrawer(); // Opens the drawer
          },
        ),
        title: Center(
          child: Text(
            'Home',
            style: TextStyle(
              color: Colors.blue[900],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage('assets/profile_pic.jpg'),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Stack(
          children: [
            Positioned(
              top: -300,
              right: -50,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi User!👋🏼',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        'Good Morning',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: TextField(
                          cursorColor: Colors.transparent,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search, color: Colors.blue),
                            hintText: 'Search...',
                            hintStyle: TextStyle(color: Colors.blue.shade500),
                            filled: true,
                            fillColor: Colors.grey[300],
                            border: InputBorder.none,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '  Browse',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      Gradient gradient = LinearGradient(
                        colors: [Colors.blue.shade900, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      );

                      return FlipCard(
                        direction: FlipDirection.HORIZONTAL,
                        front: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: gradient,
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (items[index]['extraWidget'] != null &&
                                          index != 0 &&
                                          index != 1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: items[index]['extraWidget'],
                                        ),
                                      if (items[index]['extraWidget'] != null &&
                                          index != 0 &&
                                          index != 1)
                                        SizedBox(height: 10),
                                      Text(
                                        items[index]['title']!,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        items[index]['subtitle']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (items[index]['icon'] != null)
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Icon(
                                      items[index]['icon'],
                                      color: Colors.orange,
                                      size: 30,
                                    ),
                                  ),
                                if (index == 1 &&
                                    items[index]['extraWidget'] != null)
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: items[index]['extraWidget'],
                                  ),
                                if (items[index]['secondaryIcon'] != null)
                                  Positioned(
                                    top: 15,
                                    right: 15,
                                    child: Icon(
                                      items[index]['secondaryIcon'],
                                      color: Colors.blue.shade200,
                                      size: 30,
                                    ),
                                  ),
                                if (index == 0 &&
                                    items[index]['extraWidget'] != null)
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: items[index]['extraWidget'],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        back: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: gradient,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    items[index]['description']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HiddenDrawer extends StatefulWidget {
  @override
  _HiddenDrawerState createState() => _HiddenDrawerState();
}

class _HiddenDrawerState extends State<HiddenDrawer> {
  List<ScreenHiddenDrawer> _pages = [];

  @override
  void initState() {
    super.initState();

    // Define the screens for the drawer
    _pages = [
      ScreenHiddenDrawer(
        ItemHiddenMenu(
          name: "Home",
          baseStyle: TextStyle(color: Colors.white, fontSize: 20),
          selectedStyle: TextStyle(color: Colors.yellow, fontSize: 20),
        ),
        HomeScreen(),
      ),
      ScreenHiddenDrawer(
        ItemHiddenMenu(
          name: "Menu",
          baseStyle: TextStyle(color: Colors.white, fontSize: 20),
          selectedStyle: TextStyle(color: Colors.yellow, fontSize: 20),
        ),
        MenuScreen(),
      ),
      ScreenHiddenDrawer(
        ItemHiddenMenu(
          name: "Employee Login",
          baseStyle: TextStyle(color: Colors.white, fontSize: 20),
          selectedStyle: TextStyle(color: Colors.yellow, fontSize: 20),
        ),
        EmployeeLoginScreen(),
      ),
      ScreenHiddenDrawer(
        ItemHiddenMenu(
          name: "Settings",
          baseStyle: TextStyle(color: Colors.white, fontSize: 20),
          selectedStyle: TextStyle(color: Colors.yellow, fontSize: 20),
        ),
        SettingsScreen(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return HiddenDrawerMenu(
      screens: _pages,
      backgroundColorMenu: Colors.blueGrey.shade900, // Menu background color
      initPositionSelected: 0, // Start with "Home" selected
      slidePercent: 60.0, // How much the drawer slides
      contentCornerRadius: 20.0, // Corner radius of the main content
      enableShadowItensMenu: true, // Add shadow to menu items
      enableScaleAnimation: true, // Enable scale animation
      enableCornerAnimation: true, // Enable corner animation
    );
  }
}

class EmployeeLoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          "Employee Login Page",
          style: TextStyle(fontSize: 30, color: Colors.black),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          "Settings Page",
          style: TextStyle(fontSize: 30, color: Colors.black),
        ),
      ),
    );
  }
}
