import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum Difficulty { easy, normal, hard }

class DifficultyConfig {
  final int rows;
  final int cols;
  final int mines;
  final String label;
  const DifficultyConfig({required this.rows, required this.cols, required this.mines, required this.label});

  static const configs = {
    Difficulty.easy: DifficultyConfig(rows: 8, cols: 6, mines: 6, label: 'Kolay'),
    Difficulty.normal: DifficultyConfig(rows: 10, cols: 8, mines: 12, label: 'Normal'),
    Difficulty.hard: DifficultyConfig(rows: 12, cols: 8, mines: 20, label: 'Zor'),
  };
}

class MinesweeperGame extends StatefulWidget {
  const MinesweeperGame({super.key});

  @override
  State<MinesweeperGame> createState() => _MinesweeperGameState();
}

class _MinesweeperGameState extends State<MinesweeperGame> {
  Difficulty _difficulty = Difficulty.normal;
  DifficultyConfig get _config => DifficultyConfig.configs[_difficulty]!;

  int get rows => _config.rows;
  int get cols => _config.cols;
  int get mineCount => _config.mines;

  late List<List<_Cell>> _grid;
  bool _gameOver = false;
  bool _won = false;
  int _flagCount = 0;
  int _revealedCount = 0;
  final _stopwatch = Stopwatch();
  int _elapsedSeconds = 0;
  int _hintsUsed = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    _grid = List.generate(rows, (r) => List.generate(cols, (c) => _Cell()));
    _gameOver = false;
    _won = false;
    _flagCount = 0;
    _revealedCount = 0;
    _elapsedSeconds = 0;
    _hintsUsed = 0;
    _stopwatch.reset();

    // Mayınları yerleştir
    final rng = Random();
    int placed = 0;
    while (placed < mineCount) {
      final r = rng.nextInt(rows);
      final c = rng.nextInt(cols);
      if (!_grid[r][c].isMine) {
        _grid[r][c].isMine = true;
        placed++;
      }
    }

