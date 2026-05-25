import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';
import 'minesweeper_config.dart';
import 'minesweeper_progress_service.dart';

/// Tema dükkanı — tüm temalar, coin ile satın alma, günlük ödül.
class MinesweeperThemeShop extends StatefulWidget {
  const MinesweeperThemeShop({super.key});

  @override
  State<MinesweeperThemeShop> createState() => _MinesweeperThemeShopState();
}

class _MinesweeperThemeShopState extends State<MinesweeperThemeShop> {
  final _progress = MinesweeperProgressService();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_onChange);
    // Günlük ödül geri sayımı için saniye ticker
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _progress.removeListener(_onChange);
    _ticker?.cancel();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _buyOrSelect(MinesweeperTheme theme) async {
    if (_progress.ownsTheme(theme.id)) {
      // Zaten sahip, aktif yap
      if (_progress.activeTheme != theme.id) {
        await _progress.setActiveTheme(theme.id);
        _showSnack('${theme.name} aktif edildi');
      }
      return;
    }

    // Satın alma
    if (_progress.coins < theme.price) {
      _showSnack('Yeterli coin yok (${theme.price} gerekli)');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmPurchaseDialog(theme: theme),
    );
    if (confirm != true) return;

    final ok = await _progress.buyTheme(theme.id, theme.price);
    final loc = LocalizationService();
    if (ok) {
      await _progress.setActiveTheme(theme.id);
      if (mounted) _showSnack(loc.t('MSThemePurchased').replaceAll('{name}', theme.name));
    } else {
      _showSnack(loc.t('MSPurchaseFailed'));
    }
  }

  void _claimDailyReward() async {
    if (!_progress.canClaimDailyReward) return;
    final ok = await _progress.claimDailyReward();
    if (ok) {
      _showSnack(LocalizationService().t('MSCoinsEarned').replaceAll('{n}', '40'));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
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

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final themes = MinesweeperThemes.all;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LocalizationService().t('MSThemeShop'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          _CoinBadge(coins: _progress.coins),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            // ─── Günlük ödül kartı ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _DailyRewardCard(
                  canClaim: _progress.canClaimDailyReward,
                  remaining: _progress.nextDailyRewardIn,
                  onClaim: _claimDailyReward,
                  formatter: _formatDuration,
                ),
              ),
            ),
            // ─── Tema ızgarası başlık ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Row(
                  children: [
                    const Icon(Icons.palette_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Temalar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_progress.ownedThemes.length}/${themes.length}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ─── Tema kartları ───
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final theme = themes[index];
                    final owned = _progress.ownsTheme(theme.id);
                    final active = _progress.activeTheme == theme.id;
                    return _ThemeCard(
                      theme: theme,
                      owned: owned,
                      active: active,
                      canAfford: _progress.coins >= theme.price,
                      onTap: () => _buyOrSelect(theme),
                    );
                  },
                  childCount: themes.length,
                ),
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

class _DailyRewardCard extends StatelessWidget {
  final bool canClaim;
  final Duration remaining;
  final VoidCallback onClaim;
  final String Function(Duration) formatter;

  const _DailyRewardCard({
    required this.canClaim,
    required this.remaining,
    required this.onClaim,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFD700).withValues(alpha: 0.12),
                const Color(0xFF8B5CF6).withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService().t('MSDailyReward'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canClaim
                          ? '+40 coin seni bekliyor!'
                          : 'Sonraki: ${formatter(remaining)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: canClaim ? onClaim : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: canClaim
                        ? const LinearGradient(
                            colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                          )
                        : null,
                    color: canClaim
                        ? null
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: canClaim
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: canClaim
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFBBF24)
                                  .withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    canClaim ? 'Al' : 'Bekle',
                    style: TextStyle(
                      color: canClaim
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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

class _ThemeCard extends StatelessWidget {
  final MinesweeperTheme theme;
  final bool owned;
  final bool active;
  final bool canAfford;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.owned,
    required this.active,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? theme.accent
                : Colors.white.withValues(alpha: 0.1),
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Önizleme ───
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                child: _ThemePreview(theme: theme),
              ),
            ),
            // ─── İsim + aksiyon ───
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _ActionBadge(
                    theme: theme,
                    owned: owned,
                    active: active,
                    canAfford: canAfford,
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

class _ThemePreview extends StatelessWidget {
  final MinesweeperTheme theme;
  const _ThemePreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    // 3x3 grid preview
    return Container(
      color: theme.background,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (row) {
          return Expanded(
            child: Row(
              children: List.generate(3, (col) {
                // Özel hücreler: (0,1) açık sayı 2, (1,1) bayrak, (2,2) mayın
                final isRevealed = row == 0 && col == 1;
                final isFlag = row == 1 && col == 1;
                final isMine = row == 2 && col == 2;

                Color bg;
                if (isMine) {
                  bg = theme.cellMine;
                } else if (isRevealed) {
                  bg = theme.cellRevealed;
                } else {
                  bg = theme.cellCovered;
                }

                Widget? content;
                if (isRevealed) {
                  content = Text(
                    '2',
                    style: TextStyle(
                      color: theme.numberColor(2),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                } else if (isFlag) {
                  content = Icon(
                    Icons.flag_rounded,
                    color: theme.flagColor,
                    size: 14,
                  );
                } else if (isMine) {
                  content = Icon(
                    Icons.brightness_7_rounded,
                    color: theme.mineColor,
                    size: 14,
                  );
                }

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: theme.borderColor,
                        width: 0.5,
                      ),
                    ),
                    child: Center(child: content),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  final MinesweeperTheme theme;
  final bool owned;
  final bool active;
  final bool canAfford;

  const _ActionBadge({
    required this.theme,
    required this.owned,
    required this.active,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    if (active) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: theme.accentGradient),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_rounded, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'Aktif',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (owned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LocalizationService().t('GameSelect'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    // Satın alınabilir — fiyat
    final affordable = canAfford;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: affordable
            ? const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
              )
            : null,
        color: affordable ? null : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: affordable
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on_rounded,
            color: affordable
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '${theme.price}',
            style: TextStyle(
              color: affordable
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmPurchaseDialog extends StatelessWidget {
  final MinesweeperTheme theme;
  const _ConfirmPurchaseDialog({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: theme.accentGradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accent.withValues(alpha: 0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  theme.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LocalizationService().t('MSBuyConfirm').replaceAll('{n}', '${theme.price}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        child: Text(
                          LocalizationService().t('GameCancel'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: theme.accentGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: theme.accent.withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              LocalizationService().t('GameBuy'),
                              style: const TextStyle(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
