import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';

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
      "title": "Welcome to Eazy Meals",
      "subtitle": "Your personalized meal service",
      "image": "assets/images/on1.png",
    },
    {
      "title": "Choose Your Plan",
      "subtitle": "Select from 1-week, 2-week, or 4-week meal plans.",
      "image": "assets/images/on2.png",
    },
    {
      "title": "Get Started",
      "subtitle": "Login or sign up to start your food journey.",
      "image": "assets/images/on1.png",
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _buttonAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
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
        curve: Curves.ease,
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

    // Define colors based on the current theme
    final backgroundColor =
        theme.brightness == Brightness.light
            ? Colors.lightBlue[100]!
            : Colors.grey[900]!;
    final waveColor =
        theme.brightness == Brightness.light
            ? Colors.blue.withAlpha(51)
            : Colors.blue.withAlpha(26);
    final textColor =
        theme.brightness == Brightness.light ? Colors.black : Colors.white;
    final subtitleColor =
        theme.brightness == Brightness.light
            ? Colors.grey[800]
            : Colors.grey[300];
    final buttonColor =
        theme.brightness == Brightness.light ? Colors.blue : Colors.blue[700]!;

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
            // Top Wave Shape
            Positioned(
              top: 0,
              child: ClipPath(
                clipper: TopWaveClipper(),
                child: Container(
                  width: screenWidth,
                  height: 150,
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
                  subtitleColor: subtitleColor!,
                );
              },
            ),

            // Bottom Wave Shape
            Positioned(
              bottom: 0,
              child: ClipPath(
                clipper: BottomWaveClipper(),
                child: Container(
                  width: screenWidth,
                  height: 100,
                  color: waveColor,
                ),
              ),
            ),

            // Dots Indicator
            Positioned(
              bottom: screenHeight * 0.15,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  onboardingData.length,
                  (index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _currentPage == index
                              ? buttonColor
                              : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ),

            // Animated Button
            Positioned(
              bottom: screenHeight * 0.05,
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
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: buttonColor.withAlpha(
                                77,
                              ), // 0.3 * 255 = 76.5 ≈ 77
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            padding: EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                          ),
                          child: Text(
                            _currentPage == onboardingData.length - 1
                                ? "Get Started"
                                : "Next",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: screenHeight * 0.4,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(image),
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: 40),
          Text(
            title,
            style: TextStyle(
              fontSize: screenWidth < 400 ? 28 : 34,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: screenWidth < 400 ? 16 : 18,
              color: subtitleColor,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Custom Clipper for Top Wave Shape
class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.6,
      size.width * 0.5,
      size.height * 0.8,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height,
      size.width,
      size.height * 0.8,
    );
    path.lineTo(size.width, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Custom Clipper for Bottom Wave Shape
class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.4,
      size.width * 0.5,
      size.height,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.6,
      size.width,
      size.height,
    );
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
