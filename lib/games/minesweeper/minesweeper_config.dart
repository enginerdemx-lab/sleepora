import 'package:flutter/material.dart';

/// Seviye konfigürasyonu — grid boyutu, mayın sayısı, süre limiti.
class MinesweeperLevelConfig {
  final int level;
  final int rows;
  final int cols;
  final int mines;
  final int timeLimit; // saniye

  const MinesweeperLevelConfig({
    required this.level,
    required this.rows,
    required this.cols,
    required this.mines,
    required this.timeLimit,
  });

  /// 1-100 arası seviye için kademeli zorluk üretir.
  /// Grid 6x8'den başlar, 10x12'ye kadar büyür.
  /// Mayın yoğunluğu %12'den %22'ye doğru artar.
  static MinesweeperLevelConfig forLevel(int level) {
    final clamped = level.clamp(1, 100);

    // Grid boyutu — her 20 seviyede 1 artış
    final sizeStep = (clamped - 1) ~/ 20; // 0-4
    final cols = 6 + sizeStep;             // 6, 7, 8, 9, 10
    final rows = 8 + sizeStep;             // 8, 9, 10, 11, 12

    // Mayın yoğunluğu — seviyeyle birlikte artar.
    // Taban %15'e çekildi ve minimum 8 mayın: erken seviyelerde tahta fazla
    // seyrek kalıp ilk tıkta tamamen açılmasın (anında kazanma önlenir).
    final totalCells = rows * cols;
    final density = 0.15 + (clamped / 100) * 0.08; // 0.15 → 0.23
    final mines = (totalCells * density).round().clamp(8, totalCells - 9);

    // Süre limiti — mayın başına 8 saniye + 30 baz
    final timeLimit = mines * 8 + 30;

    return MinesweeperLevelConfig(
      level: clamped,
      rows: rows,
      cols: cols,
      mines: mines,
      timeLimit: timeLimit,
    );
  }
}

// ─────────────── TEMA ───────────────

class MinesweeperTheme {
  final String id;
  final String name;
  final int price; // 0 = free
  final Color cellCovered;      // kapalı karenin rengi
  final Color cellRevealed;     // açılmış karenin rengi
  final Color cellMine;         // mayın patladığında karenin arka rengi
  final Color flagColor;        // bayrak rengi
  final Color mineColor;        // mayın ikonunun rengi
  final Color borderColor;      // grid kenarlık
  final Color background;       // oyun alanı arka plan
  final List<Color> numberColors; // 1-8 için
  final Color accent;           // aksan rengi (butonlar, barlar)
  final List<Color> accentGradient;

  const MinesweeperTheme({
    required this.id,
    required this.name,
    required this.price,
    required this.cellCovered,
    required this.cellRevealed,
    required this.cellMine,
    required this.flagColor,
    required this.mineColor,
    required this.borderColor,
    required this.background,
    required this.numberColors,
    required this.accent,
    required this.accentGradient,
  });

  Color numberColor(int n) {
    if (n < 1 || n > numberColors.length) return numberColors.last;
    return numberColors[n - 1];
  }
}

class MinesweeperThemes {
  static const defaultTheme = MinesweeperTheme(
    id: 'default',
    name: 'Klasik Mor',
    price: 0,
    cellCovered: Color(0xFF2D1B4E),
    cellRevealed: Color(0x14FFFFFF),
    cellMine: Color(0x4DEF4444),
    flagColor: Color(0xFFFBBF24),
    mineColor: Color(0xFFEF4444),
    borderColor: Color(0x0FFFFFFF),
    background: Color(0xFF1A1025),
    numberColors: [
      Color(0xFF60A5FA), // 1
      Color(0xFF34D399), // 2
      Color(0xFFEF4444), // 3
      Color(0xFF8B5CF6), // 4
      Color(0xFFF59E0B), // 5
      Color(0xFFF472B6), // 6
      Color(0xFFFBBF24), // 7
      Color(0xFFFFFFFF), // 8
    ],
    accent: Color(0xFF8B5CF6),
    accentGradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  );

  static const dark = MinesweeperTheme(
    id: 'dark',
    name: 'Gece Yarısı',
    price: 0, // ikinci bedava tema
    cellCovered: Color(0xFF1F2937),
    cellRevealed: Color(0x14FFFFFF),
    cellMine: Color(0x4DDC2626),
    flagColor: Color(0xFFF59E0B),
    mineColor: Color(0xFFDC2626),
    borderColor: Color(0x14FFFFFF),
    background: Color(0xFF0B0F17),
    numberColors: [
      Color(0xFF93C5FD),
      Color(0xFF6EE7B7),
      Color(0xFFFCA5A5),
      Color(0xFFC4B5FD),
      Color(0xFFFCD34D),
      Color(0xFFF9A8D4),
      Color(0xFFFDE68A),
      Color(0xFFE5E7EB),
    ],
    accent: Color(0xFF6366F1),
    accentGradient: [Color(0xFF6366F1), Color(0xFF4338CA)],
  );

