import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _onboardingData = [
    OnboardingData(
      title: 'Tak Terhentikan',
      description: 'Kuasai waktumu dengan pengingat intuitif dan tugas berbasis lokasi dari RemindMe+.',
      icon: Icons.rocket_launch,
      color: AppTheme.primary,
    ),
    OnboardingData(
      title: 'Asisten AI Mira',
      description: 'Dapatkan ringkasan harimu dan biarkan AI membantumu memprioritaskan hal yang paling penting.',
      icon: Icons.auto_awesome,
      color: AppTheme.secondary,
    ),
    OnboardingData(
      title: 'Kumpulkan Fokus',
      description: 'Ubah produktivitas menjadi permainan. Dapatkan hadiah saat kamu mencapai targetmu.',
      icon: Icons.sports_esports,
      color: Colors.orangeAccent,
    ),
  ];

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingData.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final data = _onboardingData[index];
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: data.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: data.color.withValues(alpha: 0.2), width: 2),
                          ),
                          child: data.icon == Icons.rocket_launch
                              ? Image.asset('assets/app_icon.png', width: 100, height: 100)
                              : Icon(data.icon, size: 100, color: data.color),
                        ),
                        const SizedBox(height: 50),
                        Text(
                          data.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          data.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.onSurface.withValues(alpha: 0.6),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? AppTheme.primary : AppTheme.outline.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _onboardingData.length - 1) {
                          _finishOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(
                        _currentPage == _onboardingData.length - 1 ? 'MULAI SEKARANG' : 'LANJUT',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
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
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
