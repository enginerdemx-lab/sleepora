import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  DATA
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidGlassTabItem {
  final IconData icon;
  final String label;
  const LiquidGlassTabItem({required this.icon, required this.label});
}

// ═══════════════════════════════════════════════════════════════════════════════
//  FINITE STATE MODEL
// ═══════════════════════════════════════════════════════════════════════════════

enum _InteractionState { idle, pressed, scrubbing }

// ═══════════════════════════════════════════════════════════════════════════════
//  LIQUID GLASS TAB BAR
//
//  Architecture:
//    LiquidGlassTabBar          ← public API
//      └─ _GlassCapsule         ← ONE root glass material (blur + tint + border)
//           ├─ _ActivePill      ← animated inner capsule that slides between slots
//           └─ _TabSlot × 5     ← icon + label columns
//      └─ _ScrubOverlayLabel   ← floating label during scrubbing
//
//  Interaction: idle → pressed (long press) → scrubbing (drag) → commit
// ═══════════════════════════════════════════════════════════════════════════════

class LiquidGlassTabBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LiquidGlassTabItem> items;

  const LiquidGlassTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<LiquidGlassTabBar> createState() => _LiquidGlassTabBarState();
}

class _LiquidGlassTabBarState extends State<LiquidGlassTabBar>
    with TickerProviderStateMixin {
  // ── State ──
  _InteractionState _state = _InteractionState.idle;
  int _scrubIndex = -1;

  // ── Pill morph animation (expands on long press) ──
  late final AnimationController _pillMorphCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final CurvedAnimation _pillMorph = CurvedAnimation(
    parent: _pillMorphCtrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  // ── Design tokens ──
  static const double capsuleHeight = 70.0;
  static const double capsuleHPad = 16.0;
  static const double capsuleRadius = 26.0;
  static const double pillInset = 5.0;
  static const double blurSigma = 20.0;

  @override
  void dispose() {
    _pillMorphCtrl.dispose();
    _pillMorph.dispose();
    super.dispose();
  }

  // ── Helpers ──
  int _indexFromX(double localX, double capsuleWidth) {
    final n = widget.items.length;
    return (localX / (capsuleWidth / n)).floor().clamp(0, n - 1);
  }

  // ── Interaction handlers ──

  void _handleTap(int index) {
    if (index != widget.currentIndex) {
      widget.onTap(index);
      HapticFeedback.lightImpact();
    }
  }

  void _handleLongPressStart(LongPressStartDetails d, double w) {
    final idx = _indexFromX(d.localPosition.dx, w);
    setState(() {
      _state = _InteractionState.pressed;
      _scrubIndex = idx;
    });
    _pillMorphCtrl.forward();
    HapticFeedback.lightImpact();
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails d, double w) {
    if (_state == _InteractionState.pressed) {
      setState(() => _state = _InteractionState.scrubbing);
    }
    final idx = _indexFromX(d.localPosition.dx, w);
    if (idx != _scrubIndex) {
      setState(() => _scrubIndex = idx);
      if (idx != widget.currentIndex) {
        // Sekmeler arası anında geçiş yap (gerçek zamanlı scrub)
        widget.onTap(idx);
      }
      HapticFeedback.lightImpact();
    }
  }

  void _handleLongPressEnd(LongPressEndDetails _) {
    // Commit the scrub target
    if (_scrubIndex >= 0 && _scrubIndex < widget.items.length) {
      if (_scrubIndex != widget.currentIndex) {
        widget.onTap(_scrubIndex);
      }
    }
    _pillMorphCtrl.reverse();
    setState(() {
      _state = _InteractionState.idle;
      _scrubIndex = -1;
    });
  }

  void _handleLongPressCancel() {
    _pillMorphCtrl.reverse();
    setState(() {
      _state = _InteractionState.idle;
      _scrubIndex = -1;
    });
  }

  // ── Effective selected index (what the pill follows) ──
  int get _effectiveIndex {
    if (_state != _InteractionState.idle && _scrubIndex >= 0) {
      return _scrubIndex;
    }
    return widget.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomPad = bottomInset > 0 ? bottomInset + 2 : 14.0;

    return LayoutBuilder(builder: (context, box) {
      final capsuleWidth = box.maxWidth - (capsuleHPad * 2);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Scrub overlay label ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _state == _InteractionState.scrubbing && _scrubIndex >= 0
                ? Padding(
                    key: const ValueKey('scrub'),
                    padding:
                        EdgeInsets.fromLTRB(capsuleHPad, 0, capsuleHPad, 6),
                    child: _ScrubOverlayLabel(
                      items: widget.items,
                      hoveredIndex: _scrubIndex,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),

          // ── Glass capsule ──
          Padding(
            padding: EdgeInsets.fromLTRB(capsuleHPad, 0, capsuleHPad, bottomPad),
            child: _GlassCapsule(
              width: capsuleWidth,
              onLongPressStart: (d) => _handleLongPressStart(d, capsuleWidth),
              onLongPressMoveUpdate: (d) =>
                  _handleLongPressMoveUpdate(d, capsuleWidth),
              onLongPressEnd: _handleLongPressEnd,
              onLongPressCancel: _handleLongPressCancel,
              children: [
                // Active pill — animated sliding background
                _ActivePill(
                  index: _effectiveIndex,
                  itemCount: widget.items.length,
                  capsuleWidth: capsuleWidth,
                  morphAnimation: _pillMorph,
                  isScrubbing: _state != _InteractionState.idle,
                ),

                // Tab slots on top
                Row(
                  children: List.generate(widget.items.length, (i) {
                    final isEffective = i == _effectiveIndex;
                    final isScrubTarget =
                        _state != _InteractionState.idle && i == _scrubIndex;
                    return Expanded(
                      child: _TabSlot(
                        item: widget.items[i],
                        isActive: i == widget.currentIndex,
                        isHighlighted: isEffective || isScrubTarget,
                        onTap: () => _handleTap(i),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _GlassCapsule — ONE root floating glass surface
//
//  Visual layers (bottom to top):
//    1) Floating shadow
//    2) ClipRRect + BackdropFilter (blurred background)
//    3) Translucent tint gradient
//    4) Subtle top highlight band
//    5) Thin white border (0.5px, 20% opacity)
// ═══════════════════════════════════════════════════════════════════════════════

class _GlassCapsule extends StatelessWidget {
  final double width;
  final List<Widget> children;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;

  const _GlassCapsule({
    required this.width,
    required this.children,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
  });

  static const _h = _LiquidGlassTabBarState.capsuleHeight;
  static const _r = _LiquidGlassTabBarState.capsuleRadius;
  static const _sigma = _LiquidGlassTabBarState.blurSigma;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: _h,
      child: Stack(
        children: [
          // ── Layer 1: Floating shadow ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 30,
                    spreadRadius: -4,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.06),
                    blurRadius: 44,
                    spreadRadius: -8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),

          // ── Layers 2–5: Glass material ──
          ClipRRect(
            borderRadius: BorderRadius.circular(_r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
              child: GestureDetector(
                onLongPressStart: onLongPressStart,
                onLongPressMoveUpdate: onLongPressMoveUpdate,
                onLongPressEnd: onLongPressEnd,
                onLongPressCancel: onLongPressCancel,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: _h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_r),
                    // Layer 3: Translucent tint
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.13),
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    // Layer 5: Thin white border
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                      width: 0.5,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Layer 4a: Top edge highlight
                      Positioned(
                        top: 0, left: 30, right: 30,
                        child: Container(
                          height: 0.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.0),
                            ]),
                          ),
                        ),
                      ),
                      // Layer 4b: Top highlight band
                      Positioned(
                        top: 0, left: 0, right: 0,
                        height: _h * 0.36,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(_r)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.07),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Content layers (pill + slots)
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _ActivePill — animated inner capsule that slides between tab slots
//
//  Slides horizontally via AnimatedPositioned.
//  Expands slightly during scrubbing (morphAnimation).
// ═══════════════════════════════════════════════════════════════════════════════

class _ActivePill extends StatelessWidget {
  final int index;
  final int itemCount;
  final double capsuleWidth;
  final Animation<double> morphAnimation;
  final bool isScrubbing;

  const _ActivePill({
    required this.index,
    required this.itemCount,
    required this.capsuleWidth,
    required this.morphAnimation,
    required this.isScrubbing,
  });

  @override
  Widget build(BuildContext context) {
    final slotWidth = capsuleWidth / itemCount;
    const vInset = _LiquidGlassTabBarState.pillInset;

    return ListenableBuilder(
      listenable: morphAnimation,
      builder: (_, __) {
        // Morph expansion: pill grows wider during long press/scrub
        final morphExtra = morphAnimation.value * 6.0;
        final pillWidth = slotWidth - (vInset * 2) + morphExtra;
        final left = (slotWidth * index) + vInset - (morphExtra / 2);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          left: left,
          top: vInset,
          bottom: vInset,
          width: pillWidth,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                  _LiquidGlassTabBarState.capsuleRadius - vInset),
              color: AppColors.purple.withValues(alpha: isScrubbing ? 0.16 : 0.13),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.18),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.20),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _TabSlot — one tab slot: Column(icon, label)
//
//  No glass effect here — visual emphasis comes from color only.
//  Active/highlighted → AppColors.purple, passive → AppColors.grey
// ═══════════════════════════════════════════════════════════════════════════════

class _TabSlot extends StatefulWidget {
  final LiquidGlassTabItem item;
  final bool isActive;
  final bool isHighlighted; // true when pill is here (active or scrub target)
  final VoidCallback onTap;

  const _TabSlot({
    required this.item,
    required this.isActive,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_TabSlot> createState() => _TabSlotState();
}

class _TabSlotState extends State<_TabSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 120),
  );

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lit = widget.isHighlighted;

    final iconColor = lit ? AppColors.purple : AppColors.grey;
    final labelColor = lit ? AppColors.purple : AppColors.grey;

    return GestureDetector(
      onTapDown: (_) => _tapCtrl.forward(),
      onTapUp: (_) {
        _tapCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tapCtrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ListenableBuilder(
        listenable: _tapCtrl,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - (_tapCtrl.value * 0.08),
          child: child,
        ),
        child: SizedBox(
          height: _LiquidGlassTabBarState.capsuleHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon ──
              AnimatedScale(
                scale: lit ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(widget.item.icon, color: iconColor, size: 23),
              ),
              const SizedBox(height: 3),
              // ── Label ──
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: labelColor,
                  fontSize: lit ? 10.0 : 9.5,
                  fontWeight: lit ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.05,
                  height: 1.1,
                ),
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  _ScrubOverlayLabel — floating glass label strip during scrubbing
// ═══════════════════════════════════════════════════════════════════════════════

class _ScrubOverlayLabel extends StatelessWidget {
  final List<LiquidGlassTabItem> items;
  final int hoveredIndex;

  const _ScrubOverlayLabel({
    required this.items,
    required this.hoveredIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final hov = i == hoveredIndex;
              return Expanded(
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 140),
                    style: TextStyle(
                      color: hov
                          ? AppColors.purple
                          : Colors.white.withValues(alpha: 0.28),
                      fontSize: hov ? 12.0 : 10.5,
                      fontWeight: hov ? FontWeight.w700 : FontWeight.w400,
                    ),
                    child: Text(items[i].label),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
