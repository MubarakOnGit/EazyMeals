import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:lottie/lottie.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Best Quality Food",
      "subtitle":
          "You get restaurant-quality food with the warmth of home cooking.",
      "image": "assets/images/shield.json",
    },
    {
      "title": "Doorstep Delivery",
      "subtitle":
          "Fastest delivery at your doorstep. Get your meals delivered to your location.",
      "image": "assets/images/food_delivery.json",
    },
    {
      "title": "Healthy & Hygienic",
      "subtitle":
          "Prepared with fresh ingredients and strict hygiene standards.",
      "image": "assets/images/fruits.json",
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _buttonAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
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
    });
  }

  void _nextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    final backgroundColor =
        theme.brightness == Brightness.light
            ? Colors.lightBlue[50]!
            : Colors.grey[850]!;
    final waveColor =
        theme.brightness == Brightness.light
            ? Colors.blue.withOpacity(0.15)
            : Colors.blue.withOpacity(0.1);
    final textColor =
        theme.brightness == Brightness.light ? Colors.black87 : Colors.white;
    final subtitleColor =
        theme.brightness == Brightness.light
            ? Colors.grey[700]!
            : Colors.grey[400]!;
    final buttonGradient = LinearGradient(
      colors: [
        theme.brightness == Brightness.light ? Colors.blue : Colors.blue[800]!,
        theme.brightness == Brightness.light ? Colors.blue[700]! : Colors.blue,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundColor, theme.scaffoldBackgroundColor],
          ),
        ),
        child: Stack(
          children: [
            // Subtle Top Wave Shape
            Positioned(
              top: 0,
              child: ClipPath(
                clipper: TopWaveClipper(),
                child: Container(
                  width: screenWidth,
                  height: 120,
                  color: waveColor,
                ),
              ),
            ),

            // PageView
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: onboardingData.length,
              itemBuilder: (context, index) {
                return SingleOnboardingScreen(
                  title: onboardingData[index]["title"]!,
                  subtitle: onboardingData[index]["subtitle"]!,
                  image: onboardingData[index]["image"]!,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                );
              },
            ),

            // Animated Dot Indicator
            Positioned(
              bottom: screenHeight * 0.12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  onboardingData.length,
                  (index) => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 6),
                    width: _currentPage == index ? 24 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color:
                          _currentPage == index
                              ? Colors.blue[600]
                              : Colors.grey[400]!.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),

            // Animated Gradient Button
            Positioned(
              bottom: screenHeight * 0.04,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _buttonAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _buttonAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          gradient: buttonGradient,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              horizontal: 50,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: Text(
                            _currentPage == onboardingData.length - 1
                                ? "Get Started"
                                : "Next",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: screenHeight * 0.45,
            child: Lottie.asset(image, fit: BoxFit.contain, repeat: true),
          ),
          SizedBox(height: 30),
          Text(
            title,
            style: TextStyle(
              fontSize: screenWidth < 400 ? 30 : 36,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: screenWidth < 400 ? 16 : 18,
              color: subtitleColor,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Custom Clipper for Subtle Top Wave Shape
class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.9,
      size.width * 0.5,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.5,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
