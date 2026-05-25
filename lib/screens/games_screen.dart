import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../games/minesweeper/minesweeper_level_select.dart';
import '../games/game_2048.dart';
import '../games/quiz_game.dart';
import '../games/block_puzzle/block_puzzle_game.dart';
import '../services/localization_service.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';
import 'leaderboard_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> with TickerProviderStateMixin {
  final _loc = LocalizationService();
  late AnimationController _headerController;
  late AnimationController _cardsController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    // LocalizationService bir ChangeNotifier — dil değiştiğinde tüm dinleyici
    // ekranlar rebuild olmalı. IndexedStack içinde 'const GamesScreen()' olarak
    // tutulduğumuz için parent rebuild bize ulaşmıyordu; bu yüzden kendimiz
    // listen ediyoruz. Aynı pattern home_screen.dart'ta da kullanılıyor.
    _loc.addListener(_onLanguageChanged);
    _headerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));
    _cardsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardsController.forward();
    });
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _loc.removeListener(_onLanguageChanged);
    _headerController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final games = [
      _GameData(
        title: _loc.t('GameMinesweeper'),
        subtitle: _loc.t('GameMinesweeperSub'),
        icon: Icons.flag_rounded,
        imagePath: 'assets/images/artwork/mayintarlasi.jpg',
        accentColors: [const Color(0xFF0E7490), const Color(0xFF06B6D4)],
        tag: '🧠',
        tagLabel: _loc.t('TagStrategy'),
        rating: '4.8',
        screen: const MinesweeperLevelSelect(),
      ),
      _GameData(
        title: _loc.t('Game2048'),
        subtitle: _loc.t('Game2048Sub'),
        icon: Icons.grid_4x4_rounded,
        imagePath: 'assets/images/artwork/2048.jpg',
        accentColors: [const Color(0xFF9D174D), const Color(0xFFDB2777)],
        tag: '🔢',
        tagLabel: _loc.t('TagPuzzle'),
        rating: '4.9',
        screen: const Game2048(),
      ),
      _GameData(
        title: _loc.t('GameBlockPuzzle'),
        subtitle: _loc.t('GameBlockPuzzleSub'),
        icon: Icons.dashboard_rounded,
        imagePath: 'assets/images/artwork/block.png',
        accentColors: [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
        tag: '🧩',
        tagLabel: _loc.t('TagPuzzle'),
        rating: '4.7',
        screen: const BlockPuzzleGame(),
      ),
      _GameData(
        title: _loc.t('GameQuiz'),
        subtitle: _loc.t('GameQuizSub'),
        icon: Icons.quiz_rounded,
        imagePath: 'assets/images/artwork/bilgiyarismasi.jpg',
        accentColors: [const Color(0xFF4C1D95), const Color(0xFF7C3AED)],
        tag: '💡',
        tagLabel: _loc.t('TagKnowledge'),
        rating: '5.0',
        screen: const QuizGame(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ─── Kompakt Başlık: sol tarafta başlık+altyazı,
            //      sağda camsı kupa butonu (Sıralama) ───
            SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 14, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _loc.t('TabGames'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _loc.t('GamesSub'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _LeaderboardButton(
                        label: _loc.t('Leaderboard'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LeaderboardScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ─── Oyun Kartları ───
            Expanded(
              child: ListenableBuilder(
                listenable: _cardsController,
                builder: (context, _) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                    itemCount: games.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final delay = index * 0.2;
                      final end = (delay + 0.6).clamp(0.0, 1.0);
                      final progress = Interval(delay, end, curve: Curves.easeOutCubic)
                          .transform(_cardsController.value);
                      final game = games[index];

                      return Transform.translate(
                        offset: Offset(0, 40 * (1 - progress)),
                        child: Opacity(
                          opacity: progress.clamp(0.0, 1.0),
                          child: _GameCard(game: game),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String imagePath;
  final List<Color> accentColors;
  final String tag;
  final String tagLabel;
  final String rating;
  final Widget screen;

  const _GameData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.imagePath,
    required this.accentColors,
    required this.tag,
    required this.tagLabel,
    required this.rating,
    required this.screen,
  });
}

class _GameCard extends StatefulWidget {
  final _GameData game;
  const _GameCard({required this.game});

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final c1 = g.accentColors[0];
    final c2 = g.accentColors[1];

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => g.screen)),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c1.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: c1.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // ─── İkon alanı ───
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: c2.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          g.imagePath,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [c1, c2],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(g.icon, color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // ─── Bilgi ───
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            g.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Tag
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c1.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${g.tag} ${g.tagLabel}',
                                  style: TextStyle(
                                    color: c2,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Rating
                              Icon(Icons.star_rounded,
                                  color: const Color(0xFFFFD700), size: 13),
                              const SizedBox(width: 2),
                              Text(
                                g.rating,
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ─── Oyna butonu ───
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [c1, c2],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: c2.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 24),
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
}

// ─────────────────────────────────────────────────────────────
// Kompakt Sıralama (Leaderboard) butonu — başlık satırında durur
// Camsı arka plan + altın kupa + hafif glow + basma animasyonu
// Kullanıcının 4 oyundaki EN İYİ sırasını küçük rozet olarak gösterir.
// Giriş yapmamış / skoru yoksa rozet görünmez — buton sade kalır.
// ─────────────────────────────────────────────────────────────
class _LeaderboardButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _LeaderboardButton({required this.label, required this.onTap});

  @override
  State<_LeaderboardButton> createState() => _LeaderboardButtonState();
}

class _LeaderboardButtonState extends State<_LeaderboardButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _glow;

  // En iyi rank (4 oyun arasından en düşük rank numarası).
  // null → hazırlanıyor / veri yok / giriş yok
  int? _bestRank;

  // 1 saatlik in-memory cache — aynı oturumda ekrana her dönüşte tekrar fetch etmesin.
  static int? _cachedRank;
  static DateTime? _cachedAt;
  static const _cacheTtl = Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Cache varsa hemen göster
    if (_cachedRank != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      _bestRank = _cachedRank;
    }
    // Arka planda taze veriyi çek (ilk frame'i bloklamadan)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBestRank());
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  /// 4 oyun için paralel olarak leaderboard çekip kullanıcının
  /// tüm oyunlardaki EN İYİ (en düşük) rank'ını bulur.
  Future<void> _loadBestRank() async {
    final auth = AuthService();
    if (!auth.isLoggedIn || auth.uid == null) return;
    final uid = auth.uid!;

    const gameIds = ['2048', 'block_puzzle', 'minesweeper', 'quiz'];
    const higherIsBetter = {
      '2048': true,
      'block_puzzle': true,
      'minesweeper': false, // minesweeper: düşük süre iyi
      'quiz': true,
    };

    try {
      final results = await Future.wait(gameIds.map((id) =>
          LeaderboardService().getLeaderboard(
            id,
            higherIsBetter: higherIsBetter[id] ?? true,
            limit: 50,
          )));

      int? best;
      for (final scores in results) {
        for (final s in scores) {
          if (s['uid'] == uid) {
            final r = s['rank'] as int?;
            if (r != null && (best == null || r < best)) {
              best = r;
            }
            break; // Kullanıcı listede tek girişli olur
          }
        }
      }

      if (!mounted) return;
      setState(() => _bestRank = best);
      _cachedRank = best;
      _cachedAt = DateTime.now();
    } catch (_) {
      // Sessizce yoksay — rozet görünmez, buton yine çalışır
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _glow,
          builder: (_, __) {
            final t = _glow.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ─── Ana pill ───
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.10),
                            Colors.white.withValues(alpha: 0.03),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFFD700)
                              .withValues(alpha: 0.28),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700)
                                .withValues(alpha: 0.18 + 0.12 * t),
                            blurRadius: 14 + 6 * t,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Altın kupa — nefes alır gibi parlar
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFE082),
                                  Color(0xFFFFB300),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.55 + 0.25 * t),
                                  blurRadius: 8 + 4 * t,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ─── Rank rozeti — sağ üst köşeye yapışık ───
                if (_bestRank != null)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: _RankBadge(rank: _bestRank!, glow: t),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kullanıcının en iyi sırasını gösteren küçük altın rozet.
/// İlk 3 için madalya emoji, sonrası için "#N".
class _RankBadge extends StatefulWidget {
  final int rank;
  final double glow; // 0..1
  const _RankBadge({required this.rank, required this.glow});

  @override
  State<_RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<_RankBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // İlk 3: madalya emoji, sonrası: #N
    final isMedal = widget.rank <= 3;
    final label = isMedal
        ? (widget.rank == 1 ? '🥇' : widget.rank == 2 ? '🥈' : '🥉')
        : '#${widget.rank}';

    // Renk tonlaması: 1 = parlak altın, 2 = gümüş, 3 = bronz, 4+ = mor
    final List<Color> bgColors;
    if (widget.rank == 1) {
      bgColors = const [Color(0xFFFFE082), Color(0xFFFFB300)];
    } else if (widget.rank == 2) {
      bgColors = const [Color(0xFFE0E0E0), Color(0xFF9E9E9E)];
    } else if (widget.rank == 3) {
      bgColors = const [Color(0xFFD7A06E), Color(0xFF8B5A2B)];
    } else {
      bgColors = const [Color(0xFF8B5CF6), Color(0xFF4C1D95)];
    }

    return ScaleTransition(
      scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
      child: Container(
        constraints: const BoxConstraints(minWidth: 26, minHeight: 20),
        padding: EdgeInsets.symmetric(
          horizontal: isMedal ? 4 : 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgColors,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: bgColors.last.withValues(alpha: 0.5 + 0.3 * widget.glow),
              blurRadius: 8 + 4 * widget.glow,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMedal ? 12 : 11,
            fontWeight: FontWeight.w800,
            letterSpacing: isMedal ? 0 : 0.3,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
