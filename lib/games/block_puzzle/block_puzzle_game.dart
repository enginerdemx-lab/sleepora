import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/localization_service.dart';
import '../../services/ad_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../screens/leaderboard_screen.dart';
import '../../screens/login_screen.dart';

/// Block Dreams — Sleepora'nın bloklu bulmaca oyunu.
///
/// 8x8 tahta üzerinde Tetris benzeri parçaları sürükle-bırak ile yerleştir.
/// Satır veya sütun tamamen dolduğunda temizlenir; çoklu temizlikler combo
/// bonusu verir. Hiç parça yerleşmediğinde oyun biter ve skor leaderboard'a
/// gönderilir.
class BlockPuzzleGame extends StatefulWidget {
  const BlockPuzzleGame({super.key});

  @override
  State<BlockPuzzleGame> createState() => _BlockPuzzleGameState();
}

class _BlockPuzzleGameState extends State<BlockPuzzleGame>
    with TickerProviderStateMixin {
  static const int rows = 8;
  static const int cols = 8;

  String get _uidPrefix {
    final uid = AuthService().uid;
    return uid != null ? '${uid}_' : '';
  }
  String get _kBest => '${_uidPrefix}block_puzzle_best';
  String get _kBoard => '${_uidPrefix}block_puzzle_board';
  String get _kScore => '${_uidPrefix}block_puzzle_score';
  String get _kTray => '${_uidPrefix}block_puzzle_tray';
  static const String _kTheme = 'block_puzzle_theme'; // 'dark' | 'light'
  static const String _kHaptic = 'block_puzzle_haptic'; // bool
  static const String _kHowToShown = 'block_puzzle_howto_shown'; // bool

  // ── Tema & ayarlar ──
  _BlockTheme _theme = _BlockTheme.dark;
  bool _hapticEnabled = true;
  _BlockPalette get _palette => _BlockPalette.forTheme(_theme);

  // 0 = boş, 1..7 = blok renk indeksi
  List<List<int>> _grid =
      List.generate(rows, (_) => List.filled(cols, 0, growable: false));

  // Tablanın altındaki 3 parça slotu
  List<_Shape?> _tray = [null, null, null];

  int _score = 0;
  int _bestScore = 0;
  int _lastComboLines = 0;
  bool _gameOver = false;

  // ── Ana menü / oyun modu ──
  _BlockMode _mode = _BlockMode.menu;
  bool _hasSavedGame = false; // Devam Et butonu aktif mi?

  // ── Game Over rewarded "Devam Et" — oyun başına 1 kez ──
  bool _usedContinueAd = false;

  // Drag-drop durumu
  int _dragSlot = -1;
  Offset _fingerGlobal = Offset.zero;
  Offset _grabOffsetLocal = Offset.zero; // parmak ile parça sol-üst köşesi arası
  int _hoverRow = -1;
  int _hoverCol = -1;
  bool _hoverValid = false;

  // Parmağı parçanın üzerinden ~110px yukarıda tut — görünürlük için
  static const double _liftAbove = 110;

  final GlobalKey _gridKey = GlobalKey();
  final List<_ScorePopup> _popups = [];
  int _popupSeq = 0;

  // ── Patlama animasyonu durumu ──
  late AnimationController _fx; // 0 → 1, 620ms
  final List<_FadingCell> _fadingCells = [];
  final List<_Particle> _particles = [];
  double _shakeStrength = 0;

  SharedPreferences? _prefs;
  final _rnd = Random();
  final _loc = LocalizationService();

  @override
  void initState() {
    super.initState();
    _fx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _fadingCells.clear();
          _particles.clear();
          _shakeStrength = 0;
          if (mounted) setState(() {});
          _save();
        }
      });
    _restore();
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    _prefs = await SharedPreferences.getInstance();
    _bestScore = _prefs!.getInt(_kBest) ?? 0;
    _score = _prefs!.getInt(_kScore) ?? 0;

    final auth = AuthService();
    if (auth.isLoggedIn && auth.uid != null) {
      final remoteBest = await LeaderboardService().getUserBestScore('block_puzzle', auth.uid!);
      if (remoteBest != null && remoteBest > _bestScore) {
        _bestScore = remoteBest;
        _prefs!.setInt(_kBest, _bestScore);
      }
    }

    // Ayarlar
    final themeStr = _prefs!.getString(_kTheme);
    _theme = themeStr == 'light' ? _BlockTheme.light : _BlockTheme.dark;
    _hapticEnabled = _prefs!.getBool(_kHaptic) ?? true;
    final howToShown = _prefs!.getBool(_kHowToShown) ?? false;
    if (!howToShown) {
      // İlk açılışta Nasıl Oynanır'ı göster (frame'den sonra)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openHowTo(isFirstTime: true);
      });
    }

    final boardJson = _prefs!.getString(_kBoard);
    bool restored = false;
    if (boardJson != null) {
      try {
        final list = jsonDecode(boardJson) as List;
        for (int r = 0; r < rows; r++) {
          final row = list[r] as List;
          for (int c = 0; c < cols; c++) {
            _grid[r][c] = (row[c] as num).toInt();
          }
        }
        restored = true;
      } catch (_) {
        _grid = List.generate(rows, (_) => List.filled(cols, 0));
      }
    }

    final trayJson = _prefs!.getString(_kTray);
    if (trayJson != null) {
      try {
        final list = jsonDecode(trayJson) as List;
        _tray = list
            .map((e) =>
                e == null ? null : _Shape.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        while (_tray.length < 3) _tray.add(null);
      } catch (_) {
        _tray = [null, null, null];
      }
    }

    if (_tray.every((t) => t == null)) _refillTray();

    if (!restored) {
      _score = 0;
    }

    // "Devam Et" butonu için: kayıtlı bir oyun var mı? (skor > 0 veya
    // grid'de hiç bir blok varsa "devam edilebilir oyun" sayılır)
    bool hasBlocks = false;
    for (int r = 0; r < rows && !hasBlocks; r++) {
      for (int c = 0; c < cols && !hasBlocks; c++) {
        if (_grid[r][c] != 0) hasBlocks = true;
      }
    }
    _hasSavedGame = restored && (hasBlocks || _score > 0);

    if (mounted) setState(() {});

    if (!_canPlaceAny()) {
      // Kayıtlı oyun gerçekten bittiğinde, Devam Et anlamsız — yeni başlatma şart
      _hasSavedGame = false;
      if (mounted) setState(() => _gameOver = true);
    }
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setInt(_kBest, _bestScore);
    p.setInt(_kScore, _score);
    p.setString(_kBoard, jsonEncode(_grid));
    p.setString(
      _kTray,
      jsonEncode(_tray.map((t) => t?.toJson()).toList()),
    );
  }

  Future<void> _saveSettings() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kTheme, _theme == _BlockTheme.light ? 'light' : 'dark');
    await p.setBool(_kHaptic, _hapticEnabled);
  }

  // Titreşim wrapper'ları — _hapticEnabled false'sa sessizce yoksayar
  void _hapticSelection() {
    if (_hapticEnabled) HapticFeedback.selectionClick();
  }

  void _hapticLight() {
    if (_hapticEnabled) HapticFeedback.lightImpact();
  }

  void _hapticMedium() {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
  }

  void _hapticHeavy() {
    if (_hapticEnabled) HapticFeedback.heavyImpact();
  }

  // ────────────────────────────────────────────────
  // Parça üretimi
  // ────────────────────────────────────────────────

  // ────────────────────────────────────────────────
  // Tray refill — "subtle assist" mekaniği
  // ────────────────────────────────────────────────
  // Block Blast tarzı oyunlarda klasik teknik: uniform random vermek yerine
  // tahta durumuna göre çok hafif bir biased seçim yapılır. Amaç:
  //   1) Oyun her refill'de aniden bitmesin (safety net)
  //   2) Tahta dolduğunda küçük parça eğilimi artsın (oyun uzasın)
  //   3) Bazen tam ihtiyacı olan parça gelsin (combo ↑ tatmin ↑)
  // Tüm biaslar OLASILIKLI — kullanıcı paterni fark edemesin. Düşük baskıda
  // (boş tahtada) tamamen random, böylece erken oyunda zorluk hissi korunur.
  //
  // Son verilen 3 şekil index'ini tutarak aynı parçanın 3 kez üst üste
  // gelmesini de engelliyoruz (klasik "bag" hilesi).

  /// Son verilen şeklin _ShapeLib.all içindeki index'i — anti-clumping için
  final List<int> _recentShapeIdxs = [];
  static const int _recentMemoryCap = 4;

  void _refillTray() {
    final pressure = _filledRatio(); // 0.0 (boş) → 1.0 (dolu)

    // Pressure-based bias eşikleri — düşük baskı = tamamen random.
    // Yüksek baskıda assist eğrisi devreye girer.
    final double smallBias = pressure < 0.40
        ? 0.0
        : pressure < 0.55
            ? 0.10
            : pressure < 0.70
                ? 0.28
                : 0.42;
    final double completerBias = pressure < 0.55 ? 0.0 : (pressure < 0.70 ? 0.15 : 0.22);

    // Near-clear satır/sütun aralıklarını hesapla — completer için kullanılacak
    final nearClearGaps = _findNearClearGaps(minFilled: 6);

    for (int i = 0; i < 3; i++) {
      _tray[i] = _generateAssistedShape(
        smallBias: smallBias,
        completerBias: completerBias,
        nearClearGaps: nearClearGaps,
      );
    }

    // Safety net: tray'deki HİÇBİR parça yerleştirilemiyorsa, en az birini
    // küçük bir parçayla değiştir ki oyun aniden bitmesin. Random sequence
    // kötü çıkarsa kullanıcıya haksızlık olmasın diye en fazla 6 deneme.
    int safety = 0;
    while (!_canPlaceAny() && safety < 6) {
      // En problemli slotu (tahtaya en sığmayacak olanı) küçük bir parçayla değiştir
      _tray[safety % 3] = _pickSmallShape();
      safety++;
    }
  }

  /// 0.0 ile 1.0 arası tahta doluluk oranı.
  double _filledRatio() {
    int filled = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_grid[r][c] != 0) filled++;
      }
    }
    return filled / (rows * cols);
  }

  /// Asıl assist'li şekil üretici. Bias parametrelerine göre küçük parça /
  /// completer parça / tamamen random arasında olasılıklı seçim yapar.
  _Shape _generateAssistedShape({
    required double smallBias,
    required double completerBias,
    required List<_NearClearGap> nearClearGaps,
  }) {
    final roll = _rnd.nextDouble();

    // 1) Completer bias — near-clear bir satır/sütun varsa ve şans uygunsa,
    //    o aralığa tam sığacak küçük bir parça ver.
    if (nearClearGaps.isNotEmpty && roll < completerBias) {
      final gap = nearClearGaps[_rnd.nextInt(nearClearGaps.length)];
      final fit = _pickShapeFittingGap(gap);
      if (fit != null) return _finalizeShape(fit);
    }

    // 2) Small piece bias — yüksek baskıda küçük parça eğilimi.
    if (roll < smallBias + completerBias) {
      return _finalizeShape(_pickSmallDef());
    }

    // 3) Default — anti-clumping ile uniform random.
    return _finalizeShape(_pickRandomDefAvoidingRecent());
  }

  /// _ShapeLib.all içinden, son verilenleri tekrar etmeyen rastgele bir tanım.
  _Shape _pickRandomDefAvoidingRecent() {
    for (int attempt = 0; attempt < 6; attempt++) {
      final idx = _rnd.nextInt(_ShapeLib.all.length);
      if (!_recentShapeIdxs.contains(idx)) {
        _trackShape(idx);
        return _ShapeLib.all[idx];
      }
    }
    // Son çare — anti-clumping zorlayamadık, uniform random
    final idx = _rnd.nextInt(_ShapeLib.all.length);
    _trackShape(idx);
    return _ShapeLib.all[idx];
  }

  /// Küçük (≤ 3 hücre) bir şekil seçer — sıkışmış tahtaya nefes alma payı verir.
  _Shape _pickSmallDef() {
    final pool = <int>[];
    for (int i = 0; i < _ShapeLib.all.length; i++) {
      if (_ShapeLib.all[i].cells.length <= 3) pool.add(i);
    }
    final idx = pool[_rnd.nextInt(pool.length)];
    _trackShape(idx);
    return _ShapeLib.all[idx];
  }

  /// Safety net'te kullanılan: kesinlikle tahtaya sığacak bir 1-2 hücreli şekil.
  _Shape _pickSmallShape() {
    // 1-hücreli (index 0) her tahtada sığar (en az 1 boş hücre varsa)
    final def = _ShapeLib.all[0];
    return _finalizeShape(def);
  }

  /// Verilen boşluğa (örn. "satır 5'te 2 hücrelik yatay gap") tam sığacak
  /// bir şekli _ShapeLib.all'dan döndür. Yoksa null.
  _Shape? _pickShapeFittingGap(_NearClearGap gap) {
    final candidates = <int>[];
    for (int i = 0; i < _ShapeLib.all.length; i++) {
      final s = _ShapeLib.all[i];
      // Gap orientation: horizontal → 1 satırlık parça, vertical → 1 sütunluk parça
      if (gap.horizontal && s.height == 1 && s.width == gap.length) {
        candidates.add(i);
      } else if (!gap.horizontal && s.width == 1 && s.height == gap.length) {
        candidates.add(i);
      }
    }
    if (candidates.isEmpty) return null;
    final idx = candidates[_rnd.nextInt(candidates.length)];
    _trackShape(idx);
    return _ShapeLib.all[idx];
  }

  /// Anti-clumping memory'sine ekle (cap'li, eski düşer).
  void _trackShape(int idx) {
    _recentShapeIdxs.add(idx);
    while (_recentShapeIdxs.length > _recentMemoryCap) {
      _recentShapeIdxs.removeAt(0);
    }
  }

  /// Şekil tanımına rastgele renk ata.
  _Shape _finalizeShape(_Shape def) {
    final color = 1 + _rnd.nextInt(7);
    return _Shape(
      cells: List<Point<int>>.from(def.cells),
      width: def.width,
      height: def.height,
      colorIndex: color,
    );
  }

  /// 6+ hücre dolu satır/sütunlardaki boşlukları bulur — completer hint için.
  List<_NearClearGap> _findNearClearGaps({int minFilled = 6}) {
    final gaps = <_NearClearGap>[];
    // Satırlar
    for (int r = 0; r < rows; r++) {
      int filled = 0;
      for (int c = 0; c < cols; c++) {
        if (_grid[r][c] != 0) filled++;
      }
      if (filled < minFilled) continue;
      // Bu satırda contiguous gap uzunluklarını bul
      int gapStart = -1;
      for (int c = 0; c <= cols; c++) {
        final isEmpty = c < cols && _grid[r][c] == 0;
        if (isEmpty && gapStart == -1) {
          gapStart = c;
        } else if (!isEmpty && gapStart != -1) {
          gaps.add(_NearClearGap(horizontal: true, length: c - gapStart));
          gapStart = -1;
        }
      }
    }
    // Sütunlar
    for (int c = 0; c < cols; c++) {
      int filled = 0;
      for (int r = 0; r < rows; r++) {
        if (_grid[r][c] != 0) filled++;
      }
      if (filled < minFilled) continue;
      int gapStart = -1;
      for (int r = 0; r <= rows; r++) {
        final isEmpty = r < rows && _grid[r][c] == 0;
        if (isEmpty && gapStart == -1) {
          gapStart = r;
        } else if (!isEmpty && gapStart != -1) {
          gaps.add(_NearClearGap(horizontal: false, length: r - gapStart));
          gapStart = -1;
        }
      }
    }
    return gaps;
  }

  /// Backwards-compat: bazı yerlerde hala _randomShape() çağrısı varsa
  /// (test/legacy), assist-li yeni jeneratörü çağırsın.
  _Shape _randomShape() => _finalizeShape(_pickRandomDefAvoidingRecent());

  // ────────────────────────────────────────────────
  // Yerleşim mantığı
  // ────────────────────────────────────────────────

  bool _canPlace(_Shape s, int row, int col) {
    for (final p in s.cells) {
      final r = row + p.y;
      final c = col + p.x;
      if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
      if (_grid[r][c] != 0) return false;
    }
    return true;
  }

  bool _canPlaceAnywhere(_Shape s) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_canPlace(s, r, c)) return true;
      }
    }
    return false;
  }

  bool _canPlaceAny() {
    for (final t in _tray) {
      if (t != null && _canPlaceAnywhere(t)) return true;
    }
    return false;
  }

  void _placePiece(int slot, int row, int col) async {
    final s = _tray[slot];
    if (s == null || !_canPlace(s, row, col)) return;

    _hapticLight();

    for (final p in s.cells) {
      _grid[row + p.y][col + p.x] = s.colorIndex;
    }

    int gained = s.cells.length; // +1 her hücre

    // Dolu satır/sütun tespiti
    final clearedRows = <int>[];
    final clearedCols = <int>[];

    for (int r = 0; r < rows; r++) {
      if (_grid[r].every((v) => v != 0)) clearedRows.add(r);
    }
    for (int c = 0; c < cols; c++) {
      bool full = true;
      for (int r = 0; r < rows; r++) {
        if (_grid[r][c] == 0) {
          full = false;
          break;
        }
      }
      if (full) clearedCols.add(c);
    }

    _tray[slot] = null;
    final totalLines = clearedRows.length + clearedCols.length;

    if (totalLines > 0) {
      // Tüm temizlenecek hücreleri topla
      final allClearing = <_Cell>{};
      for (final r in clearedRows) {
        for (int c = 0; c < cols; c++) allClearing.add(_Cell(r, c));
      }
      for (final c in clearedCols) {
        for (int r = 0; r < rows; r++) allClearing.add(_Cell(r, c));
      }

      // Fading ghost hücreleri + parçacıklar oluştur
      final cellSize = _currentCellPx();
      _fadingCells.clear();
      _particles.clear();

      for (final cell in allClearing) {
        final ci = _grid[cell.r][cell.c];
        if (ci == 0) continue;

        // Sıralı patlama için gecikme (merkeze göre dalga)
        final centerR = clearedRows.isNotEmpty
            ? clearedRows.reduce((a, b) => a + b) / clearedRows.length
            : rows / 2;
        final centerC = clearedCols.isNotEmpty
            ? clearedCols.reduce((a, b) => a + b) / clearedCols.length
            : cols / 2;
        final dist = sqrt(pow(cell.r - centerR, 2) + pow(cell.c - centerC, 2));
        final delay = (dist * 0.05).clamp(0.0, 0.35);

        _fadingCells.add(_FadingCell(
          row: cell.r,
          col: cell.c,
          colorIndex: ci,
          delay: delay,
        ));

        _spawnBurst(cell.r, cell.c, ci, cellSize, delay);

        // Gridden hemen sil — fading cell üzerinde çiziyoruz
        _grid[cell.r][cell.c] = 0;
      }

      // Bonus skor: 10 hücre başına, combo multiplier
      final baseBonus = allClearing.length * 10;
      final multi = totalLines == 1 ? 1 : (totalLines == 2 ? 2 : totalLines + 1);
      final bonus = baseBonus * multi;
      gained += bonus;

      // Kademeli haptic
      if (totalLines >= 3) {
        _hapticHeavy();
      } else if (totalLines >= 2) {
        _hapticMedium();
      } else {
        _hapticLight();
      }

      // Ekran sarsıntısı — combo'ya göre
      _shakeStrength = (totalLines.clamp(1, 5)) * 3.0 + allClearing.length * 0.2;
      _lastComboLines = totalLines;

      // Skor popup'ı ortadaki hücrede
      _popups.add(_ScorePopup(
        id: _popupSeq++,
        amount: bonus,
        row: clearedRows.isNotEmpty ? clearedRows.first : rows ~/ 2,
        col: cols ~/ 2,
      ));

      // Patlama animasyonunu başlat
      _fx.forward(from: 0);

      setState(() {});
    }

    _score += gained;
    if (_score > _bestScore) _bestScore = _score;

    // Hepsi kullanıldıysa yeni parçalar
    if (_tray.every((t) => t == null)) {
      _refillTray();
    }

    // Oyun sonu kontrolü
    if (!_canPlaceAny()) {
      _gameOver = true;
      _hapticHeavy();
      _submitScore();
    }

    setState(() {});
    _save();

    // Popup temizliği
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _popups.removeWhere((p) => p.id <= _popupSeq - 20);
      });
    });
  }

  // ────────────────────────────────────────────────
  // Patlama yardımcıları
  // ────────────────────────────────────────────────

  /// Grid hücre piksel boyutunu döner (grid henüz ölçülmediyse varsayılan 36).
  double _currentCellPx() {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 36;
    return box.size.width / cols;
  }

  /// Bir hücre pozisyonunda 8-12 parçacık oluşturur.
  void _spawnBurst(
    int row,
    int col,
    int colorIndex,
    double cellSize,
    double delay,
  ) {
    final centerX = col * cellSize + cellSize / 2;
    final centerY = row * cellSize + cellSize / 2;
    final count = 8 + _rnd.nextInt(5); // 8..12

    for (int i = 0; i < count; i++) {
      final angle = (2 * pi * i / count) + (_rnd.nextDouble() - 0.5) * 0.6;
      final speed = 140.0 + _rnd.nextDouble() * 180.0; // 140..320 px/s
      final vx = cos(angle) * speed;
      final vy = sin(angle) * speed - 60; // hafif yukarı bias
      _particles.add(_Particle(
        startX: centerX,
        startY: centerY,
        vx: vx,
        vy: vy,
        gravity: 520.0,
        color: _ShapeLib.colors[colorIndex],
        size: cellSize * (0.18 + _rnd.nextDouble() * 0.22),
        rotation: _rnd.nextDouble() * 2 * pi,
        rotSpeed: (_rnd.nextDouble() - 0.5) * 8,
        lifetime: 0.55 + _rnd.nextDouble() * 0.15,
        spawnDelay: delay,
      ));
    }
  }

  // ────────────────────────────────────────────────
  // Skor gönderme
  // ────────────────────────────────────────────────

  Future<void> _submitScore() async {
    final auth = AuthService();
    if (!auth.isLoggedIn || auth.uid == null) return;
    try {
      await LeaderboardService().submitScore(
        gameId: 'block_puzzle',
        uid: auth.uid!,
        displayName: auth.displayName ?? 'Anonim',
        score: _bestScore,
        higherIsBetter: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loc.t('ScoreSaved')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.purple,
        ),
      );
    } catch (e) {
      debugPrint('❌ BlockPuzzle submitScore hatası: $e');
    }
  }

  Future<void> _promptLoginAndSubmit() async {
    _hapticSelection();
    final ok = await LoginScreen.show(context, feature: 'Skor Tablosu');
    if (!ok || !mounted) return;
    await _submitScore();
    if (mounted) setState(() {});
  }

  void _newGame() {
    _hapticSelection();
    setState(() {
      _grid = List.generate(rows, (_) => List.filled(cols, 0));
      _score = 0;
      _gameOver = false;
      _popups.clear();
      _fadingCells.clear();
      _particles.clear();
      _shakeStrength = 0;
      _lastComboLines = 0;
      _usedContinueAd = false; // Yeni oyun → rewarded continue tekrar kullanılabilir
      _hasSavedGame = true;    // Yeni başlatılan oyun da artık "devam edilebilir"
      _mode = _BlockMode.playing;
      _refillTray();
    });
    _fx.reset();
    _save();
  }

  /// Mevcut kayıtlı oyuna devam et. Skor ve tahta korunur.
  void _continueGame() {
    _hapticSelection();
    setState(() {
      _mode = _BlockMode.playing;
      _gameOver = false;
    });
  }

  /// Game-Over ekranındaki "Reklam İzle, Devam Et" butonu.
  /// Oyun başına 1 kez kullanılabilir. Reklam izlenince alt 3 satır temizlenir,
  /// tepside oyun bitince kalan parçalar yenilenir.
  Future<void> _useContinueAd() async {
    if (_usedContinueAd) return;
    _hapticSelection();
    final ok = await AdService().showRewarded(
      slot: RewardedSlot.blockContinue,
      onAdShown: () {},
      onAdClosed: () {},
    );
    if (!mounted) return;
    if (!ok) return; // Reklam yüklenmedi/atlandı → ödül yok

    setState(() {
      _usedContinueAd = true;
      // Alt 3 satırı temizle → kullanıcıya "nefes aldıracak" açık alan
      for (int r = rows - 3; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          _grid[r][c] = 0;
        }
      }
      // Mevcut tepsi oyun-bitti yapmıştı → tepsiyi yenile
      _refillTray();
      _gameOver = false;
      _shakeStrength = 0;
      _hapticMedium();
    });
    _save();
  }

  // ────────────────────────────────────────────────
  // Drag & drop
  // ────────────────────────────────────────────────

  /// Parmak parçaya basar basmaz çağrılır (onPanDown). Eskiden onPanStart
  /// kullanılıyordu — ama o ~18px hareket eşiği bekliyor → kullanıcı "tam
  /// tutmak gerekebiliyor" hissi yaşıyordu. onPanDown anında tetikleniyor.
  void _onDragStart(int slot, Offset globalPosition, Offset localOnPiece) {
    if (_gameOver) return;
    if (_tray[slot] == null) return;
    setState(() {
      _dragSlot = slot;
      _fingerGlobal = globalPosition;
      _grabOffsetLocal = localOnPiece;
      _computeHover();
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragSlot < 0) return;
    setState(() {
      _fingerGlobal = d.globalPosition;
      _computeHover();
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragSlot < 0) return;
    if (_hoverValid) {
      final slot = _dragSlot;
      final r = _hoverRow;
      final c = _hoverCol;
      setState(() {
        _dragSlot = -1;
        _hoverRow = -1;
        _hoverCol = -1;
        _hoverValid = false;
      });
      _placePiece(slot, r, c);
    } else {
      setState(() {
        _dragSlot = -1;
        _hoverRow = -1;
        _hoverCol = -1;
        _hoverValid = false;
      });
    }
  }

  void _onDragCancel() {
    setState(() {
      _dragSlot = -1;
      _hoverRow = -1;
      _hoverCol = -1;
      _hoverValid = false;
    });
  }

  void _computeHover() {
    if (_dragSlot < 0) {
      _hoverRow = -1;
      _hoverCol = -1;
      _hoverValid = false;
      return;
    }
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _hoverRow = -1;
      _hoverCol = -1;
      _hoverValid = false;
      return;
    }
    final origin = box.localToGlobal(Offset.zero);
    final cell = box.size.width / cols;

    // Parçanın sol-üst köşesinin global konumu = parmak - grab offset
    // Parmağı parçanın yukarısına kaldır (daha iyi görünüm)
    final pieceTopLeft = _fingerGlobal - _grabOffsetLocal - const Offset(0, _liftAbove);

    // Lokal konumdaki parça sol-üst köşesi
    final local = pieceTopLeft - origin;

    // En yakın hücreye snap
    final c = (local.dx / cell).round();
    final r = (local.dy / cell).round();

    final s = _tray[_dragSlot];
    if (s == null) {
      _hoverRow = -1;
      _hoverCol = -1;
      _hoverValid = false;
      return;
    }

    // Hücre değiştiyse ufak titreşim — drag sırasında geribildirim
    final prevR = _hoverRow;
    final prevC = _hoverCol;
    _hoverRow = r;
    _hoverCol = c;
    _hoverValid = _canPlace(s, r, c);
    if ((prevR != r || prevC != c) && _hoverValid) {
      _hapticSelection();
    }
  }

  // ────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pal = _palette;
    if (_mode == _BlockMode.menu) {
      return Scaffold(
        backgroundColor: pal.background,
        body: Stack(
          children: [
            _buildBackgroundGlow(),
            SafeArea(child: _buildMainMenu()),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: pal.background,
      body: Stack(
        children: [
          _buildBackgroundGlow(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildScoreBar(),
                const SizedBox(height: 18),
                Expanded(child: _buildGridArea()),
                _buildTray(),
                // ─── Sabit alt banner (oyun ekranında da görünüyor) ───
                if (AdService().adsEnabled) ...[
                  const SizedBox(height: 10),
                  const Center(child: BannerAdWidget(slot: BannerSlot.blockMenu)),
                  const SizedBox(height: 4),
                ] else
                  const SizedBox(height: 22),
              ],
            ),
          ),

          // Sürüklenen parçanın önizlemesi (ekranın en üstünde)
          if (_dragSlot >= 0) _buildDragPreview(),

          // Game over ekranı
          if (_gameOver) _buildGameOverOverlay(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Ana Menü
  // ═══════════════════════════════════════════════════════
  Widget _buildMainMenu() {
    final pal = _palette;
    return Column(
      children: [
        // Üst bar — Geri tuşu + ayarlar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios_rounded,
                    color: pal.textPrimary, size: 20),
                tooltip: 'Geri',
              ),
              const Spacer(),
              IconButton(
                onPressed: _openSettings,
                icon: Icon(Icons.settings_rounded,
                    color: pal.iconMuted, size: 22),
                tooltip: 'Ayarlar',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Logo
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/artwork/block.png',
              width: 110,
              height: 110,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Block Dreams',
          style: TextStyle(
            color: pal.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'En iyi: $_bestScore',
          style: TextStyle(
            color: pal.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),

        // Menü butonları
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _menuButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Yeni Oyun',
                  primary: true,
                  onTap: _newGame,
                ),
                const SizedBox(height: 12),
                _menuButton(
                  icon: Icons.history_rounded,
                  label: _hasSavedGame
                      ? 'Devam Et  •  $_score puan'
                      : 'Devam Et',
                  enabled: _hasSavedGame,
                  onTap: _hasSavedGame ? _continueGame : null,
                ),
                const SizedBox(height: 12),
                _menuButton(
                  icon: Icons.emoji_events_rounded,
                  label: 'Skor Tablosu',
                  iconColor: const Color(0xFFFFD700),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaderboardScreen(
                          initialGameId: 'block_puzzle'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _menuButton(
                  icon: Icons.help_outline_rounded,
                  label: _loc.t('GameHowToPlay'),
                  onTap: () => _openHowTo(),
                ),
              ],
            ),
          ),
        ),

        // Sabit alt banner — Plus olmayanlara
        if (AdService().adsEnabled) ...[
          const SizedBox(height: 12),
          const Center(child: BannerAdWidget(slot: BannerSlot.blockMenu)),
          const SizedBox(height: 6),
        ] else
          const SizedBox(height: 16),
      ],
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    bool primary = false,
    bool enabled = true,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final pal = _palette;
    return Opacity(
      opacity: enabled ? 1.0 : 0.42,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: primary ? null : pal.gridPanel.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primary
                  ? Colors.white.withValues(alpha: 0.18)
                  : pal.gridPanelBorder,
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor ??
                    (primary ? Colors.white : pal.textPrimary),
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: primary ? Colors.white : pal.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: primary
                      ? Colors.white.withValues(alpha: 0.7)
                      : pal.textMuted,
                  size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    final pal = _palette;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.1,
            colors: [
              pal.glow,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final pal = _palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          IconButton(
            // Oyun içinden ana menüye dön (state korunur, "Devam Et" işe yarar)
            onPressed: () {
              _save();
              setState(() {
                _hasSavedGame = !_gameOver; // Bitmişse devam edemez
                _mode = _BlockMode.menu;
              });
            },
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: pal.textPrimary, size: 20),
            tooltip: _loc.t('GameMenu'),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/artwork/block.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const Spacer(),
          // Nasıl oynanır
          IconButton(
            onPressed: () => _openHowTo(),
            icon: Icon(Icons.help_outline_rounded,
                color: pal.iconMuted, size: 22),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: _loc.t('GameHowToPlay'),
          ),
          // Leaderboard
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const LeaderboardScreen(initialGameId: 'block_puzzle'),
              ),
            ),
            icon: const Icon(Icons.emoji_events_rounded,
                color: Color(0xFFFFD700), size: 22),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
          // Yenile
          IconButton(
            onPressed: _newGame,
            icon: Icon(Icons.refresh_rounded,
                color: pal.iconMuted, size: 22),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
          // Ayarlar
          IconButton(
            onPressed: _openSettings,
            icon: Icon(Icons.settings_rounded,
                color: pal.iconMuted, size: 22),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: 'Ayarlar',
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: _scoreCard(
              label: _loc.t('Score'),
              value: '$_score',
              colors: const [Color(0xFF7C3AED), Color(0xFF4C1D95)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _scoreCard(
              label: _loc.t('Best'),
              value: '$_bestScore',
              colors: const [Color(0xFFFFA500), Color(0xFFD97706)],
              icon: Icons.emoji_events_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCard({
    required String label,
    required String value,
    required List<Color> colors,
    IconData? icon,
  }) {
    final pal = _palette;
    final isLight = _theme == _BlockTheme.light;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors[0].withValues(alpha: isLight ? 0.18 : 0.25),
                colors[1].withValues(alpha: isLight ? 0.06 : 0.12),
              ],
            ),
            border: Border.all(
                color: colors[0].withValues(alpha: isLight ? 0.5 : 0.35)),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: colors[0]),
                const SizedBox(width: 6),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: colors[0],
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Text(
                  value,
                  key: ValueKey('$label-$value'),
                  style: TextStyle(
                    color: pal.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = min(constraints.maxWidth, constraints.maxHeight) - 28;
        final size = maxW.clamp(240.0, 420.0);
        final cellSize = size / cols;

        return Center(
          child: AnimatedBuilder(
            animation: _fx,
            builder: (context, _) {
              // Ekran sarsıntısı — _fx ilerledikçe söner
              final shakeT = _fx.value;
              final shakeDecay = (1 - shakeT).clamp(0.0, 1.0);
              final shakeX = _shakeStrength *
                  shakeDecay *
                  sin(shakeT * pi * 8) *
                  (1 - shakeT * 0.3);
              final shakeY = _shakeStrength *
                  shakeDecay *
                  cos(shakeT * pi * 7) *
                  0.6;

              final pal = _palette;
              return Transform.translate(
                offset: Offset(shakeX, shakeY),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        pal.gridPanel,
                        pal.gridPanel.withValues(alpha: 0.4),
                      ],
                    ),
                    border: Border.all(color: pal.gridPanelBorder),
                    boxShadow: [
                      BoxShadow(
                        color: pal.shadow,
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    key: _gridKey,
                    width: size,
                    height: size,
                    child: Stack(
                      children: [
                        // Arka plan grid çizgileri
                        for (int r = 0; r < rows; r++)
                          for (int c = 0; c < cols; c++)
                            Positioned(
                              left: c * cellSize,
                              top: r * cellSize,
                              width: cellSize,
                              height: cellSize,
                              child: Container(
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: pal.emptyCell,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),

                        // Yerleşmiş bloklar
                        for (int r = 0; r < rows; r++)
                          for (int c = 0; c < cols; c++)
                            if (_grid[r][c] != 0)
                              Positioned(
                                left: c * cellSize,
                                top: r * cellSize,
                                width: cellSize,
                                height: cellSize,
                                child: _BlockCell(
                                  colorIndex: _grid[r][c],
                                  size: cellSize,
                                ),
                              ),

                        // Patlayan hücreler (scale + flash + rotate)
                        for (final fc in _fadingCells)
                          _buildFadingCell(fc, cellSize),

                        // Parçacıklar overlay
                        if (_particles.isNotEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _ParticlePainter(
                                  particles: _particles,
                                  progress: _fx.value,
                                  totalDurationSec:
                                      _fx.duration!.inMilliseconds / 1000,
                                ),
                              ),
                            ),
                          ),

                        // Hover preview (geçerli konum)
                        if (_dragSlot >= 0 &&
                            _hoverRow >= 0 &&
                            _hoverCol >= 0 &&
                            _tray[_dragSlot] != null)
                          for (final p in _tray[_dragSlot]!.cells)
                            if (_hoverRow + p.y >= 0 &&
                                _hoverRow + p.y < rows &&
                                _hoverCol + p.x >= 0 &&
                                _hoverCol + p.x < cols)
                              Positioned(
                                left: (_hoverCol + p.x) * cellSize,
                                top: (_hoverRow + p.y) * cellSize,
                                width: cellSize,
                                height: cellSize,
                                child: Container(
                                  margin: const EdgeInsets.all(1.5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: (_hoverValid
                                            ? _ShapeLib.colors[
                                                _tray[_dragSlot]!.colorIndex]
                                            : Colors.redAccent)
                                        .withValues(alpha: 0.25),
                                    border: Border.all(
                                      color: (_hoverValid
                                              ? _ShapeLib.colors[
                                                  _tray[_dragSlot]!.colorIndex]
                                              : Colors.redAccent)
                                          .withValues(alpha: 0.6),
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),

                        // Skor popup'ları
                        for (final pop in _popups)
                          Positioned(
                            left: pop.col * cellSize - 30,
                            top: pop.row * cellSize,
                            width: cellSize * 2 + 60,
                            height: cellSize,
                            child: IgnorePointer(
                              child: _ScorePopupWidget(popup: pop),
                            ),
                          ),

                        // Combo popup (ortada) — _fx tabanlı
                        if (_lastComboLines >= 2 && _fx.isAnimating)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: _buildComboBadge(_fx.value),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Tek bir patlayan hücrenin animasyonunu oluşturur.
  /// Faz 1 (0→0.35): beyaz flash + büyüme (1→1.35)
  /// Faz 2 (0.35→1): küçülüp sönme + rotasyon
  Widget _buildFadingCell(_FadingCell fc, double cellSize) {
    final raw = _fx.value;
    // Hücre gecikmesi — dalga efekti için
    final local = ((raw - fc.delay) / (1 - fc.delay)).clamp(0.0, 1.0);

    // Faz 1: flash + büyüme
    final grow = local < 0.35
        ? 1.0 + (local / 0.35) * 0.35
        : 1.35 - ((local - 0.35) / 0.65) * 1.35;
    final scale = grow.clamp(0.0, 1.4);

    final opacity = local < 0.35
        ? 1.0
        : (1.0 - (local - 0.35) / 0.65).clamp(0.0, 1.0);

    final flashStrength = local < 0.25
        ? (local / 0.25) * 0.85
        : local < 0.4
            ? 1.0 - (local - 0.25) / 0.15
            : 0.0;

    final rotate =
        local < 0.35 ? 0.0 : (local - 0.35) / 0.65 * 0.35 * (fc.col.isEven ? 1 : -1);

    return Positioned(
      left: fc.col * cellSize,
      top: fc.row * cellSize,
      width: cellSize,
      height: cellSize,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: rotate,
            child: Transform.scale(
              scale: scale,
              child: Stack(
                children: [
                  _BlockCell(colorIndex: fc.colorIndex, size: cellSize),
                  if (flashStrength > 0)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white.withValues(alpha: flashStrength),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white
                                  .withValues(alpha: flashStrength * 0.8),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Combo rozeti — _fx ilerledikçe büyür, sabitlenir, sonra söner.
  Widget _buildComboBadge(double t) {
    // 0→0.25 büyü, 0.25→0.75 sabit, 0.75→1 fade
    final inT = (t / 0.25).clamp(0.0, 1.0);
    final outT = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
    final scale = 0.5 + 0.6 * Curves.easeOutBack.transform(inT);
    final opacity = (1 - outT).clamp(0.0, 1.0);
    final translateY = -20 * inT - 10 * outT;

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFF6B6B),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.6),
                  blurRadius: 22,
                ),
              ],
            ),
            child: Text(
              'COMBO x$_lastComboLines',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(color: Colors.black38, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTray() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / 3;
          final pieceCell = (slotWidth - 32) / 5; // 5 hücre sığacak
          final cellSize = pieceCell.clamp(16.0, 28.0);

          return SizedBox(
            height: cellSize * 5 + 24,
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: _TraySlot(
                    shape: _tray[i],
                    cellSize: cellSize,
                    dragging: _dragSlot == i,
                    onDragStart: (globalPos, localOnPiece) =>
                        _onDragStart(i, globalPos, localOnPiece),
                    onDragUpdate: _onDragUpdate,
                    onDragEnd: _onDragEnd,
                    onDragCancel: _onDragCancel,
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragPreview() {
    final s = _tray[_dragSlot];
    if (s == null) return const SizedBox.shrink();

    // Drag sırasında hücre daha büyük (grid ile aynı)
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    double cellSize = 36;
    if (box != null && box.hasSize) {
      cellSize = box.size.width / cols;
    }

    final top = _fingerGlobal.dy - _grabOffsetLocal.dy - _liftAbove;
    final left = _fingerGlobal.dx - _grabOffsetLocal.dx;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: SizedBox(
          width: s.width * cellSize,
          height: s.height * cellSize,
          child: Stack(
            children: [
              for (final p in s.cells)
                Positioned(
                  left: p.x * cellSize,
                  top: p.y * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: _BlockCell(colorIndex: s.colorIndex, size: cellSize),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    final pal = _palette;
    final isLight = _theme == _BlockTheme.light;
    return Positioned.fill(
      child: Container(
        color: (isLight ? Colors.white : Colors.black)
            .withValues(alpha: isLight ? 0.7 : 0.65),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF7C3AED)
                          .withValues(alpha: isLight ? 0.18 : 0.3),
                      pal.sheetBackground.withValues(alpha: isLight ? 0.9 : 0.05),
                    ],
                  ),
                  border: Border.all(color: pal.gridPanelBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF6B6B)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B)
                                .withValues(alpha: 0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.emoji_events_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _loc.t('GameOver'),
                      style: TextStyle(
                        color: pal.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statBlock(_loc.t('Score'), '$_score'),
                        _statBlock(_loc.t('Best'), '$_bestScore'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ─── Giriş yapılmamışsa: skor kaydetme CTA'sı ───
                    if (!AuthService().isLoggedIn) ...[
                      GestureDetector(
                        onTap: _promptLoginAndSubmit,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFBBF24)
                                  .withValues(alpha: 0.55),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_outline_rounded,
                                  color: Color(0xFFFBBF24), size: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _loc.t('LeaderboardLoginRequired'),
                                  style: TextStyle(
                                    color: pal.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded,
                                  color: pal.textPrimary
                                      .withValues(alpha: 0.7),
                                  size: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else
                      const SizedBox(height: 4),
                    // ── 1. satır: 🏆 + Tekrar Oyna ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LeaderboardScreen(
                                    initialGameId: 'block_puzzle',
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(
                                color: Color(0xFFFFD700),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '🏆',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _newGame,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF7C3AED),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              _loc.t('PlayAgain'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // ── 2. satır: Reklam İzle, Devam Et (oyun başına 1 kez) ──
                    if (!_usedContinueAd) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _useContinueAd,
                          icon: const Icon(
                            Icons.play_circle_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: Text(
                            _loc.t('GameWatchAdContinue'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                    // ── 3. satır: Ana Menüye Dön ──
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.home_rounded,
                          color: pal.textMuted,
                          size: 18,
                        ),
                        label: Text(
                          _loc.t('GameMainMenu'),
                          style: TextStyle(
                            color: pal.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: pal.gridPanelBorder,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBlock(String label, String value) {
    final pal = _palette;
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: pal.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: pal.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────
  // Ayarlar + Nasıl Oynanır
  // ────────────────────────────────────────────────

  void _openSettings() {
    _hapticSelection();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BlockSettingsSheet(
        theme: _theme,
        haptic: _hapticEnabled,
        onThemeChanged: (t) {
          setState(() => _theme = t);
          _saveSettings();
          _hapticSelection();
        },
        onHapticChanged: (v) {
          setState(() => _hapticEnabled = v);
          _saveSettings();
          if (v) HapticFeedback.selectionClick(); // yeni açıldıysa önizleme
        },
        onShowHowTo: () {
          Navigator.pop(context);
          _openHowTo();
        },
      ),
    );
  }

  Future<void> _openHowTo({bool isFirstTime = false}) async {
    _hapticSelection();
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const _BlockHowToPage(),
    );
    if (isFirstTime) {
      await _prefs?.setBool(_kHowToShown, true);
    }
  }
}

// ═══════════════════════════════════════════════════════
// Görsel parça hücresi
// ═══════════════════════════════════════════════════════

class _BlockCell extends StatelessWidget {
  final int colorIndex;
  final double size;
  const _BlockCell({required this.colorIndex, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = _ShapeLib.colors[colorIndex];
    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.25)!,
            color,
            Color.lerp(color, Colors.black, 0.2)!,
          ],
          stops: const [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Üst parlama
          Positioned(
            top: 2,
            left: 2,
            right: 2,
            height: (size * 0.35).clamp(6, 14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Tray slot — parçayı gösterir, sürüklemeyi başlatır
// ═══════════════════════════════════════════════════════

class _TraySlot extends StatefulWidget {
  final _Shape? shape;
  final double cellSize;
  final bool dragging;
  // onDragStart artık Offset alıyor (DragStartDetails yerine) — onPanDown ile
  // anında tetiklenebilmesi için.
  final void Function(Offset globalPosition, Offset localOnPiece) onDragStart;
  final void Function(DragUpdateDetails) onDragUpdate;
  final void Function(DragEndDetails) onDragEnd;
  final VoidCallback onDragCancel;

  const _TraySlot({
    required this.shape,
    required this.cellSize,
    required this.dragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  @override
  State<_TraySlot> createState() => _TraySlotState();
}

class _TraySlotState extends State<_TraySlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _spawnCtrl;
  final GlobalKey _pieceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _spawnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    if (widget.shape != null) _spawnCtrl.forward();
  }

  @override
  void didUpdateWidget(covariant _TraySlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shape != null && oldWidget.shape == null) {
      _spawnCtrl.forward(from: 0);
    } else if (widget.shape == null) {
      _spawnCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _spawnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shape;
    if (s == null) {
      return const SizedBox.shrink();
    }

    final w = s.width * widget.cellSize;
    final h = s.height * widget.cellSize;

    // Hit area minimum boyutu — küçük parçalar (1x1, 1x2, 2x1) için bile
    // parmakla rahatça yakalanacak şekilde dokunma alanını genişletir.
    // Bu, parçanın görsel boyutunu DEĞİŞTİRMEZ; sadece görünmez bir genişletme.
    const double minHitSide = 80;
    final hitW = w < minHitSide ? minHitSide : w;
    final hitH = h < minHitSide ? minHitSide : h;

    return Opacity(
      opacity: widget.dragging ? 0.0 : 1.0,
      child: Center(
        child: AnimatedBuilder(
          animation: _spawnCtrl,
          builder: (context, child) {
            final t = Curves.easeOutBack.transform(_spawnCtrl.value);
            return Transform.scale(scale: t, child: child);
          },
          child: GestureDetector(
            // İmleç parçaya temas eder etmez yakala — onPanStart'ın
            // ~18px touch slop bekleme süresini atlıyoruz.
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) {
              final box = _pieceKey.currentContext?.findRenderObject()
                  as RenderBox?;
              if (box == null) return;
              // Parça merkezine "snap" et — kullanıcı parçanın hangi noktasına
              // bastığından bağımsız olarak tutulan parça aynı şekilde davransın.
              // Bu, küçük parçalarda hit area kenarına bastığında bile
              // parçayı doğru yerden tutmuş gibi davranmamızı sağlar.
              final pieceLocal = box.globalToLocal(d.globalPosition);
              // Eğer dokunuş gerçek parçanın dışında (genişletilmiş hit
              // alanında) ise, parçanın merkezine clamp et.
              final clampedLocal = Offset(
                pieceLocal.dx.clamp(0.0, w),
                pieceLocal.dy.clamp(0.0, h),
              );
              widget.onDragStart(d.globalPosition, clampedLocal);
            },
            onPanUpdate: widget.onDragUpdate,
            onPanEnd: widget.onDragEnd,
            onPanCancel: widget.onDragCancel,
            // Görünmez genişletilmiş dokunma alanı — parça küçük olsa bile
            // hit target en az 80×80px.
            child: SizedBox(
              width: hitW,
              height: hitH,
              child: Center(
                child: SizedBox(
                  key: _pieceKey,
                  width: w,
                  height: h,
                  child: Stack(
                    children: [
                      for (final p in s.cells)
                        Positioned(
                          left: p.x * widget.cellSize,
                          top: p.y * widget.cellSize,
                          width: widget.cellSize,
                          height: widget.cellSize,
                          child: _BlockCell(
                            colorIndex: s.colorIndex,
                            size: widget.cellSize,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Floating score popup
// ═══════════════════════════════════════════════════════

class _ScorePopupWidget extends StatefulWidget {
  final _ScorePopup popup;
  const _ScorePopupWidget({required this.popup});

  @override
  State<_ScorePopupWidget> createState() => _ScorePopupWidgetState();
}

class _ScorePopupWidgetState extends State<_ScorePopupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -40 * t),
            child: Transform.scale(
              scale: 0.8 + 0.6 * Curves.easeOutBack.transform(t.clamp(0.0, 1.0)),
              child: Center(
                child: Text(
                  '+${widget.popup.amount}',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 6),
                      Shadow(
                          color: Color(0xFFFFD700),
                          blurRadius: 14,
                          offset: Offset(0, 0)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// Veri tipleri
// ═══════════════════════════════════════════════════════

class _Shape {
  final List<Point<int>> cells;
  final int width;
  final int height;
  final int colorIndex;

  _Shape({
    required this.cells,
    required this.width,
    required this.height,
    required this.colorIndex,
  });

  Map<String, dynamic> toJson() => {
        'cells': cells.map((p) => [p.x, p.y]).toList(),
        'w': width,
        'h': height,
        'ci': colorIndex,
      };

  factory _Shape.fromJson(Map<String, dynamic> j) {
    final cells = (j['cells'] as List)
        .map((e) => Point<int>(
              (e[0] as num).toInt(),
              (e[1] as num).toInt(),
            ))
        .toList();
    return _Shape(
      cells: cells,
      width: (j['w'] as num).toInt(),
      height: (j['h'] as num).toInt(),
      colorIndex: (j['ci'] as num).toInt(),
    );
  }
}

/// Near-clear tarama sonucu: bir satır/sütundaki contiguous boş alan tanımı.
/// Subtle-assist algoritması bu aralıklara tam sığacak parçalar önerebilir.
class _NearClearGap {
  /// true → satır boyunca yatay gap, false → sütun boyunca dikey gap
  final bool horizontal;
  /// Boşluğun hücre uzunluğu (1, 2, vs.)
  final int length;
  const _NearClearGap({required this.horizontal, required this.length});
}

class _ScorePopup {
  final int id;
  final int amount;
  final int row;
  final int col;
  _ScorePopup({
    required this.id,
    required this.amount,
    required this.row,
    required this.col,
  });
}

class _Cell {
  final int r;
  final int c;
  const _Cell(this.r, this.c);

  @override
  bool operator ==(Object other) =>
      other is _Cell && other.r == r && other.c == c;

  @override
  int get hashCode => r * 31 + c;
}

// ═══════════════════════════════════════════════════════
// Patlama animasyonu — fading cell & particles
// ═══════════════════════════════════════════════════════

class _FadingCell {
  final int row;
  final int col;
  final int colorIndex;
  /// 0..~0.35 arası — bu hücrenin patlama dalga gecikmesi
  final double delay;

  _FadingCell({
    required this.row,
    required this.col,
    required this.colorIndex,
    required this.delay,
  });
}

class _Particle {
  final double startX;
  final double startY;
  final double vx;
  final double vy;
  final double gravity;
  final Color color;
  final double size;
  final double rotation;
  final double rotSpeed;
  /// 0.0..1.0 — partikülün yaşam süresi (animasyon süresine oranla)
  final double lifetime;
  /// 0..~0.35 — patlama merkezinden mesafe gecikmesi
  final double spawnDelay;

  _Particle({
    required this.startX,
    required this.startY,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotSpeed,
    required this.lifetime,
    required this.spawnDelay,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1
  final double totalDurationSec;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.totalDurationSec,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Her parçacık kendi gecikmesinden sonra canlanır
      final local = ((progress - p.spawnDelay) / (1 - p.spawnDelay))
          .clamp(0.0, 1.0);
      if (local <= 0 || local > p.lifetime) continue;

      // Hayat içindeki yaş: 0..1
      final age = (local / p.lifetime).clamp(0.0, 1.0);
      final tSec = local * totalDurationSec;

      final x = p.startX + p.vx * tSec;
      final y = p.startY + p.vy * tSec + 0.5 * p.gravity * tSec * tSec;

      final alpha = (1 - age).clamp(0.0, 1.0);
      final sz = p.size * (1 - age * 0.4);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotSpeed * tSec);

      // Glow
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: alpha * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: sz * 1.3, height: sz * 1.3),
        glowPaint,
      );

      // Body
      final bodyPaint = Paint()
        ..color = p.color.withValues(alpha: alpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: sz, height: sz),
          Radius.circular(sz * 0.25),
        ),
        bodyPaint,
      );

      // Highlight
      final hlPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.55);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-sz * 0.18, -sz * 0.18),
            width: sz * 0.45,
            height: sz * 0.45,
          ),
          Radius.circular(sz * 0.2),
        ),
        hlPaint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.progress != progress || old.particles != particles;
}

// ═══════════════════════════════════════════════════════
// Şekil kütüphanesi — klasik blok-puzzle parçaları
// ═══════════════════════════════════════════════════════

class _ShapeLib {
  // Renk paleti (index 0 boş, 1..7 kullanılır)
  static const List<Color> colors = [
    Colors.transparent,
    Color(0xFF7C3AED), // purple
    Color(0xFF3B82F6), // blue
    Color(0xFF06B6D4), // teal
    Color(0xFF10B981), // green
    Color(0xFFFACC15), // yellow
    Color(0xFFF97316), // orange
    Color(0xFFEC4899), // pink
  ];

  static final List<_Shape> all = _generateShapes();

  static List<_Shape> _generateShapes() {
    // cells: List<Point(x=col, y=row)>, (0,0) sol-üst
    _Shape make(List<List<int>> pts, int w, int h) => _Shape(
          cells: pts.map((p) => Point<int>(p[0], p[1])).toList(),
          width: w,
          height: h,
          colorIndex: 1,
        );

    return [
      // 1 hücre
      make([[0, 0]], 1, 1),
      // 2 hücre yatay
      make([[0, 0], [1, 0]], 2, 1),
      // 2 hücre dikey
      make([[0, 0], [0, 1]], 1, 2),
      // 3 hücre yatay
      make([[0, 0], [1, 0], [2, 0]], 3, 1),
      // 3 hücre dikey
      make([[0, 0], [0, 1], [0, 2]], 1, 3),
      // 4 hücre yatay
      make([[0, 0], [1, 0], [2, 0], [3, 0]], 4, 1),
      // 4 hücre dikey
      make([[0, 0], [0, 1], [0, 2], [0, 3]], 1, 4),
      // 5 hücre yatay
      make([[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]], 5, 1),
      // 5 hücre dikey
      make([[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]], 1, 5),
      // 2x2 kare
      make([[0, 0], [1, 0], [0, 1], [1, 1]], 2, 2),
      // 3x3 kare
      make([
        [0, 0], [1, 0], [2, 0],
        [0, 1], [1, 1], [2, 1],
        [0, 2], [1, 2], [2, 2],
      ], 3, 3),
      // L — 4 dönüş
      make([[0, 0], [0, 1], [1, 1], [2, 1]], 3, 2),
      make([[0, 0], [1, 0], [0, 1], [0, 2]], 2, 3),
      make([[0, 0], [1, 0], [2, 0], [2, 1]], 3, 2),
      make([[1, 0], [1, 1], [0, 2], [1, 2]], 2, 3),
      // J — 4 dönüş
      make([[2, 0], [0, 1], [1, 1], [2, 1]], 3, 2),
      make([[0, 0], [0, 1], [0, 2], [1, 2]], 2, 3),
      make([[0, 0], [1, 0], [2, 0], [0, 1]], 3, 2),
      make([[0, 0], [1, 0], [1, 1], [1, 2]], 2, 3),
      // T — 4 dönüş
      make([[0, 0], [1, 0], [2, 0], [1, 1]], 3, 2),
      make([[1, 0], [0, 1], [1, 1], [1, 2]], 2, 3),
      make([[1, 0], [0, 1], [1, 1], [2, 1]], 3, 2),
      make([[0, 0], [0, 1], [1, 1], [0, 2]], 2, 3),
      // S — 2 dönüş
      make([[1, 0], [2, 0], [0, 1], [1, 1]], 3, 2),
      make([[0, 0], [0, 1], [1, 1], [1, 2]], 2, 3),
      // Z — 2 dönüş
      make([[0, 0], [1, 0], [1, 1], [2, 1]], 3, 2),
      make([[1, 0], [0, 1], [1, 1], [0, 2]], 2, 3),
      // Küçük L (3 hücre)
      make([[0, 0], [0, 1], [1, 1]], 2, 2),
      make([[0, 0], [1, 0], [1, 1]], 2, 2),
      make([[0, 0], [1, 0], [0, 1]], 2, 2),
      make([[0, 1], [1, 1], [1, 0]], 2, 2),
    ];
  }
}

// ═══════════════════════════════════════════════════════
// Tema sistemi
// ═══════════════════════════════════════════════════════

enum _BlockTheme { dark, light }

/// Oyun ekranının iki modu: ana menü ve oyun.
enum _BlockMode { menu, playing }

class _BlockPalette {
  final Color background;
  final Color glow;
  final Color textPrimary;
  final Color textMuted;
  final Color iconMuted;
  final Color gridPanel;
  final Color gridPanelBorder;
  final Color emptyCell;
  final Color shadow;
  final Color sheetBackground;
  final Color divider;

  const _BlockPalette({
    required this.background,
    required this.glow,
    required this.textPrimary,
    required this.textMuted,
    required this.iconMuted,
    required this.gridPanel,
    required this.gridPanelBorder,
    required this.emptyCell,
    required this.shadow,
    required this.sheetBackground,
    required this.divider,
  });

  static const _BlockPalette dark = _BlockPalette(
    // Derin mor-indigo bir atmosfer — gri-beyaz yerine renkli alpha'lar
    background: Color(0xFF140825),
    glow: Color(0x5C7C3AED),
    textPrimary: Colors.white,
    textMuted: Color(0x99E9DEFD),        // hafif eflatun-beyaz
    iconMuted: Color(0xCCCBB6FF),        // açık mor
    gridPanel: Color(0x247C3AED),        // mor %14
    gridPanelBorder: Color(0x4D7C3AED),  // mor %30
    emptyCell: Color(0x147C3AED),        // mor %8 — grişliden kurtuldu
    shadow: Color(0x663C1E66),           // mor-siyah gölge
    sheetBackground: Color(0xFF1C0F35),  // biraz daha canlı mor
    divider: Color(0x337C3AED),          // mor %20
  );

  static const _BlockPalette light = _BlockPalette(
    background: Color(0xFFF1EBFA),
    glow: Color(0x287C3AED),
    textPrimary: Color(0xFF1A1025),
    textMuted: Color(0x991A1025),
    iconMuted: Color(0xCC4C1D95),
    gridPanel: Color(0xFFE9DEFD),
    gridPanelBorder: Color(0x337C3AED),
    emptyCell: Color(0x14000000),
    shadow: Color(0x337C3AED),
    sheetBackground: Color(0xFFFFFFFF),
    divider: Color(0x1A000000),
  );

  static _BlockPalette forTheme(_BlockTheme t) =>
      t == _BlockTheme.light ? light : dark;
}

// ═══════════════════════════════════════════════════════
// Ayarlar modal sheet
// ═══════════════════════════════════════════════════════

class _BlockSettingsSheet extends StatefulWidget {
  final _BlockTheme theme;
  final bool haptic;
  final ValueChanged<_BlockTheme> onThemeChanged;
  final ValueChanged<bool> onHapticChanged;
  final VoidCallback onShowHowTo;

  const _BlockSettingsSheet({
    required this.theme,
    required this.haptic,
    required this.onThemeChanged,
    required this.onHapticChanged,
    required this.onShowHowTo,
  });

  @override
  State<_BlockSettingsSheet> createState() => _BlockSettingsSheetState();
}

class _BlockSettingsSheetState extends State<_BlockSettingsSheet> {
  late _BlockTheme _theme;
  late bool _haptic;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme;
    _haptic = widget.haptic;
  }

  @override
  Widget build(BuildContext context) {
    final pal = _BlockPalette.forTheme(_theme);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: pal.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: pal.gridPanelBorder),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: pal.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Ayarlar',
            style: TextStyle(
              color: pal.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 22),

          // Tema seçimi
          Text(
            'TEMA',
            style: TextStyle(
              color: pal.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ThemeChoice(
                  label: 'Koyu',
                  icon: Icons.dark_mode_rounded,
                  selected: _theme == _BlockTheme.dark,
                  accent: const Color(0xFF7C3AED),
                  palette: pal,
                  onTap: () {
                    setState(() => _theme = _BlockTheme.dark);
                    widget.onThemeChanged(_BlockTheme.dark);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ThemeChoice(
                  label: LocalizationService().t('GameLight'),
                  icon: Icons.light_mode_rounded,
                  selected: _theme == _BlockTheme.light,
                  accent: const Color(0xFFFFA500),
                  palette: pal,
                  onTap: () {
                    setState(() => _theme = _BlockTheme.light);
                    widget.onThemeChanged(_BlockTheme.light);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Titreşim
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _haptic
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.14)
                  : pal.gridPanel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _haptic
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.55)
                    : pal.gridPanelBorder,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _haptic
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.22)
                        : pal.gridPanel,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _haptic
                        ? Icons.vibration_rounded
                        : Icons.do_not_disturb_on_outlined,
                    color: _haptic
                        ? const Color(0xFF7C3AED)
                        : pal.iconMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService().t('GameVibration'),
                        style: TextStyle(
                          color: pal.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _haptic
                              ? LocalizationService().t('GameVibrationOn')
                              : LocalizationService().t('GameVibrationOff'),
                          key: ValueKey(_haptic),
                          style: TextStyle(
                            color: pal.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _haptic,
                  activeColor: const Color(0xFF7C3AED),
                  onChanged: (v) {
                    setState(() => _haptic = v);
                    widget.onHapticChanged(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Nasıl oynanır
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onShowHowTo,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: pal.gridPanel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pal.gridPanelBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      color: pal.iconMuted, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      LocalizationService().t('GameHowToPlayQ'),
                      style: TextStyle(
                        color: pal.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: pal.iconMuted, size: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final _BlockPalette palette;
  final VoidCallback onTap;

  const _ThemeChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : palette.gridPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.75)
                : palette.gridPanelBorder,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 26, color: selected ? accent : palette.iconMuted),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Nasıl Oynanır — 4 sayfalık PageView
// ═══════════════════════════════════════════════════════

/// Block Puzzle "Nasıl Oynanır" — Mayın Tarlası tarzı 4 sayfalık glass overlay.
/// Her sayfada başlığın üstünde animasyonlu mini-demo bulunur:
///   1) Tepsiden sürükle (parmak göstergesi parçaya gidip tutuyor)
///   2) Tahtaya yerleştir (yeşil önizleme + drop animasyonu)
///   3) Satır/sütun temizleme (dolan satır parlayarak siliniyor)
///   4) Combo (iki çizgi + ateş efekti)
class _BlockHowToPage extends StatefulWidget {
  const _BlockHowToPage();

  @override
  State<_BlockHowToPage> createState() => _BlockHowToPageState();
}

class _BlockHowToPageState extends State<_BlockHowToPage> {
  final _pageController = PageController();
  int _page = 0;

  List<_HowToPageData> get _pages {
    final loc = LocalizationService();
    return [
      _HowToPageData(
        title: loc.t('BPSelectPieceTitle'),
        description: loc.t('BPSelectPieceDesc'),
        icon: Icons.touch_app_rounded,
        color: const Color(0xFFA78BFA),
        demo: _BlockDemoType.pickup,
      ),
      _HowToPageData(
        title: loc.t('BPPlacePieceTitle'),
        description: loc.t('BPPlacePieceDesc'),
        icon: Icons.grid_on_rounded,
        color: const Color(0xFF60A5FA),
        demo: _BlockDemoType.place,
      ),
      _HowToPageData(
        title: loc.t('BPClearTitle'),
        description: loc.t('BPClearDesc'),
        icon: Icons.auto_fix_high_rounded,
        color: const Color(0xFF34D399),
        demo: _BlockDemoType.lineClear,
      ),
      _HowToPageData(
        title: 'Combo',
        description: loc.t('BPComboDesc'),
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF6B6B),
        demo: _BlockDemoType.combo,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    final accent = _pages[_page].color;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.32),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Header ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videogame_asset_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        LocalizationService().t('GameHowToPlay'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Pages ───
                SizedBox(
                  height: 360,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) =>
                        _HowToPageView(data: _pages[i]),
                  ),
                ),

                // ─── Dots ───
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? accent
                              : Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),

                // ─── Nav ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: Row(
                    children: [
                      _HowToNavBtn(
                        icon: Icons.chevron_left_rounded,
                        enabled: _page > 0,
                        onTap: _prev,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _next,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent,
                                  accent.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.5),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isLast ? LocalizationService().t('GameGotIt') : LocalizationService().t('GameNext'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    isLast
                                        ? Icons.check_rounded
                                        : Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _BlockDemoType { pickup, place, lineClear, combo }

class _HowToPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final _BlockDemoType demo;
  const _HowToPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.demo,
  });
}

class _HowToPageView extends StatelessWidget {
  final _HowToPageData data;
  const _HowToPageView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const SizedBox(height: 4),
          // ─── Demo kutusu ───
          Container(
            width: 230,
            height: 170,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1025),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.all(10),
            child: _BlockDemo(type: data.demo, accent: data.color),
          ),
          const SizedBox(height: 18),
          // ─── Başlık ───
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, color: data.color, size: 18),
              const SizedBox(width: 6),
              Text(
                data.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ─── Açıklama ───
          Expanded(
            child: Text(
              data.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13.5,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animasyonlu Demo ───
/// Tek bir AnimationController üzerinden 4 farklı demo türetir.
class _BlockDemo extends StatefulWidget {
  final _BlockDemoType type;
  final Color accent;
  const _BlockDemo({required this.type, required this.accent});

  @override
  State<_BlockDemo> createState() => _BlockDemoState();
}

class _BlockDemoState extends State<_BlockDemo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        switch (widget.type) {
          case _BlockDemoType.pickup:
            return _DemoPickup(t: _ctrl.value, accent: widget.accent);
          case _BlockDemoType.place:
            return _DemoPlace(t: _ctrl.value, accent: widget.accent);
          case _BlockDemoType.lineClear:
            return _DemoLineClear(t: _ctrl.value, accent: widget.accent);
          case _BlockDemoType.combo:
            return _DemoCombo(t: _ctrl.value, accent: widget.accent);
        }
      },
    );
  }
}

// ─── Sayfa 1: Parça Seç ───
/// 4×4 mini grid + altta tepsi parçası. Parmak göstergesi parçaya yaklaşıp
/// "tutuyor" → parçayı yukarı sürüklüyor → grid üzerine geliyor.
class _DemoPickup extends StatelessWidget {
  final double t; // 0..1
  final Color accent;
  const _DemoPickup({required this.t, required this.accent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cell = (w / 4).clamp(20.0, 30.0);
        // Faz 1 (0-0.4): parmak parçaya doğru iniyor
        // Faz 2 (0.4-0.6): parça kavranıyor (scale up)
        // Faz 3 (0.6-1): parça yukarı taşınıyor
        final phase1 = (t / 0.4).clamp(0.0, 1.0);
        final phase2 = ((t - 0.4) / 0.2).clamp(0.0, 1.0);
        final phase3 = ((t - 0.6) / 0.4).clamp(0.0, 1.0);

        // Parça konumu — başlangıç altta tepsi seviyesinde, son grid içinde
        final pieceY = 110.0 - phase3 * 75.0;
        final pieceX = w * 0.5 + (phase3 - 0.5) * 6;
        final pieceScale = 1.0 + phase2 * 0.2 - phase3 * 0.05;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          children: [
            // Mini grid arka plan (4×4)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: _MiniGrid(rows: 4, cols: 4, cell: cell),
              ),
            ),
            // Tepsi alanı (altta)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 44,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
            ),
            // Hareketli parça (1×2 dikey)
            Positioned(
              top: pieceY,
              child: Transform.scale(
                scale: pieceScale,
                child: _DemoPiece(
                  width: cell - 4,
                  height: (cell - 4) * 2,
                  color: accent,
                  glow: phase2 > 0,
                ),
              ),
            ),
            // Parmak göstergesi
            Positioned(
              top: pieceY + (cell - 4) * 0.5 + 6,
              left: pieceX - 8 + 6,
              child: Opacity(
                opacity: phase1.clamp(0.0, 1.0),
                child: _Pointer(pulsing: phase2 > 0 && phase3 < 0.95, accent: accent),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Sayfa 2: Tahtaya Yerleştir ───
/// Parça grid üzerine sürükleniyor, yeşil önizleme yanıyor, drop sırasında
/// kalıcı renk alıyor.
class _DemoPlace extends StatelessWidget {
  final double t;
  final Color accent;
  const _DemoPlace({required this.t, required this.accent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cell = (w / 4).clamp(20.0, 30.0);
        // 0-0.5 sürükleme, 0.5-0.7 önizleme parlıyor, 0.7-1 yerleşmiş
        final dragPhase = (t / 0.5).clamp(0.0, 1.0);
        final previewPhase = ((t - 0.5) / 0.2).clamp(0.0, 1.0);
        final placedPhase = ((t - 0.7) / 0.3).clamp(0.0, 1.0);

        // Parça hedefi: grid'in 1. satır 1. sütun
        final targetX = cell * 1 + 4;
        final targetY = cell * 1 + 4;
        final startX = cell * 0.2;
        final startY = cell * 2.8;
        final pieceX = startX + (targetX - startX) * Curves.easeOutCubic.transform(dragPhase);
        final pieceY = startY + (targetY - startY) * Curves.easeOutCubic.transform(dragPhase);

        return Stack(
          children: [
            // Grid
            Positioned.fill(child: _MiniGrid(rows: 4, cols: 4, cell: cell)),

            // Yeşil önizleme (drag bittiğinde parlıyor)
            if (dragPhase >= 0.95 && placedPhase < 1.0)
              Positioned(
                left: targetX,
                top: targetY,
                child: Opacity(
                  opacity: (1 - placedPhase) * 0.7,
                  child: Container(
                    width: cell - 4,
                    height: (cell - 4) * 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.85),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

            // Yerleşmiş parça (kalıcı renk, drop sonrası)
            if (placedPhase > 0)
              Positioned(
                left: targetX,
                top: targetY,
                child: Opacity(
                  opacity: placedPhase,
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * Curves.easeOutBack.transform(placedPhase),
                    child: _DemoPiece(
                      width: cell - 4,
                      height: (cell - 4) * 2,
                      color: accent,
                    ),
                  ),
                ),
              ),

            // Sürüklenen parça (yerleşmeden önce)
            if (placedPhase < 0.05)
              Positioned(
                left: pieceX,
                top: pieceY,
                child: _DemoPiece(
                  width: cell - 4,
                  height: (cell - 4) * 2,
                  color: accent,
                  glow: previewPhase > 0,
                ),
              ),

            // Parmak göstergesi (sürüklendiği süre boyunca)
            if (placedPhase < 0.1)
              Positioned(
                left: pieceX + (cell - 4) * 0.5 - 8,
                top: pieceY + (cell - 4) - 4,
                child: _Pointer(pulsing: false, accent: accent),
              ),
          ],
        );
      },
    );
  }
}

// ─── Sayfa 3: Satır Temizle ───
/// 1×4 yatay sıra dolduruluyor, dolan satır parlayarak siliniyor.
class _DemoLineClear extends StatelessWidget {
  final double t;
  final Color accent;
  const _DemoLineClear({required this.t, required this.accent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cell = (w / 4).clamp(20.0, 30.0);
        // 0-0.5 satır doluyor (4 hücre tek tek)
        // 0.5-0.7 parlama (flash)
        // 0.7-1 silinme (opacity fade)
        final fillPhase = (t / 0.5).clamp(0.0, 1.0);
        final flashPhase = ((t - 0.5) / 0.2).clamp(0.0, 1.0);
        final clearPhase = ((t - 0.7) / 0.3).clamp(0.0, 1.0);

        return Stack(
          children: [
            Positioned.fill(child: _MiniGrid(rows: 3, cols: 4, cell: cell)),
            // 4 hücreyi satır 1'e tek tek yerleştir
            for (int i = 0; i < 4; i++)
              Positioned(
                left: cell * i + 4,
                top: cell * 1 + 4,
                child: Opacity(
                  opacity: fillPhase >= (i + 1) / 4 ? (1 - clearPhase) : 0,
                  child: Transform.scale(
                    scale: 1.0 + flashPhase * 0.15,
                    child: Container(
                      width: cell - 4,
                      height: cell - 4,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: flashPhase > 0 ? 0.9 : 0.7),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: flashPhase > 0
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.7 * flashPhase),
                                  blurRadius: 14 * flashPhase,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            // "+1 LİNE" etiketi clear sırasında çıkıyor
            if (clearPhase > 0 && clearPhase < 1)
              Positioned(
                left: 0,
                right: 0,
                top: cell * 1 - 14 + (1 - clearPhase) * 6,
                child: Opacity(
                  opacity: (1 - clearPhase),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.6)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '+1 LINE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Sayfa 4: Combo ───
/// Aynı anda 1 satır + 1 sütun temizleniyor → "COMBO!" badge.
class _DemoCombo extends StatelessWidget {
  final double t;
  final Color accent;
  const _DemoCombo({required this.t, required this.accent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cell = (w / 4).clamp(20.0, 30.0);
        final flash = ((t - 0.4) / 0.25).clamp(0.0, 1.0);
        final clear = ((t - 0.65) / 0.35).clamp(0.0, 1.0);
        final fill = (t / 0.4).clamp(0.0, 1.0);

        return Stack(
          children: [
            Positioned.fill(child: _MiniGrid(rows: 4, cols: 4, cell: cell)),
            // Satır 2 (yatay, 4 hücre)
            for (int i = 0; i < 4; i++)
              Positioned(
                left: cell * i + 4,
                top: cell * 2 + 4,
                child: Opacity(
                  opacity: fill >= (i + 1) / 4 ? (1 - clear) : 0,
                  child: _ComboCell(cell: cell, color: accent, flashing: flash > 0),
                ),
              ),
            // Sütun 2 (dikey, 4 hücre — satır 2 ile kesişen hariç)
            for (int j = 0; j < 4; j++)
              if (j != 2) // satır 2 ile kesişen hücre tek sayılır
                Positioned(
                  left: cell * 2 + 4,
                  top: cell * j + 4,
                  child: Opacity(
                    opacity: fill >= (j + 1) / 4 ? (1 - clear) : 0,
                    child: _ComboCell(cell: cell, color: const Color(0xFFFBBF24), flashing: flash > 0),
                  ),
                ),

            // COMBO! badge
            if (flash > 0 && clear < 0.95)
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: (flash * (1 - clear)).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.7 + 0.4 * Curves.easeOutBack.transform(flash.clamp(0.0, 1.0)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFFD700)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B6B).withValues(alpha: 0.6),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔥', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Text(
                              'COMBO!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ComboCell extends StatelessWidget {
  final double cell;
  final Color color;
  final bool flashing;
  const _ComboCell({required this.cell, required this.color, required this.flashing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cell - 4,
      height: cell - 4,
      decoration: BoxDecoration(
        color: color.withValues(alpha: flashing ? 0.95 : 0.7),
        borderRadius: BorderRadius.circular(4),
        boxShadow: flashing
            ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 10)]
            : null,
      ),
    );
  }
}

// ─── Yardımcı görsel widget'lar ───

/// Mini grid arka planı — boş hücreler.
class _MiniGrid extends StatelessWidget {
  final int rows;
  final int cols;
  final double cell;
  const _MiniGrid({required this.rows, required this.cols, required this.cell});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int r = 0; r < rows; r++)
          for (int c = 0; c < cols; c++)
            Positioned(
              left: cell * c + 4,
              top: cell * r + 4,
              child: Container(
                width: cell - 4,
                height: cell - 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Bir parça (renkli, gradyan dolu, opsiyonel glow).
class _DemoPiece extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final bool glow;
  const _DemoPiece({
    required this.width,
    required this.height,
    required this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Animasyonlu parmak/dokunma göstergesi.
class _Pointer extends StatefulWidget {
  final bool pulsing;
  final Color accent;
  const _Pointer({required this.pulsing, required this.accent});

  @override
  State<_Pointer> createState() => _PointerState();
}

class _PointerState extends State<_Pointer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final scale = widget.pulsing ? 1.0 + 0.18 * _ctrl.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accent.withValues(alpha: 0.35),
              border: Border.all(color: widget.accent, width: 1.4),
            ),
          ),
        );
      },
    );
  }
}

/// Geri/İleri butonu (Mayın Tarlası tutorial'ındaki ile aynı stil).
class _HowToNavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _HowToNavBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.15 : 0.05),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: enabled ? 0.85 : 0.25),
          size: 22,
        ),
      ),
    );
  }
}
