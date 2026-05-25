import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../screens/sounds_screen.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';
import '../screens/paywall_screen.dart';
import '../screens/login_screen.dart';
import '../services/localization_service.dart';

class MiniPlayer extends StatefulWidget {
  final Sound? sound;
  final bool isPlaying;
  final bool isCollapsed;
  final VoidCallback onPlayPause;
  final VoidCallback onClose;
  final VoidCallback? onCollapse;
  // Mixer aksiyon butonları (opsiyonel — sadece mixer modunda)
  final VoidCallback? onMixerVolume;
  final VoidCallback? onMixerSave;
  final VoidCallback? onMixerClear;

  const MiniPlayer({
    super.key,
    required this.sound,
    required this.isPlaying,
    this.isCollapsed = false,
    required this.onPlayPause,
    required this.onClose,
    this.onCollapse,
    this.onMixerVolume,
    this.onMixerSave,
    this.onMixerClear,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  final _loc = LocalizationService();
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulse;

  // AirPlay / çıkış seçici kanalı
  static const _airplayChannel = MethodChannel('com.sleepora/airplay');

  Future<void> _showRoutePicker() async {
    try {
      await _airplayChannel.invokeMethod('showRoutePicker');
    } catch (_) {}
  }

  // Zamanlayıcı
  int? _timerMinutes;
  int _remainingSeconds = 0;
  bool _timerActive = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.sound != null) {
      _slideController.forward();
    }
  }

