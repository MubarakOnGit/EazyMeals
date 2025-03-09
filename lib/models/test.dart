// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:iconsax/iconsax.dart';
// import 'package:flip_card/flip_card.dart';
// import 'dart:async';
// import 'package:flutter_bounce/flutter_bounce.dart';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: HomeScreen(),
//     );
//   }
// }
//
// class HomeScreen extends StatelessWidget {
//   final BannerController bannerController = Get.put(BannerController());
//
//   @override
//   Widget build(BuildContext context) {
//     RxBool isSwitched = false.obs;
//     RxBool isChecked = false.obs;
//
//     List<Map<String, dynamic>> categories = [
//       {
//         'title': 'North Indian',
//         'description':
//             'Savor the rich flavors of North India with our authentic curries and tandoori dishes',
//         'image': 'assets/north_indian.png',
//       },
//       {
//         'title': 'South Indian',
//         'description':
//             'Enjoy traditional South Indian delicacies like dosas, idlis, and sambar',
//         'image': 'assets/south_indian.png',
//       },
//       {
//         'title': 'Veg',
//         'description': 'Fresh and healthy vegetarian options for every meal',
//         'image': 'assets/veg.png',
//       },
//     ];
//
//     List<Map<String, dynamic>> items = [
//       {
//         'title': 'Pause and Play',
//         'subtitle': 'Currently not subscribed',
//         'description':
//             'You can pause and play your subscription according to your wishes this way you can save the money and the dish',
//         'icon': Iconsax.play,
//         'secondaryIcon': null,
//         'extraWidget': Obx(
//           () => Switch(
//             value: isSwitched.value,
//             onChanged: (value) {
//               isSwitched.value = value;
//             },
//             activeColor: Colors.blue.shade200,
//             inactiveThumbColor: Colors.white,
//             inactiveTrackColor: Colors.blue.shade900,
//           ),
//         ),
//       },
//       {
//         'title': 'Today\'s Order',
//         'subtitle': 'You are not subscribed any plan yet',
//         'description':
//             'You can see the current days order status from here you can also check the orders page for more information',
//         'icon': null,
//         'secondaryIcon': Iconsax.arrow_circle_right,
//         'extraWidget': Obx(
//           () => Checkbox(
//             value: isChecked.value,
//             onChanged: (value) {
//               isChecked.value = value!;
//             },
//             activeColor: Colors.blue.shade200,
//             checkColor: Colors.blue.shade900,
//             side: BorderSide(
//               color: isChecked.value ? Colors.blue.shade200 : Colors.orange,
//               width: 1.5,
//             ),
//             fillColor: MaterialStateProperty.resolveWith((states) {
//               if (!states.contains(MaterialState.selected)) {
//                 return Colors.blue.shade900;
//               }
//               return null;
//             }),
//             materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//             visualDensity: VisualDensity(horizontal: 0, vertical: 0),
//           ),
//         ),
//       },
//       {
//         'title': '3 Days Left',
//         'subtitle': 'Your plan automatically unsubscribe after 3 days',
//         'description': 'Check the orders section for more details',
//         'icon': null,
//         'secondaryIcon': Iconsax.arrow_circle_right,
//         'extraWidget': Stack(
//           alignment: Alignment.center,
//           children: [
//             SizedBox(
//               width: 50,
//               height: 50,
//               child: CircularProgressIndicator(
//                 value: 0.4,
//                 strokeWidth: 5,
//                 backgroundColor: Colors.white30,
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
//               ),
//             ),
//             Text('40%', style: TextStyle(color: Colors.white, fontSize: 14)),
//           ],
//         ),
//       },
//       {
//         'title': 'Student Verification',
//         'subtitle': 'Complete your student verification to get 10% discount',
//         'description':
//             'Complete your student verification with your university ID to get 10% discount',
//         'icon': Iconsax.user_edit,
//         'secondaryIcon': Iconsax.arrow_circle_right,
//         'extraWidget': null,
//       },
//       {
//         'title': 'Your Active Address',
//         'subtitle': '123 Food Street, Flavor Town, FT 12345',
//         'description':
//             'You can add multiple addresses and set to an active address then our team can easily reach you in your place',
//         'icon': Iconsax.location,
//         'secondaryIcon': Iconsax.arrow_circle_right,
//         'extraWidget': null,
//       },
//       {
//         'title': 'Support Us',
//         'subtitle': 'Report bugs as well as inform your feedback',
//         'description':
//             'Please feel free to inform your ideas and feedbacks, also don\'t forget to report an issue if you find anything',
//         'icon': Iconsax.heart,
//         'secondaryIcon': Iconsax.arrow_circle_right,
//         'extraWidget': null,
//       },
//     ];
//
//     List<String> banners = [
//       'assets/pic1.png',
//       'assets/pic1.png',
//       'assets/pic1.png',
//     ];
//
//     bannerController.setBanners(banners);
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: Icon(Icons.menu, color: Colors.blue[900]),
//           onPressed: () {},
//         ),
//         title: Center(
//           child: Text(
//             'Home',
//             style: TextStyle(
//               color: Colors.blue[900],
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 10.0),
//             child: CircleAvatar(
//               radius: 18,
//               backgroundImage: AssetImage('assets/profile_pic.jpg'),
//             ),
//           ),
//         ],
//       ),
//       backgroundColor: Colors.white,
//       body: SingleChildScrollView(
//         physics: BouncingScrollPhysics(),
//         child: Stack(
//           children: [
//             Positioned(
//               top: -300,
//               right: -50,
//               child: Container(
//                 width: 600,
//                 height: 600,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//             ),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Hi User!👋🏼',
//                         style: TextStyle(
//                           fontSize: 34,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.blue.shade900,
//                         ),
//                       ),
//                       Text(
//                         'Good Morning',
//                         style: TextStyle(fontSize: 16, color: Colors.grey),
//                       ),
//                       SizedBox(height: 20),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 10),
//                         child: TextField(
//                           cursorColor: Colors.transparent,
//                           decoration: InputDecoration(
//                             prefixIcon: Icon(Icons.search, color: Colors.blue),
//                             hintText: 'Search...',
//                             hintStyle: TextStyle(color: Colors.blue.shade500),
//                             filled: true,
//                             fillColor: Colors.grey[300],
//                             border: InputBorder.none,
//                             enabledBorder: OutlineInputBorder(
//                               borderSide: BorderSide.none,
//                               borderRadius: BorderRadius.circular(30),
//                             ),
//                             focusedBorder: OutlineInputBorder(
//                               borderSide: BorderSide.none,
//                               borderRadius: BorderRadius.circular(30),
//                             ),
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: 20),
//                       Text(
//                         'Categories',
//                         style: TextStyle(
//                           fontSize: 25,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.blue.shade900,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(
//                   height: 200,
//                   child: Column(
//                     children: [
//                       Expanded(
//                         child: PageView.builder(
//                           controller: bannerController.pageController,
//                           onPageChanged: (index) {
//                             bannerController.currentIndex.value = index;
//                           },
//                           itemCount: categories.length,
//                           itemBuilder: (context, index) {
//                             return Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 10.0,
//                               ),
//                               child: Container(
//                                 width: 300,
//                                 decoration: BoxDecoration(
//                                   border: Border.all(
//                                     color: Colors.blue.shade900,
//                                     width: 2,
//                                   ),
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     Expanded(
//                                       flex: 2,
//                                       child: Padding(
//                                         padding: const EdgeInsets.all(16.0),
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.center,
//                                           children: [
//                                             Text(
//                                               categories[index]['title']!,
//                                               style: TextStyle(
//                                                 fontSize: 18,
//                                                 fontWeight: FontWeight.bold,
//                                                 color: Colors.blue.shade900,
//                                               ),
//                                             ),
//                                             SizedBox(height: 8),
//                                             Text(
//                                               categories[index]['description']!,
//                                               style: TextStyle(
//                                                 fontSize: 14,
//                                                 color: Colors.grey.shade700,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       flex: 1,
//                                       child: ClipRRect(
//                                         borderRadius: BorderRadius.only(
//                                           topRight: Radius.circular(18),
//                                           bottomRight: Radius.circular(18),
//                                         ),
//                                         child: Image.asset(
//                                           categories[index]['image'],
//                                           fit: BoxFit.cover,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                       SizedBox(height: 10),
//                       Obx(
//                         () => Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: List.generate(
//                             categories.length,
//                             (index) => Container(
//                               margin: EdgeInsets.symmetric(horizontal: 4),
//                               width: 8,
//                               height: 8,
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 color:
//                                     bannerController.currentIndex.value == index
//                                         ? Colors.blue.shade900
//                                         : Colors.grey[300],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Text(
//                     '  Browse',
//                     style: TextStyle(
//                       fontSize: 25,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blue.shade900,
//                     ),
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   child: GridView.builder(
//                     physics: NeverScrollableScrollPhysics(),
//                     shrinkWrap: true,
//                     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: 2,
//                       crossAxisSpacing: 5,
//                       mainAxisSpacing: 5,
//                       childAspectRatio: 0.8,
//                     ),
//                     itemCount: items.length,
//                     itemBuilder: (context, index) {
//                       Gradient gradient = LinearGradient(
//                         colors: [Colors.blue.shade900, Colors.blue.shade600],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       );
//
//                       return FlipCard(
//                         direction: FlipDirection.HORIZONTAL,
//                         front: Card(
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           elevation: 2,
//                           child: Container(
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(20),
//                               gradient: gradient,
//                             ),
//                             child: Stack(
//                               children: [
//                                 Padding(
//                                   padding: const EdgeInsets.all(16.0),
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       if (items[index]['extraWidget'] != null &&
//                                           index != 0 &&
//                                           index != 1)
//                                         Padding(
//                                           padding: const EdgeInsets.only(
//                                             bottom: 10,
//                                           ),
//                                           child: items[index]['extraWidget'],
//                                         ),
//                                       if (items[index]['extraWidget'] != null &&
//                                           index != 0 &&
//                                           index != 1)
//                                         SizedBox(height: 10),
//                                       Text(
//                                         items[index]['title']!,
//                                         style: TextStyle(
//                                           fontSize: 18,
//                                           fontWeight: FontWeight.bold,
//                                           color: Colors.white,
//                                         ),
//                                       ),
//                                       SizedBox(height: 10),
//                                       Text(
//                                         items[index]['subtitle']!,
//                                         style: TextStyle(
//                                           fontSize: 14,
//                                           color: Colors.white.withOpacity(0.8),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 if (items[index]['icon'] != null)
//                                   Positioned(
//                                     top: 10,
//                                     left: 10,
//                                     child: Icon(
//                                       items[index]['icon'],
//                                       color: Colors.orange,
//                                       size: 30,
//                                     ),
//                                   ),
//                                 if (index == 1 &&
//                                     items[index]['extraWidget'] != null)
//                                   Positioned(
//                                     top: 10,
//                                     left: 10,
//                                     child: items[index]['extraWidget'],
//                                   ),
//                                 if (items[index]['secondaryIcon'] != null)
//                                   Positioned(
//                                     top: 15,
//                                     right: 15,
//                                     child: Icon(
//                                       items[index]['secondaryIcon'],
//                                       color: Colors.blue.shade200,
//                                       size: 30,
//                                     ),
//                                   ),
//                                 if (index == 0 &&
//                                     items[index]['extraWidget'] != null)
//                                   Positioned(
//                                     top: 5,
//                                     right: 5,
//                                     child: items[index]['extraWidget'],
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ),
//                         back: Card(
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           elevation: 2,
//                           child: Container(
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(20),
//                               gradient: gradient,
//                             ),
//                             child: Padding(
//                               padding: const EdgeInsets.all(16.0),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     items[index]['description']!,
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//                 SizedBox(height: 20),
//               ],
//             ),
//           ],
//         ),
//       ),
//       bottomNavigationBar: CustomBottomNavBar(),
//       floatingActionButton: Container(
//         width: 60,
//         height: 60,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.blue.shade900.withOpacity(0.5),
//               spreadRadius: 3,
//               blurRadius: 8,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//         child: FloatingActionButton(
//           onPressed: () {},
//           child: Icon(Icons.add, size: 30, color: Colors.white),
//           backgroundColor: Colors.blue[900],
//           shape: CircleBorder(),
//           elevation: 0,
//         ),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
//       extendBody: true,
//     );
//   }
// }
//
// // Rest of the code (CustomBottomNavBar, BottomNavBarPainter, NavItem, BannerController) remains unchanged
//
// class CustomBottomNavBar extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 80,
//       child: CustomPaint(
//         painter: BottomNavBarPainter(),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             NavItem(icon: Iconsax.home, label: 'Home', isSelected: true),
//             NavItem(icon: Iconsax.book, label: 'Menu', isSelected: false),
//             SizedBox(width: 60),
//             NavItem(icon: Iconsax.calendar_1, label: 'Plan', isSelected: false),
//             NavItem(
//               icon: Iconsax.profile_circle,
//               label: 'Profile',
//               isSelected: false,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class BottomNavBarPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     Paint paint =
//         Paint()
//           ..color = Colors.white
//           ..style = PaintingStyle.fill;
//
//     Path leftPath = Path();
//     leftPath.moveTo(20, size.height);
//     leftPath.quadraticBezierTo(0, size.height, 0, size.height - 20);
//     leftPath.lineTo(0, 20);
//     leftPath.quadraticBezierTo(0, 0, 20, 0);
//     leftPath.lineTo(size.width * 0.32, 0);
//     leftPath.lineTo(size.width * 0.32, size.height);
//     leftPath.close();
//     canvas.drawShadow(leftPath, Colors.grey.withOpacity(0.3), 4.0, false);
//     canvas.drawPath(leftPath, paint);
//
//     Path rightPath = Path();
//     rightPath.moveTo(size.width * 0.68, 0);
//     rightPath.lineTo(size.width - 20, 0);
//     rightPath.quadraticBezierTo(size.width, 0, size.width, 20);
//     rightPath.lineTo(size.width, size.height - 20);
//     rightPath.quadraticBezierTo(
//       size.width,
//       size.height,
//       size.width - 20,
//       size.height,
//     );
//     rightPath.lineTo(size.width * 0.68, size.height);
//     rightPath.close();
//     canvas.drawShadow(rightPath, Colors.grey.withOpacity(0.3), 4.0, false);
//     canvas.drawPath(rightPath, paint);
//
//     Path curvePath = Path();
//     curvePath.moveTo(size.width * 0.32, size.height);
//     curvePath.lineTo(size.width * 0.32, 0);
//     curvePath.quadraticBezierTo(
//       size.width * 0.38,
//       0,
//       size.width * 0.42,
//       size.height * 0.2,
//     );
//     curvePath.quadraticBezierTo(
//       size.width * 0.46,
//       size.height * 0.4,
//       size.width * 0.50,
//       size.height * 0.5,
//     );
//     curvePath.quadraticBezierTo(
//       size.width * 0.54,
//       size.height * 0.4,
//       size.width * 0.58,
//       size.height * 0.2,
//     );
//     curvePath.quadraticBezierTo(size.width * 0.62, 0, size.width * 0.68, 0);
//     curvePath.lineTo(size.width * 0.68, size.height);
//     curvePath.close();
//     canvas.drawPath(curvePath, paint);
//   }
//
//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) => false;
// }
//
// class NavItem extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final bool isSelected;
//
//   NavItem({required this.icon, required this.label, required this.isSelected});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(
//           icon,
//           color: Colors.blue[900],
//           size: 24,
//           semanticLabel: isSelected ? 'filled' : 'outlined',
//         ),
//         SizedBox(height: 4),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.blue[900],
//             fontSize: 12,
//             fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class BannerController extends GetxController {
//   final PageController pageController = PageController(initialPage: 1);
//   final RxInt currentIndex = 1.obs;
//   List<String> banners = [];
//
//   void setBanners(List<String> bannerList) {
//     banners = bannerList;
//   }
//
//   @override
//   void onInit() {
//     super.onInit();
//     startAutoScroll();
//   }
//
//   void startAutoScroll() {
//     Timer.periodic(Duration(seconds: 4), (timer) {
//       if (currentIndex.value < banners.length - 1) {
//         currentIndex.value++;
//       } else {
//         currentIndex.value = 0;
//       }
//       pageController.animateToPage(
//         currentIndex.value,
//         duration: Duration(milliseconds: 500),
//         curve: Curves.easeInOut,
//       );
//     });
//   }
// }
