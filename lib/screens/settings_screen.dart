import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/review_service.dart';
import '../services/subscription_service.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../services/sleep_tracking_service.dart';
import '../services/profanity_filter.dart';
import '../widgets/unlock_button.dart';
import '../widgets/banner_ad_widget.dart';
import '../services/ad_service.dart';
import 'paywall_screen.dart';
import 'login_screen.dart';
import 'feedback_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<String>? onBabyNameChanged;
  const SettingsScreen({super.key, this.onBabyNameChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  late AnimationController _diamondPulse;
  late AnimationController _diamondRotate;
  final TextEditingController _nameController = TextEditingController();
  final _loc = LocalizationService();
  bool _nameSaved = false;

  // Ayar değerleri
  bool _notificationsEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  // Ön hatırlatma — açıksa ana hatırlatmadan _preReminderMinutes dk önce
  // ekstra bir bildirim gönderilir.
  bool _preReminderEnabled = false;
  int _preReminderMinutes = 15; // 5 / 15 / 30 / 60 dk seçenekleri

  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    // IndexedStack içinde sabit instance — dil değişimi için kendimiz listen ediyoruz.
    _loc.addListener(_onLanguageChanged);
    _diamondPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _diamondRotate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _loadSettings();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('baby_name') ?? '';
      _notificationsEnabled = prefs.getBool('notifications') ?? false;
      int remHour = prefs.getInt('rem_hour') ?? 21;
      int remMinute = prefs.getInt('rem_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: remHour, minute: remMinute);
      _preReminderEnabled = prefs.getBool('pre_rem_enabled') ?? false;
      _preReminderMinutes = prefs.getInt('pre_rem_minutes') ?? 15;
    });
  }

  Future<void> _saveBabyName() async {
    final name = _nameController.text.trim();

    // Küfür filtresi kontrolü
    if (ProfanityFilter.containsProfanity(name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_loc.t('ProfanityWarning')),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baby_name', name);
    widget.onBabyNameChanged?.call(name);
    FocusScope.of(context).unfocus();
    setState(() => _nameSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _nameSaved = false);
    });
  }

  Future<void> _toggleSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    if (key == 'notifications') {
      if (value) {
        await NotificationService().scheduleSleepReminder(
          _reminderTime,
          preReminderEnabled: _preReminderEnabled,
          preReminderMinutesBefore: _preReminderMinutes,
        );
      } else {
        await NotificationService().cancelReminder();
      }
    }
  }

  Future<void> _saveReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rem_hour', time.hour);
    await prefs.setInt('rem_minute', time.minute);

    if (_notificationsEnabled) {
      await NotificationService().scheduleSleepReminder(
        time,
        preReminderEnabled: _preReminderEnabled,
        preReminderMinutesBefore: _preReminderMinutes,
      );
    }
  }

  /// Ön hatırlatma toggle'ı veya süre seçimi değiştiğinde çağrılır.
  /// Ana hatırlatma açıksa tüm planı yeniden kurar.
  Future<void> _savePreReminder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pre_rem_enabled', _preReminderEnabled);
    await prefs.setInt('pre_rem_minutes', _preReminderMinutes);

    if (_notificationsEnabled) {
      await NotificationService().scheduleSleepReminder(
        _reminderTime,
        preReminderEnabled: _preReminderEnabled,
        preReminderMinutesBefore: _preReminderMinutes,
      );
    }
  }

  Future<void> _updateLang(int val) async {
    await _loc.setLanguage(val);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _loc.removeListener(_onLanguageChanged);
    _nameController.dispose();
    _diamondPulse.dispose();
    _diamondRotate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 160),
          children: [
            const SizedBox(height: 32),

            // ─── Logo + Başlık + (Premium ise) sağda Plus rozeti ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/logo.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sleepora', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                        Text(_loc.t('AppSubtitle'), style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  // Premium kullanıcı için sağ üst köşede Plus rozeti
                  if (SubscriptionService().isPremium) _buildHeaderPlusBadge(),
                ],
              ),
            ),

            // Premium kullanıcı için büyük kartı tamamen gizliyoruz —
            // üstteki header rozeti zaten Plus durumunu gösteriyor.
            if (SubscriptionService().isPremium) const SizedBox.shrink() else ...[
            const SizedBox(height: 20),

            // ─── Premium Abonelik (sadece ücretsiz kullanıcılar için) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () {
                  if (SubscriptionService().isPremium) return;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2A1060), Color(0xFF4C1D95), Color(0xFF3B1F8C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: SubscriptionService().isPremium
                          ? const Color(0xFFB794F4).withValues(alpha: 0.5)
                          : const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                      width: SubscriptionService().isPremium ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: SubscriptionService().isPremium ? 0.2 : 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Animasyonlu elmas ikonu
                      ListenableBuilder(
                        listenable: Listenable.merge([_diamondPulse, _diamondRotate]),
                        builder: (context, _) {
                          final pulse = 0.95 + _diamondPulse.value * 0.1;
                          final glow = 0.2 + _diamondPulse.value * 0.3;
                          final rotateY = math.sin(_diamondRotate.value * math.pi * 2) * 0.15;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(rotateY)
                              ..scale(pulse),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA), Color(0xFF7C3AED)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: glow),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Lottie.asset(
                                  'assets/images/elmas.json',
                                  fit: BoxFit.contain,
                                  repeat: true,
                                  // PNG fallback (paket yüklenmediyse veya
                                  // animasyon dosyası bulunamazsa Material ikonu)
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.diamond_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Sleepora Plus',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                if (SubscriptionService().isPremium) ...[
                                  const SizedBox(width: 8),
                                  // ── Premium badge ──
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFB794F4), Color(0xFF7C3AED)],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('✦', style: TextStyle(color: Colors.white, fontSize: 9)),
                                        const SizedBox(width: 3),
                                        Text(
                                          _loc.t('ActiveBadge'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              SubscriptionService().isPremium
                                  ? _loc.t('AllUnlocked')
                                  : _loc.t('UnlockAllFeatures'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!SubscriptionService().isPremium)
                        // Tıklamayı dışarıya iletme — kart zaten navigate ediyor
                        IgnorePointer(
                          child: UnlockButton(
                            label: _loc.t('UpgradeToPlus'),
                            height: 36,
                            fontSize: 12,
                            horizontalPadding: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ], // büyük Plus kartı bloğu sonu (sadece non-premium)

            const SizedBox(height: 16),

            // ─── Hesap (Account) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _auth.isLoggedIn ? _buildProfilePanel() : _buildLoginPrompt(),
            ),

            // ─── Uyku İstatistikleri (sadece giriş yapılmışsa) ───
            // Önceden inline kartla gösteriliyordu; artık tıklanabilir
            // launcher tile → tüm istatistikler açılır pencerede açılır.
            if (_auth.isLoggedIn) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _openSleepStatsDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.10),
                          const Color(0xFF1A1025),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                          ),
                          child: const Icon(
                            Icons.nightlight_round,
                            color: Color(0xFF8B5CF6),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _loc.t('SleepStatsTitle'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _loc.t('SleepStatsDesc'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.45),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ─── Bebek Adı ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1025),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha:0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _loc.t('BabyNameDesc'),
                        style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loc.t('BabyNameTitle'),
                      style: TextStyle(color: Colors.white.withValues(alpha:0.35), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha:0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha:0.08)),
                            ),
                            child: TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: _loc.t('BabyNameHint'),
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.2), fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _saveBabyName,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _nameSaved ? AppColors.green : AppColors.purple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _nameSaved ? Icons.check_circle_rounded : Icons.check_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Hatırlatıcı Ayarları ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1025),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha:0.06)),
                ),
                child: Column(
                  children: [
                    _SettingToggleRow(
                      assetPath: 'assets/images/hatirlatici.png',
                      // Yeni ikon kendi içinde dolu — zoom kaldırıldı.
                      assetScale: 1.0,
                      iconColor: const Color(0xFFFBBF24),
                      bgColor: const Color(0xFF3D3200),
                      label: _loc.t('SleepReminder'),
                      subtitle: _loc.t('SleepReminderSub'),
                      value: _notificationsEnabled,
                      onChanged: (v) {
                        setState(() => _notificationsEnabled = v);
                        _toggleSetting('notifications', v);
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: _notificationsEnabled
                          ? Container(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ─── 1) Ana Hatırlatma kartı ───
                                  _ReminderRowCard(
                                    accent: const Color(0xFFFBBF24),
                                    icon: Icons.alarm_rounded,
                                    title: _loc.t('ReminderMain'),
                                    description: _loc.t('ReminderMainDesc'),
                                    trailing: GestureDetector(
                                      onTap: () async {
                                        final time = await showTimePicker(
                                            context: context,
                                            initialTime: _reminderTime);
                                        if (time != null) {
                                          setState(() => _reminderTime = time);
                                          _saveReminderTime(time);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.access_time_rounded, color: Colors.white, size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              _reminderTime.format(context),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // ─── 2) Ön Hatırlatma kartı (toggle'lı) ───
                                  _ReminderRowCard(
                                    accent: const Color(0xFF8B5CF6),
                                    icon: Icons.notifications_active_rounded,
                                    title: _loc.t('PreReminder'),
                                    description: _loc.t('PreReminderDesc'),
                                    trailing: Transform.scale(
                                      scale: 0.85,
                                      child: Switch.adaptive(
                                        value: _preReminderEnabled,
                                        activeColor: const Color(0xFF8B5CF6),
                                        onChanged: (v) {
                                          setState(() => _preReminderEnabled = v);
                                          _savePreReminder();
                                        },
                                      ),
                                    ),
                                  ),

                                  // Ön hatırlatma açıksa: dakika seçimi
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    child: !_preReminderEnabled
                                        ? const SizedBox.shrink()
                                        : Padding(
                                            padding: const EdgeInsets.fromLTRB(14, 10, 4, 0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _loc.t('PreReminderOffset'),
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.55),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Dakika çipleri: 5 / 15 / 30 / 60
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 6,
                                                  children: [5, 15, 30, 60].map((m) {
                                                    final selected = _preReminderMinutes == m;
                                                    return GestureDetector(
                                                      onTap: () {
                                                        setState(() => _preReminderMinutes = m);
                                                        _savePreReminder();
                                                      },
                                                      child: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 220),
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                                        decoration: BoxDecoration(
                                                          gradient: selected
                                                              ? const LinearGradient(
                                                                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                                                )
                                                              : null,
                                                          color: selected ? null : Colors.white.withValues(alpha: 0.06),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(
                                                            color: selected
                                                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                                                                : Colors.white.withValues(alpha: 0.08),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          '$m ${_loc.t('MinutesBefore')}',
                                                          style: TextStyle(
                                                            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                                                            fontSize: 12,
                                                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),

                                  const SizedBox(height: 12),

                                  // ─── 3) Bilgi callout'u ───
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06B6D4).withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF06B6D4).withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.info_outline_rounded, color: Color(0xFF67E8F9), size: 14),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _loc.t('ReminderInfoTitle'),
                                                style: const TextStyle(
                                                  color: Color(0xFF67E8F9),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                _loc.t('ReminderInfoDesc'),
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.62),
                                                  fontSize: 11,
                                                  height: 1.4,
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
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Dil Seçimi ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1025),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha:0.06)),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    title: Text(_loc.t('LanguageTitle'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white.withValues(alpha:0.5),
                    children: [
                      _LanguageRow(name: 'Türkçe', flag: '🇹🇷', isSelected: _loc.selectedLang == 0, onTap: () => _updateLang(0)),
                      _RowDivider(),
                      _LanguageRow(name: 'English', flag: '🇬🇧', isSelected: _loc.selectedLang == 1, onTap: () => _updateLang(1)),
                      _RowDivider(),
                      _LanguageRow(name: 'Español', flag: '🇪🇸', isSelected: _loc.selectedLang == 2, onTap: () => _updateLang(2)),
                      _RowDivider(),
                      _LanguageRow(name: 'Français', flag: '🇫🇷', isSelected: _loc.selectedLang == 3, onTap: () => _updateLang(3)),
                      _RowDivider(),
                      _LanguageRow(name: 'Deutsch', flag: '🇩🇪', isSelected: _loc.selectedLang == 4, onTap: () => _updateLang(4)),
                      _RowDivider(),
                      _LanguageRow(name: 'Русский', flag: '🇷🇺', isSelected: _loc.selectedLang == 5, onTap: () => _updateLang(5)),
                      _RowDivider(),
                      _LanguageRow(name: 'العربية', flag: '🇸🇦', isSelected: _loc.selectedLang == 6, onTap: () => _updateLang(6)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Destek & İletişim ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _loc.t('SupportContact'),
                style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1025),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha:0.06)),
                ),
                child: Column(
                  children: [
                    _ContactRow(
                      faIcon: FontAwesomeIcons.star,
                      iconColor: Colors.white,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFB347), Color(0xFFFFD700)],
                      ),
                      label: _loc.t('RateApp'),
                      // Platforma göre doğru mağazaya yönlendirir
                      // (Android → Google Play, iOS → App Store).
                      onTap: () => ReviewService.openStoreListing(),
                    ),
                    _RowDivider(),
                    _ContactRow(
                      faIcon: FontAwesomeIcons.instagram,
                      iconColor: Colors.white,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF77737), Color(0xFFE1306C), Color(0xFF833AB4)],
                      ),
                      label: _loc.t('FollowInsta'),
                      onTap: () async {
                        final uri = Uri.parse('https://instagram.com/sleepora');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    _RowDivider(),
                    _ContactRow(
                      faIcon: FontAwesomeIcons.youtube,
                      iconColor: Colors.white,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                      ),
                      label: _loc.t('YouTubeChannel'),
                      onTap: () async {
                        final uri = Uri.parse('https://youtube.com/@sleepora');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    _RowDivider(),
                    _ContactRow(
                      icon: Icons.rate_review_rounded,
                      iconColor: Colors.white,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C3AED), Color(0xFF5DE8DA)],
                      ),
                      label: _loc.t('FeedbackTitle'),
                      onTap: () => FeedbackScreen.show(context),
                    ),
                    _RowDivider(),
                    _ContactRow(
                      icon: Icons.mail_rounded,
                      iconColor: Colors.white,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      ),
                      label: _loc.t('ContactFeed'),
                      onTap: () async {
                        final uri = Uri.parse('mailto:destek@sleepora.app?subject=Sleepora%20Geri%20Bildirim');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                    _RowDivider(),
                    _ContactRow(
                      icon: Icons.shield_rounded,
                      iconColor: Colors.white,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
                      ),
                      label: _loc.t('PrivacyPolicy'),
                      onTap: () async {
                        final uri = Uri.parse('https://sleepora.app/privacy-policy.html');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    _RowDivider(),
                    _ContactRow(
                      icon: Icons.play_circle_outline_rounded,
                      iconColor: Colors.white,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                      ),
                      label: _loc.t('ReplayOnboarding'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ─── Hesap Aksiyonları — Çıkış Yap + Hesabı Sil ───
            // Sadece giriş yapılmışsa göster. Çıkış Yap nötr (kehribar/amber),
            // Hesabı Sil yıkıcı (koyu kırmızı). Apple Guideline 5.1.1(v) uyumu:
            // hesap silme açıkça keşfedilebilir ve eşit görsel hiyerarşide.
            if (_auth.isLoggedIn) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Çıkış Yap — turuncu tonlu, uyarı seviyesi
                    GestureDetector(
                      onTap: _handleSignOut,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded,
                                color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              _loc.t('AccountSignOut'),
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Hesabı Sil — kırmızı tonlu, yıkıcı seviyesi
                    GestureDetector(
                      onTap: _handleDeleteAccount,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              _loc.t('DeleteAccountTitle'),
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ─── Alt bilgi ───
            Center(
              child: Column(
                children: [
                  Text('Sleepora v1.0.0', style: TextStyle(color: Colors.white.withValues(alpha:0.2), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(_loc.t('PeacefulSleep'), style: TextStyle(color: Colors.white.withValues(alpha:0.15), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Uyku İstatistikleri Açılır Penceresi
  // ═══════════════════════════════════════════════════════════
  /// Settings'teki uyku istatistikleri tile'ına basıldığında çağrılır.
  /// Tüm istatistik kartını (grafik + chip'ler + bugünkü uyutmalar +
  /// saatlik dağılım + streak) modal dialog içinde gösterir.
  void _openSleepStatsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Ekran yüksekliğinin %85'ini geçmesin — uzun listeler scroll'lar
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
              maxWidth: 560,
            ),
            child: SingleChildScrollView(
              child: _SleepStatsCard(
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Premium kullanıcı için sağ üst köşede kompakt Plus rozeti
  // ═══════════════════════════════════════════════════════════

  /// Plus rozeti — yalnızca [SubscriptionService.isPremium] true iken çağrılır.
  /// Sol tarafta animasyonlu elmas (Lottie), sağında "Sleepora Plus" başlığı
  /// ve abonelik tipine göre durum metni ("Ömür Boyu", "{N} gün kaldı" veya
  /// fallback "Aktif").
  /// Plus durum metnini üretir ("Ömür Boyu" / "{n} gün kaldı" / plan adı).
  String _plusStatusText() {
    final svc = SubscriptionService();
    if (svc.isLifetime) return _loc.t('Lifetime');
    if (svc.remainingDays != null) {
      return _loc.t('DaysLeft').replaceAll('{n}', '${svc.remainingDays}');
    }
    if (svc.subscriptionPlan == 'monthly') return _loc.t('MonthlyPlan');
    if (svc.subscriptionPlan == 'yearly') return _loc.t('YearlyPlan');
    return _loc.t('ActiveBadge');
  }

  /// Cihazın platformuna göre sistem "Abonelikleri Yönet" sayfasını açar.
  /// iOS → App Store hesap abonelikleri, Android → Play Store abonelikleri.
  Future<void> _openManageSubscriptions() async {
    final url = Uri.parse(
      Platform.isIOS
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Premium kullanıcı üst rozete dokununca: paywall yerine durum penceresi.
  /// Plus durumunu gösterir ve "Aboneliği Yönet" ile sistem abonelik sayfasını
  /// açar. Böylece zaten abone olan kullanıcıya satış ekranı çıkmaz.
  void _showPlusStatusDialog() {
    final loc = _loc;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1235),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFFB794F4).withValues(alpha: 0.35),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.diamond_rounded, color: Color(0xFFB794F4), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.t('PlusActiveTitle'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          _plusStatusText(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              loc.t('Ok'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openManageSubscriptions();
            },
            child: Text(
              loc.t('ManageSubscription'),
              style: const TextStyle(
                color: Color(0xFFB794F4),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPlusBadge() {
    final svc = SubscriptionService();
    final loc = _loc;

    // Durum metnini belirle
    String statusText;
    if (svc.isLifetime) {
      statusText = loc.t('Lifetime');
    } else if (svc.remainingDays != null) {
      statusText = loc.t('DaysLeft').replaceAll('{n}', '${svc.remainingDays}');
    } else if (svc.subscriptionPlan == 'monthly') {
      statusText = loc.t('MonthlyPlan');
    } else if (svc.subscriptionPlan == 'yearly') {
      statusText = loc.t('YearlyPlan');
    } else {
      statusText = loc.t('ActiveBadge');
    }

    return GestureDetector(
      // Premium kullanıcı: paywall AÇMA. Bunun yerine durum + "Aboneliği Yönet"
      // penceresini göster (zaten Plus olan kullanıcıya satış ekranı çıkmasın).
      onTap: _showPlusStatusDialog,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFB794F4).withValues(alpha: 0.45),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lottie elmas
            SizedBox(
              width: 32,
              height: 32,
              child: Lottie.asset(
                'assets/images/elmas.json',
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.diamond_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sleepora Plus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  statusText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Giriş yapmamış — Login Prompt Kartı
  // ═══════════════════════════════════════════════════════════

  Widget _buildLoginPrompt() {
    return Column(
      children: [
        // Ana login kartı
        GestureDetector(
          onTap: () => LoginScreen.show(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1025),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF9D5FF3), Color(0xFF6D28D9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _loc.t('AccountTitle'),
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _loc.t('AccountPrompt'),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 22),
                  ],
                ),
                const SizedBox(height: 14),
                // ─── Cihazlar arası senkronizasyon vurgusu ───
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.03),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        ),
                        child: Icon(Icons.sync_rounded, color: const Color(0xFF10B981).withValues(alpha: 0.8), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loc.t('SyncDevicesMsg'),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _loc.t('SyncDevicesDesc'),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                              maxLines: 2,
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
        ),
        const SizedBox(height: 12),
        // ─── Uyku İstatistikleri Kartı (Login motivasyonu) ───
        GestureDetector(
          onTap: () => LoginScreen.show(context, feature: _loc.t('SleepStatsTitle')),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.08),
                  const Color(0xFF1A1025),
                ],
              ),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  ),
                  child: Icon(Icons.bar_chart_rounded, color: const Color(0xFF10B981).withValues(alpha: 0.8), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loc.t('SleepStatsTitle'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _loc.t('SleepStatsDesc'),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  ),
                  child: Text(
                    _loc.t('BtnSignIn'),
                    style: TextStyle(color: const Color(0xFF10B981).withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Giriş yapılmış — Profil Paneli
  // ═══════════════════════════════════════════════════════════

  Widget _buildProfilePanel() {
    final user = _auth.currentUser;
    final displayName = user?.displayName ?? _loc.t('AccountTitle');
    final email = user?.email ?? '';
    final photoUrl = user?.photoURL;
    final provider = _auth.authProvider;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Avatar (compact)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: photoUrl == null
                  ? const LinearGradient(colors: [Color(0xFF9D5FF3), Color(0xFF6D28D9)])
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: photoUrl != null
                ? Image.network(photoUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitials(displayName))
                : _buildInitials(displayName),
          ),
          const SizedBox(width: 12),
          // İsim + e-posta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Ad düzenleme butonu
          GestureDetector(
            onTap: () => _showEditNameDialog(displayName),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(Icons.edit_outlined, color: Colors.white.withValues(alpha: 0.5), size: 16),
            ),
          ),
          const SizedBox(width: 4),
          // Provider icon
          if (provider != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                provider == 'apple' ? Icons.apple : Icons.g_mobiledata,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ),
          // Çıkış ikonu
          GestureDetector(
            onTap: _handleSignOut,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Bir [Duration]'ı "kalan gün" sayısına çevirir (yukarı yuvarlar, min 1).
  int _cooldownDays(Duration d) =>
      (d.inMinutes / (60 * 24)).ceil().clamp(1, 999);

  void _showEditNameDialog(String currentName) async {
    // Bekleme süresi dolmuş mu? Diyalog açılmadan önce kontrol et.
    Duration? remaining = await _auth.nameChangeRemaining();
    if (!mounted) return;

    final controller = TextEditingController(text: currentName);
    bool saving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final locked = remaining != null;
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1025),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              _loc.t('EditNameTitle'),
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: !locked,
                  enabled: !locked,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    hintText: _loc.t('EditNameHint'),
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Bilgi / uyarı: 3 günlük kural ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      locked ? Icons.lock_clock_rounded : Icons.info_outline_rounded,
                      size: 15,
                      color: locked
                          ? const Color(0xFFFBBF24)
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        locked
                            ? _loc.t('NameChangeCooldownError').replaceAll(
                                '{n}', '${_cooldownDays(remaining!)}')
                            : _loc.t('NameChangeCooldownInfo'),
                        style: TextStyle(
                          color: locked
                              ? const Color(0xFFFBBF24)
                              : Colors.white.withValues(alpha: 0.45),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_loc.t('BtnCancel'), style: const TextStyle(color: Colors.white38)),
              ),
              TextButton(
                onPressed: (saving || locked) ? null : () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;

                  // Küfür filtresi kontrolü
                  if (ProfanityFilter.containsProfanity(name)) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(_loc.t('ProfanityWarning')),
                        backgroundColor: AppColors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                    return;
                  }

                  // Bekleme süresi son bir kez doğrulanır (yarış durumlarına karşı).
                  final stillRemaining = await _auth.nameChangeRemaining();
                  if (stillRemaining != null) {
                    setLocal(() => remaining = stillRemaining);
                    return;
                  }

                  setLocal(() => saving = true);
                  final ok = await _auth.updateDisplayName(name);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? _loc.t('EditNameSuccess') : _loc.t('EditNameError')),
                      backgroundColor: ok ? AppColors.green : AppColors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
                child: Text(
                  saving ? '...' : _loc.t('BtnSave'),
                  style: TextStyle(
                    color: (saving || locked)
                        ? Colors.white24
                        : const Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInitials(String name) {
    final initials = name.isNotEmpty
        ? name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1025),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _loc.t('SignOutConfirmTitle'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          _loc.t('SignOutConfirmMsg'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_loc.t('Cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_loc.t('AccountSignOut'), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_loc.t('SignOutSuccess')),
              backgroundColor: AppColors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_loc.t('ErrorPrefix')}: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // Apple Guideline 5.1.1(v) — Hesap Silme (Account Deletion)
  // ═══════════════════════════════════════════════════════

  /// İki adımlı onaylı hesap silme akışı.
  /// 1. Kullanıcı uyarıyı kabul eder.
  /// 2. Son kez onaylar (TextField "SİL" yazımı ile).
  /// 3. AuthService.deleteAccount() çağrılır; başarısızsa yeniden
  ///    kimlik doğrulama yönlendirmesi yapılır.
  Future<void> _handleDeleteAccount() async {
    // ── 1. Uyarı + ilk onay
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1025),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _loc.t('DeleteAccountTitle'),
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _loc.t('DeleteAccountWarning'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _loc.t('DeleteAccountConsequences'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_loc.t('Cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _loc.t('Continue'),
              style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    // ── 2. Son onay (yazılı doğrulama)
    final keyword = _loc.t('DeleteConfirmKeyword'); // "SİL" / "DELETE"
    final controller = TextEditingController();
    bool canDelete = false;
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1A1025),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            _loc.t('DeleteAccountConfirmTitle'),
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _loc.t('DeleteAccountTypeToConfirm').replaceAll('{keyword}', keyword),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => setLocal(() => canDelete = v.trim().toUpperCase() == keyword.toUpperCase()),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: keyword,
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_loc.t('Cancel'), style: const TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: canDelete ? () => Navigator.pop(ctx, true) : null,
              child: Text(
                _loc.t('DeleteAccountTitle'),
                style: TextStyle(
                  color: canDelete ? const Color(0xFFEF4444) : Colors.white24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (finalConfirm != true || !mounted) return;

    // ── 3. Silme işlemini başlat
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFEF4444))),
    );

    final ok = await _auth.deleteAccount();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // progress dialog'u kapat

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loc.t('DeleteAccountSuccess')),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // Login ekranına yönlendir
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } else {
      final err = _auth.error ?? _loc.t('DeleteAccountError');
      final needsReauth = err.contains('tekrar giriş') || err.contains('requires-recent-login');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(needsReauth ? _loc.t('DeleteAccountReauthNeeded') : err),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
      // Yeniden kimlik doğrulama gerekiyorsa kullanıcıyı login ekranına gönder
      if (needsReauth) {
        await _auth.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    }
  }
}

// ─── Hatırlatma Satırı (Ana / Ön) ───
/// Solda renkli ikon rozetiyle başlık + açıklama, sağda trailing widget
/// (saat butonu veya toggle) gösterir. Hatırlatma panelinin içinde kullanılır.
class _ReminderRowCard extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final String description;
  final Widget trailing;
  const _ReminderRowCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.description,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.32),
                  accent.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          trailing,
        ],
      ),
    );
  }
}

// ─── Toggle Ayar Satırı ───
class _SettingToggleRow extends StatelessWidget {
  final IconData? icon;
  final String? assetPath;
  final double assetScale;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggleRow({
    this.icon,
    this.assetPath,
    this.assetScale = 1.0,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  }) : assert(icon != null || assetPath != null);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: assetPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Transform.scale(
                      scale: assetScale,
                      child: Image.asset(
                        assetPath!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon!, color: iconColor, size: 20),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha:0.35), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.purple,
              activeTrackColor: AppColors.purple.withValues(alpha:0.4),
              inactiveThumbColor: Colors.white.withValues(alpha:0.4),
              inactiveTrackColor: Colors.white.withValues(alpha:0.1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              splashRadius: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dil Satırı ───
class _LanguageRow extends StatelessWidget {
  final String name;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;
  const _LanguageRow({required this.name, required this.flag, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400))),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── İletişim Satırı ───
class _ContactRow extends StatelessWidget {
  final IconData? icon;
  final FaIconData? faIcon;
  final Color iconColor;
  final Gradient? gradient;
  final String label;
  final VoidCallback onTap;
  const _ContactRow({
    this.icon,
    this.faIcon,
    required this.iconColor,
    this.gradient,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || faIcon != null);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: gradient,
                color: gradient == null ? Colors.white.withValues(alpha: 0.08) : null,
                borderRadius: BorderRadius.circular(13),
                boxShadow: gradient != null
                    ? [
                        BoxShadow(
                          color: (gradient as LinearGradient).colors.last.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: faIcon != null
                    ? FaIcon(faIcon!, color: iconColor, size: 17)
                    : Icon(icon!, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Satır Ayırıcı ───
class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 74),
      child: Divider(color: Colors.white.withValues(alpha:0.05), height: 1),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Uyku İstatistikleri Kartı
// ══════════════════════════════════════════════════════════
class _SleepStatsCard extends StatefulWidget {
  /// Dialog modunda kapatma butonunu görünür yapar.
  /// null ise sadece (i) ve refresh butonları gösterilir (eski inline davranış).
  final VoidCallback? onClose;
  const _SleepStatsCard({this.onClose});

  @override
  State<_SleepStatsCard> createState() => _SleepStatsCardState();
}

class _SleepStatsCardState extends State<_SleepStatsCard> {
  final _loc = LocalizationService();
  WeeklyStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final stats = await SleepTrackingService().getWeeklyStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '—';
    if (minutes < 60) return '$minutes ${_loc.t('StatsMinLabel')}';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '$h ${_loc.t('StatsHoursShort')} $m ${_loc.t('StatsMinLabel')}' : '$h ${_loc.t('StatsHoursShort')}';
  }

  String _formatPreferredHour(int hour) {
    final h = hour.toString().padLeft(2, '0');
    return '~$h:00';
  }

  String _dayLabel(int weekdayIndex) {
    // weekdayIndex: 1=Pzt ... 7=Paz
    return _loc.t('StatsDayShort_${weekdayIndex - 1}');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1025),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Başlık ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1040),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.nightlight_round, color: Color(0xFF8B5CF6), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  _loc.t('SleepStatsTitle'),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                // ─── (i) Bilgi butonu ───
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => _StatsInfoDialog(loc: _loc),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.35),
                      size: 18,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _loadStats,
                  child: Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 20,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.purple.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else if (_stats == null || _stats!.sessionCount == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.bedtime_outlined, color: Colors.white.withValues(alpha: 0.2), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _loc.t('StatsNoData'),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                  ),
                ],
              ),
            )
          else ...[
            // ─── 7 Günlük Bar Grafik ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _WeekBarChart(
                stats: _stats!,
                formatDuration: _formatDuration,
                dayLabel: _dayLabel,
              ),
            ),
            const SizedBox(height: 12),

            // ─── Sayısal İstatistikler ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  _StatChip(
                    label: _loc.t('StatsSessionsCount'),
                    value: '${_stats!.sessionCount}',
                    icon: Icons.nights_stay_rounded,
                    color: const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: _loc.t('StatsTotalTime'),
                    value: _formatDuration(_stats!.totalMinutes),
                    icon: Icons.access_time_rounded,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: _loc.t('StatsAvgDuration'),
                    value: _formatDuration(_stats!.avgMinutes),
                    icon: Icons.show_chart_rounded,
                    color: const Color(0xFFFBBF24),
                  ),
                  if (_stats!.preferredHour != null) ...[
                    const SizedBox(width: 8),
                    _StatChip(
                      label: _loc.t('StatsPreferredTime'),
                      value: _formatPreferredHour(_stats!.preferredHour!),
                      icon: Icons.schedule_rounded,
                      color: const Color(0xFFEC4899),
                    ),
                  ],
                ],
              ),
            ),

            // ─── En çok çalınan ses ───
            if (_stats!.topSoundName != null && _stats!.topSoundName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      const Text('🎵', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loc.t('StatsTopSound'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _stats!.topSoundName!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatDuration(_stats!.topSoundMinutes),
                          style: const TextStyle(
                            color: Color(0xFFB794F4),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Bugünkü Uyutmalar ───
            _TodayNapsSection(
              sessions: _stats!.todaySessions,
              loc: _loc,
              formatDuration: _formatDuration,
            ),

            // ─── Saatlik Dağılım (24h mini histogram) ───
            if (_stats!.hourHistogram.any((c) => c > 0))
              _HourlyDistribution(
                histogram: _stats!.hourHistogram,
                loc: _loc,
              ),

            // ─── Seri (streak) ───
            if (_stats!.streakDays > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        '${_stats!.streakDays} ${_loc.t('StatsStreak')}',
                        style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// Bugünkü Uyutmalar — kronolojik liste (genişletilebilir)
// ════════════════════════════════════════════════════════
/// Varsayılan kapalı (collapsed) — başlık ve seans sayısı görünür.
/// Başlığa tıklandığında animasyonlu olarak liste açılır/kapanır.
class _TodayNapsSection extends StatefulWidget {
  final List<SleepSession> sessions;
  final LocalizationService loc;
  final String Function(int) formatDuration;
  const _TodayNapsSection({
    required this.sessions,
    required this.loc,
    required this.formatDuration,
  });

  @override
  State<_TodayNapsSection> createState() => _TodayNapsSectionState();
}

class _TodayNapsSectionState extends State<_TodayNapsSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions;
    final loc = widget.loc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık satırı (her zaman tıklanabilir) ──
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: Row(
                children: [
                  const Icon(Icons.wb_twilight_rounded, color: Color(0xFF06B6D4), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    loc.t('StatsTodayNapsTitle'),
                    style: const TextStyle(
                      color: Color(0xFF67E8F9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (sessions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${sessions.length} ${loc.t('StatsSessionsCount')}',
                        style: const TextStyle(
                          color: Color(0xFF67E8F9),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Açılır/kapanır chevron — _expanded değişince 180° döner
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF67E8F9).withValues(alpha: 0.85),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // ── İçerik (animasyonlu açılma/kapanma) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: !_expanded
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: sessions.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  loc.t('StatsNoNapsToday'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : Column(
                                children: List.generate(sessions.length, (i) {
                                  final s = sessions[i];
                                  final start = _formatTime(s.startTime);
                                  final end = _formatTime(s.endTime);
                                  final isLast = i == sessions.length - 1;
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
                                    child: Row(
                                      children: [
                                        // Saat çipi
                                        Container(
                                          width: 34,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF06B6D4).withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${i + 1}.',
                                            style: const TextStyle(
                                              color: Color(0xFF67E8F9),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Başlangıç → bitiş
                                        Expanded(
                                          child: Text(
                                            '$start → $end',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        // Süre
                                        Text(
                                          widget.formatDuration(s.durationMinutes),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// Saatlik Dağılım — 24h mini histogram
// ════════════════════════════════════════════════════════
class _HourlyDistribution extends StatelessWidget {
  final List<int> histogram;
  final LocalizationService loc;
  const _HourlyDistribution({
    required this.histogram,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final maxCount = histogram.fold<int>(0, (m, v) => v > m ? v : m);
    final currentHour = DateTime.now().hour;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEC4899).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_rounded, color: Color(0xFFEC4899), size: 16),
                const SizedBox(width: 6),
                Text(
                  loc.t('StatsHourlyTitle'),
                  style: const TextStyle(
                    color: Color(0xFFF9A8D4),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 24 saatlik bar
            SizedBox(
              height: 36,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(24, (h) {
                  final c = histogram[h];
                  final fraction = maxCount > 0 ? c / maxCount : 0.0;
                  final barH = (fraction * 30).clamp(2.0, 30.0);
                  final isCurrent = h == currentHour;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: Duration(milliseconds: 250 + h * 10),
                            curve: Curves.easeOutCubic,
                            height: c == 0 ? 2 : barH,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: c == 0
                                  ? Colors.white.withValues(alpha: isCurrent ? 0.18 : 0.06)
                                  : isCurrent
                                      ? const Color(0xFFEC4899)
                                      : const Color(0xFFEC4899).withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
            // Saat etiketleri (00, 06, 12, 18)
            Row(
              children: [
                _hourLabel('00'),
                Expanded(child: Center(child: _hourLabel('06'))),
                Expanded(child: Center(child: _hourLabel('12'))),
                Expanded(child: Center(child: _hourLabel('18'))),
                _hourLabel('23'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hourLabel(String s) => Text(
        s,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
}

// ─── 7 Günlük Bar Grafik (Gün seçilebilir) ───
class _WeekBarChart extends StatefulWidget {
  final WeeklyStats stats;
  final String Function(int) formatDuration;
  final String Function(int) dayLabel;

  const _WeekBarChart({
    required this.stats,
    required this.formatDuration,
    required this.dayLabel,
  });

  @override
  State<_WeekBarChart> createState() => _WeekBarChartState();
}

class _WeekBarChartState extends State<_WeekBarChart> {
  int? _selectedDayIndex; // Seçili gün (null = seçim yok)

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse('$dateStr 00:00:00');
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxMin = widget.stats.days.fold(0, (m, d) => math.max(m, d.totalMinutes));
    final today = DateTime.now();
    final loc = LocalizationService();

    return Column(
      children: [
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final day = widget.stats.days[i];
              final fraction = maxMin > 0 ? day.totalMinutes / maxMin : 0.0;
              final barHeight = (fraction * 52).clamp(4.0, 52.0);
              final isEmpty = day.totalMinutes == 0;
              final isToday = day.date ==
                  '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
              final isSelected = _selectedDayIndex == i;

              // Haftanın günü (1=Pzt, 7=Paz)
              final dt = DateTime.parse('${day.date} 00:00:00');
              final wdLabel = widget.dayLabel(dt.weekday);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDayIndex = _selectedDayIndex == i ? null : i;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: 400 + i * 60),
                        curve: Curves.easeOutCubic,
                        height: isEmpty ? 4 : barHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: isEmpty
                              ? (isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.07))
                              : isSelected
                                  ? const Color(0xFF10B981)
                                  : isToday
                                      ? AppColors.purple
                                      : AppColors.purple.withValues(alpha: 0.55),
                          boxShadow: isEmpty
                              ? null
                              : [
                                  BoxShadow(
                                    color: (isSelected ? const Color(0xFF10B981) : AppColors.purple).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        wdLabel,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : isToday
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                          fontSize: 9,
                          fontWeight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),

        // ─── Seçili Gün Detayı ───
        if (_selectedDayIndex != null) ...[
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Builder(builder: (context) {
              final day = widget.stats.days[_selectedDayIndex!];
              final dateLabel = _formatDate(day.date);
              final dt = DateTime.parse('${day.date} 00:00:00');
              final wdFull = widget.dayLabel(dt.weekday);
              final daySessions = widget.stats.sessionsByDay[day.date] ?? const [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Tarih ve gün
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$wdFull · $dateLabel',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            day.sessionCount == 0
                                ? loc.t('StatsNoData')
                                : '${day.sessionCount} ${loc.t('StatsSessionsCount')}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Toplam süre
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          day.totalMinutes > 0
                              ? widget.formatDuration(day.totalMinutes)
                              : '—',
                          style: const TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ─── O güne ait oturum saatleri (drill-down) ───
                  if (daySessions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      height: 1,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: daySessions.map((s) {
                        final l = s.startTime.toLocal();
                        final h = l.hour.toString().padLeft(2, '0');
                        final m = l.minute.toString().padLeft(2, '0');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$h:$m · ${widget.formatDuration(s.durationMinutes)}',
                            style: const TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              );
            }),
          ),
        ],
      ],
    );
  }
}

// ─── İstatistik Chip ───
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// Uyku İstatistikleri Bilgi Dialog'u
// ════════════════════════════════════════════════════════
class _StatsInfoDialog extends StatelessWidget {
  final LocalizationService loc;
  const _StatsInfoDialog({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF120D22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                    const Color(0xFF6D28D9).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.t('StatsInfoTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            // ─── İçerik (scrollable) ───
            // Flexible + SingleChildScrollView: header ve close butonu sabit,
            // ortadaki info item'lar uzun olduğunda kullanıcı scroll edebiliyor.
            // Aksi takdirde 6 item + dipnot ekrandan taşıyor (özellikle küçük
            // cihazlarda veya dil çevirisi uzun olan yerlerde).
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoItem(
                      title: loc.t('StatsInfoItem1Title'),
                      description: loc.t('StatsInfoItem1Desc'),
                      color: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(height: 12),
                    _InfoItem(
                      title: loc.t('StatsInfoItem2Title'),
                      description: loc.t('StatsInfoItem2Desc'),
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 12),
                    _InfoItem(
                      title: loc.t('StatsInfoItem3Title'),
                      description: loc.t('StatsInfoItem3Desc'),
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _InfoItem(
                      title: loc.t('StatsInfoItem4Title'),
                      description: loc.t('StatsInfoItem4Desc'),
                      color: const Color(0xFFFBBF24),
                    ),
                    const SizedBox(height: 12),
                    _InfoItem(
                      title: loc.t('StatsInfoItem5Title'),
                      description: loc.t('StatsInfoItem5Desc'),
                      color: const Color(0xFF06B6D4),
                    ),
                    const SizedBox(height: 12),
                    _InfoItem(
                      title: loc.t('StatsInfoItem6Title'),
                      description: loc.t('StatsInfoItem6Desc'),
                      color: const Color(0xFFEC4899),
                    ),
                    const SizedBox(height: 16),

                    // ─── Dipnot ───
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Text(
                        loc.t('StatsInfoNote'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ─── Kapat Butonu ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      loc.t('StatsInfoClose'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tek bilgi satırı ───
class _InfoItem extends StatelessWidget {
  final String title;
  final String description;
  final Color color;

  const _InfoItem({
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
