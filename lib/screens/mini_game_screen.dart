import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import '../services/sensor_service.dart';

class MiniGameScreen extends StatefulWidget {
  const MiniGameScreen({super.key});

  @override
  State<MiniGameScreen> createState() => _MiniGameScreenState();
}

class _MiniGameScreenState extends State<MiniGameScreen> {
  static const int _maxMissedItems = 5;
  static const int _sessionSeconds = 30;

  // ── Game state ─────────────────────────────────────────────────────────────
  int _score = 0;
  int _highScore = 0;
  int _missedItems = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _timeLeft = _sessionSeconds;
  int _tick = 0;
  double _playerX = 0;
  double _fallSpeed = 0.018;
  double _spawnChance = 0.045;
  bool _isPlaying = false;
  bool _showGlow = false;
  String? _feedbackText;
  List<GameItem> _items = [];
  Timer? _timer;

  // ── Gyro state ─────────────────────────────────────────────────────────────
  bool _gyroEnabled = false;
  StreamSubscription<double>? _gyroSub;

  // Sensitivitas: gyro Y (rad/s) × nilai ini per event (~100Hz).
  // 0.018 → bar menempuh full range dalam ~1.1 detik pada tilt 1 rad/s.
  static const double _gyroSensitivity = 0.018;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
  }

  // ── Gyro helpers ───────────────────────────────────────────────────────────

  void _startGyroListen() {
    _gyroSub?.cancel();
    _gyroSub = SensorService.onGyroRaw.listen((yRate) {
      if (!_isPlaying) return;
      setState(() {
        // event.y positif = tilt kanan, negatif = tilt kiri
        // +yRate: tilt kanan → bar ke kanan, tilt kiri → bar ke kiri
        _playerX = (_playerX + yRate * _gyroSensitivity).clamp(-1.0, 1.0);
      });
    });
  }

  void _stopGyroListen() {
    _gyroSub?.cancel();
    _gyroSub = null;
  }

  void _toggleGyro() {
    setState(() => _gyroEnabled = !_gyroEnabled);
    if (_gyroEnabled && _isPlaying) {
      _startGyroListen();
    } else {
      _stopGyroListen();
    }
  }

  // ── Score persistence ──────────────────────────────────────────────────────

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _highScore = prefs.getInt('mini_game_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScoreIfNeeded() async {
    if (_score <= _highScore) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mini_game_high_score', _score);
    if (!mounted) return;
    setState(() => _highScore = _score);
  }

  // ── Game lifecycle ─────────────────────────────────────────────────────────

  void _startGame() {
    _timer?.cancel();
    _stopGyroListen();

    setState(() {
      _score = 0;
      _missedItems = 0;
      _combo = 0;
      _bestCombo = 0;
      _timeLeft = _sessionSeconds;
      _tick = 0;
      _playerX = 0;
      _fallSpeed = 0.018;
      _spawnChance = 0.045;
      _isPlaying = true;
      _showGlow = false;
      _feedbackText = null;
      _items = [];
    });

    if (_gyroEnabled) _startGyroListen();

    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateGame();
    });
  }

  void _updateGame() {
    if (!_isPlaying) return;

    _tick++;
    var missedThisTick = 0;
    var shouldEndGame = false;

    setState(() {
      if (_tick % 20 == 0 && _timeLeft > 0) _timeLeft--;

      if (_tick % 80 == 0) {
        _fallSpeed = min(_fallSpeed + 0.003, 0.05);
        _spawnChance = min(_spawnChance + 0.005, 0.12);
      }

      for (final item in _items) {
        item.y += _fallSpeed * item.speedFactor;
      }

      _items.removeWhere((item) {
        if (item.y > 0.8 && (item.x - _playerX).abs() < 0.2) {
          _handleCaughtItem(item);
          return true;
        }
        if (item.y > 1.0) {
          if (item.kind != ItemKind.distraksi) {
            missedThisTick++;
            _combo = 0;
          }
          return true;
        }
        return false;
      });

      _missedItems += missedThisTick;

      if (Random().nextDouble() < _spawnChance) {
        _items.add(GameItem.spawn());
      }

      if (_missedItems >= _maxMissedItems || _timeLeft <= 0) {
        shouldEndGame = true;
      }
    });

    if (shouldEndGame) _endGame();
  }

  void _handleCaughtItem(GameItem item) {
    switch (item.kind) {
      case ItemKind.focus:
        _combo++;
        _bestCombo = max(_bestCombo, _combo);
        final points = _combo >= 6 ? 3 : _combo >= 3 ? 2 : 1;
        _score += points;
        _flashFeedback(_combo >= 3 ? 'Combo x$points!' : 'Nice!', glow: true);
        break;
      case ItemKind.boost:
        _combo++;
        _bestCombo = max(_bestCombo, _combo);
        _score += 5;
        _flashFeedback('Task Boost +5', glow: true);
        break;
      case ItemKind.distraksi:
        _combo = 0;
        _missedItems = min(_missedItems + 1, _maxMissedItems);
        _flashFeedback('Distraksi!', glow: false);
        break;
    }
  }

  void _flashFeedback(String text, {required bool glow}) {
    _feedbackText = text;
    _showGlow = glow;
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || !_isPlaying) return;
      setState(() {
        if (_feedbackText == text) {
          _feedbackText = null;
          _showGlow = false;
        }
      });
    });
  }

  void _endGame() {
    _timer?.cancel();
    _stopGyroListen();
    _saveHighScoreIfNeeded();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _showGlow = false;
      _feedbackText = _timeLeft <= 0 ? 'Waktu habis!' : 'Fokus pecah!';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopGyroListen();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          'Focus Collector',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          // ── Toggle gyro ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _toggleGyro,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _gyroEnabled
                      ? AppTheme.secondary.withValues(alpha: 0.15)
                      : AppTheme.outline.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _gyroEnabled
                        ? AppTheme.secondary.withValues(alpha: 0.4)
                        : AppTheme.outline.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.screen_rotation_alt_outlined,
                      size: 16,
                      color: _gyroEnabled ? AppTheme.secondary : AppTheme.outline,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _gyroEnabled ? 'Gyro ON' : 'Gyro OFF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _gyroEnabled ? AppTheme.secondary : AppTheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        // Drag hanya aktif saat gyro nonaktif
        onHorizontalDragUpdate: _gyroEnabled
            ? null
            : (details) {
                setState(() {
                  _playerX += details.delta.dx /
                      (MediaQuery.of(context).size.width / 2);
                  _playerX = _playerX.clamp(-1.0, 1.0);
                });
              },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.surface,
                const Color(0xFFFFF1D6),
                AppTheme.secondary.withValues(alpha: 0.08),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // ── Pre-game / post-game screen ────────────────────────────
              if (!_isPlaying)
                Center(
                  child: SingleChildScrollView(
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orangeAccent.withValues(alpha: 0.2),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.psychology_alt_outlined,
                            size: 72,
                            color: Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Tangkap Fokus, Hindari Distraksi',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _score > 0 || _missedItems > 0
                              ? 'Sesi selesai. Skor kamu $_score.'
                              : 'Kumpulkan Focus Point dan Task Boost.\nJangan sentuh Distraksi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.onSurface.withValues(alpha: 0.55),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'High Score: $_highScore',
                          style: const TextStyle(
                            color: AppTheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Durasi $_sessionSeconds detik • Maksimal lolos: $_maxMissedItems',
                          style: TextStyle(
                            color: AppTheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        if (_score > 0 || _missedItems > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Best Combo: $_bestCombo',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),

                        // ── Legend ─────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            children: [
                              _LegendRow(
                                icon: Icons.bolt_rounded,
                                label: 'Focus Point',
                                color: Colors.orangeAccent,
                              ),
                              SizedBox(height: 8),
                              _LegendRow(
                                icon: Icons.star_rounded,
                                label: 'Task Boost +5',
                                color: Colors.amber,
                              ),
                              SizedBox(height: 8),
                              _LegendRow(
                                icon: Icons.notifications_active_rounded,
                                label: 'Distraksi',
                                color: Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Gyro toggle card ───────────────────────────────
                        GestureDetector(
                          onTap: _toggleGyro,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: _gyroEnabled
                                  ? AppTheme.secondary.withValues(alpha: 0.1)
                                  : Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _gyroEnabled
                                    ? AppTheme.secondary.withValues(alpha: 0.35)
                                    : AppTheme.outline.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.screen_rotation_alt_outlined,
                                  color: _gyroEnabled
                                      ? AppTheme.secondary
                                      : AppTheme.outline,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kontrol Gyroscope',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _gyroEnabled
                                              ? AppTheme.secondary
                                              : AppTheme.onSurface,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        _gyroEnabled
                                            ? 'Aktif — miringkan HP untuk gerakkan bar'
                                            : 'Nonaktif — geser layar untuk gerakkan bar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _gyroEnabled,
                                  onChanged: (_) => _toggleGyro(),
                                  activeThumbColor: AppTheme.secondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: _startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondary,
                          ),
                          child: Text(
                            _score > 0 || _missedItems > 0
                                ? 'Main Lagi'
                                : 'Mulai Focus Session',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

              // ── In-game score display ──────────────────────────────────
              if (_isPlaying)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Center(
                        child: Text(
                          'Score: $_score',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
              // ── In-game feedback text ──────────────────────────────────
              if (_isPlaying && _feedbackText != null)
                Center(
                  child: AnimatedOpacity(
                    opacity: _feedbackText == null ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (_showGlow ? Colors.orangeAccent : Colors.redAccent).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Text(
                        _feedbackText!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _showGlow
                              ? Colors.orangeAccent
                              : Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── In-game stat pills ─────────────────────────────────────
              if (_isPlaying)
                Positioned(
                  top: 90,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: Row(
                    children: [
                      Expanded(
                        child: _StatPill(
                          text: 'Waktu: $_timeLeft s',
                          color: AppTheme.primary,
                          icon: Icons.timer_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatPill(
                          text: 'Combo: x$_combo',
                          color: Colors.orangeAccent,
                          icon: Icons.local_fire_department_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatPill(
                          text: 'Miss: $_missedItems/$_maxMissedItems',
                          color: AppTheme.secondary,
                          icon: Icons.flash_off_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Gyro active indicator (in-game) ────────────────────────
              if (_isPlaying && _gyroEnabled)
                Positioned(
                  top: 135,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppTheme.secondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.screen_rotation_alt_outlined,
                            size: 12,
                            color: AppTheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Gyro — miringkan HP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Falling items ──────────────────────────────────────────
              ..._items.map(
                (item) => Align(
                  alignment: Alignment(item.x, item.y),
                  child: Icon(item.icon, color: item.color, size: item.size),
                ),
              ),

              // ── Player bar ─────────────────────────────────────────────
              if (_isPlaying)
                Align(
                  alignment: Alignment(_playerX, 0.9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: 92,
                  height: 14,
                  decoration: BoxDecoration(
                    color:
                        _showGlow ? Colors.orangeAccent : AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (_showGlow
                                ? Colors.orangeAccent
                                : AppTheme.primary)
                            .withValues(alpha: 0.38),
                        blurRadius: _showGlow ? 18 : 10,
                        offset: const Offset(0, 4),
                      ),
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

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _StatPill({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LegendRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Game model ─────────────────────────────────────────────────────────────────

enum ItemKind { focus, boost, distraksi }

class GameItem {
  double x;
  double y;
  final ItemKind kind;
  final IconData icon;
  final Color color;
  final double size;
  final double speedFactor;

  GameItem({
    required this.x,
    required this.y,
    required this.kind,
    required this.icon,
    required this.color,
    required this.size,
    required this.speedFactor,
  });

  factory GameItem.spawn() {
    final rng = Random();
    final roll = rng.nextDouble();

    if (roll < 0.12) {
      return GameItem(
        x: rng.nextDouble() * 2 - 1,
        y: -1.0,
        kind: ItemKind.boost,
        icon: Icons.star_rounded,
        color: Colors.amber,
        size: 34,
        speedFactor: 0.95,
      );
    }

    if (roll < 0.28) {
      return GameItem(
        x: rng.nextDouble() * 2 - 1,
        y: -1.0,
        kind: ItemKind.distraksi,
        icon: Icons.notifications_active_rounded,
        color: Colors.redAccent,
        size: 30,
        speedFactor: 1.15,
      );
    }

    return GameItem(
      x: rng.nextDouble() * 2 - 1,
      y: -1.0,
      kind: ItemKind.focus,
      icon: Icons.bolt_rounded,
      color: Colors.orangeAccent,
      size: 30,
      speedFactor: 1.0,
    );
  }
}