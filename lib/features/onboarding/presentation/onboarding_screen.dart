import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vybin/app.dart';
import 'package:vybin/features/auth/presentation/login_screen.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

/// Navigation action that completes onboarding and routes the user to the Login screen.
Future<void> completeOnboarding(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('is_first_launch', false);

  if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // Allow the pushReplacement transition to complete before swapping the root MaterialApp builder
  Future.delayed(const Duration(milliseconds: 300), () {
    VybinApp.onboardingCompleteNotifier.value = true;
  });
}

/// Alias to support alternative naming conventions requested in specifications
typedef StatefulOnboardingScreen = OnboardingScreen;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? VybinTheme.darkCharcoal : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF075E54);
    final secondaryTextColor = isDark ? VybinTheme.secondaryText : Colors.grey[700]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top-right corner Skip button (hidden on the final slide)
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0, right: 16.0),
                  child: _currentPage < 2
                      ? TextButton(
                          onPressed: () => completeOnboarding(context),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: VybinTheme.whatsappGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),

            // Center PageView builder
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 3,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          // Visual element based on the current slide
                          _buildSlideVisual(index),
                          const SizedBox(height: 32),

                          // Slide Title
                          Text(
                            _getSlideTitle(index),
                            style: TextStyle(
                              fontFamily: 'System',
                              fontWeight: FontWeight.w900,
                              fontSize: 24.0,
                              letterSpacing: 1.2,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),

                          // Slide Subtitle
                          Text(
                            _getSlideSubtitle(index),
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 15.0,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Row: Dots indicators and button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Smooth, animated dot indicators
                  Row(
                    children: List.generate(
                      3,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? VybinTheme.whatsappGreen
                              : Colors.grey.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Floating Navigation Button
                  _currentPage == 2
                      ? AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: VybinTheme.whatsappGreen.withOpacity(0.3 + 0.2 * _animationController.value),
                                    blurRadius: 10 + 5 * _animationController.value,
                                    spreadRadius: 1 + 2 * _animationController.value,
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: ElevatedButton(
                            onPressed: () => completeOnboarding(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VybinTheme.whatsappGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Generate Keys & Start',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VybinTheme.whatsappGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideVisual(int index) {
    if (index == 0) {
      // Slide 1: Padlock inside a circular ring with glowing accents
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VybinTheme.whatsappGreen.withOpacity(0.05),
              border: Border.all(
                color: VybinTheme.whatsappGreen.withOpacity(0.1 + 0.2 * _animationController.value),
                width: 2 + 2 * _animationController.value,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.lock_person,
              size: 70 + 5 * _animationController.value,
              color: VybinTheme.whatsappGreen,
            ),
          );
        },
      );
    } else if (index == 1) {
      // Slide 2: Two interconnected chat bubbles displaying cyphertext/encryption patterns
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            width: 140,
            height: 140,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(-14 + 4 * _animationController.value, -10),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 60,
                    color: VybinTheme.whatsappGreen,
                  ),
                ),
                Transform.translate(
                  offset: Offset(14 - 4 * _animationController.value, 10),
                  child: Icon(
                    Icons.enhanced_encryption,
                    size: 64,
                    color: VybinTheme.whatsappGreen.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Slide 3: Circular transparent logo.png alongside a neon rocket indicator or glowing verification badge
      return Container(
        width: 140,
        height: 140,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60.0,
              height: 60.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.asset(
                'assets/images/logo_dark.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.chat_bubble,
                    size: 60,
                    color: VybinTheme.whatsappGreen,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -8 * _animationController.value),
                  child: Icon(
                    Icons.rocket_launch,
                    size: 56,
                    color: Colors.orangeAccent.withOpacity(0.8 + 0.2 * _animationController.value),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  String _getSlideTitle(int index) {
    switch (index) {
      case 0:
        return 'Your Space, Your Keys';
      case 1:
        return 'Absolute Privacy';
      case 2:
        return 'Vibe Securely';
      default:
        return '';
    }
  }

  String _getSlideSubtitle(int index) {
    switch (index) {
      case 0:
        return 'VYBIN generates your personal RSA-2048 cryptographic identity directly on your device. Absolutely zero-trust required.';
      case 1:
        return 'Verify peer public keys locally and send chats knowing no intermediary—not even our servers—can ever decrypt them.';
      case 2:
        return 'Your keys are ready to be generated. Let\'s step into the next era of simple, secure, and private messaging.';
      default:
        return '';
    }
  }
}
