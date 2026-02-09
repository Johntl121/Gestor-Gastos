import 'package:flutter/material.dart';
import 'onboarding_page.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      "icon": Icons.radar,
      "color": Colors.purpleAccent,
      "title": "Adiós al '¿En qué se me fue?'",
      "subtitle":
          "Rastrea tus gastos en segundos. Control total sobre cada centavo."
    },
    {
      "icon": Icons.rocket_launch,
      "color": Colors.orangeAccent,
      "title": "Ahorra con Propósito",
      "subtitle":
          "Define tus metas y mira cómo crecen. Tu próximo sueño está más cerca."
    },
    {
      "icon": Icons.diamond,
      "color": Colors.cyanAccent,
      "title": "Tu Billetera, Reinventada",
      "subtitle":
          "Simple, segura y elegante. Toma el mando de tus finanzas hoy."
    }
  ];

  void _onSkip() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OnboardingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Slide Content
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Floating Icon
                      TweenAnimationBuilder<double>(
                        duration: const Duration(seconds: 2),
                        tween: Tween(begin: 0, end: 10),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(
                                0,
                                value *
                                    (index % 2 == 0
                                        ? 1
                                        : -1)), // Simple float effect
                            child: Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (slide["color"] as Color)
                                      .withOpacity(0.1),
                                  boxShadow: [
                                    BoxShadow(
                                        color: (slide["color"] as Color)
                                            .withOpacity(0.2),
                                        blurRadius: 40,
                                        spreadRadius: 10)
                                  ]),
                              child: Icon(slide["icon"],
                                  size: 100, color: slide["color"]),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 60),
                      Text(
                        slide["title"],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        slide["subtitle"],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 16, height: 1.5),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Skip Button
            Positioned(
              top: 20,
              right: 20,
              child: TextButton(
                onPressed: _onSkip,
                child: Text("Saltar",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 30 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color:
                              isActive ? Colors.cyanAccent : Colors.grey[800],
                          borderRadius: BorderRadius.circular(5),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 30),

                  // Start Button (Only on last slide)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _currentPage == _slides.length - 1 ? 1 : 0,
                    child: PointerInterceptor(
                      // Disable hits if hidden
                      intercepting: _currentPage != _slides.length - 1,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Colors.cyanAccent, Colors.blueAccent]),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 5))
                            ]),
                        child: ElevatedButton(
                          onPressed: _currentPage == _slides.length - 1
                              ? _onSkip
                              : null,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30))),
                          child: const Text(
                            "¡Empezar Ahora!",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// Helper mainly for opacity ignoring hits (simplified version)
class PointerInterceptor extends StatelessWidget {
  final bool intercepting;
  final Widget child;
  const PointerInterceptor(
      {super.key, required this.intercepting, required this.child});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(ignoring: intercepting, child: child);
  }
}
