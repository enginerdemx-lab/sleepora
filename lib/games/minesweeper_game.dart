import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../services/ad_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/login_screen.dart';
import '../services/localization_service.dart';
import 'minesweeper/minesweeper_config.dart';
import 'minesweeper/minesweeper_progress_service.dart';
import 'minesweeper/minesweeper_tutorial.dart';

/// Mayın Tarlası — seviye bazlı mod.
class MinesweeperGame extends StatefulWidget {
  final int level;
  const MinesweeperGame({super.key, this.level = 1});

  @override
  State<MinesweeperGame> createState() => _MinesweeperGameState();
}

class _MinesweeperGameState extends State<MinesweeperGame> {
  late MinesweeperLevelConfig _config;
  final _progress = MinesweeperProgressService();

  int get rows => _config.rows;
  int get cols => _config.cols;
  int get mineCount => _config.mines;
  int get timeLimit => _config.timeLimit;

  late List<List<_Cell>> _grid;
  bool _gameOver = false;
  bool _won = false;
  bool _timeUp = false;
  int _flagCount = 0;
  int _revealedCount = 0;
  int _remaining = 0; // kalan saniye
  int _elapsed = 0;
  bool _firstTap = true;
  bool _rewardShown = false;
  int _earnedCoins = 0;
  int _starsEarned = 0;

  Timer? _timer;

  MinesweeperTheme get _theme =>
      MinesweeperThemes.byId(_progress.activeTheme);

  @override
  void initState() {
    super.initState();
    _config = MinesweeperLevelConfig.forLevel(widget.level);
    _remaining = timeLimit;
    _progress.addListener(_onProgressChange);
    _initGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progress.removeListener(_onProgressChange);
    super.dispose();
  }

  void _onProgressChange() {
    if (mounted) setState(() {});
  }

  void _initGame() {
    _grid = List.generate(rows, (r) => List.generate(cols, (c) => _Cell()));
    _gameOver = false;
    _won = false;
    _timeUp = false;
    _flagCount = 0;
    _revealedCount = 0;
    _elapsed = 0;
    _remaining = timeLimit;
    _firstTap = true;
    _rewardShown = false;
    _earnedCoins = 0;
    _starsEarned = 0;
    _timer?.cancel();
  }

