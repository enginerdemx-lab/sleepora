import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';

class Game2048 extends StatefulWidget {
  const Game2048({super.key});

  @override
  State<Game2048> createState() => _Game2048State();
}

class _Game2048State extends State<Game2048> {
  static const int size = 4;
  late List<List<int>> _board;
  int _score = 0;
  int _bestScore = 0;
  bool _gameOver = false;
  bool _won = false;

  // Geri al (undo) için önceki durum
  List<List<int>>? _previousBoard;
  int? _previousScore;
  bool _canUndo = false;

  // Swipe tracking
  Offset? _panStart;

  @override
  void initState() {
    super.initState();
    _initBoard();
  }

  void _initBoard() {
    _board = List.generate(size, (_) => List.filled(size, 0));
    _score = 0;
    _gameOver = false;
    _won = false;
    _addRandomTile();
    _addRandomTile();
  }

  void _addRandomTile() {
    final empty = <List<int>>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] == 0) empty.add([r, c]);
      }
    }
    if (empty.isEmpty) return;
    final pos = empty[Random().nextInt(empty.length)];
    _board[pos[0]][pos[1]] = Random().nextDouble() < 0.9 ? 2 : 4;
  }

  List<int> _merge(List<int> row) {
    final tiles = row.where((t) => t != 0).toList();
    final result = <int>[];
    int i = 0;
    while (i < tiles.length) {
      if (i + 1 < tiles.length && tiles[i] == tiles[i + 1]) {
        final merged = tiles[i] * 2;
        result.add(merged);
        _score += merged;
        if (merged == 2048) _won = true;
        i += 2;
      } else {
        result.add(tiles[i]);
        i++;
      }
    }
    while (result.length < size) result.add(0);
    return result;
  }

  bool _move(int direction) {
    bool moved = false;
    final old = _board.map((r) => List<int>.from(r)).toList();

    if (direction == 0) { // sol
      for (int r = 0; r < size; r++) {
        _board[r] = _merge(_board[r]);
      }
    } else if (direction == 2) { // sağ
      for (int r = 0; r < size; r++) {
        _board[r] = _merge(_board[r].reversed.toList()).reversed.toList();
      }
    } else if (direction == 1) { // yukarı
      for (int c = 0; c < size; c++) {
        final col = List.generate(size, (r) => _board[r][c]);
        final merged = _merge(col);
        for (int r = 0; r < size; r++) _board[r][c] = merged[r];
      }
    } else if (direction == 3) { // aşağı
      for (int c = 0; c < size; c++) {
        final col = List.generate(size, (r) => _board[r][c]).reversed.toList();
        final merged = _merge(col).reversed.toList();
        for (int r = 0; r < size; r++) _board[r][c] = merged[r];
      }
    }

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] != old[r][c]) moved = true;
      }
    }
    return moved;
  }

  bool _canMove() {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] == 0) return true;
        if (c + 1 < size && _board[r][c] == _board[r][c + 1]) return true;
        if (r + 1 < size && _board[r][c] == _board[r + 1][c]) return true;
      }
    }
    return false;
  }

  void _handleSwipe(int direction) {
    if (_gameOver) return;
    setState(() {
      // Hamle öncesi durumu sakla
      _previousBoard = _board.map((r) => List<int>.from(r)).toList();
      _previousScore = _score;

      if (_move(direction)) {
        _addRandomTile();
        _canUndo = true;
        if (_score > _bestScore) _bestScore = _score;
        if (!_canMove()) _gameOver = true;
      } else {
        // Hamle geçerli değilse geri al durumunu bozma
        _previousBoard = null;
        _previousScore = null;
      }
    });
  }

  void _undo() async {
    if (!_canUndo || _previousBoard == null) return;

    // Premium kontrolü
    if (!SubscriptionService().isPremium) {
      await PaywallScreen.showIfNeeded(context, feature: 'Hamle Geri Al');
      return;
    }

    setState(() {
      _board = _previousBoard!;
      _score = _previousScore!;
      _gameOver = false;
      _canUndo = false;
      _previousBoard = null;
      _previousScore = null;
    });
  }

  void _onPanStart(DragStartDetails details) {
    _panStart = details.localPosition;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_panStart == null) return;
    final velocity = details.velocity.pixelsPerSecond;
    final dx = velocity.dx;
    final dy = velocity.dy;

    // Minimum hız eşiği
    if (dx.abs() < 50 && dy.abs() < 50) return;

    if (dx.abs() > dy.abs()) {
      // Yatay swipe
      _handleSwipe(dx > 0 ? 2 : 0);
    } else {
      // Dikey swipe
      _handleSwipe(dy > 0 ? 3 : 1);
    }
    _panStart = null;
  }

  Color _tileColor(int value) {
    switch (value) {
      case 2: return const Color(0xFF2D2B4E);
      case 4: return const Color(0xFF3D2B5E);
      case 8: return const Color(0xFFB45309);
      case 16: return const Color(0xFFD97706);
      case 32: return const Color(0xFFEF4444);
      case 64: return const Color(0xFFDC2626);
      case 128: return const Color(0xFFFBBF24);
      case 256: return const Color(0xFFF59E0B);
      case 512: return const Color(0xFF10B981);
      case 1024: return const Color(0xFF059669);
      case 2048: return const Color(0xFF7C3AED);
      default: return const Color(0xFF4C1D95);
    }
  }

  double _tileFontSize(int value) {
    if (value < 100) return 28;
    if (value < 1000) return 22;
    return 18;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('2048', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Skor
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ScoreBox(label: 'SKOR', value: _score),
                _ScoreBox(label: 'EN İYİ', value: _bestScore),
                // Geri Al butonu — premium
                GestureDetector(
                  onTap: _undo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _canUndo
                          ? const Color(0xFF8B5CF6).withValues(alpha:0.15)
                          : Colors.white.withValues(alpha:0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _canUndo
                            ? const Color(0xFF8B5CF6).withValues(alpha:0.3)
                            : Colors.white.withValues(alpha:0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.undo_rounded,
                          color: _canUndo ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha:0.2),
                          size: 16),
                        const SizedBox(width: 4),
                        if (!SubscriptionService().isPremium)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(Icons.diamond_outlined,
                              color: _canUndo ? const Color(0xFF8B5CF6) : Colors.white.withValues(alpha:0.2),
                              size: 12),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Yeni oyun
                GestureDetector(
                  onTap: () => setState(() => _initBoard()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        Text('Yeni', style: TextStyle(color: AppColors.purple, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Oyun alanı — tek GestureDetector, onPanStart/onPanEnd
          GestureDetector(
            onPanStart: _onPanStart,
            onPanEnd: _onPanEnd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1025),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha:0.06)),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Column(
                  children: List.generate(size, (r) {
                    return Expanded(
                      child: Row(
                        children: List.generate(size, (c) {
                          final value = _board[r][c];
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: value == 0 ? Colors.white.withValues(alpha:0.04) : _tileColor(value),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: value > 0
                                    ? Text(
                                        '$value',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: _tileFontSize(value),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Game Over / Win
          if (_gameOver || _won)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _won
                      ? [const Color(0xFF5B21B6), const Color(0xFF7C3AED)]
                      : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    _won ? '2048\'e Ulaştın!' : 'Oyun Bitti!',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Skor: $_score', style: TextStyle(color: Colors.white.withValues(alpha:0.7), fontSize: 14)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _initBoard()),
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
            const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final int value;
  const _ScoreBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1025),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text('$value', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