  static const sepia = MinesweeperTheme(
    id: 'sepia',
    name: 'Antik Harita',
    price: 250,
    cellCovered: Color(0xFF8B4513),
    cellRevealed: Color(0xFFD4A574),
    cellMine: Color(0xFFCD5C5C),
    flagColor: Color(0xFFDC143C),
    mineColor: Color(0xFF3E2723),
    borderColor: Color(0x33000000),
    background: Color(0xFFF5E6C8),
    numberColors: [
      Color(0xFF1E40AF),
      Color(0xFF047857),
      Color(0xFFB91C1C),
      Color(0xFF5B21B6),
      Color(0xFF92400E),
      Color(0xFFBE185D),
      Color(0xFF78350F),
      Color(0xFF111827),
    ],
    accent: Color(0xFF92400E),
    accentGradient: [Color(0xFFB45309), Color(0xFF78350F)],
  );

  static const pink = MinesweeperTheme(
    id: 'pink',
    name: 'Pembe Rüya',
    price: 250,
    cellCovered: Color(0xFF9D174D),
    cellRevealed: Color(0x22FFFFFF),
    cellMine: Color(0x66F472B6),
    flagColor: Color(0xFFFFF1F2),
    mineColor: Color(0xFFFDF2F8),
    borderColor: Color(0x22FFFFFF),
    background: Color(0xFF581C3B),
    numberColors: [
      Color(0xFFFBCFE8),
      Color(0xFFA7F3D0),
      Color(0xFFFDA4AF),
      Color(0xFFDDD6FE),
      Color(0xFFFDE68A),
      Color(0xFFFBCFE8),
      Color(0xFFFEF3C7),
      Color(0xFFFFFFFF),
    ],
    accent: Color(0xFFDB2777),
    accentGradient: [Color(0xFFEC4899), Color(0xFFBE185D)],
  );

  static const green = MinesweeperTheme(
    id: 'green',
    name: 'Orman',
    price: 500,
    cellCovered: Color(0xFF065F46),
    cellRevealed: Color(0x22FFFFFF),
    cellMine: Color(0x66DC2626),
    flagColor: Color(0xFFFBBF24),
    mineColor: Color(0xFFFFFFFF),
    borderColor: Color(0x22FFFFFF),
    background: Color(0xFF022C22),
    numberColors: [
      Color(0xFF86EFAC),
      Color(0xFFFDE68A),
      Color(0xFFFCA5A5),
      Color(0xFFA5F3FC),
      Color(0xFFFCD34D),
      Color(0xFFF9A8D4),
      Color(0xFFFEF08A),
      Color(0xFFFFFFFF),
    ],
    accent: Color(0xFF10B981),
    accentGradient: [Color(0xFF10B981), Color(0xFF047857)],
  );

  static const gold = MinesweeperTheme(
    id: 'gold',
    name: 'Altın Çağ',
    price: 500,
    cellCovered: Color(0xFFB45309),
    cellRevealed: Color(0x33FFFFFF),
    cellMine: Color(0x66DC2626),
    flagColor: Color(0xFFFEF3C7),
    mineColor: Color(0xFF1F2937),
    borderColor: Color(0x33FFFFFF),
    background: Color(0xFF422006),
    numberColors: [
      Color(0xFFFEF3C7),
      Color(0xFFBBF7D0),
      Color(0xFFFECACA),
      Color(0xFFDDD6FE),
      Color(0xFFFDE68A),
      Color(0xFFFBCFE8),
      Color(0xFFFEF08A),
      Color(0xFFFFFFFF),
    ],
    accent: Color(0xFFF59E0B),
    accentGradient: [Color(0xFFFBBF24), Color(0xFFD97706)],
  );

  static const blue = MinesweeperTheme(
    id: 'blue',
    name: 'Okyanus',
    price: 750,
    cellCovered: Color(0xFF1E3A8A),
    cellRevealed: Color(0x22FFFFFF),
    cellMine: Color(0x66DC2626),
    flagColor: Color(0xFFFCD34D),
    mineColor: Color(0xFFE0F2FE),
    borderColor: Color(0x22FFFFFF),
    background: Color(0xFF0C1E3F),
    numberColors: [
      Color(0xFF7DD3FC),
      Color(0xFF86EFAC),
      Color(0xFFFCA5A5),
      Color(0xFFC4B5FD),
      Color(0xFFFCD34D),
      Color(0xFFF9A8D4),
      Color(0xFFFDE68A),
      Color(0xFFFFFFFF),
    ],
    accent: Color(0xFF3B82F6),
    accentGradient: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  );

  static const sunset = MinesweeperTheme(
    id: 'sunset',
    name: 'Gün Batımı',
    price: 750,
    cellCovered: Color(0xFF7C2D12),
    cellRevealed: Color(0x33FFFFFF),
    cellMine: Color(0x88DC2626),
    flagColor: Color(0xFFFEF08A),
    mineColor: Color(0xFFFFF7ED),
    borderColor: Color(0x33FFFFFF),
    background: Color(0xFF431407),
    numberColors: [
      Color(0xFFFED7AA),
      Color(0xFFBBF7D0),
      Color(0xFFFECACA),
      Color(0xFFDDD6FE),
      Color(0xFFFDE68A),
      Color(0xFFFBCFE8),
      Color(0xFFFEF08A),
      Color(0xFFFFFFFF),
    ],
    accent: Color(0xFFF97316),
    accentGradient: [Color(0xFFFB923C), Color(0xFFC2410C)],
  );

  static const all = <MinesweeperTheme>[
    defaultTheme,
    dark,
    sepia,
    pink,
    green,
    gold,
    blue,
    sunset,
  ];

  static MinesweeperTheme byId(String id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => defaultTheme,
    );
  }
}
