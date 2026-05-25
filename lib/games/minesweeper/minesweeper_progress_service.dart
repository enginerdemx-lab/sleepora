import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mayın Tarlası ilerleme / coin / tema servisi.
/// SharedPreferences tabanlı singleton.
class MinesweeperProgressService extends ChangeNotifier {
  MinesweeperProgressService._();
  static final MinesweeperProgressService _i = MinesweeperProgressService._();
  factory MinesweeperProgressService() => _i;

  // ───────── Keys ─────────
  static const _kCoins = 'ms_coins';
  static const _kMaxUnlocked = 'ms_max_unlocked';
  static const _kBestTimePrefix = 'ms_best_';
  static const _kStarsPrefix = 'ms_stars_';
  static const _kOwnedThemes = 'ms_owned_themes';
  static const _kActiveTheme = 'ms_active_theme';
  static const _kTutorialDone = 'ms_tutorial_done';
  static const _kLastDailyReward = 'ms_last_daily_reward';

  SharedPreferences? _prefs;
  bool _initialized = false;

  int _coins = 25;
  int _maxUnlocked = 1;
  final Map<int, int> _bestTimes = {};
  final Map<int, int> _stars = {};
  Set<String> _ownedThemes = {'default'};
  String _activeTheme = 'default';
  bool _tutorialDone = false;
  DateTime? _lastDailyReward;

  // ───────── Getters ─────────
  int get coins => _coins;
  int get maxUnlocked => _maxUnlocked;
  Set<String> get ownedThemes => _ownedThemes;
  String get activeTheme => _activeTheme;
  bool get tutorialDone => _tutorialDone;

  int? bestTime(int level) => _bestTimes[level];
  int stars(int level) => _stars[level] ?? 0;
  bool isLevelUnlocked(int level) => level <= _maxUnlocked;
  bool ownsTheme(String id) => _ownedThemes.contains(id);

  bool get canClaimDailyReward {
    if (_lastDailyReward == null) return true;
    final diff = DateTime.now().difference(_lastDailyReward!);
    return diff.inHours >= 24;
  }

  Duration get nextDailyRewardIn {
    if (_lastDailyReward == null) return Duration.zero;
    final target = _lastDailyReward!.add(const Duration(hours: 24));
    final remaining = target.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // ───────── Init ─────────
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    _coins = _prefs!.getInt(_kCoins) ?? 25;
    _maxUnlocked = _prefs!.getInt(_kMaxUnlocked) ?? 1;
    _activeTheme = _prefs!.getString(_kActiveTheme) ?? 'default';
    _tutorialDone = _prefs!.getBool(_kTutorialDone) ?? false;

    final ownedList = _prefs!.getStringList(_kOwnedThemes) ?? const ['default'];
    _ownedThemes = ownedList.toSet();
    if (!_ownedThemes.contains('default')) _ownedThemes.add('default');

    // Best times ve stars
    _bestTimes.clear();
    _stars.clear();
    for (final key in _prefs!.getKeys()) {
      if (key.startsWith(_kBestTimePrefix)) {
        final level = int.tryParse(key.substring(_kBestTimePrefix.length));
        if (level != null) _bestTimes[level] = _prefs!.getInt(key) ?? 0;
      } else if (key.startsWith(_kStarsPrefix)) {
        final level = int.tryParse(key.substring(_kStarsPrefix.length));
        if (level != null) _stars[level] = _prefs!.getInt(key) ?? 0;
      }
    }

    final lastDailyStr = _prefs!.getString(_kLastDailyReward);
    if (lastDailyStr != null) {
      _lastDailyReward = DateTime.tryParse(lastDailyStr);
    }

    _initialized = true;
    notifyListeners();
  }

  // ───────── Actions ─────────
  Future<void> earnCoins(int amount) async {
    if (amount <= 0) return;
    _coins += amount;
    await _prefs?.setInt(_kCoins, _coins);
    notifyListeners();
  }