  @override
  void didUpdateWidget(MiniPlayer old) {
    super.didUpdateWidget(old);
    if (widget.sound != null && old.sound == null) {
      _slideController.forward();
    } else if (widget.sound == null && old.sound != null) {
      _slideController.reverse();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer(int minutes) {
    setState(() {
      _timerMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _timerActive = true;
    });
    _tickTimer();
  }

  void _tickTimer() {
    if (!_timerActive || !mounted) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_timerActive) return;
      setState(() {
        if (widget.isPlaying) {
          _remainingSeconds--;
        }
        if (_remainingSeconds <= 0) {
          _timerActive = false;
          _timerMinutes = null;
          widget.onPlayPause(); // Durdur
          // Timer bitti — giriş yapılmamışsa uyku takibi prompt'u
          if (!AuthService().isLoggedIn) {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) _showSleepTrackingPrompt();
            });
          }
        }
      });
      if (_timerActive) _tickTimer();
    });
  }

  void _showSleepTrackingPrompt() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
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
                    Colors.white.withValues(alpha: 0.05),
                    AppColors.purple.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                boxShadow: [
                  BoxShadow(color: AppColors.purple.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: -8),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [const Color(0xFF10B981).withValues(alpha: 0.3), const Color(0xFF10B981).withValues(alpha: 0.05)],
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 24, spreadRadius: -4),
                        ],
                      ),
                      child: const Icon(Icons.bedtime_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _loc.t('LoginSleepTrackMsg'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _loc.t('LoginSleepTrackDesc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    // Sync vurgusu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_rounded, color: Colors.white.withValues(alpha: 0.4), size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _loc.t('SyncDevicesMsg'),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await LoginScreen.show(context, feature: _loc.t('LoginSleepTrackMsg'));
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(_loc.t('BtnSignIn'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
                        ),
                        child: Text(
                          _loc.t('BtnLater'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w500),
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

  void _cancelTimer() {
    setState(() {
      _timerActive = false;
      _timerMinutes = null;
      _remainingSeconds = 0;
    });
  }

  String _formatRemaining() {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showTimerSheet() {
    showDialog(
      context: context,
      builder: (_) => _TimerDialog(
        currentMinutes: _timerActive ? (_remainingSeconds / 60).ceil() : 30,
        isActive: _timerActive,
        onSet: (minutes) {
          _startTimer(minutes);
        },
        onCancel: _cancelTimer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sound == null) return const SizedBox.shrink();

    // Collapsed (küçültülmüş) mod
    if (widget.isCollapsed) {
      return SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.purpleDark, AppColors.purple],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: widget.sound!.iconPath != null
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(widget.sound!.iconPath!, fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(widget.sound!.icon, color: Colors.white, size: 14)),
                            )
                          : Icon(widget.sound!.icon, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MarqueeText(
                        text: widget.sound!.localizedName,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Play/Pause
                    GestureDetector(
                      onTap: widget.onPlayPause,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        child: Icon(
                          widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: AppColors.purple,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Expand butonu (yukarı ok)
                    GestureDetector(
                      onTap: widget.onCollapse,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Normal (genişletilmiş) mod
    return SlideTransition(
      position: _slideAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppColors.purpleDark, AppColors.purple],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  // Sabit boyutlu ikon alanı — zıplamayı önler
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ListenableBuilder(
                      listenable: _pulseController,
                      builder: (_, __) => Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: widget.isPlaying ? 0.06 * _pulse.value : 0,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            child: widget.sound!.iconPath != null
                                ? Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Image.asset(widget.sound!.iconPath!, fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(widget.sound!.icon, color: Colors.white, size: 19)),
                                  )
                                : Icon(
                                    widget.sound!.icon,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MarqueeText(
                          text: widget.sound!.localizedName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timerActive
                              ? '${widget.isPlaying ? _loc.t('ShuffleStatusPlaying') : _loc.t('ShuffleStatusStopped')} • ${_formatRemaining()}'
                              : widget.isPlaying ? _loc.t('ShuffleStatusPlaying') : _loc.t('ShuffleStatusStopped'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // AirPlay / çıkış seçici — sadece mixer olmayan modda göster
                  if (widget.onMixerVolume == null) ...[
                    GestureDetector(
                      onTap: _showRoutePicker,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: Icon(
                          Icons.airplay_rounded,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                  // Mixer aksiyon butonları (varsa)
                  if (widget.onMixerVolume != null) ...[
                    _MiniActionBtn(icon: Icons.tune_rounded, color: Colors.white, onTap: widget.onMixerVolume!),
                    const SizedBox(width: 6),
                  ],
                  if (widget.onMixerSave != null) ...[
                    _MiniActionBtn(icon: Icons.save_outlined, color: const Color(0xFF10B981), onTap: widget.onMixerSave!),
                    const SizedBox(width: 6),
                  ],
                  if (widget.onMixerClear != null) ...[
                    _MiniActionBtn(icon: Icons.delete_outline_rounded, color: Colors.redAccent, onTap: widget.onMixerClear!),
                    const SizedBox(width: 6),
                  ],
                  // Zamanlayıcı butonu
                  GestureDetector(
                    onTap: _showTimerSheet,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _timerActive ? AppColors.purple.withValues(alpha: 0.5) : Colors.transparent,
                      ),
                      child: Icon(
                        _timerActive ? Icons.timer_rounded : Icons.timer_outlined,
                        color: _timerActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Play/Pause butonu
                  GestureDetector(
                    onTap: widget.onPlayPause,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        widget.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.purple,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Collapse butonu (aşağı ok)
                  GestureDetector(
                    onTap: widget.onCollapse,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class _TimerDialog extends StatefulWidget {
  final int currentMinutes;
  final bool isActive;
  final void Function(int minutes) onSet;
  final VoidCallback onCancel;
  const _TimerDialog({required this.currentMinutes, required this.isActive, required this.onSet, required this.onCancel});

  @override
  State<_TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<_TimerDialog> with SingleTickerProviderStateMixin {
  final _loc = LocalizationService();
  late double _sliderValue;
  int _selectedMinutes = 0; // Ayrı değişken — preset tıklamalarında slider'dan bağımsız
  bool _presetOverride = false; // Preset ile mi seçildi?
  late AnimationController _glowController;

  static const _steps = [0, 15, 30, 45, 60, 75, 90];
  static const _presets = [15, 30, 45, 60, 90, 120, 180, 240, 360];
  static const _presetLabels = ["15'", "30'", "45'", "1s", "1.5s", "2s", "3s", "4s", "6s"];

  @override
  void initState() {
    super.initState();
    final initial = widget.currentMinutes;
    if (initial <= 90) {
      _sliderValue = initial.toDouble().clamp(0, 90);
      _selectedMinutes = initial;
      _presetOverride = false;
    } else {
      _sliderValue = 90;
      _selectedMinutes = initial;
      _presetOverride = true;
    }
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  int get _displayMinutes => _presetOverride ? _selectedMinutes : _sliderValue.round();

  String get _displayText {
    final mins = _displayMinutes;
    if (mins < 60) return '$mins';
    final hours = mins / 60;
    if (hours == hours.roundToDouble()) return '${hours.round()}';
    return hours.toStringAsFixed(1);
  }

  String get _displayUnit {
    return _displayMinutes >= 60 ? _loc.t('timerHour') : _loc.t('timerMin');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1035),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Başlık
          Row(children: [
            Text(_loc.t('TimerDialogTitle'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.5), size: 22)),
          ]),
          const SizedBox(height: 4),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),

          // Büyük dakika göstergesi
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.purpleDark.withValues(alpha: 0.6), const Color(0xFF1A1035).withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_displayText, style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800, height: 1)),
                Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(_displayUnit, style: const TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.w500))),
              ]),
              const SizedBox(height: 6),
              Text(_loc.t('TimerDialogDesc'), style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),

              // Zaman çizgileri
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _steps.map((m) {
                    final sliderMins = _presetOverride ? 90 : _sliderValue.round();
                    final isActive = m <= sliderMins;
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 3, height: isActive ? 24 : 16,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.purple : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$m', style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontSize: 10)),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Slider — animasyonlu mor glow efekti
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListenableBuilder(
                  listenable: _glowController,
                  builder: (context, child) {
                    return SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.purple,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                        thumbColor: Colors.white,
                        overlayColor: AppColors.purple.withValues(alpha: 0.25),
                        trackHeight: 12,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 26),
                        trackShape: _GlowingTrackShape(
                          glowValue: _glowController.value,
                          activeColor: AppColors.purple,
                        ),
                      ),
                      child: Slider(
                        value: _sliderValue,
                        min: 0,
                        max: 90,
                        divisions: 18,
                        onChanged: (v) => setState(() {
                          _sliderValue = v;
                          _presetOverride = false;
                          _selectedMinutes = v.round();
                        }),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Hızlı seçim butonları — 3x3
          for (int row = 0; row < 3; row++) ...[
            Row(children: [
              for (int col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(child: _PresetButton(
                  label: row == 1 && col == 0 ? "1 ${_loc.t('timerHour')}" : _presetLabels[row * 3 + col],
                  isSelected: _presets[row * 3 + col] == _displayMinutes,
                  isPremium: SubscriptionService().isTimerPremium(_presets[row * 3 + col]),
                  onTap: () {
                    final mins = _presets[row * 3 + col];
                    setState(() {
                      _selectedMinutes = mins;
                      if (mins <= 90) {
                        _sliderValue = mins.toDouble();
                        _presetOverride = false;
                      } else {
                        _sliderValue = 90;
                        _presetOverride = true;
                      }
                    });
                  },
                )),
              ],
            ]),
            if (row < 2) const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),

          // Kaydet butonu veya İptal
          if (widget.isActive)
            GestureDetector(
              onTap: () { widget.onCancel(); Navigator.pop(context); },
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                child: Center(child: Text(_loc.t('BtnCancelTimer'), style: const TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.w700))),
              ),
            )
          else
            GestureDetector(
              onTap: () async {
                if (_displayMinutes > 0) {
                  if (SubscriptionService().isTimerPremium(_displayMinutes)) {
                    Navigator.pop(context);
                    await PaywallScreen.showIfNeeded(context, feature: _loc.t('FeatLongTimer'));
                    return;
                  }
                  widget.onSet(_displayMinutes);
                  Navigator.pop(context);
                }
              },
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Text(_loc.t('BtnSave'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
              ),
            ),
        ]),
      ),
    );
  }
}

// Özel slider track — mor glow animasyonu ile
class _GlowingTrackShape extends SliderTrackShape {
  final double glowValue;
  final Color activeColor;

  const _GlowingTrackShape({required this.glowValue, required this.activeColor});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 12;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackLeft = offset.dx + 14;
    final trackWidth = parentBox.size.width - 28;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final canvas = context.canvas;
    final trackRect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final radius = Radius.circular(trackRect.height / 2);

    // İnaktif track
    final inactivePaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawRRect(RRect.fromRectAndRadius(trackRect, radius), inactivePaint);

    // Aktif track — gradient
    final activeRect = Rect.fromLTRB(trackRect.left, trackRect.top, thumbCenter.dx, trackRect.bottom);
    if (activeRect.width > 0) {
      final activePaint = Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF7C3AED), const Color(0xFFA855F7)],
        ).createShader(activeRect);
      canvas.drawRRect(RRect.fromRectAndRadius(activeRect, radius), activePaint);

      // Glow efekti — parlayan ışık soldan sağa kayıyor
      final glowPosition = activeRect.left + (activeRect.width * glowValue);
      final glowWidth = activeRect.width * 0.35;
      final glowRect = Rect.fromCenter(
        center: Offset(glowPosition, activeRect.center.dy),
        width: glowWidth,
        height: activeRect.height,
      ).intersect(activeRect);

      if (glowRect.width > 0) {
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.4),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCenter(
            center: Offset(glowPosition, activeRect.center.dy),
            width: glowWidth,
            height: activeRect.height * 3,
          ))
          ..blendMode = BlendMode.screen;
        canvas.drawRRect(RRect.fromRectAndRadius(glowRect, radius), glowPaint);
      }

      // Dış glow (blur efekti)
      final outerGlowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.3 + 0.15 * ((glowValue * 2 - 1).abs()))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect.inflate(2), radius),
        outerGlowPaint,
      );
    }
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isPremium;
  final VoidCallback onTap;
  const _PresetButton({required this.label, required this.isSelected, required this.onTap, this.isPremium = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purple : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.purple : Colors.white.withValues(alpha: 0.08)),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.purple.withValues(alpha: 0.3), blurRadius: 8)] : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPremium) ...[
                Icon(Icons.lock_rounded, color: const Color(0xFFFFD700), size: 12),
                const SizedBox(width: 3),
              ],
              Text(label, style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yazı sığmazsa sola doğru kayan yazı (marquee) widget'ı
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  Timer? _timer;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
  }

  @override
  void didUpdateWidget(_MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _timer?.cancel();
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScroll());
    }
  }

  void _checkAndStartScroll() {
    if (!mounted) return;
    _needsScroll = _scrollController.position.maxScrollExtent > 0;
    if (_needsScroll) _startScroll();
  }

  void _startScroll() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_needsScroll) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(max, duration: Duration(milliseconds: (max * 30).toInt()), curve: Curves.linear).then((_) {
        if (!mounted) return;
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          _scrollController.jumpTo(0);
          _startScroll();
        });
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.style.fontSize != null ? widget.style.fontSize! + 6 : 20,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(widget.text, style: widget.style, maxLines: 1),
      ),
    );
  }
}
