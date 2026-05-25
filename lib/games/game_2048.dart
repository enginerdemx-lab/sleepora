import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/subscription_service.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import '../services/ad_service.dart';
import '../services/localization_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../screens/paywall_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/login_screen.dart';

/// 2048 Puzzle — animasyonlu kaydırma, doğuş ve birleşme efektleri,
/// kalıcı best skor + oyun durumu, 2048 sonrası devam, skor popup'ları.
class Game2048 extends StatefulWidget {
  const Game2048({super.key});

  @override
  State<Game2048> createState() => _Game2048State();
}

// ─── Tile modeli — kimlik (id) ile takip, animasyonlu ─────────
class _Tile {
  static int _seq = 0;
  final int id;
  int value;
  int row;
  int col;
  bool isNew;
  bool justMerged;
  _Tile({
    int? id,
    required this.value,
    required this.row,
    required this.col,
    this.isNew = false,
    this.justMerged = false,
  }) : id = id ?? _seq++;

  _Tile clone() =>
      _Tile(id: id, value: value, row: row, col: col);

  Map<String, dynamic> toJson() => {
        'id': id,
        'v': value,
        'r': row,
        'c': col,
      };

  factory _Tile.fromJson(Map<String, dynamic> m) {
    // ID'leri karıştırmamak için seq'i ilerlet
    final id = (m['id'] as num).toInt();
    if (id >= _Tile._seq) _Tile._seq = id + 1;
    return _Tile(
      id: id,
      value: (m['v'] as num).toInt(),
      row: (m['r'] as num).toInt(),
      col: (m['c'] as num).toInt(),
    );
  }
}

// ─── Skor popup modeli — "+16" gibi havaya uçan küçük yazı ─────
class _ScorePopup {
  static int _seq = 0;
  final int id;
  final int amount;
  final double row;
  final double col;
  _ScorePopup({required this.amount, required this.row, required this.col})
      : id = _seq++;
}

