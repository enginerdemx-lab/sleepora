import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';
import '../minesweeper_game.dart';
import 'minesweeper_config.dart';
import 'minesweeper_progress_service.dart';
import 'minesweeper_theme_shop.dart';
import 'minesweeper_tutorial.dart';

/// 100 seviyelik sayfalanmış seviye seçim ekranı.
class MinesweeperLevelSelect extends StatefulWidget {
  const MinesweeperLevelSelect({super.key});

  @override
  State<MinesweeperLevelSelect> createState() => _MinesweeperLevelSelectState();
}

class _MinesweeperLevelSelectState extends State<MinesweeperLevelSelect> {
  static const levelsPerPage = 20;
  static const totalLevels = 100;
  static const totalPages = totalLevels ~/ levelsPerPage; // 5

  int _page = 0;
  int _selectedLevel = 1;
  final _progress = MinesweeperProgressService();

  @override
  void initState() {
    super.initState();
    _progress.addListener(_onProgressChange);
    // İlk seçim: en son kilit açılmış seviye
    _selectedLevel = _progress.maxUnlocked.clamp(1, totalLevels);
    _page = (_selectedLevel - 1) ~/ levelsPerPage;

    // Tutorial hiç görülmemişse otomatik göster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_progress.tutorialDone && mounted) {
        _showTutorial(markAsDone: true);
      }
    });
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgressChange);
    super.dispose();
  }

  void _onProgressChange() {
    if (mounted) setState(() {});
  }

  void _showTutorial({bool markAsDone = false}) {
    MinesweeperTutorial.show(context).then((_) {
      if (markAsDone) _progress.markTutorialDone();
    });
  }

  void _nextPage() {
    if (_page < totalPages - 1) setState(() => _page++);
  }

  void _prevPage() {
    if (_page > 0) setState(() => _page--);
  }

  void _startLevel(int level) async {
    if (!_progress.isLevelUnlocked(level)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MinesweeperGame(level: level)),
    );
    if (mounted) setState(() {});
  }

  void _skipLevel() async {
    if (_selectedLevel != _progress.maxUnlocked) return;
    if (_progress.coins < 50) {
      _showSnack('Yeterli coin yok (50 gerekli)');
      return;
    }
    final confirm = await _confirmDialog(
      title: 'Seviyeyi atla?',
      message: '50 coin harcayarak seviye $_selectedLevel\'i atlayabilirsin.',
    );
    if (confirm != true) return;
    final ok = await _progress.skipLevel(_selectedLevel);
    if (ok) {
      _showSnack(LocalizationService().t('MSLevelSkipped'));
      setState(() => _selectedLevel = (_selectedLevel + 1).clamp(1, totalLevels));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars(); // önceki uyarılar kuyrukta birikmesin
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF2D1B4E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1025),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocalizationService().t('GameCancel'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = MinesweeperLevelConfig.forLevel(_selectedLevel);
    final stars = _progress.stars(_selectedLevel);
    final bestTime = _progress.bestTime(_selectedLevel);
    final isCurrentlyOn = _selectedLevel == _progress.maxUnlocked;

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
          'Seviyeler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          // Coin göstergesi
          _CoinBadge(coins: _progress.coins),
          const SizedBox(width: 4),
          // Tema dükkanı
          IconButton(
            tooltip: 'Temalar',
            icon: const Icon(Icons.palette_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MinesweeperThemeShop()),
              );
            },
          ),
          // Tutorial
          IconButton(
            tooltip: LocalizationService().t('GameHowToPlay'),
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
            onPressed: _showTutorial,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ─── Sayfa navigasyonu ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  _PageArrow(
                    icon: Icons.chevron_left_rounded,
                    enabled: _page > 0,
                    onTap: _prevPage,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Seviye ${_page * levelsPerPage + 1} - ${(_page + 1) * levelsPerPage}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _PageArrow(
                    icon: Icons.chevron_right_rounded,
                    enabled: _page < totalPages - 1,
                    onTap: _nextPage,
                  ),
                ],
              ),
            ),

            // ─── Seviye grid'i ───
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: levelsPerPage,
                  itemBuilder: (context, index) {
                    final level = _page * levelsPerPage + index + 1;
                    final unlocked = _progress.isLevelUnlocked(level);
                    final lvlStars = _progress.stars(level);
                    final isSelected = level == _selectedLevel;

                    return _LevelTile(
                      level: level,
                      unlocked: unlocked,
                      stars: lvlStars,
                      selected: isSelected,
                      onTap: unlocked
                          ? () => setState(() => _selectedLevel = level)
                          : null,
                    );
                  },
                ),
              ),
            ),

            // ─── Seçili seviye detayı + aksiyon butonları ───
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Seviye $_selectedLevel',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (stars > 0) _Stars(count: stars, size: 14),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _InfoPill(
                                  icon: Icons.grid_view_rounded,
                                  text: '${config.rows}×${config.cols}',
                                ),
                                const SizedBox(width: 6),
                                _InfoPill(
                                  icon: Icons.brightness_7_rounded,
                                  text: '${config.mines}',
                                  color: const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 6),
                                _InfoPill(
                                  icon: Icons.timer_rounded,
                                  text: '${config.timeLimit}s',
                                  color: const Color(0xFF60A5FA),
                                ),
                              ],
                            ),
                            if (bestTime != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'En iyi: ${bestTime}s',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Seviye atla
                      Expanded(
                        flex: 4,
                        child: _SecondaryButton(
                          label: 'Atla',
                          icon: Icons.skip_next_rounded,
                          subtitle: '50',
                          subtitleIcon: Icons.monetization_on_rounded,
                          subtitleColor: const Color(0xFFFFD700),
                          enabled:
                              isCurrentlyOn && _progress.coins >= 50,
                          onTap: _skipLevel,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Başlat
                      Expanded(
                        flex: 6,
                        child: _PrimaryButton(
                          label: LocalizationService().t('GameStart'),
                          icon: Icons.play_arrow_rounded,
                          onTap: () => _startLevel(_selectedLevel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────── Alt widget'lar ───────────────

class _CoinBadge extends StatelessWidget {
  final int coins;
  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.18),
            const Color(0xFFFFA500).withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFFFD700),
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(
            '$coins',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.15 : 0.05),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: enabled ? 0.85 : 0.25),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final bool unlocked;
  final int stars;
  final bool selected;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgAlpha = !unlocked
        ? 0.03
        : selected
            ? 0.18
            : 0.06;
    final border = !unlocked
        ? Colors.white.withValues(alpha: 0.06)
        : selected
            ? AppColors.purple
            : Colors.white.withValues(alpha: 0.1);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.purple.withValues(alpha: 0.35),
                    AppColors.purple.withValues(alpha: 0.12),
                  ],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: selected ? 1.6 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Seviye numarası
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$level',
                    style: TextStyle(
                      color: unlocked
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.25),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (unlocked && stars > 0) ...[
                    const SizedBox(height: 4),
                    _Stars(count: stars, size: 9),
                  ],
                ],
              ),
            ),
            // Kilit ikonu
            if (!unlocked)
              Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.lock_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int count;
  final double size;
  const _Stars({required this.count, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled
              ? const Color(0xFFFFD700)
              : Colors.white.withValues(alpha: 0.2),
        );
      }),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoPill({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white.withValues(alpha: 0.75);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 12),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? subtitle;
  final IconData? subtitleIcon;
  final Color? subtitleColor;
  final bool enabled;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    this.subtitle,
    this.subtitleIcon,
    this.subtitleColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: enabled ? 0.9 : 0.3),
              size: 18,
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.3),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Row(
                    children: [
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: subtitleColor?.withValues(
                                  alpha: enabled ? 1 : 0.4) ??
                              Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitleIcon != null) ...[
                        const SizedBox(width: 3),
                        Icon(
                          subtitleIcon,
                          color: subtitleColor?.withValues(
                                  alpha: enabled ? 1 : 0.4) ??
                              Colors.white.withValues(alpha: 0.5),
                          size: 11,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
