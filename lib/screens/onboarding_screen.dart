import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';
import '../services/localization_service.dart';
import '../services/notification_service.dart';
import '../services/profanity_filter.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../widgets/sleep_time_picker.dart';
import 'home_screen.dart';
import 'paywall_screen.dart';
import 'login_screen.dart';

/// İlk açılışta bir kez gösterilen tanıtım akışı.
/// Sayfalar: Karşılama · Sesler (demo) · Mix · Hatırlatma · Bebek adı
/// Sonda mevcut [LoginScreen] ve (premium değilse) paywall gösterilir.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String doneKey = 'onboarding_done';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _loc = LocalizationService();
  final PageController _pageController = PageController();
  int _index = 0;
  static const int _pageCount = 5;
  static const int _soundsIndex = 1;

  static const Color _accent = Color(0xFF9D5FF3);

  // ── Demo sesler (ikon + ses ana app verisinden) ──
  static const List<String> _soundNameKeys = [
    'OnbSnd1',
    'OnbSnd2',
    'OnbSnd3',
    'OnbSnd4',
  ];
  static const List<String> _soundIcons = [
    'assets/images/icon/pispis.png',
    'assets/images/icon/eee.png',
    'assets/images/icon/beyaz_gurultu.png',
    'assets/images/icon/yildiztozu.png',
  ];
  static const List<String> _soundAssets = [
    'assets/sounds/Pis Pis Sesi.mp3',
    'assets/sounds/Eee Eee.mp3',
    'assets/sounds/beyaz-gürültü.mp3',
    'assets/sounds/Yildiz-Tozu-Ninnisi.mp3',
  ];

  // ── Mix sayfası (yörünge karıştırıcı) — saat yönünde tepeden başlayarak ──
  static const int _mixIndex = 2;
  static const List<String> _orbNameKeys = [
    'OnbSnd1', // Pış Pış      (tepe)
    'OnbSnd2', // Eee Eee      (sağ üst)
    'OnbSnd3', // Beyaz Gürültü(sağ alt)
    'OnbSndLullaby', // Ninni  (alt)
    'OnbSnd4', // Yıldız Tozu  (sol alt)
    'OnbSndCabin', // Kabin    (sol üst)
  ];
  static const List<String> _orbIcons = [
    'assets/images/icon/pispis.png',
    'assets/images/icon/eee.png',
    'assets/images/icon/beyaz_gurultu.png',
    'assets/images/icon/uyusundabuyusun.png',
    'assets/images/icon/yildiztozu.png',
    'assets/images/icon/kabin.png',
  ];
  static const List<String> _orbAssets = [
    'assets/sounds/Pis Pis Sesi.mp3',
    'assets/sounds/Eee Eee.mp3',
    'assets/sounds/beyaz-gürültü.mp3',
    'assets/sounds/uyusunda-büyüsün-nini.mp3',
    'assets/sounds/Yildiz-Tozu-Ninnisi.mp3',
    'assets/sounds/kabin-sesi.mp3',
  ];

  AudioPlayer? _previewPlayer;
  int? _playingSound;

  // ── Mix (Sayfa 3) durumu ──
  // Seçili ses indeksleri (0..5) — her biri anında çalar (loop, karışık).
  final Set<int> _mixSel = {};
  // Ses başına düzey (0..1). Varsayılan 0.8.
  final Map<int, double> _mixVol = {};
  // Yalnızca mix sayfasındayken canlı olan player'lar (index → player).
  final Map<int, AudioPlayer> _mixPlayers = {};

  // Giriş ekranı (1. sayfa) video arka planı.
  VideoPlayerController? _welcomeVideo;
  bool _welcomeVideoFailed = false;

  // ── Hatırlatma ──
  bool _reminderOn = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  bool _preReminderEnabled = false;
  int _preReminderMinutes = 15;

  final TextEditingController _nameController = TextEditingController();

  late AnimationController _mixAnim;
  late AnimationController _floatAnim;
  late AnimationController _cardsAnim;

  @override
  void initState() {
    super.initState();
    _mixAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _floatAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _cardsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _initWelcomeVideo();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _reminderTime = TimeOfDay(
        hour: prefs.getInt('rem_hour') ?? 21,
        minute: prefs.getInt('rem_minute') ?? 0,
      );
      _preReminderEnabled = prefs.getBool('pre_rem_enabled') ?? false;
      _preReminderMinutes = prefs.getInt('pre_rem_minutes') ?? 15;
      _nameController.text = prefs.getString('baby_name') ?? '';
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _previewPlayer?.dispose();
    for (final p in _mixPlayers.values) {
      p.dispose();
    }
    _mixPlayers.clear();
    _nameController.dispose();
    _mixAnim.dispose();
    _floatAnim.dispose();
    _cardsAnim.dispose();
    _welcomeVideo?.dispose();
    super.dispose();
  }

  // ─────────── Giriş ekranı video ───────────
  Future<void> _initWelcomeVideo() async {
    final controller = VideoPlayerController.asset(
      'assets/images/onboarding/screen1video.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _welcomeVideo = controller;
    controller.addListener(() {
      if (controller.value.hasError && mounted && !_welcomeVideoFailed) {
        setState(() => _welcomeVideoFailed = true);
      }
    });
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      setState(() {});
      await controller.play();
    } catch (e) {
      if (mounted) setState(() => _welcomeVideoFailed = true);
    }
  }

  // Giriş ekranı arka planı: video hazırsa video (cover), değilse screen1.png.
  Widget _welcomeBg() {
    final c = _welcomeVideo;
    final size = c?.value.size ?? Size.zero;
    final ok = !_welcomeVideoFailed &&
        c != null &&
        c.value.isInitialized &&
        size.width > 0 &&
        size.height > 0;
    if (!ok) return _bgImage('screen1.png', const ValueKey('s1'));
    return SizedBox.expand(
      key: const ValueKey('vid'),
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: RepaintBoundary(child: VideoPlayer(c)),
        ),
      ),
    );
  }

  // ─────────── Navigasyon ───────────
  void _onPageChanged(int i) {
    setState(() => _index = i);
    if (i != _soundsIndex) _stopPreview();
    // Mix sayfasına gelince seçili sesleri sürdür, ayrılınca tümünü durdur.
    if (i == _mixIndex) {
      _resumeMix();
    } else {
      _stopMixAll();
    }
  }

  void _next() {
    HapticFeedback.mediumImpact();
    if (_index >= _pageCount - 1) {
      _finish(saveName: true);
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish({bool saveName = false}) async {
    await _stopPreview();
    await _stopMixAll();
    final prefs = await SharedPreferences.getInstance();
    if (saveName) {
      final name = _nameController.text.trim();
      if (name.isNotEmpty && !ProfanityFilter.containsProfanity(name)) {
        await prefs.setString('baby_name', name);
      }
    }
    await prefs.setBool(OnboardingScreen.doneKey, true);

    // Puanlama burada GÖSTERİLMEZ — ana ekran açıldıktan 5 sn sonra gelir.
    // En sonda: mevcut giriş ekranı (giriş yapılmamışsa).
    if (mounted && !AuthService().isLoggedIn) {
      await LoginScreen.show(context);
    }
    // Premium değilse paywall.
    if (mounted && !SubscriptionService().isPremium) {
      await PaywallScreen.showIfNeeded(context);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ─────────── Demo ses ───────────
  Future<void> _stopPreview() async {
    try {
      await _previewPlayer?.stop();
    } catch (_) {}
    if (mounted && _playingSound != null) setState(() => _playingSound = null);
  }

  Future<void> _toggleSound(int i) async {
    HapticFeedback.selectionClick();
    if (_playingSound == i) {
      setState(() => _playingSound = null);
      try {
        await _previewPlayer?.stop();
      } catch (_) {}
      return;
    }
    // Anında görsel geri bildirim — renk hemen değişsin.
    setState(() => _playingSound = i);
    try {
      _previewPlayer ??= AudioPlayer();
      await _previewPlayer!.stop();
      await _previewPlayer!.setAsset(_soundAssets[i]);
      await _previewPlayer!.setLoopMode(LoopMode.one);
      await _previewPlayer!.setVolume(1.0);
      await _previewPlayer!.play();
    } catch (_) {
      // Ses çalınamasa bile seçim vurgusu kalsın.
    }
  }

  // ─────────── Mix (yörünge karıştırıcı) ───────────
  double _volOf(int i) => _mixVol[i] ?? 0.8;

  /// Düğüme dokununca: seçiliyse kaldır+durdur, değilse ekle+anında çal.
  Future<void> _toggleMixNode(int i) async {
    HapticFeedback.selectionClick();
    if (_mixSel.contains(i)) {
      setState(() => _mixSel.remove(i));
      await _stopMixPlayer(i);
    } else {
      setState(() {
        _mixSel.add(i);
        _mixVol.putIfAbsent(i, () => 0.8);
      });
      await _startMixPlayer(i);
    }
  }

  Future<void> _startMixPlayer(int i) async {
    try {
      final p = _mixPlayers[i] ?? AudioPlayer();
      _mixPlayers[i] = p;
      await p.setAsset(_orbAssets[i]);
      await p.setLoopMode(LoopMode.one);
      await p.setVolume(_volOf(i));
      await p.play();
    } catch (_) {
      // Ses çalınamasa bile seçim görünür kalsın.
    }
  }

  Future<void> _stopMixPlayer(int i) async {
    final p = _mixPlayers.remove(i);
    if (p == null) return;
    try {
      await p.stop();
    } catch (_) {}
    try {
      await p.dispose();
    } catch (_) {}
  }

  Future<void> _stopMixAll() async {
    final players = List<AudioPlayer>.from(_mixPlayers.values);
    _mixPlayers.clear();
    for (final p in players) {
      try {
        await p.stop();
      } catch (_) {}
      try {
        await p.dispose();
      } catch (_) {}
    }
  }

  /// Mix sayfasına gelindiğinde seçili sesleri (varsa) yeniden başlatır.
  Future<void> _resumeMix() async {
    for (final i in _mixSel) {
      await _startMixPlayer(i);
    }
  }

  void _setMixVolume(int i, double v) {
    _mixVol[i] = v;
    try {
      _mixPlayers[i]?.setVolume(v);
    } catch (_) {}
  }

  /// Merkez küre / "ayarla" → her seçili sesin düzeyini ayrı ayrı ayarlama popup'ı.
  void _openMixVolumeSheet() {
    if (_mixSel.isEmpty) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.mediumImpact();
    final selected = _mixSel.toList()..sort();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MixVolumeSheet(
        selected: selected,
        titleText: _loc.t('OnbMixVolTitle'),
        nameOf: (i) => _loc.t(_orbNameKeys[i]),
        iconOf: (i) => _orbIcons[i],
        volumeOf: _volOf,
        onChanged: _setMixVolume,
      ),
    );
  }

  // ─────────── Hatırlatma ───────────
  Future<void> _applyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', _reminderOn);
    await prefs.setInt('rem_hour', _reminderTime.hour);
    await prefs.setInt('rem_minute', _reminderTime.minute);
    await prefs.setBool('pre_rem_enabled', _preReminderEnabled);
    await prefs.setInt('pre_rem_minutes', _preReminderMinutes);
    try {
      if (_reminderOn) {
        await NotificationService().scheduleSleepReminder(
          _reminderTime,
          preReminderEnabled: _preReminderEnabled,
          preReminderMinutesBefore: _preReminderMinutes,
        );
      } else {
        await NotificationService().cancelReminder();
      }
    } catch (_) {}
  }

  Future<void> _pickTime() async {
    final picked = await showSleepTimePicker(context, _reminderTime);
    if (picked == null) return;
    setState(() => _reminderTime = picked);
    if (_reminderOn) await _applyReminder();
  }

  // ─────────── Build ───────────
  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pageCount - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Arka plan: 1. sayfa screen1.png, diğerleri genel_arkaplan.png
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: _index == 0
                  ? _welcomeBg()
                  : _bgImage('genel_arkaplan.png', const ValueKey('gb')),
            ),
          ),
          // Yazı okunabilirliği için sadece içerikli sayfalarda hafif vinyet.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 350),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x990A0A14),
                      Color(0x000A0A14),
                      Color(0x000A0A14),
                      Color(0xB30A0A14),
                    ],
                    stops: [0.0, 0.26, 0.62, 1.0],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),
          // Son sayfada (bebek adı) küçük, yanıp sönen + süzülen yıldızlar.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _index == 4 ? 1 : 0,
                duration: const Duration(milliseconds: 450),
                child: const _TwinklingStars(),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    // Kaydırma kapalı — yalnızca "Devam Et" ile ilerlenir.
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    children: [
                      _welcomePage(),
                      _contentPage(1, _loc.t('OnbTitle2'), _loc.t('OnbSub2'),
                          _heroSounds(), heroAlign: Alignment.topCenter),
                      _contentPage(2, _loc.t('OnbTitle3'), _loc.t('OnbSub3'),
                          _heroMix()),
                      _contentPage(3, _loc.t('OnbTitle4'), _loc.t('OnbSub4'),
                          _heroReminder()),
                      _contentPage(4, _loc.t('OnbTitle5'), _loc.t('OnbSub5'),
                          _heroName()),
                    ],
                  ),
                ),
                _footer(isLast),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bgImage(String file, Key key) {
    return Image.asset(
      'assets/images/onboarding/$file',
      key: key,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.3,
            colors: [Color(0xFF2D1B6E), Color(0xFF160A38), Color(0xFF0A0A14)],
          ),
        ),
      ),
    );
  }

  // 1. sayfa (giriş): görsel üzerine başlık + alt yazı.
  Widget _welcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _header(),
          const Spacer(),
          _WelcomeIntro(
            title: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: Colors.white),
                children: _highlightSpans(_titleCase(_loc.t('OnbTitle1'))),
              ),
            ),
            subtitle: Text(_loc.t('OnbSub1'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 15,
                    height: 1.45)),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/logo.jpg',
              width: 32, height: 32, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(width: 32, height: 32)),
        ),
        const SizedBox(width: 9),
        const Text('Sleepora',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ],
    );
  }

  Widget _contentPage(int i, String title, String subtitle, Widget hero,
      {Alignment heroAlign = Alignment.center}) {
    final active = i == _index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _header(),
          const SizedBox(height: 14),
          // Başlık + alt yazı: sayfa etkin olunca soft açılır.
          _RevealOnActive(
            active: active,
            child: Column(
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: Colors.white),
                    children: _highlightSpans(_titleCase(title)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 14.5,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: Align(alignment: heroAlign, child: hero)),
        ],
      ),
    );
  }

  List<TextSpan> _highlightSpans(String text) {
    final parts = text.split(RegExp(r'[{}]'));
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
          text: parts[i],
          style: i.isOdd ? const TextStyle(color: _accent) : null));
    }
    return spans;
  }

  // Başlıkta her kelimenin ilk harfini büyütür (Türkçe i→İ, ı→I; {vurgu} korunur).
  String _titleCase(String text) {
    final re = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]');
    return text.split(' ').map((w) {
      for (var i = 0; i < w.length; i++) {
        if (re.hasMatch(w[i])) {
          final c = w[i];
          final up = c == 'i' ? 'İ' : (c == 'ı' ? 'I' : c.toUpperCase());
          return w.substring(0, i) + up + w.substring(i + 1);
        }
      }
      return w;
    }).join(' ');
  }

  // ─────────── Sayfa 2: Sesler ───────────
  Widget _heroSounds() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                      offset: const Offset(0, 14),
                      child: _soundCard(0, angle: -0.03)),
                  const SizedBox(height: 16),
                  _soundCard(2, angle: -0.02),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _soundCard(1, angle: 0.03),
                  const SizedBox(height: 16),
                  Transform.translate(
                      offset: const Offset(0, 18),
                      child: _soundCard(3, angle: 0.02)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _soundCard(int i, {double angle = 0}) {
    final active = _playingSound == i;
    final card = Transform.rotate(
      angle: angle,
      child: GestureDetector(
        onTap: () => _toggleSound(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 150,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF7C3AED).withValues(alpha: 0.38)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active ? _accent : Colors.white.withValues(alpha: 0.12),
              width: active ? 1.8 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                        blurRadius: 26,
                        spreadRadius: 1)
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: Icon(Icons.favorite_border_rounded,
                    size: 18,
                    color: active
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.4)),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                  color: active
                                      ? _accent.withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.12)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(13),
                            child: Image.asset(
                              _soundIcons[i],
                              fit: BoxFit.contain,
                              color: Colors.white,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 16,
                      child: active
                          ? const _EqBars(color: Colors.white)
                          : Text(_loc.t(_soundNameKeys[i]),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                    ),
                    if (active)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_loc.t(_soundNameKeys[i]),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Kartlar sürekli hafifçe süzülerek hareket eder (her kart farklı fazda).
    return AnimatedBuilder(
      animation: _cardsAnim,
      builder: (_, child) {
        final dy = math.sin(_cardsAnim.value * 2 * math.pi + i * 1.6) * 4.5;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: card,
    );
  }

  // ─────────── Sayfa 3: Mix (yörünge karıştırıcı) ───────────
  Widget _heroMix() {
    return Column(
      children: [
        Expanded(child: _orbitalMixer()),
        const SizedBox(height: 10),
        _selectedSoundsPanel(),
      ],
    );
  }

  /// Merkezde "Gece Mix'i" küresi, çevresinde 6 ses düğümü (yörünge dizilimi).
  Widget _orbitalMixer() {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final dim = math.min(w, h);
        final center = Offset(w / 2, h / 2);
        final ringR = (dim / 2) - 36;
        final orbD = (dim * 0.42).clamp(112.0, 148.0);

        final nodes = <Widget>[];
        for (int i = 0; i < 6; i++) {
          final a = -math.pi / 2 + i * (math.pi / 3); // tepeden saat yönünde
          final dx = center.dx + ringR * math.cos(a);
          final dy = center.dy + ringR * math.sin(a);
          nodes.add(Positioned(
            left: dx - 46,
            top: dy - 28,
            child: SizedBox(
              width: 92,
              child: _OrbitNode(
                label: _loc.t(_orbNameKeys[i]),
                iconAsset: _orbIcons[i],
                selected: _mixSel.contains(i),
                onTap: () => _toggleMixNode(i),
                onLongPress: _openMixVolumeSheet,
                anim: _cardsAnim,
                phase: i.toDouble(),
              ),
            ),
          ));
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Dönen kesik yörünge halkası
            Positioned(
              left: center.dx - ringR,
              top: center.dy - ringR,
              child: AnimatedBuilder(
                animation: _mixAnim,
                builder: (_, __) => Transform.rotate(
                  angle: _mixAnim.value * 2 * math.pi,
                  child: CustomPaint(
                      size: Size(ringR * 2, ringR * 2),
                      painter: _DashedRingPainter()),
                ),
              ),
            ),
            // Seçili düğümlerden merkeze akan ışık çizgileri
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _mixAnim,
                builder: (_, __) => CustomPaint(
                  painter: _OrbitLinksPainter(
                    t: _mixAnim.value,
                    center: center,
                    ringR: ringR,
                    selected: _mixSel.toList(),
                  ),
                ),
              ),
            ),
            // Merkez küre — dokununca ses düzeyi popup'ı açılır
            Positioned(
              left: center.dx - orbD / 2,
              top: center.dy - orbD / 2,
              child: _centerOrb(orbD),
            ),
            ...nodes,
          ],
        );
      },
    );
  }

  Widget _centerOrb(double d) {
    return GestureDetector(
      onTap: _openMixVolumeSheet,
      child: AnimatedBuilder(
        animation: _mixAnim,
        builder: (_, child) {
          final pulse = 1 + math.sin(_mixAnim.value * 2 * math.pi) * 0.02;
          return Transform.scale(scale: pulse, child: child);
        },
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
              radius: 0.95,
            ),
            border: Border.all(
                color: const Color(0xFFB794F4).withValues(alpha: 0.5),
                width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.55),
                  blurRadius: 38,
                  spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.nightlight_round,
                      color: Colors.white, size: 32),
                  Positioned(
                    right: -11,
                    bottom: -1,
                    child: Icon(Icons.music_note_rounded,
                        color: Colors.white.withValues(alpha: 0.92), size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_loc.t('OnbMixNight'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  _loc.t('OnbMixCount').replaceAll('{n}', '${_mixSel.length}'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedSoundsPanel() {
    final sel = _mixSel.toList()..sort();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withValues(alpha: 0.3)),
                child: const Icon(Icons.music_note_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(_loc.t('OnbMixSelectedTitle'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (sel.isNotEmpty)
                GestureDetector(
                  onTap: _openMixVolumeSheet,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(Icons.tune_rounded,
                      color: Colors.white.withValues(alpha: 0.75), size: 20),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (sel.isEmpty)
            Text(_loc.t('OnbMixEmptyHint'),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12.5,
                    height: 1.3))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sel.map(_selChip).toList(),
            ),
        ],
      ),
    );
  }

  Widget _selChip(int i) {
    return GestureDetector(
      onTap: _openMixVolumeSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(_orbIcons[i],
                width: 16,
                height: 16,
                color: Colors.white,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 14)),
            const SizedBox(width: 7),
            Text(_loc.t(_orbNameKeys[i]),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ─────────── Sayfa 4: Hatırlatma ───────────
  Widget _heroReminder() {
    final timeStr =
        '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            // Ana hatırlatma satırı (ikon = ayarlar ile aynı görsel)
            Row(
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/hatirlatici.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.alarm_rounded,
                            color: Color(0xFFFBBF24),
                            size: 26)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_loc.t('SleepReminder'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_loc.t('SleepReminderSub'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _reminderOn,
                  activeColor: AppColors.purple,
                  onChanged: (v) {
                    setState(() => _reminderOn = v);
                    _applyReminder();
                  },
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              child: !_reminderOn
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      children: [
                        const SizedBox(height: 14),
                        // Saat seçici
                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    color: Color(0xFFFBBF24), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_loc.t('ReminderMain'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ),
                                Text(timeStr,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(width: 6),
                                Icon(Icons.chevron_right_rounded,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    size: 22),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 2. (ön) hatırlatma — ayarlardaki gibi
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.notifications_active_rounded,
                                      color: _accent, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(_loc.t('PreReminder'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  Transform.scale(
                                    scale: 0.8,
                                    child: Switch.adaptive(
                                      value: _preReminderEnabled,
                                      activeColor: _accent,
                                      onChanged: (v) {
                                        setState(
                                            () => _preReminderEnabled = v);
                                        _applyReminder();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                child: !_preReminderEnabled
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding:
                                            const EdgeInsets.only(top: 6),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [5, 15, 30, 60].map((m) {
                                            final sel =
                                                _preReminderMinutes == m;
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() =>
                                                    _preReminderMinutes = m);
                                                _applyReminder();
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 12,
                                                    vertical: 7),
                                                decoration: BoxDecoration(
                                                  color: sel
                                                      ? _accent
                                                      : Colors.white
                                                          .withValues(
                                                              alpha: 0.06),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10),
                                                ),
                                                child: Text(
                                                    '$m ${_loc.t('MinutesBefore')}',
                                                    style: TextStyle(
                                                        color: sel
                                                            ? Colors.white
                                                            : Colors.white
                                                                .withValues(
                                                                    alpha:
                                                                        0.7),
                                                        fontSize: 12,
                                                        fontWeight: sel
                                                            ? FontWeight.w800
                                                            : FontWeight
                                                                .w600)),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────── Sayfa 5: Bebek adı ───────────
  Widget _heroName() {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // bebek.png — hafif aşağı-yukarı süzülür.
          AnimatedBuilder(
            animation: _floatAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, math.sin(_floatAnim.value * math.pi) * 7 - 3),
              child: child,
            ),
            child: Image.asset(
              'assets/images/onboarding/bebek.png',
              height: 178,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)]),
                ),
                child: const Icon(Icons.child_care_rounded,
                    color: Colors.white, size: 56),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_loc.t('OnbBabyNameLabel'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: _accent,
                  textCapitalization: TextCapitalization.words,
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    hintText: _loc.t('OnbBabyNameHint'),
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: _accent, size: 14),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(_loc.t('OnbBabyNameNote'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              height: 1.35)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── Footer ───────────
  Widget _footer(bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 0),
      child: Column(
        children: [
          _OnbPrimaryButton(
            label: _index == _mixIndex
                ? _loc.t('OnbMixCreate')
                : (isLast ? _loc.t('OnbStart') : _loc.t('Continue')),
            onTap: _next,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _finish();
            },
            child: Text(isLast ? _loc.t('OnbLater') : _loc.t('OnbSkip'),
                style: const TextStyle(
                    color: _accent,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 6),
          _dots(),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pageCount, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _accent : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ════════════ Yardımcı widget'lar ════════════

/// Sayfa etkin olunca içeriği soft (fade + yukarı kayma) açar; bir kez.
class _RevealOnActive extends StatefulWidget {
  final bool active;
  final Widget child;
  const _RevealOnActive({required this.active, required this.child});

  @override
  State<_RevealOnActive> createState() => _RevealOnActiveState();
}

class _RevealOnActiveState extends State<_RevealOnActive>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    if (widget.active) {
      _revealed = true;
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _RevealOnActive old) {
    super.didUpdateWidget(old);
    if (widget.active && !_revealed) {
      _revealed = true;
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child));
  }
}

/// Basınca hafif küçülen + dokunsal geri bildirimli ana buton.
class _OnbPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OnbPrimaryButton({required this.label, required this.onTap});

  @override
  State<_OnbPrimaryButton> createState() => _OnbPrimaryButtonState();
}

class _OnbPrimaryButtonState extends State<_OnbPrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18)),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 18),
              ),
              Expanded(
                child: Text(widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700)),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 22),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Çalan ses için küçük ekolayzer çubukları.
class _EqBars extends StatefulWidget {
  final Color color;
  const _EqBars({required this.color});
  @override
  State<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<_EqBars> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(4, (i) {
            final v = (math.sin((_c.value * 2 * math.pi) + i) + 1) / 2;
            return Container(
              width: 3.5,
              height: 5 + v * 11,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Mix knob'unun etrafındaki dönen kesik halka.
class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final paint = Paint()
      ..color = const Color(0xFFB794F4).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    const total = 40;
    for (int i = 0; i < total; i++) {
      if (i % 2 == 0) continue;
      final a0 = (i / total) * 2 * math.pi;
      final a1 = a0 + (2 * math.pi / total) * 0.6;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius), a0, a1 - a0, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => false;
}

/// Yörünge karıştırıcısındaki tekil ses düğümü (daire + ekle/✓ rozeti + etiket).
/// Dokun → seç/oynat, basılı tut → ses düzeyi popup'ı. Hafifçe süzülür.
class _OrbitNode extends StatelessWidget {
  final String label;
  final String iconAsset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Animation<double> anim;
  final double phase;
  const _OrbitNode({
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.anim,
    required this.phase,
  });

  static const Color _accent = Color(0xFF9D5FF3);

  @override
  Widget build(BuildContext context) {
    final node = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: selected
                        ? _accent
                        : Colors.white.withValues(alpha: 0.15),
                    width: selected ? 1.8 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Image.asset(
                    iconAsset,
                    fit: BoxFit.contain,
                    color: Colors.white,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 22),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? _accent : const Color(0xFF2D1B4E),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Icon(selected ? Icons.check_rounded : Icons.add_rounded,
                      color: Colors.white, size: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: selected ? 0.95 : 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) {
        final dy = math.sin(anim.value * 2 * math.pi + phase * 1.4) * 3.0;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: node,
    );
  }
}

/// Seçili düğümlerden merkez küreye akan ışık çizgileri + hareketli noktalar.
class _OrbitLinksPainter extends CustomPainter {
  final double t;
  final Offset center;
  final double ringR;
  final List<int> selected;
  _OrbitLinksPainter({
    required this.t,
    required this.center,
    required this.ringR,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = const Color(0xFF7C3AED).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = const Color(0xFF9D5FF3).withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (final i in selected) {
      final a = -math.pi / 2 + i * (math.pi / 3);
      final p0 = Offset(
          center.dx + ringR * math.cos(a), center.dy + ringR * math.sin(a));
      canvas.drawLine(p0, center, glow);
      canvas.drawLine(p0, center, line);
      for (int k = 0; k < 2; k++) {
        final tt = (t + k / 2) % 1.0;
        final pt = Offset.lerp(p0, center, tt)!;
        canvas.drawCircle(
            pt,
            2.4,
            Paint()
              ..color = Colors.white
                  .withValues(alpha: (0.8 * (1 - tt)).clamp(0.1, 0.8)));
      }
    }
  }

  @override
  bool shouldRepaint(_OrbitLinksPainter old) =>
      old.t != t || old.selected.length != selected.length;
}

/// Her seçili sesin düzeyini ayrı ayrı ayarlayan alttan açılır popup.
class _MixVolumeSheet extends StatefulWidget {
  final List<int> selected;
  final String titleText;
  final String Function(int) nameOf;
  final String Function(int) iconOf;
  final double Function(int) volumeOf;
  final void Function(int, double) onChanged;
  const _MixVolumeSheet({
    required this.selected,
    required this.titleText,
    required this.nameOf,
    required this.iconOf,
    required this.volumeOf,
    required this.onChanged,
  });

  @override
  State<_MixVolumeSheet> createState() => _MixVolumeSheetState();
}

class _MixVolumeSheetState extends State<_MixVolumeSheet> {
  late final Map<int, double> _v = {
    for (final i in widget.selected) i: widget.volumeOf(i),
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF160A2E).withValues(alpha: 0.92),
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).padding.bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.tune_rounded,
                      color: Color(0xFF9D5FF3), size: 20),
                  const SizedBox(width: 10),
                  Text(widget.titleText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              ...widget.selected.map(_row),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(int i) {
    final v = _v[i] ?? 0.8;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(widget.iconOf(i),
                  fit: BoxFit.contain,
                  color: Colors.white,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: 16)),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 78,
            child: Text(widget.nameOf(i),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF7C3AED),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                thumbColor: Colors.white,
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: v,
                onChanged: (nv) {
                  setState(() => _v[i] = nv);
                  widget.onChanged(i, nv);
                },
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('${(v * 100).toInt()}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Son sayfada (bebek adı) küçük, yanıp sönen ve hafifçe süzülen yıldızlar.
class _TwinklingStars extends StatefulWidget {
  const _TwinklingStars();
  @override
  State<_TwinklingStars> createState() => _TwinklingStarsState();
}

class _TwinklingStarsState extends State<_TwinklingStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    _stars = List.generate(
      48,
      (_) => _Star(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        r: 0.6 + rnd.nextDouble() * 1.5,
        phase: rnd.nextDouble() * math.pi * 2,
        speed: 0.5 + rnd.nextDouble() * 1.1,
      ),
    );
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) =>
          CustomPaint(size: Size.infinite, painter: _StarsPainter(_c.value, _stars)),
    );
  }
}

class _Star {
  final double x, y, r, phase, speed;
  const _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.phase,
    required this.speed,
  });
}

class _StarsPainter extends CustomPainter {
  final double t;
  final List<_Star> stars;
  _StarsPainter(this.t, this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      // Yanıp sönme (twinkle)
      final tw = (math.sin(t * 2 * math.pi * s.speed + s.phase) + 1) / 2;
      final alpha = (0.12 + tw * 0.78).clamp(0.0, 1.0);
      // Hafif yukarı süzülme — ekran içinde döngüsel
      final dx = s.x * size.width;
      final dy = ((s.y - t * 0.12 * s.speed) % 1.0 + 1.0) % 1.0 * size.height;
      final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), s.r * (0.7 + tw * 0.6), paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.t != t;
}

/// Giriş ekranı başlık + alt yazısının kademeli (staggered) animasyonlu açılışı.
class _WelcomeIntro extends StatefulWidget {
  final Widget title;
  final Widget subtitle;
  const _WelcomeIntro({required this.title, required this.subtitle});
  @override
  State<_WelcomeIntro> createState() => _WelcomeIntroState();
}

class _WelcomeIntroState extends State<_WelcomeIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _item(Widget child, double start, double end) {
    final fade = CurvedAnimation(
        parent: _c, curve: Interval(start, end, curve: Curves.easeOut));
    final slide = Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _c,
            curve: Interval(start, end, curve: Curves.easeOutCubic)));
    final scale = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(
        parent: _c, curve: Interval(start, end, curve: Curves.easeOutBack)));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _item(widget.title, 0.0, 0.62),
        const SizedBox(height: 12),
        _item(widget.subtitle, 0.32, 1.0),
      ],
    );
  }
}
