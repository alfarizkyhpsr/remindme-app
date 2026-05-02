import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/app_icon.png'), context);
  }

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!hasSeenOnboarding) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Cek apakah sudah masuk (ada sesi)
    if (auth.sudahMasuk) {
      // Cek apakah sudah lebih dari 15 detik sejak aplikasi terakhir digunakan
      final perluAuth = await auth.periksaPerluAutentikasi();
      
      if (perluAuth) {
        if (auth.biometrikAktif) {
          final berhasil = await auth.autentikasiBiometrik();
          if (berhasil) {
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            // Jika gagal biometrik atau dibatalkan, lempar ke login
            await auth.keluar();
            Navigator.pushReplacementNamed(context, '/login');
          }
        } else {
          // Sesi kadaluarsa (> 15s) dan biometrik tidak aktif, paksa login ulang
          await auth.keluar();
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        // Kurang dari 15 detik, langsung masuk
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      // Belum ada sesi
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary,
              AppTheme.primaryContainer,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative shapes
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: Image.asset(
                      'assets/app_icon.png',
                      width: 80,
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'RemindMe+',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dibuat untuk Produktivitas',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: SpinKitThreeBounce(
                  color: Colors.white.withOpacity(0.6),
                  size: 25.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
