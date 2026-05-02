import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';

class MiniGameScreen extends StatefulWidget {
  const MiniGameScreen({super.key});

  @override
  State<MiniGameScreen> createState() => _MiniGameScreenState();
}

class _MiniGameScreenState extends State<MiniGameScreen> {
  int _score = 0;
  double _playerX = 0;
  List<Point> _items = [];
  Timer? _timer;
  bool _isPlaying = false;

  void _startGame() {
    setState(() {
      _score = 0;
      _items = [];
      _isPlaying = true;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _updateGame();
    });
  }

  void _updateGame() {
    setState(() {
      for (var item in _items) {
        item.y += 0.02;
      }

      _items.removeWhere((item) {
        if (item.y > 0.8 && (item.x - _playerX).abs() < 0.2) {
          _score++;
          return true;
        }
        return item.y > 1.0;
      });

      if (Random().nextDouble() < 0.05) {
        _items.add(Point(Random().nextDouble() * 2 - 1, -1.0));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Focus Collector', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _playerX += details.delta.dx / (MediaQuery.of(context).size.width / 2);
            _playerX = _playerX.clamp(-1.0, 1.0);
          });
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.background, AppTheme.secondary.withOpacity(0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              if (!_isPlaying)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, size: 80, color: Colors.orangeAccent),
                      const SizedBox(height: 20),
                      Text('Collect the Bolts!', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 10),
                      Text('Catch them to stay focused.', style: TextStyle(color: AppTheme.onSurface.withOpacity(0.5))),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _startGame,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                        child: const Text('Start Focus Session'),
                      ),
                    ],
                  ),
                )
              else
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Score: $_score',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ),
                ),
              ..._items.map((item) => Align(
                alignment: Alignment(item.x, item.y),
                child: const Icon(Icons.bolt, color: Colors.orangeAccent, size: 30),
              )),
              Align(
                alignment: Alignment(_playerX, 0.9),
                child: Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Point {
  double x;
  double y;
  Point(this.x, this.y);
}