  /// Başarılı harcama: true döner.
  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return true;
    if (_coins < amount) return false;
    _coins -= amount;
    await _prefs?.setInt(_kCoins, _coins);
    notifyListeners();
    return true;
  }

  /// Seviye tamamlandığında çağır.
  /// Yıldız sayısı süreye göre hesaplanır (3: %50 altı, 2: %80 altı, 1: içinde bitti).
  /// Dönen değer: kazanılan coin.
  Future<int> completeLevel({
    required int level,
    required int timeSeconds,
    required int timeLimit,
  }) async {
    int starsEarned;
    final ratio = timeSeconds / timeLimit;
    if (ratio <= 0.5) {
      starsEarned = 3;
    } else if (ratio <= 0.8) {
      starsEarned = 2;
    } else {
      starsEarned = 1;
    }

    // Yıldız kaydı (sadece daha iyiyse güncelle)
    final prevStars = _stars[level] ?? 0;
    final isFirstTime = prevStars == 0;
    if (starsEarned > prevStars) {
      _stars[level] = starsEarned;
      await _prefs?.setInt('$_kStarsPrefix$level', starsEarned);
    }

    // Best time
    final prevBest = _bestTimes[level];
    if (prevBest == null || timeSeconds < prevBest) {
      _bestTimes[level] = timeSeconds;
      await _prefs?.setInt('$_kBestTimePrefix$level', timeSeconds);
    }

    // Bir sonraki seviyeyi aç
    if (level >= _maxUnlocked && level < 100) {
      _maxUnlocked = level + 1;
      await _prefs?.setInt(_kMaxUnlocked, _maxUnlocked);
    }

    // Coin ödülü: ilk defa 30 + yıldız başına 10, tekrar oynayınca yıldız iyileştiyse 10 fark
    int coinReward;
    if (isFirstTime) {
      coinReward = 30 + starsEarned * 10;
    } else if (starsEarned > prevStars) {
      coinReward = (starsEarned - prevStars) * 10;
    } else {
      coinReward = 5; // tekrar bitirme teşviği
    }
    await earnCoins(coinReward);

    notifyListeners();
    return coinReward;
  }

  /// Seviye atla — coin harcar, sonraki seviyeyi açar.
  Future<bool> skipLevel(int level, {int cost = 50}) async {
    if (level != _maxUnlocked) return false;
    if (_coins < cost) return false;
    await spendCoins(cost);
    if (level < 100) {
      _maxUnlocked = level + 1;
      await _prefs?.setInt(_kMaxUnlocked, _maxUnlocked);
    }
    // Atlanan seviyeye 1 yıldız ver (gösterimi için)
    _stars[level] = 1;
    await _prefs?.setInt('$_kStarsPrefix$level', 1);
    notifyListeners();
    return true;
  }

  Future<bool> buyTheme(String id, int price) async {
    if (_ownedThemes.contains(id)) return true;
    if (!await spendCoins(price)) return false;
    _ownedThemes.add(id);
    await _prefs?.setStringList(_kOwnedThemes, _ownedThemes.toList());
    notifyListeners();
    return true;
  }

  Future<void> setActiveTheme(String id) async {
    if (!_ownedThemes.contains(id)) return;
    _activeTheme = id;
    await _prefs?.setString(_kActiveTheme, id);
    notifyListeners();
  }

  Future<void> markTutorialDone() async {
    _tutorialDone = true;
    await _prefs?.setBool(_kTutorialDone, true);
    notifyListeners();
  }

  /// Günlük ödülü al (+40 coin). Alınamıyorsa false.
  Future<bool> claimDailyReward() async {
    if (!canClaimDailyReward) return false;
    _lastDailyReward = DateTime.now();
    await _prefs?.setString(_kLastDailyReward, _lastDailyReward!.toIso8601String());
    await earnCoins(40);
    return true;
  }
}
