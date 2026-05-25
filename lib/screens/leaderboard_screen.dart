import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/localization_service.dart';
import '../services/leaderboard_service.dart';
import '../services/auth_service.dart';

class LeaderboardScreen extends StatefulWidget {
  final String initialGameId;
  const LeaderboardScreen({super.key, this.initialGameId = '2048'});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final _loc = LocalizationService();
  final _lb = LeaderboardService();
  final _auth = AuthService();
  late TabController _tabController;

  final _games = [
    _GameTab(id: '2048',         label: '2048',       icon: Icons.grid_4x4_rounded,   higherIsBetter: true,  isTime: false, color: const Color(0xFFDB2777)),
    _GameTab(id: 'block_puzzle', label: '',            icon: Icons.dashboard_rounded,  higherIsBetter: true,  isTime: false, color: const Color(0xFF3B82F6)),
    _GameTab(id: 'minesweeper',  label: '',            icon: Icons.flag_rounded,       higherIsBetter: false, isTime: true,  color: const Color(0xFF06B6D4)),
    _GameTab(id: 'quiz',         label: '',            icon: Icons.quiz_rounded,       higherIsBetter: true,  isTime: false, color: const Color(0xFF8B5CF6)),
  ];

  List<Map<String, dynamic>> _scores = [];
  bool _loading = true;
  int? _userBest;

  @override
  void initState() {
    super.initState();
    _games[0] = _games[0].copyWith(label: '2048');
    _games[1] = _games[1].copyWith(label: _loc.t('GameBlockPuzzle'));
    _games[2] = _games[2].copyWith(label: _loc.t('GameMinesweeper'));
    _games[3] = _games[3].copyWith(label: _loc.t('GameQuiz'));

    final initialIndex = _games.indexWhere((g) => g.id == widget.initialGameId);
    _tabController = TabController(
      length: _games.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadScores();
    });
    _loadScores();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadScores() async {
    setState(() => _loading = true);
    final game = _games[_tabController.index];
    final scores = await _lb.getLeaderboard(game.id, higherIsBetter: game.higherIsBetter);
    int? userBest;
    if (_auth.isLoggedIn && _auth.uid != null) {
      userBest = await _lb.getUserBestScore(game.id, _auth.uid!);
    }
    if (mounted) setState(() { _scores = scores; _userBest = userBest; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final game = _games[_tabController.index];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ─── Gradient header ───
          _buildHeader(game),

          // ─── Sekme seçici ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    game.color.withValues(alpha: 0.7),
                    game.color,
                  ]),
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(4),
                tabs: _games.map((g) => Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(g.icon, size: 14),
                      const SizedBox(width: 5),
                      Flexible(child: Text(g.label, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),

          // ─── İçerik ───
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(
                    color: game.color, strokeWidth: 2.5))
                : _scores.isEmpty
                    ? _buildEmpty(game)
                    : RefreshIndicator(
                        onRefresh: _loadScores,
                        color: game.color,
                        child: CustomScrollView(
                          slivers: [
                            // Podium (top 3)
                            if (_scores.length >= 3)
                              SliverToBoxAdapter(child: _buildPodium(game)),

                            // Kullanıcı skoru
                            if (_auth.isLoggedIn && _userBest != null)
                              SliverToBoxAdapter(child: _buildMyScore(game)),

                            // Liste
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final entry = _scores[index];
                                    final rank = entry['rank'] as int;
                                    // Podium'da gösterilenler (top 3) listeye dahil edilmez
                                    if (_scores.length >= 3 && rank <= 3) {
                                      return const SizedBox.shrink();
                                    }
                                    return _buildRow(entry, game);
                                  },
                                  childCount: _scores.length,
                                ),
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

  // ─── Gradient Header ───
  Widget _buildHeader(_GameTab game) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            game.color.withValues(alpha: 0.15),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 4),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _loc.t('Leaderboard'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Podium (Top 3) ───
  Widget _buildPodium(_GameTab game) {
    if (_scores.length < 3) return const SizedBox.shrink();
    final first  = _scores.firstWhere((s) => s['rank'] == 1);
    final second = _scores.firstWhere((s) => s['rank'] == 2);
    final third  = _scores.firstWhere((s) => s['rank'] == 3);
    final isTime = game.isTime;

    String _fmt(Map<String, dynamic> e) =>
        isTime ? '${e['score']}s' : '${e['score']}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              game.color.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: game.color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2. sıra
            Expanded(child: _PodiumPillar(
              entry: second, rank: 2,
              score: _fmt(second),
              height: 72,
              color: const Color(0xFFC0C0C0),
              isMe: _auth.uid != null && second['uid'] == _auth.uid,
            )),
            const SizedBox(width: 8),
            // 1. sıra — ortada ve en yüksek
            Expanded(child: _PodiumPillar(
              entry: first, rank: 1,
              score: _fmt(first),
              height: 96,
              color: const Color(0xFFFFD700),
              isMe: _auth.uid != null && first['uid'] == _auth.uid,
            )),
            const SizedBox(width: 8),
            // 3. sıra
            Expanded(child: _PodiumPillar(
              entry: third, rank: 3,
              score: _fmt(third),
              height: 56,
              color: const Color(0xFFCD7F32),
              isMe: _auth.uid != null && third['uid'] == _auth.uid,
            )),
          ],
        ),
      ),
    );
  }

  // ─── Kendi skorum ───
  Widget _buildMyScore(_GameTab game) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.purple.withValues(alpha: 0.3),
            AppColors.purple.withValues(alpha: 0.15),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white70, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              _loc.t('LeaderboardYourBest'),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Spacer(),
            Text(
              game.isTime ? '${_userBest}s' : '$_userBest',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Skor satırı ───
  Widget _buildRow(Map<String, dynamic> entry, _GameTab game) {
    final rank  = entry['rank'] as int;
    final name  = (entry['display_name'] as String?) ?? 'Anonim';
    final score = entry['score'] as int;
    final uid   = entry['uid'] as String?;
    final isMe  = _auth.uid != null && uid == _auth.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.purple.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppColors.purple.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Sıra numarası
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // İsim
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isMe ? AppColors.purple : Colors.white,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMe)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(LocalizationService().t('FeedbackYou'),
                  style: const TextStyle(
                      color: Color(0xFFB794F4),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          // Skor
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: game.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: game.color.withValues(alpha: 0.2)),
            ),
            child: Text(
              game.isTime ? '${score}s' : '$score',
              style: TextStyle(
                color: game.color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Boş durum ───
  Widget _buildEmpty(_GameTab game) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: game.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emoji_events_outlined,
                color: game.color.withValues(alpha: 0.5), size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            _loc.t('LeaderboardEmpty'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─── Podium Pillar ───
class _PodiumPillar extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int rank;
  final String score;
  final double height;
  final Color color;
  final bool isMe;

  const _PodiumPillar({
    required this.entry,
    required this.rank,
    required this.score,
    required this.height,
    required this.color,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final name = (entry['display_name'] as String?) ?? 'Anonim';
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // İsim
        Text(
          name,
          style: TextStyle(
            color: isMe ? const Color(0xFFB794F4) : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Madalya
        Text(medal, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        // Skor
        Text(
          score,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        // Sütun
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0.15)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GameTab {
  final String id;
  final String label;
  final IconData icon;
  final bool higherIsBetter;
  final bool isTime;
  final Color color;

  const _GameTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.higherIsBetter,
    required this.isTime,
    required this.color,
  });

  _GameTab copyWith({String? label}) => _GameTab(
    id: id, label: label ?? this.label, icon: icon,
    higherIsBetter: higherIsBetter, isTime: isTime, color: color,
  );
}