  /// Belirli (r,c) hücresine mayın YERLEŞTIRMEDEN mayınları dağıt.
  /// İlk tıklamada çağrılır, böylece ilk kare her zaman güvenli olur.
  void _placeMines(int safeR, int safeC) {
    final rng = Random();
    int placed = 0;
    while (placed < mineCount) {
      final r = rng.nextInt(rows);
      final c = rng.nextInt(cols);
      if (_grid[r][c].isMine) continue;
      // İlk tıklanan karenin çevresine mayın koyma (3x3 güvenli alan)
      if ((r - safeR).abs() <= 1 && (c - safeC).abs() <= 1) continue;
      _grid[r][c].isMine = true;
      placed++;
    }

    // Komşu mayın sayılarını hesapla
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_grid[r][c].isMine) {
          int count = 0;
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              final nr = r + dr, nc = c + dc;
              if (nr >= 0 &&
                  nr < rows &&
                  nc >= 0 &&
                  nc < cols &&
                  _grid[nr][nc].isMine) {
                count++;
              }
            }
          }
          _grid[r][c].adjacentMines = count;
        }
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _gameOver) return;
      setState(() {
        _elapsed++;
        _remaining = (timeLimit - _elapsed).clamp(0, timeLimit);
        if (_remaining == 0) {
          _gameOver = true;
          _won = false;
          _timeUp = true;
          _revealAllMines();
        }
      });
    });
  }

  void _revealAllMines() {
    for (var row in _grid) {
      for (var cell in row) {
        if (cell.isMine) cell.isRevealed = true;
      }
    }
  }

  void _reveal(int r, int c) {
    if (_gameOver || _grid[r][c].isRevealed || _grid[r][c].isFlagged) return;

    if (_firstTap) {
      _placeMines(r, c);
      _firstTap = false;
      _startTimer();
    }

    setState(() {
      if (_grid[r][c].isMine) {
        HapticFeedback.heavyImpact();
        _gameOver = true;
        _won = false;
        _revealAllMines();
        return;
      }

      _floodReveal(r, c);
      _checkWin();
    });
  }

  void _floodReveal(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;
    if (_grid[r][c].isRevealed ||
        _grid[r][c].isFlagged ||
        _grid[r][c].isMine) return;

    _grid[r][c].isRevealed = true;
    _revealedCount++;

    if (_grid[r][c].adjacentMines == 0) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          _floodReveal(r + dr, c + dc);
        }
      }
    }
  }

  void _toggleFlag(int r, int c) {
    if (_gameOver || _grid[r][c].isRevealed) return;
    HapticFeedback.lightImpact();
    setState(() {
      _grid[r][c].isFlagged = !_grid[r][c].isFlagged;
      _flagCount += _grid[r][c].isFlagged ? 1 : -1;
    });
  }

  void _checkWin() async {
    final totalSafe = rows * cols - mineCount;
    if (_revealedCount >= totalSafe) {
      _gameOver = true;
      _won = true;
      _timer?.cancel();
      HapticFeedback.mediumImpact();
      _submitScore();
      // Seviye tamamlama — coin/yıldız kaydı
      final coins = await _progress.completeLevel(
        level: widget.level,
        timeSeconds: _elapsed,
        timeLimit: timeLimit,
      );
      final stars = _progress.stars(widget.level);
      if (mounted) {
        setState(() {
          _earnedCoins = coins;
          _starsEarned = stars;
          _rewardShown = true;
        });
      }
    }
  }

  Future<void> _submitScore() async {
    if (!_won) return;
    final auth = AuthService();
    if (!auth.isLoggedIn || auth.uid == null) return;
    try {
      await LeaderboardService().submitScore(
        gameId: 'minesweeper',
        uid: auth.uid!,
        displayName: auth.displayName ?? 'Anonim',
        score: _elapsed,
        higherIsBetter: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService().t('ScoreSaved')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.purple,
        ),
      );
    } catch (e) {
      debugPrint('❌ Minesweeper submitScore hatası: $e');
    }
  }

  Future<void> _promptLoginAndSubmit() async {
    HapticFeedback.selectionClick();
    final ok = await LoginScreen.show(context, feature: 'Skor Tablosu');
    if (!ok || !mounted) return;
    await _submitScore();
    if (mounted) setState(() {});
  }

  void _restart() {
    setState(() => _initGame());
  }

  void _showTutorial() {
    MinesweeperTutorial.show(context);
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final lowTime = _remaining <= (timeLimit * 0.2).ceil();
    final flagsLeft = mineCount - _flagCount;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Seviye ${widget.level}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: LocalizationService().t('GameHowToPlay'),
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Colors.white,
            ),
            onPressed: _showTutorial,
          ),
          IconButton(
            tooltip: LocalizationService().t('GameRestart'),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _restart,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ─── Üst bilgi bar ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.flag_rounded,
                      label: 'Bayrak',
                      value: '$flagsLeft / $mineCount',
                      color: theme.flagColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeCard(
                      remaining: _remaining,
                      total: timeLimit,
                      lowTime: lowTime,
                      formatter: _formatTime,
                      accent: theme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.grid_view_rounded,
                      label: 'Grid',
                      value: '$rows×$cols',
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Oyun alanı ───
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AspectRatio(
                    aspectRatio: cols / rows,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.accent.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: rows * cols,
                        itemBuilder: (context, index) {
                          final r = index ~/ cols;
                          final c = index % cols;
                          final cell = _grid[r][c];
                          return _buildCell(cell, r, c, theme);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Oyun sonu paneli ───
            if (_gameOver) _buildEndPanel(theme),
            const SizedBox(height: 8),

            // ─── Sabit alt banner (oyun ekranında da görünüyor) ───
            if (AdService().adsEnabled) ...[
              const Center(child: BannerAdWidget(slot: BannerSlot.minesweeperMenu)),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCell(_Cell cell, int r, int c, MinesweeperTheme theme) {
    Color bg;
    Widget? child;

    if (cell.isRevealed) {
      if (cell.isMine) {
        bg = theme.cellMine;
        child = Icon(
          Icons.brightness_7_rounded,
          color: theme.mineColor,
          size: 18,
        );
      } else {
        bg = theme.cellRevealed;
        if (cell.adjacentMines > 0) {
          child = Text(
            '${cell.adjacentMines}',
            style: TextStyle(
              color: theme.numberColor(cell.adjacentMines),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          );
        }
      }
    } else if (cell.isFlagged) {
      bg = theme.cellCovered;
      child = Icon(
        Icons.flag_rounded,
        color: theme.flagColor,
        size: 16,
      );
    } else {
      bg = theme.cellCovered;
    }

    return GestureDetector(
      onTap: () => _reveal(r, c),
      onLongPress: () => _toggleFlag(r, c),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.borderColor, width: 0.5),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildEndPanel(MinesweeperTheme theme) {
    final won = _won;
    final titleColor = Colors.white;
    final loc = LocalizationService();
    final title = won
        ? loc.t('GameCongrats')
        : _timeUp
            ? loc.t('MSTimeUp')
            : loc.t('MSMineHit');
    final subtitle = won ? '${loc.t('MSTimeLabel')}: ${_formatTime(_elapsed)}' : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: won
              ? [
                  theme.accentGradient.first.withValues(alpha: 0.9),
                  theme.accentGradient.last.withValues(alpha: 0.9),
                ]
              : [
                  const Color(0xFF7F1D1D).withValues(alpha: 0.9),
                  const Color(0xFF991B1B).withValues(alpha: 0.9),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (won ? theme.accent : const Color(0xFFEF4444)).withValues(
              alpha: 0.35,
            ),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                won
                    ? Icons.emoji_events_rounded
                    : _timeUp
                        ? Icons.timer_off_rounded
                        : Icons.sentiment_dissatisfied_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (won && _rewardShown) ...[
            const SizedBox(height: 14),
            // Yıldızlar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < _starsEarned;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    duration: Duration(milliseconds: 300 + i * 120),
                    scale: filled ? 1.0 : 0.7,
                    child: Icon(
                      filled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: filled
                          ? const Color(0xFFFFD700)
                          : Colors.white.withValues(alpha: 0.4),
                      size: 36,
                      shadows: filled
                          ? [
                              const BoxShadow(
                                color: Color(0xFFFFD700),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            // Coin ödülü
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+$_earnedCoins',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            // ─── Giriş yapılmamışsa: skor kaydetme CTA'sı ───
            if (!AuthService().isLoggedIn) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _promptLoginAndSubmit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          const Color(0xFFFBBF24).withValues(alpha: 0.55),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: Color(0xFFFBBF24), size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          LocalizationService()
                              .t('LeaderboardLoginRequired'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white70, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _restart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Tekrar Oyna',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (won && widget.level < 100 && _progress.maxUnlocked > widget.level)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MinesweeperGame(
                            level: widget.level + 1,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Sonraki',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Seviyeler',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!won) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaderboardScreen(
                    initialGameId: 'minesweeper',
                  ),
                ),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.leaderboard_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Skor Tablosu',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cell {
  bool isMine = false;
  bool isRevealed = false;
  bool isFlagged = false;
  int adjacentMines = 0;
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final int remaining;
  final int total;
  final bool lowTime;
  final String Function(int) formatter;
  final Color accent;

  const _TimeCard({
    required this.remaining,
    required this.total,
    required this.lowTime,
    required this.formatter,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    final color = lowTime ? const Color(0xFFEF4444) : const Color(0xFF60A5FA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lowTime
              ? color.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_rounded, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                formatter(remaining),
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
