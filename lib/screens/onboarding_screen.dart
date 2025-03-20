import 'package:flutter/material.dart';
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
  late Animation<double> _fadeAnimation;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Quality Food",
      "subtitle": "Restaurant-grade meals with home-cooked warmth.",
      "image": "assets/images/shield.json",
    },
    {
      "title": "Fast Delivery",
      "subtitle": "Fresh meals delivered right to your door.",
      "image": "assets/images/food_delivery.json",
    },
    {
      "title": "Healthy Choices",
      "subtitle": "Fresh ingredients, hygienic preparation.",
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
    const textColor = Colors.white; // Fixed for grey[900] background
    const subtitleColor = Colors.grey; // Fixed for grey[900] background

    return Scaffold(
      backgroundColor: Colors.grey[900], // Fixed background color
      body: SafeArea(
        child: Stack(
          children: [
            // PageView
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
            // Minimal Dot Indicator
            Positioned(
              bottom: 90,
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
            // Next/Get Started Button
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
                    color: Colors.blue,
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
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Skip Button
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 60),
          Container(
            height: screenHeight * 0.35,
            child: Lottie.asset(image, fit: BoxFit.contain, repeat: true),
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
