import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';

/// 4 sayfalık "Nasıl Oynanır" tutorial overlay.
/// İlk açılışta otomatik, menüden tekrar açılabilir.
class MinesweeperTutorial extends StatefulWidget {
  const MinesweeperTutorial({super.key});

  @override
  State<MinesweeperTutorial> createState() => _MinesweeperTutorialState();

  /// Dialog olarak göstermek için yardımcı.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const MinesweeperTutorial(),
    );
  }
}

class _MinesweeperTutorialState extends State<MinesweeperTutorial> {
  final _pageController = PageController();
  int _page = 0;

  List<_TutorialPageData> get _pages {
    final loc = LocalizationService();
    return [
      _TutorialPageData(
        title: loc.t('MSTutOpenTitle'),
        description: loc.t('MSTutOpenDesc'),
        icon: Icons.touch_app_rounded,
        demo: _DemoType.tap,
      ),
      _TutorialPageData(
        title: loc.t('MSTutFlagTitle'),
        description: loc.t('MSTutFlagDesc'),
        icon: Icons.flag_rounded,
        demo: _DemoType.flag,
      ),
      _TutorialPageData(
        title: loc.t('MSTutMineTitle'),
        description: loc.t('MSTutMineDesc'),
        icon: Icons.warning_rounded,
        demo: _DemoType.mine,
      ),
      _TutorialPageData(
        title: loc.t('MSTutTimeTitle'),
        description: loc.t('MSTutTimeDesc'),
        icon: Icons.timer_rounded,
        demo: _DemoType.time,
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
                  color: AppColors.purple.withValues(alpha: 0.3),
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
                    itemBuilder: (context, i) => _TutorialPageView(data: _pages[i]),
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
                              ? AppColors.purple
                              : Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),

                // ─── Nav buttons ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: Row(
                    children: [
                      // Geri
                      _NavButton(
                        icon: Icons.chevron_left_rounded,
                        enabled: _page > 0,
                        onTap: _prev,
                      ),
                      const SizedBox(width: 10),
                      // İleri / Onay
                      Expanded(
                        child: GestureDetector(
                          onTap: _next,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.purple.withValues(alpha: 0.5),
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
                                    _page == _pages.length - 1
                                        ? LocalizationService().t('GameGotIt')
                                        : LocalizationService().t('GameNext'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _page == _pages.length - 1
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

enum _DemoType { tap, flag, mine, time }

class _TutorialPageData {
  final String title;
  final String description;
  final IconData icon;
  final _DemoType demo;
  const _TutorialPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.demo,
  });
}

class _TutorialPageView extends StatelessWidget {
  final _TutorialPageData data;
  const _TutorialPageView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const SizedBox(height: 4),
          // Demo kutusu
          Container(
            width: 220,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1025),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: _buildDemo(data.demo),
          ),
          const SizedBox(height: 18),
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, color: AppColors.purple, size: 18),
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
          // Açıklama
          Expanded(
            child: Text(
              data.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
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

  Widget _buildDemo(_DemoType type) {
    switch (type) {
      case _DemoType.tap:
        return _DemoGrid(
          cells: const [
            [_DemoCell.covered, _DemoCell.covered, _DemoCell.covered, _DemoCell.covered],
            [_DemoCell.covered, _DemoCell.n1, _DemoCell.n2, _DemoCell.covered],
            [_DemoCell.covered, _DemoCell.open, _DemoCell.n1, _DemoCell.covered],
            [_DemoCell.covered, _DemoCell.covered, _DemoCell.covered, _DemoCell.covered],
          ],
          pointerRow: 2,
          pointerCol: 1,
        );
      case _DemoType.flag:
        return _DemoGrid(
          cells: const [
            [_DemoCell.covered, _DemoCell.n1, _DemoCell.n2, _DemoCell.covered],
            [_DemoCell.n1, _DemoCell.n1, _DemoCell.flag, _DemoCell.covered],
            [_DemoCell.open, _DemoCell.n1, _DemoCell.n2, _DemoCell.covered],
            [_DemoCell.covered, _DemoCell.covered, _DemoCell.covered, _DemoCell.covered],
          ],
          pointerRow: 1,
          pointerCol: 2,
          hold: true,
        );
      case _DemoType.mine:
        return _DemoGrid(
          cells: const [
            [_DemoCell.n1, _DemoCell.flag, _DemoCell.n2, _DemoCell.mine],
            [_DemoCell.n2, _DemoCell.n3, _DemoCell.mineHit, _DemoCell.mine],
            [_DemoCell.covered, _DemoCell.n1, _DemoCell.n2, _DemoCell.mine],
            [_DemoCell.covered, _DemoCell.covered, _DemoCell.covered, _DemoCell.covered],
          ],
          pointerRow: 1,
          pointerCol: 2,
        );
      case _DemoType.time:
        return _TimeDemoVisual();
    }
  }
}

enum _DemoCell { covered, open, n1, n2, n3, flag, mine, mineHit }

class _DemoGrid extends StatelessWidget {
  final List<List<_DemoCell>> cells;
  final int? pointerRow;
  final int? pointerCol;
  final bool hold;

  const _DemoGrid({
    required this.cells,
    this.pointerRow,
    this.pointerCol,
    this.hold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(cells.length, (r) {
        return Expanded(
          child: Row(
            children: List.generate(cells[r].length, (c) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  child: _buildCell(cells[r][c], r == pointerRow && c == pointerCol),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildCell(_DemoCell type, bool hasPointer) {
    Color bg;
    Widget? child;

    switch (type) {
      case _DemoCell.covered:
        bg = const Color(0xFF2D1B4E);
        break;
      case _DemoCell.open:
        bg = Colors.white.withValues(alpha: 0.05);
        break;
      case _DemoCell.n1:
        bg = Colors.white.withValues(alpha: 0.05);
        child = const Text('1',
            style: TextStyle(
                color: Color(0xFF60A5FA),
                fontWeight: FontWeight.w800,
                fontSize: 13));
        break;
      case _DemoCell.n2:
        bg = Colors.white.withValues(alpha: 0.05);
        child = const Text('2',
            style: TextStyle(
                color: Color(0xFF34D399),
                fontWeight: FontWeight.w800,
                fontSize: 13));
        break;
      case _DemoCell.n3:
        bg = Colors.white.withValues(alpha: 0.05);
        child = const Text('3',
            style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w800,
                fontSize: 13));
        break;
      case _DemoCell.flag:
        bg = const Color(0xFF2D1B4E);
        child = const Icon(Icons.flag_rounded, color: Color(0xFFFBBF24), size: 14);
        break;
      case _DemoCell.mine:
        bg = const Color(0xFF2D1B4E);
        child = const Icon(Icons.brightness_7_rounded,
            color: Color(0xFFEF4444), size: 14);
        break;
      case _DemoCell.mineHit:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.5);
        child = const Icon(Icons.brightness_7_rounded, color: Colors.white, size: 14);
        break;
    }

    final content = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(child: child),
    );

    if (!hasPointer) return content;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        content,
        Positioned(
          bottom: -6,
          right: -4,
          child: _AnimatedPointer(hold: hold),
        ),
      ],
    );
  }
}

class _AnimatedPointer extends StatefulWidget {
  final bool hold;
  const _AnimatedPointer({required this.hold});
  @override
  State<_AnimatedPointer> createState() => _AnimatedPointerState();
}

class _AnimatedPointerState extends State<_AnimatedPointer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.hold ? 1400 : 900),
    )..repeat(reverse: !widget.hold);
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
        final scale = widget.hold
            ? 1.0 + 0.15 * (_ctrl.value < 0.5 ? _ctrl.value * 2 : 1.0)
            : 1.0 + 0.2 * _ctrl.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
              border: Border.all(
                color: const Color(0xFF8B5CF6),
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimeDemoVisual extends StatefulWidget {
  @override
  State<_TimeDemoVisual> createState() => _TimeDemoVisualState();
}

class _TimeDemoVisualState extends State<_TimeDemoVisual>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.timer_rounded,
          color: Color(0xFF60A5FA),
          size: 52,
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final seconds = (60 - _ctrl.value * 60).ceil();
            return Text(
              '${seconds}s',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              3,
              (i) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.star_rounded,
                        color: Color(0xFFFFD700), size: 18),
                  )),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _NavButton({
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