class _Game2048State extends State<Game2048>
    with SingleTickerProviderStateMixin {
  static const int boardSize = 4;
  static const moveDuration = Duration(milliseconds: 170);

  List<_Tile> _tiles = [];
  int _score = 0;
  int _bestScore = 0;
  bool _gameOver = false;
  bool _won = false;
  bool _keepPlaying = false;
  bool _animating = false;

  // Undo
  List<_Tile>? _prevTiles;
  int? _prevScore;
  bool _canUndo = false;

  // Skor popup'ları
  final List<_ScorePopup> _popups = [];

  // Storage keys
  String get _uidPrefix {
    final uid = AuthService().uid;
    return uid != null ? '${uid}_' : '';
  }
  String get _kBest => '${_uidPrefix}g2048_best';
  String get _kBoard => '${_uidPrefix}g2048_board';
  String get _kScore => '${_uidPrefix}g2048_score';
  String get _kWon => '${_uidPrefix}g2048_won';

  SharedPreferences? _prefs;
  bool _loaded = false;

  // Swipe tracking — kesin yön algılama
  Offset? _panStart;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _bestScore = _prefs!.getInt(_kBest) ?? 0;
      _score = _prefs!.getInt(_kScore) ?? 0;
      _won = _prefs!.getBool(_kWon) ?? false;

      final auth = AuthService();
      if (auth.isLoggedIn && auth.uid != null) {
        final remoteBest = await LeaderboardService().getUserBestScore('2048', auth.uid!);
        if (remoteBest != null && remoteBest > _bestScore) {
          _bestScore = remoteBest;
          _prefs!.setInt(_kBest, _bestScore);
        }
      }

      final boardStr = _prefs!.getString(_kBoard);
      if (boardStr != null && boardStr.isNotEmpty) {
        try {
          final list = (jsonDecode(boardStr) as List)
              .map((e) => _Tile.fromJson(e as Map<String, dynamic>))
              .toList();
          if (list.isNotEmpty) _tiles = list;
        } catch (_) {}
      }
    } catch (_) {}
    if (_tiles.isEmpty) _initBoard();
    _loaded = true;
    if (mounted) setState(() {});
  }

  void _initBoard() {
    _tiles.clear();
    _score = 0;
    _gameOver = false;
    _won = false;
    _keepPlaying = false;
    _canUndo = false;
    _prevTiles = null;
    _prevScore = null;
    _popups.clear();
    _spawnRandomTile();
    _spawnRandomTile();
    _save();
  }

  void _spawnRandomTile() {
    final taken = <int>{};
    for (var t in _tiles) {
      taken.add(t.row * boardSize + t.col);
    }
    final empty = <int>[];
    for (int i = 0; i < boardSize * boardSize; i++) {
      if (!taken.contains(i)) empty.add(i);
    }
    if (empty.isEmpty) return;
    final pick = empty[Random().nextInt(empty.length)];
    _tiles.add(_Tile(
      value: Random().nextDouble() < 0.9 ? 2 : 4,
      row: pick ~/ boardSize,
      col: pick % boardSize,
      isNew: true,
    ));
  }

  bool _canMove() {
    final grid = List.generate(
        boardSize, (_) => List<int>.filled(boardSize, 0));
    for (var t in _tiles) grid[t.row][t.col] = t.value;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (grid[r][c] == 0) return true;
        if (c + 1 < boardSize && grid[r][c] == grid[r][c + 1]) return true;
        if (r + 1 < boardSize && grid[r][c] == grid[r + 1][c]) return true;
      }
    }
    return false;
  }

  /// direction: 0 sol, 1 yukarı, 2 sağ, 3 aşağı
  void _handleSwipe(int direction) {
    if (_animating || _gameOver) return;

    // Undo snapshot
    _prevTiles = _tiles.map((t) => t.clone()).toList();
    _prevScore = _score;

    // Bayrakları sıfırla
    for (var t in _tiles) {
      t.isNew = false;
      t.justMerged = false;
    }

    // Grid lookup
    final grid = List.generate(
        boardSize, (_) => List<_Tile?>.filled(boardSize, null));
    for (var t in _tiles) grid[t.row][t.col] = t;

    final toRemove = <_Tile>[];
    bool moved = false;
    int scoreDelta = 0;
    final mergeRows = <double>[];
    final mergeCols = <double>[];
    final mergeAmounts = <int>[];

    // Her satır/sütun için (yön bazlı)
    for (int line = 0; line < boardSize; line++) {
      final lineTiles = <_Tile>[];
      for (int i = 0; i < boardSize; i++) {
        int r, c;
        switch (direction) {
          case 0:
            r = line;
            c = i;
            break; // sol: satır boyunca L→R tara
          case 2:
            r = line;
            c = boardSize - 1 - i;
            break; // sağ: R→L
          case 1:
            r = i;
            c = line;
            break; // yukarı: sütun T→B
          case 3:
            r = boardSize - 1 - i;
            c = line;
            break; // aşağı: B→T
          default:
            r = line;
            c = i;
        }
        if (grid[r][c] != null) lineTiles.add(grid[r][c]!);
      }

      int writeIdx = 0;
      int read = 0;
      while (read < lineTiles.length) {
        final tile = lineTiles[read];
        final next =
            read + 1 < lineTiles.length ? lineTiles[read + 1] : null;

        int targetR, targetC;
        switch (direction) {
          case 0:
            targetR = line;
            targetC = writeIdx;
            break;
          case 2:
            targetR = line;
            targetC = boardSize - 1 - writeIdx;
            break;
          case 1:
            targetR = writeIdx;
            targetC = line;
            break;
          case 3:
            targetR = boardSize - 1 - writeIdx;
            targetC = line;
            break;
          default:
            targetR = line;
            targetC = writeIdx;
        }

        if (next != null && next.value == tile.value) {
          // MERGE — iki taş hedefe kayıp birleşir
          if (tile.row != targetR || tile.col != targetC) moved = true;
          tile.row = targetR;
          tile.col = targetC;

          if (next.row != targetR || next.col != targetC) moved = true;
          next.row = targetR;
          next.col = targetC;

          final newVal = tile.value * 2;
          next.value = newVal;
          next.justMerged = true;

          toRemove.add(tile);
          scoreDelta += newVal;
          mergeRows.add(targetR.toDouble());
          mergeCols.add(targetC.toDouble());
          mergeAmounts.add(newVal);
          if (newVal == 2048 && !_won) _won = true;

          read += 2;
        } else {
          if (tile.row != targetR || tile.col != targetC) moved = true;
          tile.row = targetR;
          tile.col = targetC;
          read += 1;
        }
        writeIdx += 1;
      }
    }

    if (!moved) {
      _prevTiles = null;
      _prevScore = null;
      return;
    }

    HapticFeedback.selectionClick();
    if (scoreDelta >= 64) {
      HapticFeedback.mediumImpact();
    } else if (scoreDelta > 0) {
      HapticFeedback.lightImpact();
    }

    _score += scoreDelta;
    if (_score > _bestScore) _bestScore = _score;

    setState(() {
      _animating = true;
      for (int i = 0; i < mergeAmounts.length; i++) {
        _popups.add(_ScorePopup(
          amount: mergeAmounts[i],
          row: mergeRows[i],
          col: mergeCols[i],
        ));
      }
    });

    // Slide bittikten sonra: kaybolanları kaldır, yeni taş doğur
    Future.delayed(moveDuration, () {
      if (!mounted) return;
      setState(() {
        _tiles.removeWhere((t) => toRemove.contains(t));
        _spawnRandomTile();
        _animating = false;
        _canUndo = true;
        if (!_canMove()) {
          _gameOver = true;
          HapticFeedback.heavyImpact();
          _submitScore();
        }
      });
      _save();
    });

    // Eski popup'ları temizle (animasyondan sonra)
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_popups.length > 20) {
        setState(() {
          _popups.removeRange(0, _popups.length - 20);
        });
      }
    });
  }

  void _undo() async {
    if (!_canUndo || _prevTiles == null) return;
    if (!SubscriptionService().isPremium) {
      await PaywallScreen.showIfNeeded(context, feature: 'Hamle Geri Al');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _tiles = _prevTiles!;
      _score = _prevScore!;
      _gameOver = false;
      _canUndo = false;
      _prevTiles = null;
      _prevScore = null;
    });
    _save();
  }

  Future<void> _submitScore() async {
    final auth = AuthService();
    if (!auth.isLoggedIn || auth.uid == null) {
      // Giriş yapılmamış — skoru asla kaybetme: pending olarak işaretle,
      // kullanıcı end panel'deki "Giriş Yap" butonuna basınca gönderilir.
      return;
    }
    try {
      await LeaderboardService().submitScore(
        gameId: '2048',
        uid: auth.uid!,
        displayName: auth.displayName ?? 'Anonim',
        score: _score,
        higherIsBetter: true,
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
      debugPrint('❌ 2048 submitScore hatası: $e');
    }
  }

  /// Giriş yapılmamış kullanıcının oyun sonunda görüp dokunabileceği
  /// "Skoru kaydetmek için giriş yapın" CTA'sını işler.
  /// Login başarılıysa pending skoru otomatik gönderir.
  Future<void> _promptLoginAndSubmit() async {
    HapticFeedback.selectionClick();
    final ok = await LoginScreen.show(context, feature: 'Skor Tablosu');
    if (!ok || !mounted) return;
    // Login sonrası AuthService.uid hazır — skoru gönder.
    await _submitScore();
    if (mounted) setState(() {}); // CTA'yı yenilemek için
  }

  void _save() {
    if (_prefs == null) return;
    _prefs!.setInt(_kBest, _bestScore);
    _prefs!.setInt(_kScore, _score);
    _prefs!.setBool(_kWon, _won);
    _prefs!.setString(
        _kBoard, jsonEncode(_tiles.map((t) => t.toJson()).toList()));
  }

  void _onPanStart(DragStartDetails d) => _panStart = d.localPosition;

  void _onPanEnd(DragEndDetails d) {
    if (_panStart == null) return;
    final v = d.velocity.pixelsPerSecond;
    if (v.dx.abs() < 50 && v.dy.abs() < 50) return;
    if (v.dx.abs() > v.dy.abs()) {
      _handleSwipe(v.dx > 0 ? 2 : 0);
    } else {
      _handleSwipe(v.dy > 0 ? 3 : 1);
    }
    _panStart = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white30),
        ),
      );
    }

    final topMax = _tiles.isEmpty
        ? 0
        : _tiles.map((t) => t.value).reduce(max);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '2048 Puzzle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ─── Üst skor paneli ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  _ScoreBox(
                    label: LocalizationService().t('Score').toUpperCase(),
                    value: _score,
                    gradient: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  ),
                  const SizedBox(width: 10),
                  _ScoreBox(
                    label: LocalizationService().t('GameBest'),
                    value: _bestScore,
                    gradient: const [Color(0xFFFBBF24), Color(0xFFD97706)],
                  ),
                  const Spacer(),
                  _TopBtn(
                    icon: Icons.undo_rounded,
                    onTap: _undo,
                    enabled: _canUndo,
                    premium: !SubscriptionService().isPremium,
                  ),
                  const SizedBox(width: 8),
                  _TopBtn(
                    icon: Icons.refresh_rounded,
                    enabled: true,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _initBoard());
                    },
                  ),
                ],
              ),
            ),

            // ─── Oyun tahtası ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanEnd: _onPanEnd,
                behavior: HitTestBehavior.opaque,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(builder: (ctx, cons) {
                    return _buildBoard(cons.biggest);
                  }),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ─── En yüksek değer / durum ───
            if (topMax > 0)
              _MilestoneBar(max: topMax),

            const Spacer(),

            // ─── Kazandı / Kaybetti paneli ───
            if (_gameOver || (_won && !_keepPlaying))
              _buildEndPanel()
            else
              const SizedBox(height: 12),

            // ─── Sabit alt banner (Plus olmayanlara, oyun ekranında da) ───
            if (AdService().adsEnabled) ...[
              const Center(child: BannerAdWidget(slot: BannerSlot.game2048Menu)),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(Size size) {
    const pad = 8.0;
    const gap = 6.0;
    final cell = (size.width - pad * 2 - gap * (boardSize - 1)) / boardSize;

    double posLeft(int c) => pad + c * (cell + gap);
    double posTop(int r) => pad + r * (cell + gap);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1025),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.15),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Arka plan — boş kareler
          for (int r = 0; r < boardSize; r++)
            for (int c = 0; c < boardSize; c++)
              Positioned(
                left: posLeft(c),
                top: posTop(r),
                width: cell,
                height: cell,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

          // Taşlar — AnimatedPositioned ile kayma
          for (var t in _tiles)
            AnimatedPositioned(
              key: ValueKey('tile-${t.id}'),
              duration: moveDuration,
              curve: Curves.easeOut,
              left: posLeft(t.col),
              top: posTop(t.row),
              width: cell,
              height: cell,
              child: _TileWidget(tile: t),
            ),

          // Skor popup'ları
          for (var p in _popups)
            Positioned(
              key: ValueKey('popup-${p.id}'),
              left: posLeft(p.col.toInt()),
              top: posTop(p.row.toInt()),
              width: cell,
              height: cell,
              child: IgnorePointer(
                child: _ScorePopupWidget(popup: p),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEndPanel() {
    final won = _won;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: won
              ? [const Color(0xFF5B21B6), const Color(0xFF7C3AED)]
              : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (won ? AppColors.purple : const Color(0xFFEF4444))
                .withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                    : Icons.sentiment_dissatisfied_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      won ? LocalizationService().t('Game2048Reached') : LocalizationService().t('GameOver'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Skor: $_score  •  En iyi: $_bestScore',
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
          const SizedBox(height: 14),
          Row(
            children: [
              if (won)
                Expanded(
                  child: _EndBtn(
                    label: 'Devam Et',
                    icon: Icons.arrow_forward_rounded,
                    bright: true,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _keepPlaying = true);
                    },
                  ),
                ),
              if (won) const SizedBox(width: 10),
              Expanded(
                child: _EndBtn(
                  label: 'Yeni Oyun',
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _initBoard());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ─── Giriş yapılmamışsa: skor kaydetme CTA'sı ───
          if (!AuthService().isLoggedIn) ...[
            GestureDetector(
              onTap: _promptLoginAndSubmit,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.55),
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
                        LocalizationService().t('LeaderboardLoginRequired'),
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
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const LeaderboardScreen(initialGameId: '2048'),
              ),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.leaderboard_rounded,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    LocalizationService().t('Leaderboard'),
                    style: const TextStyle(
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//                    WIDGET'LAR & YARDIMCILAR
// ═══════════════════════════════════════════════════════════════

// ─── Tile görünümü + scale animasyonları ───────────────────────
class _TileWidget extends StatelessWidget {
  final _Tile tile;
  const _TileWidget({required this.tile});

  @override
  Widget build(BuildContext context) {
    final spec = _TileSpec.forValue(tile.value);

    Widget content = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: spec.gradient,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: spec.glow
            ? [
                BoxShadow(
                  color: spec.gradient.last.withValues(alpha: 0.55),
                  blurRadius: 16,
                  spreadRadius: 0.5,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              '${tile.value}',
              style: TextStyle(
                color: spec.textColor,
                fontSize: spec.fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                shadows: spec.glow
                    ? [
                        const Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );

    // Doğuş animasyonu: 0 → 1 (pop)
    if (tile.isNew) {
      content = TweenAnimationBuilder<double>(
        key: ValueKey('new-${tile.id}'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: content,
      );
    }

    // Merge animasyonu: 1 → 1.18 → 1 (pop)
    if (tile.justMerged) {
      content = TweenAnimationBuilder<double>(
        key: ValueKey('merge-${tile.id}-${tile.value}'),
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: content,
      );
    }

    return content;
  }
}

// ─── Tile renk/font spesi ──────────────────────────────────────
class _TileSpec {
  final List<Color> gradient;
  final Color textColor;
  final double fontSize;
  final bool glow;
  const _TileSpec({
    required this.gradient,
    this.textColor = Colors.white,
    this.fontSize = 28,
    this.glow = false,
  });

  static _TileSpec forValue(int v) {
    switch (v) {
      case 2:
        return const _TileSpec(
          gradient: [Color(0xFF3D2B5E), Color(0xFF2D1B4E)],
          textColor: Colors.white,
          fontSize: 30,
        );
      case 4:
        return const _TileSpec(
          gradient: [Color(0xFF4C2A7A), Color(0xFF3D2B5E)],
          fontSize: 30,
        );
      case 8:
        return const _TileSpec(
          gradient: [Color(0xFFD97706), Color(0xFFB45309)],
          fontSize: 30,
        );
      case 16:
        return const _TileSpec(
          gradient: [Color(0xFFEA580C), Color(0xFFC2410C)],
          fontSize: 28,
        );
      case 32:
        return const _TileSpec(
          gradient: [Color(0xFFF97316), Color(0xFFDC2626)],
          fontSize: 28,
        );
      case 64:
        return const _TileSpec(
          gradient: [Color(0xFFEF4444), Color(0xFFB91C1C)],
          fontSize: 28,
          glow: true,
        );
      case 128:
        return const _TileSpec(
          gradient: [Color(0xFFFBBF24), Color(0xFFD97706)],
          fontSize: 24,
          glow: true,
        );
      case 256:
        return const _TileSpec(
          gradient: [Color(0xFFF59E0B), Color(0xFFB45309)],
          fontSize: 24,
          glow: true,
        );
      case 512:
        return const _TileSpec(
          gradient: [Color(0xFF34D399), Color(0xFF059669)],
          fontSize: 24,
          glow: true,
        );
      case 1024:
        return const _TileSpec(
          gradient: [Color(0xFF10B981), Color(0xFF047857)],
          fontSize: 22,
          glow: true,
        );
      case 2048:
        return const _TileSpec(
          gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          fontSize: 22,
          glow: true,
        );
      case 4096:
        return const _TileSpec(
          gradient: [Color(0xFFEC4899), Color(0xFFBE185D)],
          fontSize: 22,
          glow: true,
        );
      case 8192:
        return const _TileSpec(
          gradient: [Color(0xFF06B6D4), Color(0xFF0E7490)],
          fontSize: 20,
          glow: true,
        );
      default:
        return const _TileSpec(
          gradient: [Color(0xFF06B6D4), Color(0xFF1E40AF)],
          fontSize: 20,
          glow: true,
        );
    }
  }
}

// ─── Skor popup'ı (+16 benzeri) ────────────────────────────────
class _ScorePopupWidget extends StatelessWidget {
  final _ScorePopup popup;
  const _ScorePopupWidget({required this.popup});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (_, v, __) {
        final opacity = (1.0 - v).clamp(0.0, 1.0);
        final offsetY = -30.0 * v;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: Center(
              child: Text(
                '+${popup.amount}',
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Skor kutusu (gradient) ─────────────────────────────────────
class _ScoreBox extends StatelessWidget {
  final String label;
  final int value;
  final List<Color> gradient;
  const _ScoreBox({
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient.map((c) => c.withValues(alpha: 0.22)).toList(),
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: gradient.first.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Üst bar butonları ─────────────────────────────────────────
class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool premium;
  const _TopBtn({
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.premium = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.purple
        : Colors.white.withValues(alpha: 0.25);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (enabled
              ? AppColors.purple.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (enabled
                ? AppColors.purple.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            if (premium && enabled)
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.diamond_outlined,
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.9),
                  size: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Milestone barı (en yüksek değer kilometre taşları) ────────
class _MilestoneBar extends StatelessWidget {
  final int max;
  const _MilestoneBar({required this.max});

  static const milestones = [128, 256, 512, 1024, 2048];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: milestones.map((m) {
          final reached = max >= m;
          final spec = _TileSpec.forValue(m);
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: reached
                  ? LinearGradient(colors: spec.gradient)
                  : null,
              color:
                  reached ? null : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              boxShadow: reached
                  ? [
                      BoxShadow(
                        color:
                            spec.gradient.last.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '$m',
              style: TextStyle(
                color: reached
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Oyun sonu butonları ───────────────────────────────────────
class _EndBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool bright;
  final VoidCallback onTap;
  const _EndBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.bright = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bright
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
