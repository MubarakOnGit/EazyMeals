import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:math';

import '../utils/theme.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Quality Food",
      "subtitle":
          "Exquisite restaurant-quality meals, crafted with premium ingredients and infused with the warmth and comfort of home.",
      "image": "assets/images/shield.json",
    },
    {
      "title": "Reliable Delivery",
      "subtitle":
          "Delicious, freshly prepared meals delivered straight to your doorstep with fast and reliable service!.",
      "image": "assets/images/food_delivery.json",
    },
    {
      "title": "Healthy Choices",
      "subtitle":
          "Fresh ingredients, hygienic preparation, The use of high-quality produce, careful handling, and clean cooking techniques enhance both taste and nutrition, delivering a meal that is not only delicious but also safe and nourishing.",
      "image": "assets/images/fruits.json",
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _nextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = headTextColor;
    const subtitleColor = subHeadTextColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: onboardingData.length,
              itemBuilder: (context, index) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleOnboardingScreen(
                    title: onboardingData[index]["title"]!,
                    subtitle: onboardingData[index]["subtitle"]!,
                    image: onboardingData[index]["image"]!,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                );
              },
            ),
            Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  onboardingData.length,
                  (index) => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          _currentPage == index
                              ? Colors.blue
                              : Colors.grey[400]!.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: _nextPage,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _currentPage == onboardingData.length - 1
                          ? "Get Started"
                          : "Next",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: buttonTextColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SingleOnboardingScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String image;
  final Color textColor;
  final Color subtitleColor;

  const SingleOnboardingScreen({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 60),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: screenHeight * 0.4,
                width: screenWidth * 0.8,
                child: CustomPaint(painter: AmoebaPainter()),
              ),
              Container(
                height: screenHeight * 0.35,
                child: Lottie.asset(image, fit: BoxFit.contain, repeat: true),
              ),
            ],
          ),
          SizedBox(height: 40),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: subtitleColor,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          Spacer(),
        ],
      ),
    );
  }
}

class AmoebaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.blue.withOpacity(0.3),
              Colors.purple.withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;

    final path = Path();
    final random = Random();
    final points = 12; // Increased points for smoother edges

    // Generate control points
    List<Offset> controlPoints = [];
    for (int i = 0; i < points; i++) {
      double angle = (2 * pi / points) * i;
      double radius =
          (size.width * 0.4) + (random.nextDouble() * size.width * 0.1);
      double x = size.width * 0.5 + radius * cos(angle);
      double y = size.height * 0.5 + radius * sin(angle);
      controlPoints.add(Offset(x, y));
    }

    // Start at first point
    path.moveTo(controlPoints[0].dx, controlPoints[0].dy);

    // Create smooth curves using cubic Bezier
    for (int i = 0; i < controlPoints.length; i++) {
      int nextIndex = (i + 1) % controlPoints.length;
      int prevIndex = (i - 1 + controlPoints.length) % controlPoints.length;

      // Calculate control points for smooth curves
      Offset midPoint = Offset(
        (controlPoints[i].dx + controlPoints[nextIndex].dx) / 2,
        (controlPoints[i].dy + controlPoints[nextIndex].dy) / 2,
      );

      Offset control1 = Offset(
        controlPoints[i].dx + (midPoint.dx - controlPoints[prevIndex].dx) * 0.3,
        controlPoints[i].dy + (midPoint.dy - controlPoints[prevIndex].dy) * 0.3,
      );

      Offset control2 = Offset(
        controlPoints[nextIndex].dx -
            (controlPoints[(nextIndex + 1) % controlPoints.length].dx -
                    midPoint.dx) *
                0.3,
        controlPoints[nextIndex].dy -
            (controlPoints[(nextIndex + 1) % controlPoints.length].dy -
                    midPoint.dy) *
                0.3,
      );

      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        controlPoints[nextIndex].dx,
        controlPoints[nextIndex].dy,
      );
    }
    path.close();

    canvas.drawShadow(path, Colors.black.withOpacity(0.2), 4.0, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