    // Komşu mayın sayılarını hesapla
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_grid[r][c].isMine) {
          int count = 0;
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              final nr = r + dr, nc = c + dc;
              if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && _grid[nr][nc].isMine) {
                count++;
              }
            }
          }
          _grid[r][c].adjacentMines = count;
        }
      }
    }
    _stopwatch.start();
  }

  void _useHint() {
    if (_gameOver) return;

    // Güvenli, henüz açılmamış bir kare bul
    final safeCells = <List<int>>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_grid[r][c].isMine && !_grid[r][c].isRevealed && !_grid[r][c].isFlagged) {
          safeCells.add([r, c]);
        }
      }
    }
    if (safeCells.isEmpty) return;

    final pos = safeCells[Random().nextInt(safeCells.length)];
    setState(() {
      _hintsUsed++;
      _floodReveal(pos[0], pos[1]);
      _checkWin();
    });
  }

  void _changeDifficulty(Difficulty diff) {
    if (diff == _difficulty) return;
    setState(() {
      _difficulty = diff;
      _initGame();
    });
  }

  void _reveal(int r, int c) {
    if (_gameOver || _grid[r][c].isRevealed || _grid[r][c].isFlagged) return;

    setState(() {
      if (_grid[r][c].isMine) {
        _gameOver = true;
        _won = false;
        _stopwatch.stop();
        _elapsedSeconds = _stopwatch.elapsed.inSeconds;
        // Tüm mayınları göster
        for (var row in _grid) {
          for (var cell in row) {
            if (cell.isMine) cell.isRevealed = true;
          }
        }
        return;
      }

      _floodReveal(r, c);
      _checkWin();
    });
  }

  void _floodReveal(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;
    if (_grid[r][c].isRevealed || _grid[r][c].isFlagged || _grid[r][c].isMine) return;

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
    setState(() {
      _grid[r][c].isFlagged = !_grid[r][c].isFlagged;
      _flagCount += _grid[r][c].isFlagged ? 1 : -1;
    });
  }

  void _checkWin() {
    final totalSafe = rows * cols - mineCount;
    if (_revealedCount >= totalSafe) {
      _gameOver = true;
      _won = true;
      _stopwatch.stop();
      _elapsedSeconds = _stopwatch.elapsed.inSeconds;
    }
  }

  Color _numberColor(int n) {
    switch (n) {
      case 1: return const Color(0xFF60A5FA);
      case 2: return const Color(0xFF34D399);
      case 3: return const Color(0xFFEF4444);
      case 4: return const Color(0xFF8B5CF6);
      case 5: return const Color(0xFFF59E0B);
      default: return const Color(0xFFF472B6);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stopwatch.isRunning) {
      // Zamanlayıcıyı güncelle
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _stopwatch.isRunning) {
          setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mayın Tarlası', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Zorluk seçimi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: Difficulty.values.map((diff) {
                final config = DifficultyConfig.configs[diff]!;
                final isActive = _difficulty == diff;
                final isPremiumDiff = false;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _changeDifficulty(diff),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.purple.withValues(alpha:0.25) : Colors.white.withValues(alpha:0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive ? AppColors.purple.withValues(alpha:0.5) : Colors.white.withValues(alpha:0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(config.label, style: TextStyle(
                            color: isActive ? Colors.white : Colors.white.withValues(alpha:isPremiumDiff ? 0.35 : 0.6),
                            fontSize: 12, fontWeight: FontWeight.w600,
                          )),
                          if (isPremiumDiff) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.diamond_outlined, color: const Color(0xFF8B5CF6).withValues(alpha:0.7), size: 11),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 6),

          // Üst bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoChip(icon: Icons.flag_rounded, label: '${mineCount - _flagCount}', color: const Color(0xFFEF4444)),
                _InfoChip(icon: Icons.timer_rounded, label: '${_elapsedSeconds}s', color: const Color(0xFF60A5FA)),
                // İpucu butonu — premium
                GestureDetector(
                  onTap: _useHint,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha:0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: const Color(0xFF8B5CF6), size: 16),
                      ],
                    ),
                  ),
                ),
                // Yeniden başla
                GestureDetector(
                  onTap: () => setState(() => _initGame()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.purple.withValues(alpha:0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: AppColors.purple, size: 16),
                        const SizedBox(width: 4),
                        Text('Yeniden', style: TextStyle(color: AppColors.purple, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Oyun alanı
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: cols / rows,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1025),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha:0.06)),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(6),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: rows * cols,
                    itemBuilder: (context, index) {
                      final r = index ~/ cols;
                      final c = index % cols;
                      final cell = _grid[r][c];
                      return _buildCell(cell, r, c);
                    },
                  ),
                ),
              ),
            ),
          ),

          // Game Over / Win
          if (_gameOver)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _won
                      ? [const Color(0xFF065F46), const Color(0xFF047857)]
                      : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    _won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _won ? 'Tebrikler! Kazandın!' : 'Mayına bastın!',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Süre: ${_elapsedSeconds}s', style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 13)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _initGame()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Tekrar Oyna', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCell(_Cell cell, int r, int c) {
    Color bg;
    Widget? child;

    if (cell.isRevealed) {
      if (cell.isMine) {
        bg = const Color(0xFFEF4444).withValues(alpha:0.3);
        child = const Icon(Icons.brightness_7, color: Color(0xFFEF4444), size: 18);
      } else {
        bg = Colors.white.withValues(alpha:0.05);
        if (cell.adjacentMines > 0) {
          child = Text(
            '${cell.adjacentMines}',
            style: TextStyle(color: _numberColor(cell.adjacentMines), fontSize: 14, fontWeight: FontWeight.w800),
          );
        }
      }
    } else if (cell.isFlagged) {
      bg = const Color(0xFF2D1B4E);
      child = const Icon(Icons.flag_rounded, color: Color(0xFFFBBF24), size: 16);
    } else {
      bg = const Color(0xFF2D1B4E);
    }

    return GestureDetector(
      onTap: () => _reveal(r, c),
      onLongPress: () => _toggleFlag(r, c),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(child: child),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
