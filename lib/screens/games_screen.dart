import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../games/minesweeper_game.dart';
import '../games/game_2048.dart';
import '../games/quiz_game.dart';
import '../services/localization_service.dart';

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

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));

    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Başlat
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardsController.forward();
    });
  }

  @override
  void dispose() {
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
        gradient: [const Color(0xFF1E6F30), const Color(0xFF2D9A46)],
        rating: '4.8',
        screen: const MinesweeperGame(),
      ),
      _GameData(
        title: _loc.t('Game2048'),
        subtitle: _loc.t('Game2048Sub'),
        icon: Icons.grid_4x4_rounded,
        gradient: [const Color(0xFFB45309), const Color(0xFFD97706)],
        rating: '4.9',
        screen: const Game2048(),
      ),
      _GameData(
        title: _loc.t('GameQuiz'),
        subtitle: _loc.t('GameQuizSub'),
        icon: Icons.quiz_rounded,
        gradient: [const Color(0xFF6D28D9), const Color(0xFF7C3AED)],
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
            const SizedBox(height: 20),
            // Başlık — fade + slide
            SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Column(
                  children: [
                    Text(
                      _loc.t('TabGames'),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loc.t('GamesSub'),
                      style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: AnimatedBuilder(
                animation: _cardsController,
                builder: (context, _) {
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                    itemCount: games.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      // Her kart sırayla gelsin
                      final delay = index * 0.2; // 0.0, 0.2, 0.4
                      final start = delay;
                      final end = (delay + 0.6).clamp(0.0, 1.0);

                      final progress = Interval(start, end, curve: Curves.easeOutCubic)
                          .transform(_cardsController.value);

                      final game = games[index];

                      return Transform.translate(
                        offset: Offset(0, 40 * (1 - progress)),
                        child: Opacity(
                          opacity: progress,
                          child: Transform.scale(
                            scale: 0.92 + 0.08 * progress,
                            child: _GameCard(
                              title: game.title,
                              subtitle: game.subtitle,
                              icon: game.icon,
                              gradient: game.gradient,
                              rating: game.rating,
                              onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => game.screen)),
                            ),
                          ),
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

// Oyun verisi
class _GameData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String rating;
  final Widget screen;

  const _GameData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.rating,
    required this.screen,
  });
}

// AnimatedBuilder — ListenableBuilder wrapper
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;
  const AnimatedBuilder({super.key, required this.animation, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: animation,
      builder: (ctx, child) => builder(ctx, child),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String rating;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.rating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1025),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha:0.06)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Icon(Icons.star_rounded, color: const Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 2),
                      Text(rating, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 12)),
                ],
              ),
            ),
            // Play button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
